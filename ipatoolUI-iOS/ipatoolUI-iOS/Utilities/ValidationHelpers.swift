import Foundation

/// Validation helpers for app ID, bundle ID, search term, etc.
enum ValidationHelpers {
    /// Returns whether either app ID or bundle ID is valid.
    static func isValidAppIDOrBundleID(appID: String, bundleID: String) -> Bool {
        if let _ = Int64(appID), !appID.isEmpty {
            return true
        }
        return !bundleID.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Returns whether the bundle ID is non-empty (after trim).
    static func isValidBundleID(_ bundleID: String) -> Bool {
        !bundleID.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Returns whether the version ID is non-empty (after trim).
    static func isValidVersionID(_ versionID: String) -> Bool {
        !versionID.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Returns whether the search term is non-empty (after trim).
    static func isValidSearchTerm(_ term: String) -> Bool {
        !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Returns whether both email and password are non-empty.
    static func isValidEmailAndPassword(email: String, password: String) -> Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    /// Parses the string as an App ID (Int64). Returns nil if empty or invalid.
    static func parseAppID(_ s: String) -> Int64? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Int64(t)
    }
}

/// String extension
extension String {
    var nonEmptyOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
