# ipatoolUI

A native iOS application for **downloading and installing** IPA files from the App Store. Connects to a dedicated HTTP API server (ipatool-api) that handles App Store operations and can install IPAs to a USB-connected device.

> **Note**: This is a personal tool project. Use at your own discretion.

## Project Overview

This repository contains two main components:

1. **`ipatool-api/`** – HTTP API server for App Store interactions (Go)
2. **`ipatoolUI-iOS/`** – Native iOS client application (SwiftUI)

### Component Relationship

```
┌─────────────────┐         HTTP API          ┌──────────────┐
│ ipatoolUI-iOS   │ ──────────────────────────> │ ipatool-api  │
│  (iOS Client)   │ <────────────────────────── │  (Server)    │
└─────────────────┘                             └──────────────┘
                                                         │
                                                         │ App Store API
                                                         ▼
                                                 ┌──────────────┐
                                                 │  App Store   │
                                                 └──────────────┘
```

**Important**: `ipatool-api` and `ipatoolUI-iOS` are designed to work together. The iOS app requires a running `ipatool-api` server instance to function.

## Quick Start

### For iOS Users

1. **Start the API server**:
   ```bash
   cd ipatool-api
   go build -o ipaserver .
   ./ipaserver -port 8080
   ```
   Optionally use API key authentication: `./ipaserver -port 8080 -api-key "your-secret-key"`  
   On some systems you may need to set `IPATOOL_KEYCHAIN_PASSPHRASE` for non-interactive keychain access.

2. **Build and run the iOS app**:
   - Open `ipatoolUI-iOS/ipatoolUI-iOS.xcodeproj` in Xcode
   - Configure the API base URL in Settings (default: `http://localhost:8080`)
   - Build and run on iOS 17+ device or simulator

See [`ipatoolUI-iOS/README.md`](ipatoolUI-iOS/README.md) for detailed iOS setup instructions.

## Requirements by OS

What you need to install depends on where you run **ipatool-api** (the server) and where you build **ipatoolUI-iOS** (the iOS app).

### Running ipatool-api (server)

| OS | To run the server | For Install to Device |
|----|-------------------|------------------------|
| **macOS** | [Go](https://go.dev/dl/) 1.19+, Apple ID | [ideviceinstaller](https://github.com/libimobiledevice/ideviceinstaller) (e.g. `brew install ideviceinstaller`). iPhone/iPad connected via USB. |
| **Linux** | Go 1.19+, Apple ID | [libimobiledevice](https://github.com/libimobiledevice/libimobiledevice) and **ideviceinstaller** (package name may be `ideviceinstaller` or `libimobiledevice-utils`). iPhone/iPad connected via USB. |
| **Windows** | Go 1.19+, Apple ID | Use [libimobiledevice-win32](https://github.com/libimobiledevice-win32) / [imobiledevice-net](https://github.com/libimobiledevice-win32/imobiledevice-net/releases) (Windows builds of libimobiledevice tools) to get an `ideviceinstaller`-style CLI; put it on PATH or set `IPATOOL_INSTALL_CMD`. iPhone/iPad connected via USB (iTunes/Apple USB drivers may be required). Auth, search, purchase, download work without this. |

- On **macOS**, non-interactive keychain access may require `IPATOOL_KEYCHAIN_PASSPHRASE`.
- Credentials: macOS Keychain, Linux Secret Service / file, Windows Credential Manager / file.

### Building and running ipatoolUI-iOS (iOS app)

| OS | Build / run |
|----|-------------|
| **macOS** | [Xcode](https://developer.apple.com/xcode/) 15+ (Swift 5.9+). Open `ipatoolUI-iOS/ipatoolUI-iOS.xcodeproj`, build and run on simulator or device (iOS 17+). |
| **Linux** | Cannot build the iOS app (Xcode is macOS-only). Use a Mac or CI on macOS to build. |
| **Windows** | Cannot build the iOS app (Xcode is macOS-only). Use a Mac or CI on macOS to build. |

The **iOS app** itself runs only on iPhone/iPad (or simulator on a Mac). The **server** (ipatool-api) can run on Windows, Linux, or macOS so that the app can connect to it over the network.

## Component Details

### ipatool-api

A server-only HTTP API for App Store interactions. Provides REST endpoints for authentication, search, purchase, version management, IPA download, and install to a USB-connected device. Runs on **Windows**, Linux, and macOS; Install to Device typically uses macOS/Linux (ideviceinstaller). Core App Store logic (`pkg/`) is kept in sync with [majd/ipatool](https://github.com/majd/ipatool); the server adds the API layer (`cmd/`).

- **Language**: Go
- **Requirements**: Go 1.19+ (1.23 recommended), Apple ID
- **Documentation**: [`ipatool-api/README.md`](ipatool-api/README.md)

**Key Features**:
- REST API for remote clients
- Streaming downloads for multi-GB files
- Install IPA to device (via `ideviceinstaller` on server host)
- Optional API key authentication
- Structured JSON logging
- Automatic port selection

### ipatoolUI-iOS

Native iOS application built with SwiftUI. Connects to `ipatool-api` server to provide a full-featured App Store client.

- **Language**: Swift
- **Requirements**: iOS 17.0+, Xcode 15.0+
- **Documentation**: [`ipatoolUI-iOS/README.md`](ipatoolUI-iOS/README.md)

**Key Features**:
- Authentication, Search, Purchase, Version list & metadata, IPA Download, Install to device (via server)
- File management: share, delete, delete after share, delete all downloaded IPAs
- Multi-language: Japanese, English, Simplified Chinese (Settings → [App] → Language)
- Currency formatting with locale selection
- Long-press to copy bundle ID or version
- Optimized downloads for large files
- Modern iOS 17+ UI design

## Architecture

### Server-Client Architecture

The iOS app (`ipatoolUI-iOS`) communicates with the API server (`ipatool-api`) via HTTP REST API:

- **Authentication**: `/api/v1/auth/*`
- **Search**: `/api/v1/search`
- **Purchase**: `/api/v1/purchase`
- **Versions**: `/api/v1/versions`
- **Version Metadata**: `/api/v1/metadata`
- **Download**: `/api/v1/download`
- **Install**: `/api/v1/install` (install IPA to USB-connected device from server host)

The server handles all App Store interactions and provides a clean API interface for clients.

### Network Configuration

For local development:
- **iOS Simulator**: Use `http://localhost:8080`
- **Physical Device**: Use `http://<server-ip>:8080` (e.g., `http://192.168.1.100:8080`)

The iOS app includes App Transport Security (ATS) configuration to allow local network connections.

## Development

### Building from Source

**API Server**:
```bash
cd ipatool-api
go build -o ipaserver .
```

**iOS App**:
```bash
cd ipatoolUI-iOS
open ipatoolUI-iOS.xcodeproj
# Build in Xcode
```

### Project Structure

```
ipatoolUI/
├── ipatool-api/          # Go HTTP API server
│   ├── main.go           # Entry point
│   ├── cmd/              # API layer: routing, handlers, middleware, types, validation
│   │   ├── server.go     # RunServer, routing, tryListen
│   │   ├── handlers.go  # HTTP handlers (auth, search, purchase, versions, download)
│   │   ├── middleware.go # CORS, rate limit, logging, session, API key
│   │   ├── api_types.go # Request/response DTOs
│   │   ├── install.go   # Install-to-device handler
│   │   ├── helpers.go   # requireAccountInfo, resolveApp, doAutoPurchaseIfNeeded
│   │   ├── response.go  # JSON response, error mapping
│   │   ├── validation.go # Input validation
│   │   └── security.go  # Rate limiter, getClientIP, sanitization
│   ├── pkg/              # Core packages (synced with upstream ipatool)
│   └── README.md         # Server documentation
├── ipatoolUI-iOS/        # iOS SwiftUI client
│   ├── ipatoolUI-iOS/    # Source code (ViewModels, Views, Services, Utilities)
│   └── README.md         # iOS documentation
└── README.md             # This file
```

## License

MIT License - See [`ipatool-api/LICENSE`](ipatool-api/LICENSE) for details.

## Disclaimer

This is a personal tool project. Use at your own risk. The tools interact with Apple's App Store and may be subject to Apple's Terms of Service.
