package cmd

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"unicode"
)

// Validation constants
const (
	MaxEmailLength     = 200
	MaxAuthCodeLength  = 10
	MaxTermLength      = 200
	MaxLimit           = 200
	MaxBundleIDLength  = 200
	MaxVersionIDLength = 100
	CountryCodeLength  = 2
)

// Validation patterns
var (
	emailRegex    = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
	bundleIDRegex = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9\-_\.]*[a-zA-Z0-9]$|^[a-zA-Z0-9]+$`)
	versionRegex  = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9\-_\.]*$`)
)

// Validation helpers
func validateEmail(email string) error {
	if email == "" {
		return fmt.Errorf("email is required")
	}
	if len(email) > MaxEmailLength {
		return fmt.Errorf("email is too long (max %d characters)", MaxEmailLength)
	}
	// Security: Validate email format
	if !emailRegex.MatchString(email) {
		return fmt.Errorf("invalid email format")
	}
	// Security: Check for control characters
	for _, char := range email {
		if unicode.IsControl(char) {
			return fmt.Errorf("email contains invalid characters")
		}
	}
	return nil
}

func validateAuthCode(authCode string) error {
	if len(authCode) > MaxAuthCodeLength {
		return fmt.Errorf("auth_code is too long (max %d characters)", MaxAuthCodeLength)
	}
	return nil
}

func validateTerm(term string) error {
	if term == "" {
		return fmt.Errorf("term parameter is required")
	}
	if len(term) > MaxTermLength {
		return fmt.Errorf("term parameter is too long (max %d characters)", MaxTermLength)
	}
	// Security: Check for control characters
	for _, char := range term {
		if unicode.IsControl(char) && char != '\n' && char != '\r' && char != '\t' {
			return fmt.Errorf("term contains invalid characters")
		}
	}
	return nil
}

func validateLimit(limitStr string) (int64, error) {
	if limitStr == "" {
		return 25, nil
	}
	limit, err := strconv.ParseInt(limitStr, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid limit parameter")
	}
	if limit < 1 {
		return 0, fmt.Errorf("limit parameter must be at least 1")
	}
	if limit > MaxLimit {
		return 0, fmt.Errorf("limit parameter cannot exceed %d", MaxLimit)
	}
	return limit, nil
}

func validateCountryCode(country string) error {
	if country == "" {
		return nil
	}
	if len(country) != CountryCodeLength {
		return fmt.Errorf("country parameter must be a %d-letter country code", CountryCodeLength)
	}
	// Security: Validate country code is uppercase letters only
	for _, char := range country {
		if !unicode.IsLetter(char) || !unicode.IsUpper(char) {
			return fmt.Errorf("country parameter must be a 2-letter uppercase country code")
		}
	}
	return nil
}

func validateBundleID(bundleID string) error {
	if bundleID == "" {
		return fmt.Errorf("bundle_id is required")
	}
	if len(bundleID) > MaxBundleIDLength {
		return fmt.Errorf("bundle_id is too long (max %d characters)", MaxBundleIDLength)
	}
	return nil
}

func validateVersionID(versionID string) error {
	if versionID == "" {
		return fmt.Errorf("version_id parameter is required")
	}
	if len(versionID) > MaxVersionIDLength {
		return fmt.Errorf("version_id is too long (max %d characters)", MaxVersionIDLength)
	}
	// Security: Validate version ID format
	if !versionRegex.MatchString(versionID) {
		return fmt.Errorf("invalid version_id format")
	}
	// Security: Check for path traversal attempts
	if strings.Contains(versionID, "..") || strings.Contains(versionID, "/") || strings.Contains(versionID, "\\") {
		return fmt.Errorf("version_id contains invalid characters")
	}
	// Security: Check for control characters
	for _, char := range versionID {
		if unicode.IsControl(char) {
			return fmt.Errorf("version_id contains invalid characters")
		}
	}
	return nil
}

func validateAppIDOrBundleID(appIDStr string, bundleID string) error {
	if appIDStr != "" {
		if _, err := strconv.ParseInt(appIDStr, 10, 64); err != nil {
			return fmt.Errorf("invalid app_id")
		}
		return nil
	}
	if bundleID == "" {
		return fmt.Errorf("app_id or bundle_id is required")
	}
	if len(bundleID) > MaxBundleIDLength {
		return fmt.Errorf("bundle_id is too long (max %d characters)", MaxBundleIDLength)
	}
	return nil
}

func validateExternalVersionID(versionID string) error {
	if versionID == "" {
		return nil
	}
	if len(versionID) > MaxVersionIDLength {
		return fmt.Errorf("external_version_id is too long (max %d characters)", MaxVersionIDLength)
	}
	// Security: Validate version ID format
	if !versionRegex.MatchString(versionID) {
		return fmt.Errorf("invalid external_version_id format")
	}
	// Security: Check for path traversal attempts
	if strings.Contains(versionID, "..") || strings.Contains(versionID, "/") || strings.Contains(versionID, "\\") {
		return fmt.Errorf("external_version_id contains invalid characters")
	}
	// Security: Check for control characters
	for _, char := range versionID {
		if unicode.IsControl(char) {
			return fmt.Errorf("external_version_id contains invalid characters")
		}
	}
	return nil
}
