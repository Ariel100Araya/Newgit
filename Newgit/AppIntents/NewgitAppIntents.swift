//
//  NewgitAppIntents.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/6/25.
//

import AppIntents
import Foundation

private enum RepoIntentError: LocalizedError {
    case missingDirectory(String)
    case notGitRepository(String)
    case commandFailed(String)
    case invalidInput(String)
    case failedToParse(String)

    var errorDescription: String? {
        switch self {
        case .missingDirectory(let path):
            return "The folder at \(path) doesn't exist or isn't a directory."
        case .notGitRepository(let path):
            return "\(path) is not a Git repository."
        case .commandFailed(let message):
            return message
        case .invalidInput(let message):
            return message
        case .failedToParse(let message):
            return message
        }
    }
}

private enum RepoIntentSupport {
    nonisolated static func presentableError(_ error: Error) -> Error {
        if let repoError = error as? RepoIntentError {
            return NSError(
                domain: "Newgit.AppIntents",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: repoError.errorDescription ?? "The action couldn't be completed."]
            )
        }

        return NSError(
            domain: "Newgit.AppIntents",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
        )
    }

    nonisolated static func savedRepositoryEntities() -> [SavedRepositoryEntity] {
        SavedRepoBackupStore.shared.savedSnapshots().map(SavedRepositoryEntity.init(snapshot:))
    }

    nonisolated static func repositoryEntity(for identifier: String) -> SavedRepositoryEntity? {
        savedRepositoryEntities().first { $0.id == identifier }
    }

    nonisolated static func issueEntities(at path: String) throws -> [SavedIssueEntity] {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)
        try ensureGHAuthenticated()

        let result = runGHCommand(
            ["issue", "list", "--state", "all", "--limit", "100", "--json", "number,title,state"],
            currentDirectory: normalizedPath
        )
        guard result.status == 0 else {
            throw RepoIntentError.commandFailed("Couldn't load issues: \(cleanedOutput(result.output))")
        }

        guard let data = result.output.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw RepoIntentError.failedToParse("Couldn't parse the issue list response.")
        }

        return array.compactMap { item in
            guard let number = item["number"] as? Int else { return nil }
            let title = (item["title"] as? String) ?? "Issue #\(number)"
            let state = ((item["state"] as? String) ?? "unknown").lowercased()
            return SavedIssueEntity(repositoryPath: normalizedPath, number: number, title: title, state: state)
        }
    }

    nonisolated static func issueEntity(for identifier: String) -> SavedIssueEntity? {
        let components = identifier.split(separator: "::", maxSplits: 1).map(String.init)
        guard components.count == 2, let number = Int(components[1]) else { return nil }
        let path = components[0]
        return try? issueEntities(at: path).first(where: { $0.number == number })
    }

    nonisolated static func pullRequestEntities(at path: String) throws -> [SavedPullRequestEntity] {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)
        try ensureGHAuthenticated()

        let result = runGHCommand(
            ["pr", "list", "--state", "all", "--limit", "100", "--json", "number,title,state,isDraft"],
            currentDirectory: normalizedPath
        )
        guard result.status == 0 else {
            throw RepoIntentError.commandFailed("Couldn't load pull requests: \(cleanedOutput(result.output))")
        }

        guard let data = result.output.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw RepoIntentError.failedToParse("Couldn't parse the pull request list response.")
        }

        return array.compactMap { item in
            guard let number = item["number"] as? Int else { return nil }
            let title = (item["title"] as? String) ?? "PR #\(number)"
            let state = ((item["state"] as? String) ?? "unknown").lowercased()
            let isDraft = (item["isDraft"] as? Bool) ?? false
            return SavedPullRequestEntity(
                repositoryPath: normalizedPath,
                number: number,
                title: title,
                state: state,
                isDraft: isDraft
            )
        }
    }

    nonisolated static func pullRequestEntity(for identifier: String) -> SavedPullRequestEntity? {
        let components = identifier.split(separator: "::", maxSplits: 1).map(String.init)
        guard components.count == 2, let number = Int(components[1]) else { return nil }
        let path = components[0]
        return try? pullRequestEntities(at: path).first(where: { $0.number == number })
    }

    nonisolated static func branchEntities(at path: String) throws -> [SavedBranchEntity] {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)

        let currentBranch = try currentBranch(at: normalizedPath)
        let result = runCommand("cd \(shellEscape(normalizedPath)) && git for-each-ref refs/heads --format='%(refname:short)'")
        guard result.status == 0 else {
            throw RepoIntentError.commandFailed("Couldn't load branches: \(cleanedOutput(result.output))")
        }

        let branches = cleanedOutput(result.output)
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }

        return branches.map { branch in
            SavedBranchEntity(repositoryPath: normalizedPath, name: branch, isCurrent: branch == currentBranch)
        }
    }

    nonisolated static func branchEntity(for identifier: String) -> SavedBranchEntity? {
        let components = identifier.split(separator: "::", maxSplits: 1).map(String.init)
        guard components.count == 2 else { return nil }
        let path = components[0]
        let name = components[1]
        return try? branchEntities(at: path).first(where: { $0.name == name })
    }

    nonisolated static func normalizedDirectory(at path: String) throws -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw RepoIntentError.invalidInput("Please provide a repository path.")
        }

        let standardizedPath = URL(fileURLWithPath: trimmedPath).standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardizedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw RepoIntentError.missingDirectory(standardizedPath)
        }

        return standardizedPath
    }

    nonisolated static func sanitizedRepositoryName(_ name: String) -> String {
        let pieces = name.split { $0.isWhitespace }
        let joined = pieces.joined(separator: "-")
        var sanitized = joined.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        while sanitized.hasPrefix("-") { sanitized.removeFirst() }
        while sanitized.hasSuffix("-") { sanitized.removeLast() }
        return sanitized
    }

    nonisolated static func defaultRepositoryName(for path: String) -> String {
        let component = URL(fileURLWithPath: path).lastPathComponent
        return sanitizedRepositoryName(component)
    }

    nonisolated static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    nonisolated static func ensureGitRepository(at path: String, initializeIfNeeded: Bool) throws {
        if isGitRepository(path) {
            return
        }

        guard initializeIfNeeded else {
            throw RepoIntentError.notGitRepository(path)
        }

        let result = runCommand("cd \(shellEscape(path)) && git init")
        guard result.status == 0 else {
            throw RepoIntentError.commandFailed("Git init failed: \(cleanedOutput(result.output))")
        }
    }

    nonisolated static func ensureGHAuthenticated() throws {
        let result = runCommand("gh auth status")
        guard result.status == 0 else {
            let details = cleanedOutput(result.output)
            throw RepoIntentError.commandFailed(
                details.isEmpty
                ? "GitHub CLI is not authenticated. Run 'gh auth login' and try again."
                : details
            )
        }
    }

    nonisolated static func isGitRepository(_ path: String) -> Bool {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: (path as NSString).appendingPathComponent(".git")) {
            return true
        }

        let result = runCommand("cd \(shellEscape(path)) && git rev-parse --is-inside-work-tree")
        return result.status == 0 && result.output.localizedCaseInsensitiveContains("true")
    }

    nonisolated static func addRepository(at path: String, name: String?, initializeIfNeeded: Bool) throws -> SavedRepoSnapshot {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: initializeIfNeeded)

        let resolvedName = sanitizedRepositoryName(name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        let finalName = resolvedName.isEmpty ? defaultRepositoryName(for: normalizedPath) : resolvedName
        guard !finalName.isEmpty else {
            throw RepoIntentError.invalidInput("Please provide a repository name or use a path whose last folder has a valid name.")
        }

        let snapshot = SavedRepoSnapshot(name: finalName, path: normalizedPath)
        SavedRepoBackupStore.shared.upsert(snapshot: snapshot)
        return snapshot
    }

    nonisolated static func currentBranch(at path: String) throws -> String {
        let branchResult = runCommand("cd \(shellEscape(path)) && git rev-parse --abbrev-ref HEAD")
        guard branchResult.status == 0 else {
            throw RepoIntentError.commandFailed("Couldn't determine the current branch: \(cleanedOutput(branchResult.output))")
        }

        let branch = cleanedOutput(branchResult.output)
        guard !branch.isEmpty, branch != "HEAD" else {
            throw RepoIntentError.commandFailed("Couldn't determine the current branch.")
        }

        return branch
    }

    nonisolated static func checkoutBranchIfNeeded(_ branch: String, at path: String) throws {
        let current = try currentBranch(at: path)
        guard current != branch else { return }

        let checkoutResult = runCommand("cd \(shellEscape(path)) && git checkout \(shellEscape(branch))")
        guard checkoutResult.status == 0 else {
            throw RepoIntentError.commandFailed("Couldn't switch to \(branch): \(cleanedOutput(checkoutResult.output))")
        }
    }

    nonisolated static func workingTreeHasChanges(at path: String) -> Bool {
        let statusResult = runCommand("cd \(shellEscape(path)) && git status --porcelain")
        guard statusResult.status == 0 else { return false }
        return !cleanedOutput(statusResult.output).isEmpty
    }

    nonisolated static func upstreamExists(at path: String) -> Bool {
        let upstreamResult = runCommand("cd \(shellEscape(path)) && git rev-parse --abbrev-ref --symbolic-full-name @{u}")
        return upstreamResult.status == 0
    }

    nonisolated static func aheadCount(at path: String) -> Int {
        let aheadResult = runCommand("cd \(shellEscape(path)) && git rev-list --count @{u}..HEAD")
        guard aheadResult.status == 0 else { return 0 }
        return Int(cleanedOutput(aheadResult.output)) ?? 0
    }

    nonisolated static func runPush(at path: String, branch: String) throws -> String {
        let pushCommand: String
        if upstreamExists(at: path) {
            pushCommand = "cd \(shellEscape(path)) && git push"
        } else {
            pushCommand = "cd \(shellEscape(path)) && git push --set-upstream origin \(shellEscape(branch))"
        }

        let pushResult = runCommand(pushCommand)
        guard pushResult.status == 0 else {
            throw RepoIntentError.commandFailed("Push failed: \(cleanedOutput(pushResult.output))")
        }

        let output = cleanedOutput(pushResult.output)
        return output.isEmpty ? "Pushed \(branch)." : output
    }

    nonisolated static func pushRepository(at path: String, branch: String) throws -> String {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)
        let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBranch.isEmpty else {
            throw RepoIntentError.invalidInput("Please choose a branch to push.")
        }

        try checkoutBranchIfNeeded(trimmedBranch, at: normalizedPath)
        if upstreamExists(at: normalizedPath), aheadCount(at: normalizedPath) == 0 {
            if workingTreeHasChanges(at: normalizedPath) {
                throw RepoIntentError.commandFailed("Nothing was pushed. \(trimmedBranch) has uncommitted changes. Use Commit and Push, or create a commit before pushing.")
            }
            return "No local commits to push for \(trimmedBranch)."
        }

        return try runPush(at: normalizedPath, branch: trimmedBranch)
    }

    nonisolated static func pullRepository(at path: String, branch: String) throws -> String {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)
        let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBranch.isEmpty else {
            throw RepoIntentError.invalidInput("Please choose a branch to pull.")
        }

        try checkoutBranchIfNeeded(trimmedBranch, at: normalizedPath)

        let pullResult = runCommand("cd \(shellEscape(normalizedPath)) && git pull")
        guard pullResult.status == 0 else {
            throw RepoIntentError.commandFailed("Pull failed: \(cleanedOutput(pullResult.output))")
        }

        return cleanedOutput(pullResult.output).isEmpty ? "Pulled latest changes for \(trimmedBranch)." : cleanedOutput(pullResult.output)
    }

    nonisolated static func commitAndPushRepository(at path: String, branch: String, message: String) throws -> String {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)
        let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBranch.isEmpty else {
            throw RepoIntentError.invalidInput("Please choose a branch to push.")
        }
        guard !trimmedMessage.isEmpty else {
            throw RepoIntentError.invalidInput("Please provide a commit title.")
        }

        try checkoutBranchIfNeeded(trimmedBranch, at: normalizedPath)

        let addResult = runCommand("cd \(shellEscape(normalizedPath)) && git add .")
        guard addResult.status == 0 else {
            throw RepoIntentError.commandFailed("git add failed: \(cleanedOutput(addResult.output))")
        }

        let commitResult = runCommand("cd \(shellEscape(normalizedPath)) && git commit -m \(shellEscape(trimmedMessage))")
        if commitResult.status != 0 {
            let output = cleanedOutput(commitResult.output).lowercased()
            let nothingToCommit = output.contains("nothing to commit")
                || output.contains("nothing added to commit")
                || output.contains("no changes added to commit")
                || output.contains("working tree clean")

            if !nothingToCommit {
                throw RepoIntentError.commandFailed("Commit failed: \(cleanedOutput(commitResult.output))")
            }

            if upstreamExists(at: normalizedPath), aheadCount(at: normalizedPath) == 0 {
                return "No changes to commit or push for \(trimmedBranch)."
            }
        }

        return try runPush(at: normalizedPath, branch: trimmedBranch)
    }

    nonisolated static func mergeRepository(at path: String, sourceBranch: String, targetBranch: String) throws -> String {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)

        let trimmedSource = sourceBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = targetBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            throw RepoIntentError.invalidInput("Please choose a source branch to merge from.")
        }
        guard !trimmedTarget.isEmpty else {
            throw RepoIntentError.invalidInput("Please choose a target branch to merge into.")
        }
        guard trimmedSource != trimmedTarget else {
            throw RepoIntentError.invalidInput("Choose two different branches to merge.")
        }
        guard !workingTreeHasChanges(at: normalizedPath) else {
            throw RepoIntentError.commandFailed("Your working tree has uncommitted changes. Commit or stash them before merging.")
        }

        try checkoutBranchIfNeeded(trimmedTarget, at: normalizedPath)

        let mergeResult = runCommand("cd \(shellEscape(normalizedPath)) && git merge \(shellEscape(trimmedSource))")
        guard mergeResult.status == 0 else {
            throw RepoIntentError.commandFailed("Merge failed: \(cleanedOutput(mergeResult.output))")
        }

        let output = cleanedOutput(mergeResult.output)
        return output.isEmpty ? "Merged \(trimmedSource) into \(trimmedTarget)." : output
    }

    nonisolated static func commitRepository(at path: String, branch: String, message: String) throws -> String {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)

        let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBranch.isEmpty else {
            throw RepoIntentError.invalidInput("Please choose a branch to commit on.")
        }
        guard !trimmedMessage.isEmpty else {
            throw RepoIntentError.invalidInput("Please provide a commit title.")
        }

        try checkoutBranchIfNeeded(trimmedBranch, at: normalizedPath)

        let addResult = runCommand("cd \(shellEscape(normalizedPath)) && git add .")
        guard addResult.status == 0 else {
            throw RepoIntentError.commandFailed("git add failed: \(cleanedOutput(addResult.output))")
        }

        let commitResult = runCommand("cd \(shellEscape(normalizedPath)) && git commit -m \(shellEscape(trimmedMessage))")
        guard commitResult.status == 0 else {
            throw RepoIntentError.commandFailed("Commit failed: \(cleanedOutput(commitResult.output))")
        }

        let output = cleanedOutput(commitResult.output)
        return output.isEmpty ? "Committed changes on \(trimmedBranch)." : output
    }

    nonisolated static func createIssue(at path: String, title: String, body: String) throws -> String {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)
        try ensureGHAuthenticated()

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw RepoIntentError.invalidInput("Please provide an issue title.")
        }

        let result = runGHCommand(["issue", "create", "--title", trimmedTitle, "--body", body], currentDirectory: normalizedPath)
        guard result.status == 0 else {
            throw RepoIntentError.commandFailed("Issue creation failed: \(cleanedOutput(result.output))")
        }

        return cleanedOutput(result.output)
    }

    nonisolated static func createPullRequest(at path: String, sourceBranch: String, title: String, subtitle: String, baseBranch: String) throws -> String {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)
        try ensureGHAuthenticated()

        let trimmedSource = sourceBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBase = baseBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            throw RepoIntentError.invalidInput("Please choose a source branch.")
        }
        guard !trimmedTitle.isEmpty else {
            throw RepoIntentError.invalidInput("Please provide a pull request title.")
        }
        guard !trimmedBase.isEmpty else {
            throw RepoIntentError.invalidInput("Please provide a base branch.")
        }

        try checkoutBranchIfNeeded(trimmedSource, at: normalizedPath)
        _ = try pushRepository(at: normalizedPath, branch: trimmedSource)
        let result = runGHCommand(
            ["pr", "create", "--title", trimmedTitle, "--body", trimmedSubtitle, "--base", trimmedBase],
            currentDirectory: normalizedPath
        )
        guard result.status == 0 else {
            throw RepoIntentError.commandFailed("Pull request creation failed: \(cleanedOutput(result.output))")
        }

        return cleanedOutput(result.output)
    }

    nonisolated static func pullRequestStatus(at path: String, number: Int) throws -> String {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)
        try ensureGHAuthenticated()

        let result = runGHCommand(
            ["pr", "view", "\(number)", "--json", "number,title,state,mergedAt,isDraft,reviewDecision,mergeStateStatus,headRefName,baseRefName,url"],
            currentDirectory: normalizedPath
        )
        guard result.status == 0 else {
            throw RepoIntentError.commandFailed("Couldn't fetch PR status: \(cleanedOutput(result.output))")
        }

        guard let data = result.output.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RepoIntentError.failedToParse("Couldn't parse the pull request status response.")
        }

        let title = (object["title"] as? String) ?? "PR #\(number)"
        let state = ((object["state"] as? String) ?? "unknown").lowercased()
        let body = cleanedOutput((object["body"] as? String) ?? "")
        let merged = (object["mergedAt"] as? String).map { !$0.isEmpty } ?? false
        let isDraft = (object["isDraft"] as? Bool) ?? false
        let reviewDecision = ((object["reviewDecision"] as? String) ?? "none").lowercased()
        let mergeState = ((object["mergeStateStatus"] as? String) ?? "unknown").lowercased()
        let head = (object["headRefName"] as? String) ?? "unknown"
        let base = (object["baseRefName"] as? String) ?? "unknown"
        let url = (object["url"] as? String) ?? ""

        let statusText: String
        if merged {
            statusText = "merged"
        } else if isDraft {
            statusText = "draft"
        } else {
            statusText = state
        }

        var lines = ["#\(number) - \(title) • \(statusText)"]

        if !body.isEmpty {
            lines.append(body)
        } else {
            var details = ["\(head) -> \(base)", "merge: \(mergeState)"]
            if reviewDecision != "none" {
                details.append("review: \(reviewDecision)")
            }
            if !url.isEmpty {
                details.append(url)
            }
            lines.append(details.joined(separator: " • "))
        }

        return lines.joined(separator: "\n")
    }

    nonisolated static func issueStatus(at path: String, number: Int) throws -> String {
        let normalizedPath = try normalizedDirectory(at: path)
        try ensureGitRepository(at: normalizedPath, initializeIfNeeded: false)
        try ensureGHAuthenticated()

        let result = runGHCommand(
            ["issue", "view", "\(number)", "--json", "number,title,state,body,author,assignees,url"],
            currentDirectory: normalizedPath
        )
        guard result.status == 0 else {
            throw RepoIntentError.commandFailed("Couldn't fetch issue status: \(cleanedOutput(result.output))")
        }

        guard let data = result.output.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RepoIntentError.failedToParse("Couldn't parse the issue status response.")
        }

        let title = (object["title"] as? String) ?? "Issue #\(number)"
        let state = ((object["state"] as? String) ?? "unknown").lowercased()
        let body = cleanedOutput((object["body"] as? String) ?? "")
        let url = (object["url"] as? String) ?? ""
        let author = ((object["author"] as? [String: Any])?["login"] as? String) ?? "unknown"
        let assigneeLogins: [String]
        if let assignees = object["assignees"] as? [[String: Any]] {
            assigneeLogins = assignees.compactMap { $0["login"] as? String }
        } else {
            assigneeLogins = []
        }

        var lines = ["#\(number) - \(title) • \(state)"]

        if !body.isEmpty {
            lines.append(body)
        } else {
            var details = ["Opened by \(author)"]
            if assigneeLogins.isEmpty {
                details.append("Unassigned")
            } else {
                details.append("Assigned to \(assigneeLogins.joined(separator: ", "))")
            }
            if !url.isEmpty {
                details.append(url)
            }
            lines.append(details.joined(separator: " • "))
        }

        return lines.joined(separator: "\n")
    }

    nonisolated static func cleanedOutput(_ output: String) -> String {
        output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n", with: "\n")
    }
}

struct SavedRepositoryEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Repository"
    static var defaultQuery = SavedRepositoryEntityQuery()

    let id: String
    let name: String
    let path: String

    init(snapshot: SavedRepoSnapshot) {
        self.id = snapshot.path
        self.name = snapshot.name
        self.path = snapshot.path
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: path)
        )
    }
}

struct SavedRepositoryEntityQuery: EntityQuery {
    func entities(for identifiers: [SavedRepositoryEntity.ID]) async throws -> [SavedRepositoryEntity] {
        identifiers.compactMap(RepoIntentSupport.repositoryEntity(for:))
    }

    func suggestedEntities() async throws -> [SavedRepositoryEntity] {
        RepoIntentSupport.savedRepositoryEntities()
    }
}

struct SavedIssueEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Issue"
    static var defaultQuery = SavedIssueEntityQuery()

    let id: String
    let repositoryPath: String
    let number: Int
    let title: String
    let state: String

    init(repositoryPath: String, number: Int, title: String, state: String) {
        self.id = "\(repositoryPath)::\(number)"
        self.repositoryPath = repositoryPath
        self.number = number
        self.title = title
        self.state = state
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: "#\(number) - \(title)"),
            subtitle: LocalizedStringResource(stringLiteral: state)
        )
    }
}

struct SavedIssueEntityQuery: EntityQuery {
    @IntentParameterDependency<CheckIssueStatusIntent>(\.$repository)
    var intent

    func entities(for identifiers: [SavedIssueEntity.ID]) async throws -> [SavedIssueEntity] {
        identifiers.compactMap(RepoIntentSupport.issueEntity(for:))
    }

    func suggestedEntities() async throws -> [SavedIssueEntity] {
        guard let repository = intent?.repository else { return [] }
        return try RepoIntentSupport.issueEntities(at: repository.path)
    }
}

struct SavedPullRequestEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Pull Request"
    static var defaultQuery = SavedPullRequestEntityQuery()

    let id: String
    let repositoryPath: String
    let number: Int
    let title: String
    let state: String
    let isDraft: Bool

    init(repositoryPath: String, number: Int, title: String, state: String, isDraft: Bool) {
        self.id = "\(repositoryPath)::\(number)"
        self.repositoryPath = repositoryPath
        self.number = number
        self.title = title
        self.state = state
        self.isDraft = isDraft
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = isDraft ? "draft" : state
        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: "#\(number) - \(title)"),
            subtitle: LocalizedStringResource(stringLiteral: subtitle)
        )
    }
}

struct SavedPullRequestEntityQuery: EntityQuery {
    @IntentParameterDependency<CheckPullRequestStatusIntent>(\.$repository)
    var intent

    func entities(for identifiers: [SavedPullRequestEntity.ID]) async throws -> [SavedPullRequestEntity] {
        identifiers.compactMap(RepoIntentSupport.pullRequestEntity(for:))
    }

    func suggestedEntities() async throws -> [SavedPullRequestEntity] {
        guard let repository = intent?.repository else { return [] }
        return try RepoIntentSupport.pullRequestEntities(at: repository.path)
    }
}

struct SavedBranchEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Branch"
    static var defaultQuery = SavedBranchEntityQuery()

    let id: String
    let repositoryPath: String
    let name: String
    let isCurrent: Bool

    init(repositoryPath: String, name: String, isCurrent: Bool) {
        self.id = "\(repositoryPath)::\(name)"
        self.repositoryPath = repositoryPath
        self.name = name
        self.isCurrent = isCurrent
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: isCurrent ? "current branch" : "branch")
        )
    }
}

struct SavedBranchEntityQuery: EntityQuery {
    func entities(for identifiers: [SavedBranchEntity.ID]) async throws -> [SavedBranchEntity] {
        identifiers.compactMap(RepoIntentSupport.branchEntity(for:))
    }

    func suggestedEntities() async throws -> [SavedBranchEntity] {
        []
    }
}

struct PushBranchEntityQuery: EntityQuery {
    @IntentParameterDependency<PushRepositoryIntent>(\.$repository)
    var intent

    func entities(for identifiers: [SavedBranchEntity.ID]) async throws -> [SavedBranchEntity] {
        identifiers.compactMap(RepoIntentSupport.branchEntity(for:))
    }

    func suggestedEntities() async throws -> [SavedBranchEntity] {
        guard let repository = intent?.repository else { return [] }
        return try RepoIntentSupport.branchEntities(at: repository.path)
    }
}

struct PullBranchEntityQuery: EntityQuery {
    @IntentParameterDependency<PullRepositoryIntent>(\.$repository)
    var intent

    func entities(for identifiers: [SavedBranchEntity.ID]) async throws -> [SavedBranchEntity] {
        identifiers.compactMap(RepoIntentSupport.branchEntity(for:))
    }

    func suggestedEntities() async throws -> [SavedBranchEntity] {
        guard let repository = intent?.repository else { return [] }
        return try RepoIntentSupport.branchEntities(at: repository.path)
    }
}

struct CommitAndPushBranchEntityQuery: EntityQuery {
    @IntentParameterDependency<CommitAndPushRepositoryIntent>(\.$repository)
    var intent

    func entities(for identifiers: [SavedBranchEntity.ID]) async throws -> [SavedBranchEntity] {
        identifiers.compactMap(RepoIntentSupport.branchEntity(for:))
    }

    func suggestedEntities() async throws -> [SavedBranchEntity] {
        guard let repository = intent?.repository else { return [] }
        return try RepoIntentSupport.branchEntities(at: repository.path)
    }
}

struct CreatePullRequestBranchEntityQuery: EntityQuery {
    @IntentParameterDependency<CreatePullRequestIntent>(\.$repository)
    var intent

    func entities(for identifiers: [SavedBranchEntity.ID]) async throws -> [SavedBranchEntity] {
        identifiers.compactMap(RepoIntentSupport.branchEntity(for:))
    }

    func suggestedEntities() async throws -> [SavedBranchEntity] {
        guard let repository = intent?.repository else { return [] }
        return try RepoIntentSupport.branchEntities(at: repository.path)
    }
}

struct MergeSourceBranchEntityQuery: EntityQuery {
    @IntentParameterDependency<MergeBranchesIntent>(\.$repository)
    var intent

    func entities(for identifiers: [SavedBranchEntity.ID]) async throws -> [SavedBranchEntity] {
        identifiers.compactMap(RepoIntentSupport.branchEntity(for:))
    }

    func suggestedEntities() async throws -> [SavedBranchEntity] {
        guard let repository = intent?.repository else { return [] }
        return try RepoIntentSupport.branchEntities(at: repository.path)
    }
}

struct MergeTargetBranchEntityQuery: EntityQuery {
    @IntentParameterDependency<MergeBranchesIntent>(\.$repository)
    var intent

    func entities(for identifiers: [SavedBranchEntity.ID]) async throws -> [SavedBranchEntity] {
        identifiers.compactMap(RepoIntentSupport.branchEntity(for:))
    }

    func suggestedEntities() async throws -> [SavedBranchEntity] {
        guard let repository = intent?.repository else { return [] }
        return try RepoIntentSupport.branchEntities(at: repository.path)
    }
}

struct AddRepositoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Repository"
    static var description = IntentDescription("Save a local repository from a user-defined path.")
    static var openAppWhenRun = false

    @Parameter(title: "Repository Path")
    var repositoryPath: String

    @Parameter(title: "Repository Name")
    var repositoryName: String?

    @Parameter(title: "Initialize If Needed", default: false)
    var initializeIfNeeded: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Add the repository at \(\.$repositoryPath)") {
            \.$repositoryName
            \.$initializeIfNeeded
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let snapshot = try RepoIntentSupport.addRepository(
                at: repositoryPath,
                name: repositoryName,
                initializeIfNeeded: initializeIfNeeded
            )
            return .result(dialog: IntentDialog(stringLiteral: "Saved \(snapshot.name) at \(snapshot.path)."))
        } catch {
            throw RepoIntentSupport.presentableError(error)
        }
    }
}

struct PushRepositoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Push Repository"
    static var description = IntentDescription("Push a selected branch for a local repository.")
    static var openAppWhenRun = false

    @Parameter(title: "Repository")
    var repository: SavedRepositoryEntity

    @Parameter(title: "Branch", optionsProvider: PushBranchEntityQuery())
    var branch: SavedBranchEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Push \(\.$branch) for \(\.$repository)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let message = try RepoIntentSupport.pushRepository(at: repository.path, branch: branch.name)
            return .result(dialog: IntentDialog(stringLiteral: message))
        } catch {
            throw RepoIntentSupport.presentableError(error)
        }
    }
}

struct PullRepositoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Pull Repository"
    static var description = IntentDescription("Pull the latest changes for a selected branch in a local repository.")
    static var openAppWhenRun = false

    @Parameter(title: "Repository")
    var repository: SavedRepositoryEntity

    @Parameter(title: "Branch", optionsProvider: PullBranchEntityQuery())
    var branch: SavedBranchEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Pull \(\.$branch) for \(\.$repository)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let message = try RepoIntentSupport.pullRepository(at: repository.path, branch: branch.name)
            return .result(dialog: IntentDialog(stringLiteral: message))
        } catch {
            throw RepoIntentSupport.presentableError(error)
        }
    }
}

struct CommitAndPushRepositoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Commit and Push Repository"
    static var description = IntentDescription("Commit local changes with a title and push the selected branch for a local repository.")
    static var openAppWhenRun = false

    @Parameter(title: "Repository")
    var repository: SavedRepositoryEntity

    @Parameter(title: "Branch", optionsProvider: CommitAndPushBranchEntityQuery())
    var branch: SavedBranchEntity

    @Parameter(title: "Commit Title")
    var commitTitle: String

    static var parameterSummary: some ParameterSummary {
        Summary("Commit \(\.$commitTitle) and push \(\.$branch) for \(\.$repository)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let message = try RepoIntentSupport.commitAndPushRepository(
                at: repository.path,
                branch: branch.name,
                message: commitTitle
            )
            return .result(dialog: IntentDialog(stringLiteral: message))
        } catch {
            throw RepoIntentSupport.presentableError(error)
        }
    }
}

struct MergeBranchesIntent: AppIntent {
    static var title: LocalizedStringResource = "Merge Branches"
    static var description = IntentDescription("Merge one branch into another in a local repository.")
    static var openAppWhenRun = false

    @Parameter(title: "Repository")
    var repository: SavedRepositoryEntity

    @Parameter(title: "Source Branch", optionsProvider: MergeSourceBranchEntityQuery())
    var sourceBranch: SavedBranchEntity

    @Parameter(title: "Target Branch", optionsProvider: MergeTargetBranchEntityQuery())
    var targetBranch: SavedBranchEntity

    @Parameter(title: "Commit Changes First", default: false)
    var commitChangesFirst: Bool

    @Parameter(title: "Commit Title")
    var commitTitle: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Merge \(\.$sourceBranch) into \(\.$targetBranch) for \(\.$repository)") {
            \.$commitChangesFirst
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            if RepoIntentSupport.workingTreeHasChanges(at: repository.path) {
                let resolvedCommitTitle = commitTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let shouldCommit = commitChangesFirst || !resolvedCommitTitle.isEmpty
                guard shouldCommit else {
                    throw RepoIntentError.commandFailed("This repository has uncommitted changes. Turn on Commit Changes First or provide a Commit Title before merging.")
                }

                guard !resolvedCommitTitle.isEmpty else {
                    throw RepoIntentError.invalidInput("Please provide a Commit Title before merging with uncommitted changes.")
                }

                _ = try RepoIntentSupport.commitRepository(
                    at: repository.path,
                    branch: targetBranch.name,
                    message: resolvedCommitTitle
                )
            }

            let message = try RepoIntentSupport.mergeRepository(
                at: repository.path,
                sourceBranch: sourceBranch.name,
                targetBranch: targetBranch.name
            )
            return .result(dialog: IntentDialog(stringLiteral: message))
        } catch {
            throw RepoIntentSupport.presentableError(error)
        }
    }
}

struct CreateIssueIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Issue"
    static var description = IntentDescription("Create a GitHub issue for a local repository.")
    static var openAppWhenRun = false

    @Parameter(title: "Repository")
    var repository: SavedRepositoryEntity

    @Parameter(title: "Issue Title")
    var issueTitle: String

    @Parameter(title: "Issue Body")
    var issueBody: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create issue \(\.$issueTitle) for \(\.$repository)") {
            \.$issueBody
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let message = try RepoIntentSupport.createIssue(at: repository.path, title: issueTitle, body: issueBody)
            return .result(dialog: IntentDialog(stringLiteral: message))
        } catch {
            throw RepoIntentSupport.presentableError(error)
        }
    }
}

struct CreatePullRequestIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Pull Request"
    static var description = IntentDescription("Create a GitHub pull request for a selected branch.")
    static var openAppWhenRun = false

    @Parameter(title: "Repository")
    var repository: SavedRepositoryEntity

    @Parameter(title: "Source Branch", optionsProvider: CreatePullRequestBranchEntityQuery())
    var sourceBranch: SavedBranchEntity

    @Parameter(title: "Pull Request Title")
    var pullRequestTitle: String

    @Parameter(title: "Pull Request Subtitle")
    var pullRequestSubtitle: String

    @Parameter(title: "Base Branch", default: "main")
    var baseBranch: String

    @Parameter(title: "Commit Changes First", default: false)
    var commitChangesFirst: Bool

    @Parameter(title: "Commit Title")
    var commitTitle: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Create pull request \(\.$pullRequestTitle) from \(\.$sourceBranch) for \(\.$repository)") {
            \.$baseBranch
            \.$pullRequestSubtitle
            \.$commitChangesFirst
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            if RepoIntentSupport.workingTreeHasChanges(at: repository.path) {
                let resolvedCommitTitle = commitTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let shouldCommit = commitChangesFirst || !resolvedCommitTitle.isEmpty
                guard shouldCommit else {
                    throw RepoIntentError.commandFailed("This branch has uncommitted changes. Turn on Commit Changes First or provide a Commit Title before making the pull request.")
                }

                guard !resolvedCommitTitle.isEmpty else {
                    throw RepoIntentError.invalidInput("Please provide a Commit Title before creating the pull request with uncommitted changes.")
                }

                _ = try RepoIntentSupport.commitRepository(
                    at: repository.path,
                    branch: sourceBranch.name,
                    message: resolvedCommitTitle
                )
            }

            let message = try RepoIntentSupport.createPullRequest(
                at: repository.path,
                sourceBranch: sourceBranch.name,
                title: pullRequestTitle,
                subtitle: pullRequestSubtitle,
                baseBranch: baseBranch
            )
            return .result(dialog: IntentDialog(stringLiteral: message))
        } catch {
            throw RepoIntentSupport.presentableError(error)
        }
    }
}

struct CheckPullRequestStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Pull Request Status"
    static var description = IntentDescription("Check the state of a pull request in a local repository.")
    static var openAppWhenRun = false

    @Parameter(title: "Repository")
    var repository: SavedRepositoryEntity

    @Parameter(title: "Pull Request")
    var pullRequest: SavedPullRequestEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Check pull request \(\.$pullRequest) for \(\.$repository)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let message = try RepoIntentSupport.pullRequestStatus(at: repository.path, number: pullRequest.number)
            return .result(dialog: IntentDialog(stringLiteral: message))
        } catch {
            throw RepoIntentSupport.presentableError(error)
        }
    }
}

struct CheckIssueStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Issue Status"
    static var description = IntentDescription("Check the state of an issue in a local repository.")
    static var openAppWhenRun = false

    @Parameter(title: "Repository")
    var repository: SavedRepositoryEntity

    @Parameter(title: "Issue")
    var issue: SavedIssueEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Check issue \(\.$issue) for \(\.$repository)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let message = try RepoIntentSupport.issueStatus(at: repository.path, number: issue.number)
            return .result(dialog: IntentDialog(stringLiteral: message))
        } catch {
            throw RepoIntentSupport.presentableError(error)
        }
    }
}

struct NewgitShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddRepositoryIntent(),
            phrases: [
                "Add a repository in \(.applicationName)",
                "Save a repository with \(.applicationName)"
            ],
            shortTitle: "Add Repo",
            systemImageName: "folder.badge.plus"
        )
        AppShortcut(
            intent: PushRepositoryIntent(),
            phrases: [
                "Push a repository with \(.applicationName)",
                "Push repo in \(.applicationName)"
            ],
            shortTitle: "Push Repo",
            systemImageName: "arrow.up.circle"
        )
        AppShortcut(
            intent: PullRepositoryIntent(),
            phrases: [
                "Pull a repository with \(.applicationName)",
                "Pull repo in \(.applicationName)"
            ],
            shortTitle: "Pull Repo",
            systemImageName: "arrow.down.circle"
        )
        AppShortcut(
            intent: CommitAndPushRepositoryIntent(),
            phrases: [
                "Commit and push a repository with \(.applicationName)",
                "Commit changes in \(.applicationName)"
            ],
            shortTitle: "Commit & Push",
            systemImageName: "arrow.up.circle.badge.clock"
        )
        AppShortcut(
            intent: MergeBranchesIntent(),
            phrases: [
                "Merge branches with \(.applicationName)",
                "Merge one branch into another in \(.applicationName)"
            ],
            shortTitle: "Merge Branches",
            systemImageName: "arrow.triangle.merge"
        )
        AppShortcut(
            intent: CreateIssueIntent(),
            phrases: [
                "Create an issue with \(.applicationName)",
                "Make a GitHub issue in \(.applicationName)"
            ],
            shortTitle: "New Issue",
            systemImageName: "exclamationmark.bubble"
        )
        AppShortcut(
            intent: CreatePullRequestIntent(),
            phrases: [
                "Create a pull request with \(.applicationName)",
                "Make a PR in \(.applicationName)"
            ],
            shortTitle: "New PR",
            systemImageName: "arrow.triangle.pull"
        )
        AppShortcut(
            intent: CheckPullRequestStatusIntent(),
            phrases: [
                "Check a pull request status with \(.applicationName)",
                "Get PR status in \(.applicationName)"
            ],
            shortTitle: "PR Status",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: CheckIssueStatusIntent(),
            phrases: [
                "Check an issue status with \(.applicationName)",
                "Get issue status in \(.applicationName)"
            ],
            shortTitle: "Issue Status",
            systemImageName: "exclamationmark.circle"
        )
    }
}
