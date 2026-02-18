import Foundation
import Combine

@MainActor
final class SearchViewModel: BaseViewModel {
    @Published var term: String = ""
    @Published var limit: Double = 5
    @Published var results: [AppInfo] = []
    @Published var isSearching: Bool = false
    @Published var feedback: String?
    @Published private(set) var artworkCache: [Int64: URL] = [:]
    @Published private(set) var purchasedKeys: Set<String> = []
    @Published private(set) var pendingPurchaseKeys: Set<String> = []
    @Published private(set) var lastUsedCountryCode: String? = nil
    
    private let purchaseStatusChecker: PurchaseStatusChecker
    
    override init() {
        self.purchaseStatusChecker = PurchaseStatusChecker(apiService: APIService.shared)
        super.init()
    }
    
    func search(countryCode: String? = nil) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ValidationHelpers.isValidSearchTerm(trimmed) else {
            activeError = .serverError(400, localizationManager.strings.searchTermRequired)
            return
        }
        feedback = nil
        runAsync(
            setLoading: { [weak self] in
                self?.isSearching = true
                self?.isLoading = true
            },
            unsetLoading: { [weak self] in
                self?.isSearching = false
                self?.isLoading = false
            },
            operation: { [weak self] in
                guard let self else { return }
                self.lastUsedCountryCode = countryCode
                let response = try await apiService.search(
                    term: trimmed,
                    limit: Int(self.limit),
                    countryCode: countryCode
                )
                self.results = response.apps
                self.feedback = "\(response.count)\(self.localizationManager.strings.appsFound)"
                self.scheduleArtworkFetch(for: response.apps)
                self.refreshPurchaseStatus(for: response.apps)
            }
        )
    }
    
    func purchase(bundleID: String?) {
        guard let bundleID = bundleID, ValidationHelpers.isValidBundleID(bundleID) else {
            activeError = .serverError(400, localizationManager.strings.bundleIDRequired)
            return
        }
        feedback = nil
        runAsync(operation: { [weak self] in
            guard let self else { return }
            let response = try await apiService.purchase(bundleID: bundleID)
            if response.success {
                self.feedback = "\(bundleID) \(self.localizationManager.strings.purchaseSuccess)"
                let key = self.purchaseStatusChecker.purchaseKey(forBundle: bundleID)
                self.purchasedKeys.insert(key)
            } else {
                self.feedback = self.localizationManager.strings.purchaseCompletedNoFlag
            }
        })
    }
    
    func artworkURL(for app: AppInfo) -> URL? {
        if let artworkURL = app.artworkURL, let url = URL(string: artworkURL) {
            return url
        }
        if let id = app.trackID {
            return artworkCache[id]
        }
        return nil
    }
    
    func isPurchased(app: AppInfo) -> Bool {
        if let bundle = app.bundleID {
            if purchasedKeys.contains(purchaseStatusChecker.purchaseKey(forBundle: bundle)) {
                return true
            }
        }
        if let trackID = app.trackID {
            return purchasedKeys.contains(purchaseStatusChecker.purchaseKey(forTrackID: trackID))
        }
        return false
    }
    
    func ensurePurchaseStatus(for app: AppInfo) async {
        guard let key = purchaseStatusChecker.purchaseKey(for: app) else { return }
        
        // Skip if already checked
        if purchasedKeys.contains(key) || pendingPurchaseKeys.contains(key) {
            return
        }
        
        // Mark as checking
        pendingPurchaseKeys.insert(key)
        defer {
            pendingPurchaseKeys.remove(key)
        }
        
        // Check purchase status
        let isPurchased = await purchaseStatusChecker.checkPurchaseStatus(for: app)
        if isPurchased {
            purchasedKeys.insert(key)
        }
    }
    
    func isCheckingPurchase(for app: AppInfo) -> Bool {
        if let bundle = app.bundleID,
           pendingPurchaseKeys.contains(purchaseStatusChecker.purchaseKey(forBundle: bundle)) {
            return true
        }
        if let trackID = app.trackID,
           pendingPurchaseKeys.contains(purchaseStatusChecker.purchaseKey(forTrackID: trackID)) {
            return true
        }
        return false
    }
}

private extension SearchViewModel {
    func scheduleArtworkFetch(for apps: [AppInfo]) {
        let missingIDs = apps
            .compactMap { $0.trackID }
            .filter { artworkCache[$0] == nil }
        guard !missingIDs.isEmpty else { return }
        
        Task { [weak self] in
            guard let self else { return }
            do {
                let lookupService = AppLookupService.shared
                let map = try await lookupService.lookupArtwork(trackIDs: missingIDs)
                for (id, url) in map {
                    self.artworkCache[id] = url
                }
            } catch {
                // Ignore errors (icons will remain as placeholders)
            }
        }
    }
    
    func refreshPurchaseStatus(for apps: [AppInfo]) {
        Task { [weak self] in
            guard let self else { return }
            for app in apps {
                await self.ensurePurchaseStatus(for: app)
            }
        }
    }
}

