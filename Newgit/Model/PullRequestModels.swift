import Foundation

// Models for Pull Requests UI
public struct PullRequest: Identifiable, Equatable {
    public let number: Int
    public let title: String
    public let state: String
    public let url: String
    public let body: String?
    public let webUrl: String?
    public let author: String?
    public let assignees: [String]
    public let headRefName: String?
    public let baseRefName: String?
    public let merged: Bool?

    public init(number: Int, title: String, state: String, url: String, body: String? = nil, webUrl: String? = nil, author: String? = nil, assignees: [String] = [], headRefName: String? = nil, baseRefName: String? = nil, merged: Bool? = nil) {
        self.number = number
        self.title = title
        self.state = state
        self.url = url
        self.body = body
        self.webUrl = webUrl
        self.author = author
        self.assignees = assignees
        self.headRefName = headRefName
        self.baseRefName = baseRefName
        self.merged = merged
    }

    public var id: Int { number }
}

// Reuse existing Comment model from IssueModels.swift for PR threads
