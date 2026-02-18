package cmd

import (
	"context"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/mux"
	"github.com/majd/ipatool/v2/pkg/log"
)

// Session management for protected endpoints
var (
	lastActivityTime = make(map[string]time.Time)
	sessionMu        sync.RWMutex
)

func accountInfoMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		accountInfo, err := dependencies.AppStore.AccountInfo()
		if err != nil {
			statusCode, message := mapAppStoreErrorToHTTPStatus(err)
			respondError(w, statusCode, message)
			return
		}

		ip := getClientIP(r)
		sessionMu.Lock()
		lastActivity, exists := lastActivityTime[ip]
		if exists {
			timeSinceLastActivity := time.Since(lastActivity)
			if timeSinceLastActivity > time.Duration(sessionTimeoutHours)*time.Hour {
				sessionMu.Unlock()
				respondError(w, http.StatusUnauthorized, "Session expired. Please login again.")
				return
			}
		}
		lastActivityTime[ip] = time.Now()
		sessionMu.Unlock()

		ctx := context.WithValue(r.Context(), "accountInfo", accountInfo)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func initSessionCleanup() {
	go func() {
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()
		for range ticker.C {
			sessionMu.Lock()
			now := time.Now()
			for ip, lastActivity := range lastActivityTime {
				if now.Sub(lastActivity) > time.Duration(sessionTimeoutHours)*time.Hour {
					delete(lastActivityTime, ip)
				}
			}
			sessionMu.Unlock()
		}
	}()
}

func apiKeyMiddleware(apiKey string) mux.MiddlewareFunc {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := r.Header.Get("X-API-Key")
			if key == "" || key != apiKey {
				respondError(w, http.StatusUnauthorized, "Invalid API key")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if corsAllowedOrigins == "" {
			w.Header().Set("Access-Control-Allow-Origin", "*")
		} else {
			allowed := strings.Split(corsAllowedOrigins, ",")
			for _, allowedOrig := range allowed {
				if strings.TrimSpace(allowedOrig) == origin {
					w.Header().Set("Access-Control-Allow-Origin", origin)
					break
				}
			}
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-API-Key")
		w.Header().Set("Access-Control-Max-Age", "3600")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func rateLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := getClientIP(r)
		if !globalRateLimiter.isAllowed(ip, r.URL.Path) {
			respondError(w, http.StatusTooManyRequests, "Rate limit exceeded. Please try again later.")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func bodySizeLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var maxSize int64 = 1024 * 1024
		path := r.URL.Path
		if strings.HasPrefix(path, "/api/v1/download") {
			maxSize = 10 * 1024 * 1024
		} else if strings.HasPrefix(path, "/api/v1/auth/login") {
			maxSize = 2 * 1024
		}
		r.Body = http.MaxBytesReader(w, r.Body, maxSize)
		next.ServeHTTP(w, r)
	})
}

func loggingMiddleware(logger log.Logger) mux.MiddlewareFunc {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			requestID := generateRequestID()
			start := time.Now()
			wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
			ctx := context.WithValue(r.Context(), "requestID", requestID)
			r = r.WithContext(ctx)
			safeURI := maskSensitiveData(r.RequestURI)

			next.ServeHTTP(wrapped, r)

			duration := time.Since(start)
			statusCode := wrapped.statusCode
			if shouldLogRequest(r, statusCode) {
				if statusCode >= 500 {
					logger.Error().
						Str("request_id", requestID).Str("method", r.Method).Str("path", safeURI).
						Str("ip", getClientIP(r)).Int("status", statusCode).Dur("duration", duration).
						Msg("Server error")
				} else if statusCode >= 400 {
					logger.Error().
						Str("request_id", requestID).Str("method", r.Method).Str("path", safeURI).
						Str("ip", getClientIP(r)).Int("status", statusCode).Dur("duration", duration).
						Msg("Client error")
				} else if statusCode >= 200 && statusCode < 300 && isCriticalEndpoint(r.RequestURI) {
					logger.Log().
						Str("request_id", requestID).Str("method", r.Method).Str("path", safeURI).
						Int("status", statusCode).Dur("duration", duration).
						Msg("Request completed")
				}
			}
		})
	}
}

func shouldLogRequest(r *http.Request, statusCode int) bool {
	path := r.RequestURI
	if strings.Contains(path, ".png") || strings.Contains(path, ".jpg") ||
		strings.Contains(path, ".jpeg") || strings.Contains(path, ".gif") ||
		strings.Contains(path, ".ico") || strings.Contains(path, ".svg") {
		return false
	}
	if path == "/health" && statusCode == 200 {
		return false
	}
	if isCriticalEndpoint(path) {
		return true
	}
	return statusCode >= 400
}

func isCriticalEndpoint(path string) bool {
	criticalPaths := []string{
		"/api/v1/auth/login", "/api/v1/auth/info", "/api/v1/auth/revoke",
		"/api/v1/search", "/api/v1/purchase", "/api/v1/download",
		"/api/v1/versions", "/api/v1/metadata",
	}
	for _, p := range criticalPaths {
		if strings.HasPrefix(path, p) {
			return true
		}
	}
	return false
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func init() {
	initSessionCleanup()
}
