package cmd

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gorilla/mux"
)

var version = "dev"

// RunServer starts the HTTP API server with the specified port and optional API key.
func RunServer(port int, apiKey string) error {
	initServer(true)
	return runServer(port, apiKey)
}

func runServer(port int, apiKey string) error {
	router := mux.NewRouter()
	router.StrictSlash(true)
	api := router.PathPrefix("/api/v1").Subrouter()
	if apiKey != "" {
		api.Use(apiKeyMiddleware(apiKey))
	}
	api.Use(corsMiddleware)
	api.Use(rateLimitMiddleware)
	api.Use(loggingMiddleware(dependencies.Logger))
	api.Use(bodySizeLimitMiddleware)

	protectedAPI := api.PathPrefix("").Subrouter()
	protectedAPI.Use(accountInfoMiddleware)

	auth := api.PathPrefix("/auth").Subrouter()
	auth.HandleFunc("/login", handleAuthLogin).Methods("POST")
	auth.HandleFunc("/info", handleAuthInfo).Methods("GET")
	auth.HandleFunc("/revoke", handleAuthRevoke).Methods("POST")

	protectedAPI.HandleFunc("/search", handleSearch).Methods("GET")
	protectedAPI.HandleFunc("/purchase", handlePurchase).Methods("POST")
	protectedAPI.HandleFunc("/versions", handleListVersions).Methods("GET")
	protectedAPI.HandleFunc("/metadata", handleVersionMetadata).Methods("GET")
	protectedAPI.HandleFunc("/download", handleDownload).Methods("POST")
	protectedAPI.HandleFunc("/install", handleInstall).Methods("POST")

	router.HandleFunc("/health", handleHealth).Methods("GET")
	router.HandleFunc("/", handleRoot).Methods("GET")
	router.NotFoundHandler = http.HandlerFunc(handleNotFound)

	addr := fmt.Sprintf(":%d", port)
	listener, actualPort, err := tryListen(addr)
	if err != nil {
		return fmt.Errorf("failed to start server: %w", err)
	}
	if actualPort != port {
		dependencies.Logger.Log().Msgf("Port %d is in use, using random port %d instead", port, actualPort)
		if portFile := os.Getenv("IPATOOL_PORT_FILE"); portFile != "" {
			if err := os.WriteFile(portFile, []byte(fmt.Sprintf("%d\n", actualPort)), 0644); err != nil {
				dependencies.Logger.Error().Err(err).Msg("Failed to write port to file")
			}
		}
		fmt.Fprintf(os.Stdout, "Server running on port %d\n", actualPort)
	}

	httpServer := &http.Server{
		Addr:           listener.Addr().String(),
		Handler:        router,
		ReadTimeout:    30 * time.Second,
		WriteTimeout:   2 * time.Hour,
		IdleTimeout:    300 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		dependencies.Logger.Log().Msgf("Starting ipatool HTTP server on port %d", actualPort)
		if apiKey != "" {
			dependencies.Logger.Log().Msg("API key authentication enabled")
		}
		if err := httpServer.Serve(listener); err != nil && err != http.ErrServerClosed {
			dependencies.Logger.Error().Err(err).Msg("Server error")
			os.Exit(1)
		}
	}()

	<-sigChan
	dependencies.Logger.Log().Msg("Shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(ctx); err != nil {
		return fmt.Errorf("error shutting down server: %w", err)
	}
	dependencies.Logger.Log().Msg("Server stopped gracefully")
	return nil
}

func tryListen(addr string) (net.Listener, int, error) {
	listener, err := net.Listen("tcp", addr)
	if err == nil {
		return listener, listener.Addr().(*net.TCPAddr).Port, nil
	}
	if isPortInUseError(err) {
		randomListener, err := net.Listen("tcp", ":0")
		if err != nil {
			return nil, 0, fmt.Errorf("failed to listen on random port: %w", err)
		}
		return randomListener, randomListener.Addr().(*net.TCPAddr).Port, nil
	}
	return nil, 0, err
}

func isPortInUseError(err error) bool {
	if err == nil {
		return false
	}
	s := err.Error()
	return strings.Contains(s, "address already in use") ||
		strings.Contains(s, "bind: address already in use") ||
		strings.Contains(s, "port is already allocated")
}
