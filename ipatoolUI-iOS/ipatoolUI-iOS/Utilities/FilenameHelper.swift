import Foundation

/// Helpers for generating safe filenames.
enum FilenameHelper {
    /// Produces a safe filename from an app name (e.g. for .ipa).
    static func sanitize(name: String) -> String {
        let sanitized = name.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "-",
            options: .regularExpression
        )
        return sanitized.isEmpty ? "ipatool-download.ipa" : "\(sanitized).ipa"
    }
    
    /// Produces a filename from a bundle ID.
    static func filename(fromBundleID bundleID: String) -> String {
        sanitize(name: bundleID)
    }
    
    /// Produces a filename from an app ID.
    static func filename(fromAppID appID: String) -> String {
        "App-\(appID).ipa"
    }
    
    /// Default download filename.
    static let defaultFilename = "ipatool-download.ipa"
}
