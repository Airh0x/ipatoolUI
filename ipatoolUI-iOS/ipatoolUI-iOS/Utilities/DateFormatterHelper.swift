import Foundation

/// Helpers for formatting dates.
enum DateFormatterHelper {
    /// Converts an ISO8601 date string to a localized date string.
    static func formatDate(_ dateString: String, locale: Locale) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        displayFormatter.locale = locale
        return displayFormatter.string(from: date)
    }
}
