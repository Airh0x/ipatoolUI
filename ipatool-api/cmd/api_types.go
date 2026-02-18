package cmd

import (
	"github.com/majd/ipatool/v2/pkg/appstore"
)

// API request/response types for HTTP endpoints.

// AuthLoginRequest represents a login request.
type AuthLoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	AuthCode string `json:"auth_code,omitempty"`
}

// AuthLoginResponse represents a login response.
type AuthLoginResponse struct {
	Success     bool   `json:"success"`
	Email       string `json:"email,omitempty"`
	Name        string `json:"name,omitempty"`
	CountryCode string `json:"country_code,omitempty"`
}

// AuthInfoResponse represents account information response.
type AuthInfoResponse struct {
	Email       string `json:"email,omitempty"`
	Name        string `json:"name,omitempty"`
	CountryCode string `json:"country_code,omitempty"`
}

// SearchResponse represents a search results response.
type SearchResponse struct {
	Count int       `json:"count"`
	Apps  []AppInfo `json:"apps"`
}

// AppInfo is the app representation in API responses.
type AppInfo struct {
	TrackID    int64   `json:"track_id,omitempty"`
	BundleID   string  `json:"bundle_id,omitempty"`
	Name       string  `json:"name,omitempty"`
	Version    string  `json:"version,omitempty"`
	Price      float64 `json:"price,omitempty"`
	ArtworkURL string  `json:"artwork_url,omitempty"`
}

func appToAppInfo(app appstore.App) AppInfo {
	return AppInfo{
		TrackID:    app.ID,
		BundleID:   app.BundleID,
		Name:       app.Name,
		Version:    app.Version,
		Price:      app.Price,
		ArtworkURL: "", // upstream App no longer exposes artwork URL fields
	}
}

// PurchaseRequest represents a purchase request.
type PurchaseRequest struct {
	BundleID string `json:"bundle_id"`
}

// PurchaseResponse represents a purchase response.
type PurchaseResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
}

// ListVersionsResponse represents list versions response.
type ListVersionsResponse struct {
	BundleID           string   `json:"bundle_id,omitempty"`
	ExternalVersionIDs []string `json:"external_version_identifiers"`
	Success            bool     `json:"success"`
}

// VersionMetadataResponse represents version metadata response.
type VersionMetadataResponse struct {
	Success           bool   `json:"success"`
	ExternalVersionID string `json:"external_version_id,omitempty"`
	DisplayVersion    string `json:"display_version,omitempty"`
	ReleaseDate       string `json:"release_date,omitempty"`
}

// DownloadRequest represents a download request.
type DownloadRequest struct {
	AppID             int64  `json:"app_id,omitempty"`
	BundleID          string `json:"bundle_id,omitempty"`
	ExternalVersionID string `json:"external_version_id,omitempty"`
	AutoPurchase      bool   `json:"auto_purchase,omitempty"`
}
