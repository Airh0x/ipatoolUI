# ipatoolUI-iOS

A native iOS client for **downloading and installing** IPA files from the App Store. It connects to the **ipatool-api** HTTP server (Go) and provides a full-featured SwiftUI interface: download IPAs to the device or install them directly to a USB-connected iPhone/iPad via the server.

> **Note**: This is a client-only app. It requires a running [ipatool-api](../ipatool-api/) server to function. See [Project Overview](#project-overview) and [Setup](#setup).

## Project Overview

This app is part of the [ipatoolUI](../README.md) project:

```
┌─────────────────┐         HTTP API          ┌──────────────┐
│ ipatoolUI-iOS   │ ────────────────────────> │ ipatool-api  │
│  (this app)     │ <──────────────────────── │  (server)    │
└─────────────────┘                             └──────────────┘
                                                         │
                                                         ▼
                                                ┌──────────────┐
                                                │  App Store   │
                                                └──────────────┘
```

- **ipatool-api** ([../ipatool-api/](../ipatool-api/)): Go HTTP API server. Handles Apple ID auth, search, purchase, versions, IPA download, and install to a USB-connected device.
- **ipatoolUI-iOS** (this app): SwiftUI iOS app. All App Store operations go through ipatool-api.

## Features

Download IPA files to this device or **install them directly to a USB-connected iPhone/iPad** via the ipatool-api server. All operations (auth, search, purchase, versions, download, install) go through the server.

### Core Functionality

| Feature | Description |
|--------|-------------|
| **Authentication** | Sign in with Apple ID, view account info, revoke credentials (handled by server) |
| **App Search** | Search by name, bundle ID, or app ID; optional country code |
| **License Purchase** | Purchase app licenses via the server |
| **Version List** | List all available versions for an app; copy version or download from list |
| **Version Metadata** | Fetch metadata for a specific version |
| **IPA Download** | Download IPA with progress; supports multi-GB files (streaming to disk) |
| **Install to Device** | Install downloaded IPA to a USB-connected device via ipatool-api (server runs `ideviceinstaller` etc.) |
| **File Management** | List downloaded IPAs; share, delete individual, or delete all; optional “delete after share” |
| **Activity Logs** | View operation logs in-app |

### User Experience

- **Localization**: Japanese, English, Simplified Chinese. Language is changed in **Settings → [App name] → Language** (system per-app language).
- **Currency**: Locale-based price formatting with manual country override.
- **Long-press**: Copy bundle ID or version string from lists.
- **Direct download**: Start download from the Versions list for a specific version.
- **About**: App icon, author (Freemathon), overview, links (ipatoolUI-iOS), Special Thanks (ipatool, ipatoolUI macOS).
- **Modern UI**: SwiftUI, tab-based navigation, iOS 17+ design.

## Requirements

- **iOS**: 17.0 or later
- **Xcode**: 15.0 or later (Swift 5.9+)
- **ipatool-api**: Server must be running and reachable (see [Setup](#setup))

## Setup

### 1. Start ipatool-api

From the project root:

```bash
cd ipatool-api
go build -o ipaserver .
./ipaserver -port 8080
```

With API key (recommended for non-local use):

```bash
./ipaserver -port 8080 -api-key "your-secret-key"
```

On some systems you may need `IPATOOL_KEYCHAIN_PASSPHRASE` for non-interactive keychain access. See [ipatool-api README](../ipatool-api/README.md) for options and production setup.

### 2. Configure the iOS App

1. Open the app → **Settings** tab.
2. Set **API Base URL**:
   - Simulator: `http://localhost:8080` or `http://127.0.0.1:8080`
   - Device on same network: `http://<server-ip>:8080` (e.g. `http://192.168.1.100:8080`)
   - Remote: `https://your-server.com:8080`
3. If the server uses an API key, set **API Key** (stored in Keychain).

### 3. Network

- **Simulator**: `localhost` / `127.0.0.1` work with the ATS exceptions in the app.
- **Physical device**: Device and server must be on the same network (or use a remote URL). Allow **Local Network** when the app prompts.
- **Bonjour**: The app declares local network usage for connecting to ipatool-api.

## Usage Guide

### Authentication

1. **Authentication** tab → enter Apple ID email and password.
2. If 2FA is on, enter the code when prompted.
3. **Sign In** → use **Account Info** to confirm; **Delete Auth** to revoke on the server.

### Search

1. **Search** tab → enter name, bundle ID, or app ID.
2. Optionally set country for results.
3. Results show icon, name, price, bundle ID; long-press bundle ID to copy.

### Purchase

1. **Purchase** tab → enter app ID or bundle ID (and optional external version ID if needed).
2. Tap **Purchase**. App must be purchasable in your region.

### Versions

1. **Versions** tab → enter app ID or bundle ID → **List Versions**.
2. Long-press a version to copy or start download for that version.

### Download

1. **Download** tab → app ID or bundle ID, optional version ID.
2. Turn **Auto Purchase** on to buy the license if needed.
3. Tap **Download**; progress is shown. Use **Share File**, **Delete File**, or manage the list of downloaded IPAs (delete one or all). Option **Delete IPA after share** in Settings removes the file after sharing.

### Install to Device

1. **Install** tab → enter Bundle ID (or App ID), optional version ID and device UDID → turn **Auto Purchase** on if needed → tap **Install to device**.
2. The app sends the request to ipatool-api. The **server** (Mac/PC) then: downloads the IPA from the App Store to a temp file → runs the install command (e.g. `ideviceinstaller install <path>`) on the server machine → the IPA is installed on the **iPhone/iPad that is USB-connected to that server**.
3. The device that receives the app is the one **USB-connected to the machine running ipatool-api**, not the device running the app (unless they are the same). See [ipatool-api README – Install flow](../ipatool-api/README.md#install-flow-what-happens-when-you-tap-install-in-the-app) for the full step-by-step.

### Version Metadata

1. **Version Metadata** tab → app ID or bundle ID + external version ID.
2. Tap **Fetch Metadata** to load details.

### Settings

- **API Base URL** / **API Key**: Server connection (API key stored in Keychain).
- **Delete IPA after share**: Remove the last downloaded file after sharing.
- **Currency locale**: For price display.
- **About**: App info, author (Freemathon), links, Special Thanks.

**Language**: Change in **Settings → [App name] → Language** (system per-app language). Restart the app if needed after changing.

## Project Structure

```
ipatoolUI-iOS/
├── ipatoolUI-iOS/                 # Source
│   ├── ipatoolUI_iOSApp.swift     # App entry point
│   ├── Assets.xcassets/           # App icon, AboutAppIcon, AccentColor
│   ├── en.lproj/
│   ├── ja.lproj/
│   ├── zh-Hans.lproj/             # Localizable.strings
│   ├── Services/
│   │   ├── APIService.swift        # REST client for ipatool-api
│   │   ├── AppLookupService.swift # iTunes lookup (e.g. app name, size)
│   │   ├── FileManagerService.swift # Documents: save, list, delete, share IPA
│   │   ├── KeychainService.swift  # Secure storage for API key
│   │   └── PurchaseStatusChecker.swift
│   ├── Models/
│   │   ├── AppState.swift         # Global state, Feature, Preferences
│   │   ├── APIResponseModels.swift # DTOs for API responses
│   │   ├── CountryCode.swift      # Country list and currency mapping
│   │   ├── CurrencyFormatter.swift # Price formatting
│   │   └── Localization.swift     # NSLocalizedString keys (ja/en/zh-Hans)
│   ├── ViewModels/
│   │   ├── BaseViewModel.swift   # runAsync, handleError, clearError; shared by all
│   │   ├── AuthViewModel.swift
│   │   ├── SearchViewModel.swift
│   │   ├── PurchaseViewModel.swift
│   │   ├── ListVersionsViewModel.swift
│   │   ├── DownloadViewModel.swift
│   │   ├── InstallViewModel.swift
│   │   └── VersionMetadataViewModel.swift
│   ├── Views/
│   │   ├── MainView.swift         # TabView and feature routing
│   │   ├── AuthView.swift
│   │   ├── SearchView.swift
│   │   ├── PurchaseView.swift
│   │   ├── ListVersionsView.swift
│   │   ├── DownloadView.swift
│   │   ├── InstallView.swift
│   │   ├── VersionMetadataView.swift
│   │   ├── LogsView.swift
│   │   ├── SettingsView.swift
│   │   └── AboutView.swift
│   └── Utilities/
│       ├── AsyncSemaphore.swift
│       ├── DateFormatterHelper.swift
│       ├── FilenameHelper.swift
│       └── ValidationHelpers.swift  # Input validation + parseAppID for API calls
├── Info.plist                     # ATS, local network, Bonjour, CFBundleLocalizations
└── README.md                      # This file
```

## Technical Details

### Architecture

- **MVVM**: Views, ViewModels, shared Models and Services.
- **Combine** and **async/await** for state and network.
- **MainActor** for UI updates.
- **BaseViewModel.runAsync**: Shared pattern for async operations (loading state, clearError, handleError, optional custom setLoading/unsetLoading). All ViewModels use it for API calls.
- **ValidationHelpers**: Centralized input validation and `parseAppID(_:)` for converting app ID strings to `Int64?` for API requests. Search, download, install, versions, and metadata flows use it.
- **API responses**: `AppInfo.artworkURL` may be empty (server does not return artwork); the app uses `AppLookupService` for icons when needed.

### Download Behaviour

Tuned for large IPAs (multi-GB):

- Streaming to a file (not full blob in memory).
- 4 MB write buffer.
- Resource timeout 2 hours (7200 s); request timeout 60 s.
- Progress reported by bytes; connection reuse via default URLSession.

### Security

- **API key**: Stored in Keychain (`KeychainService`), not in UserDefaults.
- **Credentials**: Apple ID is sent to ipatool-api only; not stored in the app.
- **Network**: ATS allows local networking and localhost HTTP; arbitrary loads disabled. Prefer HTTPS and API key for non-local servers.

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| Connection refused | ipatool-api is running and reachable; correct **API Base URL** and port. |
| Local network blocked | Allow local network when the app asks; same Wi‑Fi as server. |
| Timeouts | Network stability; server load; for downloads, 2 h resource timeout. |
| 403 | Server uses API key → set **API Key** in Settings. |
| Slow / failed download | Check server logs; confirm app is downloadable and (if needed) purchased. |
| Auth / 2FA | Correct Apple ID/password; enter 2FA code when prompted. |
| Language not updating | Restart app after changing language in **Settings → [App name] → Language**. |
| Install fails | iPhone connected via USB to the machine running ipatool-api; `ideviceinstaller` (or `IPATOOL_INSTALL_CMD`) available on server. |

## Development

### Build

1. Open `ipatoolUI-iOS/ipatoolUI-iOS.xcodeproj` in Xcode.
2. Select target device or simulator.
3. Build and run (⌘R).

### Dependencies

- Apple frameworks only (no third-party pods/SPM for the app).
- Runtime dependency: a running **ipatool-api** instance.

## License

Same license as the parent project. See [../ipatool-api/LICENSE](../ipatool-api/LICENSE) and [../README.md](../README.md).

## Disclaimer

This is a personal tool project. Use at your own risk. Use of the app and server with the App Store may be subject to Apple’s terms and policies.
