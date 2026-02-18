import Foundation
import Combine

@MainActor
final class DownloadViewModel: BaseViewModel {
    @Published var appIDString: String = ""
    @Published var bundleIdentifier: String = ""
    @Published var externalVersionID: String = ""
    @Published var shouldAutoPurchase: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadedBytes: Int64 = 0
    @Published var expectedBytes: Int64?
    @Published var suggestedFilename: String = "App.ipa"
    @Published var lastDownloadedURL: URL? = nil
    @Published var downloadedFileURLs: [URL] = []
    
    private let fileManagerService = FileManagerService.shared
    private let lookupService = AppLookupService.shared
    private var cachedAppName: String? {
        didSet { updateSuggestedFilename() }
    }
    
    func download() {
        guard ValidationHelpers.isValidAppIDOrBundleID(appID: appIDString, bundleID: bundleIdentifier) else {
            activeError = .serverError(400, localizationManager.strings.appIDOrBundleIDRequiredError)
            return
        }
        statusMessage = nil
        downloadedBytes = 0
        runAsync(
            setLoading: { [weak self] in
                self?.isDownloading = true
                self?.isLoading = true
            },
            unsetLoading: { [weak self] in
                self?.isDownloading = false
                self?.isLoading = false
                self?.expectedBytes = nil
                self?.downloadedBytes = 0
            },
            operation: { [weak self] in
                guard let self else { return }
                if let expected = await self.fetchExpectedSize() {
                    self.expectedBytes = expected
                }
                let (tempFileURL, filename) = try await apiService.downloadToFile(
                    bundleID: self.bundleIdentifier.isEmpty ? nil : self.bundleIdentifier,
                    appID: ValidationHelpers.parseAppID(self.appIDString),
                    externalVersionID: self.externalVersionID.isEmpty ? nil : self.externalVersionID,
                    autoPurchase: self.shouldAutoPurchase
                ) { downloaded, total in
                    Task { @MainActor in
                        self.downloadedBytes = downloaded
                        self.expectedBytes = total
                    }
                }
                let fileURL = try fileManagerService.moveToDocuments(from: tempFileURL, filename: filename)
                self.lastDownloadedURL = fileURL
                self.statusMessage = "\(filename) \(self.localizationManager.strings.fileSaved)"
                self.refreshDownloadedFilesList()
            }
        )
    }
    
    private func fetchExpectedSize() async -> Int64? {
        let trimmedBundle = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBundle.isEmpty, let item = await lookupService.lookup(bundleID: trimmedBundle) {
            await MainActor.run {
                if let name = item.trackName?.nonEmptyOrNil {
                    cachedAppName = name
                }
            }
            if let bytes = item.fileSizeBytes, let parsed = Int64(bytes) {
                return parsed
            }
        }
        if let appID = ValidationHelpers.parseAppID(appIDString), let item = await lookupService.lookup(appID: appID) {
            await MainActor.run {
                if let name = item.trackName?.nonEmptyOrNil {
                    cachedAppName = name
                }
            }
            if let bytes = item.fileSizeBytes, let parsed = Int64(bytes) {
                return parsed
            }
        }
        return nil
    }
    
    func ensureSuggestedFilename() {
        if let cached = cachedAppName?.nonEmptyOrNil {
            suggestedFilename = FilenameHelper.sanitize(name: cached)
            return
        }
        if let bundle = bundleIdentifier.nonEmptyOrNil {
            suggestedFilename = FilenameHelper.filename(fromBundleID: bundle)
            return
        }
        if let appID = appIDString.nonEmptyOrNil {
            suggestedFilename = FilenameHelper.filename(fromAppID: appID)
            return
        }
        suggestedFilename = FilenameHelper.defaultFilename
    }
    
    private func updateSuggestedFilename() {
        ensureSuggestedFilename()
    }
    
    func deleteDownloadedFile() {
        guard let fileURL = lastDownloadedURL else {
            activeError = .serverError(404, localizationManager.strings.fileNotFound)
            return
        }
        
        do {
            try fileManagerService.deleteFile(at: fileURL)
            lastDownloadedURL = nil
            statusMessage = localizationManager.strings.fileDeleted
            clearError()
            refreshDownloadedFilesList()
        } catch {
            handleError(error)
        }
    }
    
    /// Refresh the list of IPA files in Documents (for Downloaded IPAs section)
    func refreshDownloadedFilesList() {
        downloadedFileURLs = fileManagerService.listIPAFiles()
    }
    
    /// Delete a specific IPA file (from the list)
    func deleteFile(at url: URL) {
        do {
            try fileManagerService.deleteFile(at: url)
            if lastDownloadedURL == url {
                lastDownloadedURL = nil
            }
            statusMessage = localizationManager.strings.fileDeleted
            clearError()
            refreshDownloadedFilesList()
        } catch {
            handleError(error)
        }
    }
    
    /// Delete all IPA files in Documents
    func deleteAllDownloadedFiles() {
        do {
            try fileManagerService.deleteAllIPAFiles()
            lastDownloadedURL = nil
            statusMessage = localizationManager.strings.allIPAsDeleted
            clearError()
            refreshDownloadedFilesList()
        } catch {
            handleError(error)
        }
    }
    
    /// Called when share sheet is dismissed; deletes last downloaded file if "Delete IPA after share" is on
    func deleteLastDownloadedFileAfterShare() {
        guard let fileURL = lastDownloadedURL else { return }
        do {
            try fileManagerService.deleteFile(at: fileURL)
            lastDownloadedURL = nil
            statusMessage = localizationManager.strings.fileDeleted
            refreshDownloadedFilesList()
        } catch {
            handleError(error)
        }
    }
}
