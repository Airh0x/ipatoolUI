import Foundation

// MARK: - Authentication Responses

struct AuthLoginResponse: Codable {
    let success: Bool
    let email: String?
    let name: String?
    let countryCode: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case email
        case name
        case countryCode = "country_code"
    }
}

struct AuthInfoResponse: Codable {
    let email: String?
    let name: String?
    let countryCode: String?
    
    enum CodingKeys: String, CodingKey {
        case email
        case name
        case countryCode = "country_code"
    }
}

// MARK: - Search Response

struct SearchResponse: Codable {
    let count: Int
    let apps: [AppInfo]
}

struct AppInfo: Codable, Identifiable, Hashable {
    let trackID: Int64?
    let bundleID: String?
    let name: String?
    let version: String?
    let price: Double?
    /// Server may omit artwork (upstream change). Use AppLookupService etc. when empty.
    let artworkURL: String?
    
    var id: String {
        if let trackID = trackID {
            return "\(trackID)"
        }
        return bundleID ?? UUID().uuidString
    }
    
    enum CodingKeys: String, CodingKey {
        case trackID = "track_id"
        case bundleID = "bundle_id"
        case name
        case version
        case price
        case artworkURL = "artwork_url"
    }
}

// MARK: - Purchase Response

struct PurchaseResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Versions Response

struct ListVersionsResponse: Codable {
    let bundleID: String?
    let externalVersionIDs: [String]
    let success: Bool
    
    enum CodingKeys: String, CodingKey {
        case bundleID = "bundle_id"
        case externalVersionIDs = "external_version_identifiers"
        case success
    }
}

// MARK: - Install Response

struct InstallResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Metadata Response

struct VersionMetadataResponse: Codable {
    let success: Bool
    let externalVersionID: String?
    let displayVersion: String?
    let releaseDate: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case externalVersionID = "external_version_id"
        case displayVersion = "display_version"
        case releaseDate = "release_date"
    }
}

// MARK: - Error Response

struct ErrorResponse: Codable {
    let error: String
    let message: String?
    let code: Int?
}
