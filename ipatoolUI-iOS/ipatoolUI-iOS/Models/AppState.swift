import SwiftUI
import Combine

enum Feature: String, CaseIterable, Identifiable {
    case auth
    case search
    case purchase
    case listVersions
    case download
    case install
    case metadata
    case logs
    case settings
    case about
    
    var id: String { rawValue }
    
    func title(using strings: LocalizedStrings) -> String {
        switch self {
        case .auth: return strings.authentication
        case .search: return strings.search
        case .purchase: return strings.purchase
        case .listVersions: return strings.versions
        case .download: return strings.download
        case .install: return strings.install
        case .metadata: return strings.versionMetadata
        case .logs: return strings.logs
        case .settings: return strings.settings
        case .about: return strings.about
        }
    }
    
    var icon: String {
        switch self {
        case .auth: return "person.badge.key"
        case .search: return "magnifyingglass"
        case .purchase: return "cart"
        case .listVersions: return "list.number"
        case .download: return "arrow.down.circle"
        case .install: return "arrow.down.to.line.circle"
        case .metadata: return "info.circle"
        case .logs: return "note.text"
        case .settings: return "gear"
        case .about: return "info.square"
        }
    }
}

struct Preferences: Codable, Equatable {
    var apiBaseURL: String
    var apiKey: String
    var selectedCountryCode: String? // User-selected locale for currency display (nil means auto-detect)
    var deleteIPAAfterShare: Bool? // Delete downloaded IPA after sharing (nil = false for backward compatibility)
    
    static let `default` = Preferences(
        apiBaseURL: "http://localhost:8080",
        apiKey: "",
        selectedCountryCode: nil,
        deleteIPAAfterShare: false
    )
}

@MainActor
final class AppState: ObservableObject {
    @Published var preferences: Preferences {
        didSet {
            PreferencesStore.shared.save(preferences)
            updateLanguage()
            updateEffectiveCountryCode()
        }
    }
    
    @Published var selectedFeature: Feature = .auth
    @Published var accountCountryCode: String? = nil
    @Published var effectiveCountryCode: String? = nil
    
    private var systemCountryCode: String? = nil
    
    let localizationManager = LocalizationManager.shared
    let apiService = APIService.shared
    let authViewModel = AuthViewModel()
    let searchViewModel = SearchViewModel()
    let downloadViewModel = DownloadViewModel()
    let installViewModel = InstallViewModel()
    let listVersionsViewModel = ListVersionsViewModel()
    let versionMetadataViewModel = VersionMetadataViewModel()
    let purchaseViewModel = PurchaseViewModel()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        preferences = PreferencesStore.shared.load()
        
        // Initialize language from preferences
        updateLanguage()
        
        // Set initial country code from system locale
        systemCountryCode = Self.getSystemCountryCode()
        accountCountryCode = systemCountryCode
        updateEffectiveCountryCode()
        
        // Update API configuration
        apiService.updateConfiguration(
            baseURL: preferences.apiBaseURL,
            apiKey: preferences.apiKey.isEmpty ? nil : preferences.apiKey
        )
        
        // Observe account country code
        authViewModel.$countryCode
            .compactMap { $0 }
            .assign(to: &$accountCountryCode)
        
        // Update effective country code when account country code changes
        $accountCountryCode
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateEffectiveCountryCode()
                }
            }
            .store(in: &cancellables)
        
        // Update effective country code when preferences change
        $preferences
            .map { $0.selectedCountryCode }
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateEffectiveCountryCode()
                }
            }
            .store(in: &cancellables)
        
        // Observe preference changes
        $preferences
            .sink { [weak self] newPreferences in
                self?.apiService.updateConfiguration(
                    baseURL: newPreferences.apiBaseURL,
                    apiKey: newPreferences.apiKey.isEmpty ? nil : newPreferences.apiKey
                )
            }
            .store(in: &cancellables)
    }
    
    private func updateEffectiveCountryCode() {
        // Effective country code to use (selected locale > account locale > system locale)
        if let selected = preferences.selectedCountryCode, !selected.isEmpty {
            effectiveCountryCode = selected
        } else if let account = accountCountryCode, !account.isEmpty {
            effectiveCountryCode = account
        } else {
            effectiveCountryCode = systemCountryCode ?? Self.getSystemCountryCode()
        }
    }
    
    /// Get country code from system locale
    private static func getSystemCountryCode() -> String? {
        // First, try to get country code from current locale (iOS 16+)
        if #available(iOS 16.0, *) {
            if let regionCode = Locale.current.region?.identifier {
                return regionCode
            }
        }
        
        // Fallback: Extract country code from locale identifier
        let localeIdentifier = Locale.current.identifier
        if let range = localeIdentifier.range(of: "_") {
            let countryCode = String(localeIdentifier[range.upperBound...])
            if countryCode.count == 2 {
                return countryCode.uppercased()
            }
        }
        
        // Further fallback: Guess from language settings
        if let preferredLanguage = Locale.preferredLanguages.first {
            let components = preferredLanguage.components(separatedBy: "-")
            if components.count >= 2, components[1].count == 2 {
                return components[1].uppercased()
            }
        }
        
        return nil
    }
    
    private func updateLanguage() {
        // Language is now from Settings → [App] → Language (or system). No in-app override.
    }
}

struct PreferencesStore {
    static let shared = PreferencesStore()
    
    private let storageKey = "com.ipatoolui.ios.preferences"
    private let keychainService = KeychainService.shared
    
    func load() -> Preferences {
        var prefs: Preferences
        
        // Load non-sensitive preferences from UserDefaults
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Preferences.self, from: data) {
            prefs = decoded
        } else {
            prefs = Preferences.default
        }
        
        // Security: Load API key from Keychain (not UserDefaults)
        if let apiKey = keychainService.getAPIKey() {
            prefs.apiKey = apiKey
        } else {
            prefs.apiKey = ""
        }
        
        return prefs
    }
    
    func save(_ preferences: Preferences) {
        // Security: Save API key to Keychain separately
        if !preferences.apiKey.isEmpty {
            _ = keychainService.saveAPIKey(preferences.apiKey)
        } else {
            _ = keychainService.deleteAPIKey()
        }
        
        // Save non-sensitive preferences to UserDefaults (without API key)
        var prefsToSave = preferences
        prefsToSave.apiKey = "" // Don't save API key to UserDefaults
        
        guard let data = try? JSONEncoder().encode(prefsToSave) else {
            return
        }
        
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
