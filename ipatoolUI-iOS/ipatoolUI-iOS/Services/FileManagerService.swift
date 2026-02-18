import Foundation

/// Service providing shared file-management logic.
@MainActor
final class FileManagerService {
    static let shared = FileManagerService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    /// Returns the app Documents directory URL.
    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Returns the system temporary directory URL.
    var temporaryDirectory: URL {
        fileManager.temporaryDirectory
    }
    
    /// Creates a new temporary file and returns its URL.
    func createTempFile(extension ext: String = "ipa") throws -> URL {
        let tempDir = temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        
        if !fileManager.fileExists(atPath: tempFileURL.path) {
            fileManager.createFile(atPath: tempFileURL.path, contents: nil, attributes: nil)
        }
        
        return tempFileURL
    }
    
    /// Moves a file from the given URL into the Documents directory with the specified filename.
    func moveToDocuments(from sourceURL: URL, filename: String) throws -> URL {
        var destinationURL = documentsDirectory.appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        try? destinationURL.setResourceValues(resourceValues)
        
        return destinationURL
    }
    
    /// Deletes the file at the given URL.
    func deleteFile(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
    
    /// Returns whether a file exists at the given URL.
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
    
    /// Returns .ipa file URLs in Documents, sorted by modification date (newest first).
    func listIPAFiles() -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }
        
        return contents
            .filter { $0.pathExtension.lowercased() == "ipa" }
            .sorted { url1, url2 in
                let d1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 > d2
            }
    }
    
    /// Deletes all .ipa files in the Documents directory.
    func deleteAllIPAFiles() throws {
        let urls = listIPAFiles()
        for url in urls {
            try fileManager.removeItem(at: url)
        }
    }
}
