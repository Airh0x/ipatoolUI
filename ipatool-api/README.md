# ipatool-api

A dedicated HTTP API server for App Store interactions: authentication, search, purchase, version management, **IPA download**, and **install to a USB-connected device**. Clients (e.g. [ipatoolUI-iOS](../ipatoolUI-iOS/)) can download IPAs or have the server install them to a connected iPhone/iPad (e.g. via `ideviceinstaller`). Server-only API (no CLI).

[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Features

- **REST API**: Full REST API for App Store interactions
- **Authentication**: Apple ID login, account info, and credential management
- **App Search**: Search the App Store for iOS applications
- **License Purchase**: Purchase app licenses via API
- **Version Management**: List and retrieve metadata for app versions
- **IPA Download**: Download IPA files with streaming support for multi-GB files
- **Install to Device**: Install IPA to a USB-connected iPhone/iPad from the server host (e.g. via `ideviceinstaller`)
- **API Key Authentication**: Optional API key protection for endpoints
- **Structured Logging**: JSON-formatted logs for production environments

## Requirements

- Supported operating system: **Windows**, Linux, or macOS
- Go 1.19+ (for building from source)
- Apple ID set up to use the App Store
- For **Install to Device**: iPhone/iPad connected via USB to the machine running the server; `ideviceinstaller` (or override via `IPATOOL_INSTALL_CMD`) on the server host. **Install to Device** is typically used on macOS/Linux (where `ideviceinstaller` is available); on Windows you can still run the server for auth, search, purchase, download—only the install step requires a compatible tool on the server.

### Windows

The server runs on **Windows**. Authentication, search, purchase, version list, metadata, and **IPA download** all work; credentials are stored via Windows Credential Manager (or file backend). For **Install to Device** on Windows, use [libimobiledevice-win32](https://github.com/libimobiledevice-win32) or [imobiledevice-net](https://github.com/libimobiledevice-win32/imobiledevice-net/releases) (Windows builds of libimobiledevice tools) to get an `ideviceinstaller`-compatible CLI; put the executable on PATH or set `IPATOOL_INSTALL_CMD` to its path. iPhone/iPad must be connected via USB (iTunes for Windows / Apple USB drivers may be required for pairing).

## Security Features

This server includes comprehensive security measures:

- **CORS Protection**: Configurable allowed origins via `CORS_ALLOWED_ORIGINS` environment variable
- **Rate Limiting**: IP-based rate limiting per endpoint (login: 5/15min, purchase: 20/hour, download: 10/hour)
- **Request Size Limits**: Body size limits per endpoint to prevent memory exhaustion attacks
- **Input Validation**: Strict validation for email, bundle IDs, version IDs with regex patterns
- **Path Traversal Protection**: Filename sanitization to prevent directory traversal attacks
- **Session Timeout**: Automatic session expiration after 24 hours of inactivity
- **API Key Security**: API keys only accepted via headers (not URL parameters)
- **Error Message Sanitization**: Generic error messages in production mode (set `DEBUG=true` for detailed errors)
- **Security Headers**: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection
- **Sensitive Data Masking**: Passwords and API keys are masked in logs

## Installation

### Building from Source

```bash
# From the ipatoolUI repo (or your clone)
cd ipatool-api
go build -o ipaserver .
# Binary: ipaserver
```

## Usage

### Starting the Server

```bash
# Start server on default port (8080)
./ipaserver

# Start server on custom port
./ipaserver -port 9090

# Start server with API key authentication
./ipaserver -port 8080 -api-key "your-secret-key"
```

### Command Line Options

- `-port`: HTTP server port (default: 8080)
- `-api-key`: API key for authentication (optional, recommended for production)

### Environment Variables

- `IPATOOL_KEYCHAIN_PASSPHRASE`: Keychain passphrase for non-interactive keychain access (required if keychain is locked)
- `CORS_ALLOWED_ORIGINS`: Comma-separated list of allowed CORS origins (default: all origins allowed for development)
  - Example: `CORS_ALLOWED_ORIGINS=http://localhost:3000,https://example.com`
- `DEBUG`: Set to `true` to enable detailed error messages (default: `false`)
- `IPATOOL_PORT_FILE`: Optional file path to write the actual port number when using random port
- `IPATOOL_INSTALL_CMD`: Override the install command (default: `ideviceinstaller`). Server runs `<cmd> install <path>` or `<cmd> -u <UDID> install <path>`. Sample wrappers: [scripts/install-ipa.example.sh](scripts/install-ipa.example.sh) (macOS/Linux), [scripts/install-ipa.example.ps1](scripts/install-ipa.example.ps1) (Windows). See [scripts/README.md](scripts/README.md).

## API Endpoints

### Authentication

#### `POST /api/v1/auth/login`
Authenticate with Apple ID.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "auth_code": "123456"  // Optional, for 2FA
}
```

**Response:**
```json
{
  "success": true,
  "email": "user@example.com",
  "name": "User Name",
  "country_code": "US"
}
```

#### `GET /api/v1/auth/info`
Get current account information.

**Response:**
```json
{
  "email": "user@example.com",
  "name": "User Name",
  "country_code": "US"
}
```

#### `POST /api/v1/auth/revoke`
Revoke stored authentication credentials.

**Response:**
```json
{
  "success": true
}
```

### App Search

#### `GET /api/v1/search`
Search for apps on the App Store.

**Query Parameters:**
- `term` (required): Search term
- `limit` (optional): Maximum number of results (default: 25)
- `country` (optional): Country code for localized search

**Example:**
```bash
curl "http://localhost:8080/api/v1/search?term=twitter&limit=10&country=US"
```

**Response:**
```json
{
  "count": 10,
  "apps": [
    {
      "track_id": 123456789,
      "bundle_id": "com.example.app",
      "name": "Example App",
      "version": "1.0.0",
      "price": 0.99,
      "artwork_url": ""
    }
  ]
}
```

Note: `artwork_url` may be empty (the server does not return artwork URLs from the upstream App Store response). Clients can use a separate lookup (e.g. iTunes Lookup API) for icons if needed.

### License Purchase

#### `POST /api/v1/purchase`
Purchase a license for an app.

**Request Body:**
```json
{
  "bundle_id": "com.example.app"
}
```

**Response:**
```json
{
  "success": true,
  "message": "License purchased successfully"
}
```

### Version Management

#### `GET /api/v1/versions`
List available versions for an app.

**Query Parameters:**
- `app_id` (optional): App ID
- `bundle_id` (optional): Bundle ID (takes precedence over app_id)

**Example:**
```bash
curl "http://localhost:8080/api/v1/versions?bundle_id=com.example.app"
```

**Response:**
```json
{
  "bundle_id": "com.example.app",
  "external_version_identifiers": ["1.0.0", "1.1.0", "2.0.0"],
  "success": true
}
```

#### `GET /api/v1/metadata`
Get metadata for a specific app version.

**Query Parameters:**
- `version_id` (required): External version identifier
- `bundle_id` (optional): Bundle ID
- `app_id` (optional): App ID

**Example:**
```bash
curl "http://localhost:8080/api/v1/metadata?version_id=1.0.0&bundle_id=com.example.app"
```

**Response:**
```json
{
  "success": true,
  "external_version_id": "1.0.0",
  "display_version": "1.0.0",
  "release_date": "2024-01-01T00:00:00Z"
}
```

### IPA Download

#### `POST /api/v1/download`
Download an IPA file. Supports streaming for large files (multi-GB).

**Request Body:**
```json
{
  "app_id": 123456789,              // Optional
  "bundle_id": "com.example.app",   // Optional (takes precedence)
  "external_version_id": "1.0.0",   // Optional (defaults to latest)
  "auto_purchase": true             // Optional (auto-purchase license if needed)
}
```

**Example:**
```bash
curl -X POST http://localhost:8080/api/v1/download \
  -H "Content-Type: application/json" \
  -d '{
    "bundle_id": "com.example.app",
    "auto_purchase": true
  }' \
  --output app.ipa
```

**Response:** Binary IPA file streamed directly.

### Install to Device

#### `POST /api/v1/install`
Download the IPA (same as download) to a temporary file on the server, then install it on a USB-connected device. The server runs the install command (default: `ideviceinstaller install <path>`). Override with `IPATOOL_INSTALL_CMD` (e.g. `ideviceinstaller` so that args are `install` and the path).

**Request Body:**
```json
{
  "app_id": 123456789,              // Optional
  "bundle_id": "com.example.app",   // Optional (takes precedence)
  "external_version_id": "1.0.0",   // Optional (defaults to latest)
  "auto_purchase": true,           // Optional (auto-purchase license if needed)
  "device_udid": ""                 // Optional (first connected device if empty)
}
```

**Example:**
```bash
curl -X POST http://localhost:8080/api/v1/install \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-secret-key" \
  -d '{"bundle_id": "com.example.app", "auto_purchase": true}'
```

**Response:**
```json
{
  "success": true,
  "message": "Installed successfully"
}
```

**Requirements:** iPhone/iPad connected via USB to the machine running ipatool-api; `ideviceinstaller` (or the command set in `IPATOOL_INSTALL_CMD`) available on that machine.

#### Install flow (what happens when you tap Install in the app)

1. **You (on the iOS app)**  
   Open the **Install** tab → enter Bundle ID (or App ID), optional version ID / device UDID → turn **Auto Purchase** on if needed → tap **Install to device**.

2. **App → server**  
   The app sends `POST /api/v1/install` to the ipatool-api server (Mac/PC) with the bundle ID, version, auto_purchase, and optional device UDID.

3. **Server (ipatool-api on the Mac/PC)**  
   - Validates the request and uses the stored Apple ID (you must be signed in on the server).  
   - If **Auto Purchase** is on, purchases the app license if needed.  
   - **Downloads the IPA from the App Store** to a temporary file on the **server machine** (e.g. `/tmp/ipatool-install-xxxxx.ipa`).  
   - Runs the install command on the server, e.g.  
     `ideviceinstaller install /tmp/ipatool-install-xxxxx.ipa`  
     or `ideviceinstaller -u <UDID> install /tmp/...`  
     (or whatever you set in `IPATOOL_INSTALL_CMD`).  
   - That command installs the IPA on the **iPhone/iPad that is connected via USB to the server** (the Mac/PC).  
   - Deletes the temporary IPA.  
   - Returns success or error to the app.

4. **Important**  
   The device that **receives** the installed app is the one **USB-connected to the machine running ipatool-api**, not necessarily the device running the app. Typical setup: **Mac running ipatool-api** + **one iPhone connected by USB to that Mac**; you use the app on that same iPhone (or on another device) to trigger install → the IPA is installed on the USB-connected iPhone.

### Health Check

#### `GET /health`
Check server status.

**Response:**
```json
{
  "status": "ok",
  "service": "ipatool-api"
}
```

#### `GET /`
Get API information and available endpoints.

**Response:**
```json
{
  "service": "ipatool-api",
  "version": "dev",
  "endpoints": {
    "health": "GET /health",
    "auth_login": "POST /api/v1/auth/login",
    "auth_info": "GET /api/v1/auth/info",
    "auth_revoke": "POST /api/v1/auth/revoke",
    "search": "GET /api/v1/search",
    "purchase": "POST /api/v1/purchase",
    "list_versions": "GET /api/v1/versions",
    "version_metadata": "GET /api/v1/metadata",
    "download": "POST /api/v1/download",
    "install": "POST /api/v1/install"
  }
}
```

## API Key Authentication

When API key authentication is enabled, all requests to `/api/v1/*` endpoints must include the API key in the `X-API-Key` header:

```bash
curl -H "X-API-Key: your-secret-key" \
  http://localhost:8080/api/v1/search?term=twitter
```

## CORS Support

The server includes CORS middleware to allow cross-origin requests from web applications.

## Logging

The server uses structured JSON logging. Logs include:

- Request ID for tracing
- HTTP method and path
- Status codes
- Request duration
- Error details

Only critical errors and important operations are logged by default.

## Server Configuration

The server is optimized for large file downloads:

- **Read Timeout**: 30 seconds
- **Write Timeout**: 2 hours (for multi-GB downloads)
- **Idle Timeout**: 300 seconds
- **Max Header Size**: 1MB

## Production Deployment

### Security Recommendations

1. **Use HTTPS**: Always use HTTPS in production. Use a reverse proxy (nginx, Caddy, etc.) with SSL/TLS termination.

2. **API Key Authentication**: Always enable API key authentication in production:
   ```bash
   ./ipaserver -port 8080 -api-key "strong-random-secret-key"
   ```

3. **Keychain Passphrase**: Set the keychain passphrase via environment variable:
   ```bash
   export IPATOOL_KEYCHAIN_PASSPHRASE="your-passphrase"
   ./ipaserver -port 8080 -api-key "your-api-key"
   ```

4. **Firewall**: Configure firewall rules to restrict access to the server port.

5. **Process Management**: Use a process manager (e.g. systemd, supervisor) to manage the server process.

### Example systemd Service

Create `/etc/systemd/system/ipatool-api.service`:

```ini
[Unit]
Description=ipatool-api HTTP API Server
After=network.target

[Service]
Type=simple
User=ipatool
WorkingDirectory=/opt/ipatool-api
Environment="IPATOOL_KEYCHAIN_PASSPHRASE=your-passphrase"
ExecStart=/opt/ipatool-api/ipaserver -port 8080 -api-key "your-api-key"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Then enable and start:

```bash
sudo systemctl enable ipatool-api
sudo systemctl start ipatool-api
```

## Code Structure

The server is organized for clear separation of concerns:

| Path | Purpose |
|------|---------|
| `main.go` | Entry point; parses flags and calls `cmd.RunServer` |
| `cmd/server.go` | Server bootstrap, routing, port selection (`tryListen`) |
| `cmd/handlers.go` | HTTP handlers for auth, search, purchase, versions, metadata, download |
| `cmd/install.go` | Install-to-device handler (download + run install command) |
| `cmd/middleware.go` | CORS, rate limiting, body size limit, logging, session, API key |
| `cmd/api_types.go` | API request/response types (e.g. `AuthLoginRequest`, `AppInfo`, `SearchResponse`) |
| `cmd/helpers.go` | Shared logic: `requireAccountInfo`, `resolveApp`, `doAutoPurchaseIfNeeded`, filename/headers |
| `cmd/response.go` | JSON response helpers and App Store error → HTTP status mapping |
| `cmd/validation.go` | Input validation (email, bundle ID, version ID, country, etc.) |
| `cmd/security.go` | Rate limiter config, `getClientIP`, filename sanitization, log masking |
| `pkg/` | App Store and HTTP/keychain/log/util packages; synced with [majd/ipatool](https://github.com/majd/ipatool) |

The API layer (`cmd/`) is specific to this server; `pkg/` is kept in sync with upstream ipatool so that fixes and new App Store behaviour are easy to incorporate. The server adds a small helper in `pkg/appstore/storefront.go` (`StoreFrontForCountryCode`) so that the search API can accept a `country` query parameter.

## Compiling

```bash
go build -o ipaserver .
go test -v ./...
```

## License

This project is released under the [MIT license](LICENSE).

## Differences from Original ipatool

This API-only version:

- **No CLI**: All command-line usage has been removed; runs exclusively as an HTTP API server.
- **Simplified initialization**: No interactive prompts; uses environment variables for configuration.
- **JSON logging**: Structured JSON logging.
- **Install endpoint**: Optional install-to-device flow (server runs `ideviceinstaller` or custom command).
- **Search country**: The search endpoint accepts a `country` query parameter (2-letter code); the server maps it to a store front via `StoreFrontForCountryCode` (API-specific helper in `pkg/appstore/storefront.go`).

Core App Store logic in `pkg/` is synced with [majd/ipatool](https://github.com/majd/ipatool); only the API layer in `cmd/` and the storefront helper are specific to this server.
