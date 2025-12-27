import Foundation

// Shared models for Issues UI
public struct Issue: Identifiable, Equatable {
    public let number: Int
    public let title: String
    public let state: String
    public let url: String
    public let body: String?
    public let webUrl: String?
    // Author login who opened the issue
    public let author: String?
    // Assignees' logins
    public let assignees: [String]

    public init(number: Int, title: String, state: String, url: String, body: String?, webUrl: String? = nil, author: String? = nil, assignees: [String] = []) {
        self.number = number
        self.title = title
        self.state = state
        self.url = url
        self.body = body
        self.webUrl = webUrl
        self.author = author
        self.assignees = assignees
    }

    public var id: Int { number }
}

public struct Comment: Identifiable {
    public let id: UUID
    public let author: String
    public let body: String
    public let createdAtRaw: String

    public init(id: UUID = UUID(), author: String, body: String, createdAtRaw: String) {
        self.id = id
        self.author = author
        self.body = body
        self.createdAtRaw = createdAtRaw
    }

    public var createdAt: Date? {
        ISO8601DateFormatter().date(from: createdAtRaw)
    }

    public func formattedString() -> String {
        if let d = createdAt {
            let fmt = RelativeDateTimeFormatter()
            fmt.unitsStyle = .short
            return fmt.localizedString(for: d, relativeTo: Date())
        }
        return createdAtRaw
    }
}
