import Foundation

enum RepoNameSanitizer {
    static func forTyping(_ value: String) -> String {
        var sanitized = value.replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
        sanitized = sanitized.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return sanitized
    }

    static func forSaving(_ value: String) -> String {
        var sanitized = forTyping(value.trimmingCharacters(in: .whitespacesAndNewlines))
        while sanitized.hasPrefix("-") { sanitized.removeFirst() }
        while sanitized.hasSuffix("-") { sanitized.removeLast() }
        return sanitized
    }
}
