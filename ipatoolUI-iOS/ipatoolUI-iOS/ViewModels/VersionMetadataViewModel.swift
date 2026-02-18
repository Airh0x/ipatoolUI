import Foundation
import Combine

@MainActor
final class VersionMetadataViewModel: BaseViewModel {
    @Published var versionID: String = ""
    @Published var bundleID: String = ""
    @Published var appIDString: String = ""
    @Published var displayVersion: String?
    @Published var releaseDate: String?
    @Published var isFetching: Bool = false
    
    func fetchMetadata() {
        guard ValidationHelpers.isValidVersionID(versionID) else {
            activeError = .serverError(400, localizationManager.strings.versionIDRequiredError)
            return
        }
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
                let response = try await apiService.getVersionMetadata(
                    versionID: self.versionID,
                    bundleID: self.bundleID.isEmpty ? nil : self.bundleID,
                    appID: ValidationHelpers.parseAppID(self.appIDString)
                )
                if response.success {
                    self.displayVersion = response.displayVersion
                    self.releaseDate = response.releaseDate
                    self.statusMessage = self.localizationManager.strings.metadataFetched
                } else {
                    self.activeError = .serverError(500, self.localizationManager.strings.fetchMetadataFailed)
                }
            }
        )
    }
}
