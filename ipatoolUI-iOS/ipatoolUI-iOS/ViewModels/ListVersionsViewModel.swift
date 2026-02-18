import Foundation
import Combine

@MainActor
final class ListVersionsViewModel: BaseViewModel {
    @Published var bundleID: String = ""
    @Published var appIDString: String = ""
    @Published var versions: [String] = []
    @Published var isFetching: Bool = false
    
    func fetchVersions() {
        guard ValidationHelpers.isValidAppIDOrBundleID(appID: appIDString, bundleID: bundleID) else {
            activeError = .serverError(400, localizationManager.strings.appIDOrBundleIDRequiredError)
            return
        }
        statusMessage = nil
        runAsync(
            setLoading: { [weak self] in
                self?.isFetching = true
                self?.isLoading = true
            },
            unsetLoading: { [weak self] in
                self?.isFetching = false
                self?.isLoading = false
            },
            operation: { [weak self] in
                guard let self else { return }
                let response = try await apiService.listVersions(
                    bundleID: self.bundleID.isEmpty ? nil : self.bundleID,
                    appID: ValidationHelpers.parseAppID(self.appIDString)
                )
                if response.success {
                    self.versions = response.externalVersionIDs
                    self.statusMessage = "\(self.versions.count)\(self.localizationManager.strings.versionsFound)"
                } else {
                    self.activeError = .serverError(500, self.localizationManager.strings.fetchVersionsFailed)
                }
            }
        )
    }
}
