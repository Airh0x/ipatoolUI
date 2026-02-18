package cmd

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/majd/ipatool/v2/pkg/appstore"
)

func handleHealth(w http.ResponseWriter, r *http.Request) {
	respondSuccess(w, map[string]string{
		"status":  "ok",
		"service": "ipatool-api",
	})
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	respondSuccess(w, map[string]interface{}{
		"service": "ipatool-api",
		"version": version,
		"endpoints": map[string]string{
			"health":           "GET /health",
			"auth_login":       "POST /api/v1/auth/login",
			"auth_info":        "GET /api/v1/auth/info",
			"auth_revoke":      "POST /api/v1/auth/revoke",
			"search":           "GET /api/v1/search",
			"purchase":         "POST /api/v1/purchase",
			"list_versions":    "GET /api/v1/versions",
			"version_metadata": "GET /api/v1/metadata",
			"download":         "POST /api/v1/download",
			"install":          "POST /api/v1/install",
		},
	})
}

func handleNotFound(w http.ResponseWriter, r *http.Request) {
	respondError(w, http.StatusNotFound, fmt.Sprintf("Endpoint not found: %s %s", r.Method, r.URL.Path))
}

func handleAuthLogin(w http.ResponseWriter, r *http.Request) {
	var req AuthLoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}
	if err := validateEmail(req.Email); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.AuthCode != "" {
		if err := validateAuthCode(req.AuthCode); err != nil {
			respondError(w, http.StatusBadRequest, err.Error())
			return
		}
	}
	bagOut, err := dependencies.AppStore.Bag(appstore.BagInput{})
	if err != nil {
		dependencies.Logger.Error().Err(err).Msg("Auth login: failed to get auth endpoint")
		if handleAppStoreError(w, err) {
			return
		}
	}
	if bagOut.AuthEndpoint == "" {
		dependencies.Logger.Error().Msg("Auth login: auth endpoint is empty")
		respondError(w, http.StatusServiceUnavailable, "Authentication service unavailable. Try again later.")
		return
	}
	result, err := dependencies.AppStore.Login(appstore.LoginInput{
		Email:    req.Email,
		Password: req.Password,
		AuthCode: req.AuthCode,
		Endpoint: bagOut.AuthEndpoint,
	})
	if err != nil {
		dependencies.Logger.Error().Err(err).Msg("Auth login failed")
		if handleAppStoreError(w, err) {
			return
		}
	}
	respondSuccess(w, AuthLoginResponse{
		Success:     true,
		Email:       result.Account.Email,
		Name:        result.Account.Name,
		CountryCode: result.Account.StoreFront,
	})
}

func handleAuthInfo(w http.ResponseWriter, r *http.Request) {
	info, err := dependencies.AppStore.AccountInfo()
	if err != nil {
		code, _ := mapAppStoreErrorToHTTPStatus(err)
		if code != http.StatusNotFound {
			dependencies.Logger.Error().Err(err).Msg("Auth info failed")
		}
		if handleAppStoreError(w, err) {
			return
		}
	}
	respondSuccess(w, AuthInfoResponse{
		Email:       info.Account.Email,
		Name:        info.Account.Name,
		CountryCode: info.Account.StoreFront,
	})
}

func handleAuthRevoke(w http.ResponseWriter, r *http.Request) {
	if err := dependencies.AppStore.Revoke(); err != nil {
		code, _ := mapAppStoreErrorToHTTPStatus(err)
		if code != http.StatusNotFound {
			dependencies.Logger.Error().Err(err).Msg("Auth revoke failed")
		}
		if handleAppStoreError(w, err) {
			return
		}
	}
	respondSuccess(w, map[string]bool{"success": true})
}

func handleSearch(w http.ResponseWriter, r *http.Request) {
	term := r.URL.Query().Get("term")
	if err := validateTerm(term); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	limit, err := validateLimit(r.URL.Query().Get("limit"))
	if err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	countryCode := r.URL.Query().Get("country")
	if err := validateCountryCode(countryCode); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	accountInfo, ok := requireAccountInfo(w, r)
	if !ok {
		return
	}
	storeFront, err := appstore.StoreFrontForCountryCode(countryCode)
	if err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	account := accountInfo.Account
	account.StoreFront = storeFront
	result, err := dependencies.AppStore.Search(appstore.SearchInput{
		Account: account,
		Term:    term,
		Limit:   limit,
	})
	if err != nil {
		if handleAppStoreError(w, err) {
			return
		}
	}
	apps := make([]AppInfo, len(result.Results))
	for i, app := range result.Results {
		apps[i] = appToAppInfo(app)
	}
	respondSuccess(w, SearchResponse{Count: result.Count, Apps: apps})
}

func handlePurchase(w http.ResponseWriter, r *http.Request) {
	var req PurchaseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}
	if err := validateBundleID(req.BundleID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	accountInfo, ok := requireAccountInfo(w, r)
	if !ok {
		return
	}
	app := appstore.App{BundleID: req.BundleID}
	err := dependencies.AppStore.Purchase(appstore.PurchaseInput{
		Account: accountInfo.Account,
		App:     app,
	})
	if err != nil {
		dependencies.Logger.Error().Err(err).Str("bundleID", req.BundleID).Msg("Purchase failed")
		if handleAppStoreError(w, err) {
			return
		}
	}
	respondSuccess(w, PurchaseResponse{Success: true, Message: "License purchased successfully"})
}

func handleListVersions(w http.ResponseWriter, r *http.Request) {
	bundleID := r.URL.Query().Get("bundle_id")
	appIDStr := r.URL.Query().Get("app_id")
	if err := validateAppIDOrBundleID(appIDStr, bundleID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	accountInfo, ok := requireAccountInfo(w, r)
	if !ok {
		return
	}
	appID := int64(0)
	if appIDStr != "" {
		appID, _ = strconv.ParseInt(appIDStr, 10, 64)
	}
	app, err := resolveApp(accountInfo, appID, bundleID)
	if err != nil {
		dependencies.Logger.Error().Err(err).Str("bundle_id", bundleID).Msg("ListVersions: resolve app failed")
		if handleAppStoreError(w, err) {
			return
		}
	}
	result, err := dependencies.AppStore.ListVersions(appstore.ListVersionsInput{
		Account: accountInfo.Account,
		App:     app,
	})
	if err != nil {
		dependencies.Logger.Error().Err(err).Str("bundle_id", bundleID).Int64("app_id", app.ID).Msg("ListVersions: list versions failed")
		if handleAppStoreError(w, err) {
			return
		}
	}
	respondSuccess(w, ListVersionsResponse{
		BundleID:           app.BundleID,
		ExternalVersionIDs: result.ExternalVersionIdentifiers,
		Success:            true,
	})
}

func handleVersionMetadata(w http.ResponseWriter, r *http.Request) {
	versionID := r.URL.Query().Get("version_id")
	bundleID := r.URL.Query().Get("bundle_id")
	appIDStr := r.URL.Query().Get("app_id")
	if err := validateVersionID(versionID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := validateAppIDOrBundleID(appIDStr, bundleID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	accountInfo, ok := requireAccountInfo(w, r)
	if !ok {
		return
	}
	appID := int64(0)
	if appIDStr != "" {
		appID, _ = strconv.ParseInt(appIDStr, 10, 64)
	}
	app, err := resolveApp(accountInfo, appID, bundleID)
	if err != nil {
		if handleAppStoreError(w, err) {
			return
		}
	}
	result, err := dependencies.AppStore.GetVersionMetadata(appstore.GetVersionMetadataInput{
		Account:   accountInfo.Account,
		App:       app,
		VersionID: versionID,
	})
	if err != nil {
		if handleAppStoreError(w, err) {
			return
		}
	}
	respondSuccess(w, VersionMetadataResponse{
		Success:           true,
		ExternalVersionID: versionID,
		DisplayVersion:    result.DisplayVersion,
		ReleaseDate:       result.ReleaseDate.Format(time.RFC3339),
	})
}

func handleDownload(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Minute)
	defer cancel()
	r = r.WithContext(ctx)

	var req DownloadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}
	if err := validateAppIDOrBundleID(fmt.Sprintf("%d", req.AppID), req.BundleID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := validateExternalVersionID(req.ExternalVersionID); err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	accountInfo, ok := requireAccountInfo(w, r)
	if !ok {
		return
	}
	app, err := resolveApp(accountInfo, req.AppID, req.BundleID)
	if err != nil {
		dependencies.Logger.Error().Err(err).Str("bundleID", req.BundleID).Msg("Lookup failed")
		if handleAppStoreError(w, err) {
			return
		}
	}
	if err := doAutoPurchaseIfNeeded(accountInfo, app, req.AutoPurchase); err != nil {
		dependencies.Logger.Error().Err(err).Msg("AutoPurchase failed")
		if handleAppStoreError(w, err) {
			return
		}
	}
	if req.AutoPurchase {
		dependencies.Logger.Log().Msg("AutoPurchase: License purchased successfully")
	}

	tmpFile, err := os.CreateTemp("", "ipatool-*.ipa")
	if err != nil {
		dependencies.Logger.Error().Err(err).Msg("Failed to create temporary file")
		respondError(w, http.StatusInternalServerError, "Failed to create temporary file")
		return
	}
	tmpPath := tmpFile.Name()
	tmpFile.Close()
	defer func() {
		if err := os.Remove(tmpPath); err != nil {
			dependencies.Logger.Error().Err(err).Str("path", tmpPath).Msg("Failed to remove temporary file")
		}
	}()

	result, err := dependencies.AppStore.Download(appstore.DownloadInput{
		Account:           accountInfo.Account,
		App:               app,
		ExternalVersionID: req.ExternalVersionID,
		OutputPath:        tmpPath,
	})
	if err != nil {
		dependencies.Logger.Error().Err(err).Msg("Download failed")
		if handleAppStoreError(w, err) {
			return
		}
	}
	file, err := os.Open(result.DestinationPath)
	if err != nil {
		dependencies.Logger.Error().Err(err).Str("path", result.DestinationPath).Msg("Failed to open downloaded file")
		respondError(w, http.StatusInternalServerError, "Failed to open downloaded file")
		return
	}
	defer file.Close()
	filename := generateFilename(app, req.ExternalVersionID)
	fileInfo, err := file.Stat()
	if err != nil {
		dependencies.Logger.Error().Err(err).Str("path", result.DestinationPath).Msg("Failed to stat downloaded file")
		respondError(w, http.StatusInternalServerError, "Failed to get file information")
		return
	}
	setDownloadHeaders(w, filename, fileInfo.Size())
	buffer := make([]byte, 4*1024*1024)
	if _, err := io.CopyBuffer(w, file, buffer); err != nil {
		if err != io.ErrClosedPipe && err != io.EOF {
			dependencies.Logger.Error().Err(err).Msg("Error streaming file")
			if strings.Contains(err.Error(), "timeout") || strings.Contains(err.Error(), "broken pipe") {
				dependencies.Logger.Log().Err(err).Msg("Client disconnected or timeout during file streaming")
			}
		}
		return
	}
	dependencies.Logger.Log().Str("filename", filename).Int64("size", fileInfo.Size()).Msg("File downloaded and streamed successfully")
}
