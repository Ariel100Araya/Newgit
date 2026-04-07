import Foundation

struct RepoInsight: Identifiable, Equatable {
    enum Severity: Int {
        case info
        case warning
        case critical
    }

    let id = UUID()
    let severity: Severity
    let title: String
    let detail: String
}

struct RepoAssociatedPullRequest: Equatable {
    let number: Int
    let title: String
    let state: String
    let isDraft: Bool
    let merged: Bool
    let headRefName: String?
    let baseRefName: String?
    let url: String
}

struct RepoStatusSnapshot: Equatable {
    let currentBranch: String
    let upstreamBranch: String?
    let changedFileCount: Int
    let hasWorkingChanges: Bool
    let hasStagedChanges: Bool
    let hasUnstagedChanges: Bool
    let hasUntrackedFiles: Bool
    let hasConflicts: Bool
    let aheadCount: Int
    let behindCount: Int
    let stashCount: Int
    let isDetachedHead: Bool
    let isMerging: Bool
    let isRebasing: Bool
    let isCherryPicking: Bool
    let remoteBranchExists: Bool?
    let associatedPullRequest: RepoAssociatedPullRequest?
    let insights: [RepoInsight]

    var primarySummary: String {
        if isDetachedHead {
            return "Detached HEAD"
        }

        if hasConflicts {
            return "Conflicts need attention on \(currentBranch)"
        }

        if aheadCount > 0 && behindCount > 0 {
            return "\(currentBranch) has diverged from remote"
        }

        if aheadCount > 0 {
            return "\(currentBranch) is ahead by \(aheadCount) commit\(aheadCount == 1 ? "" : "s")"
        }

        if behindCount > 0 {
            return "\(currentBranch) is behind by \(behindCount) commit\(behindCount == 1 ? "" : "s")"
        }

        if hasWorkingChanges {
            return "\(changedFileCount) local file change\(changedFileCount == 1 ? "" : "s")"
        }

        return "\(currentBranch) looks up to date"
    }

    var branchLooksDeletedAfterPR: Bool {
        guard let remoteBranchExists else { return false }
        guard remoteBranchExists == false else { return false }
        guard let pr = associatedPullRequest else { return false }
        return pr.merged || pr.state == "closed"
    }
}

enum RepoStatusEngine {
    static func load(projectDirectory: String) -> RepoStatusSnapshot {
        let escapedDirectory = shellEscape(projectDirectory)
        let status = runCommand("cd \(escapedDirectory) && git status --porcelain=v2 -b")
        let statusLines = status.output.split(whereSeparator: \.isNewline).map(String.init)

        let currentBranch = parseBranchHead(from: statusLines) ?? "HEAD"
        let upstreamBranch = parseUpstreamBranch(from: statusLines)
        let (aheadCount, behindCount) = parseAheadBehind(from: statusLines)
        let fileState = parseFileState(from: statusLines)

        let isDetachedHead = currentBranch == "HEAD" || currentBranch == "(detached)"
        let isMerging = gitPathExists("MERGE_HEAD", in: escapedDirectory)
        let isRebasing = gitPathExists("rebase-merge", in: escapedDirectory) || gitPathExists("rebase-apply", in: escapedDirectory)
        let isCherryPicking = gitPathExists("CHERRY_PICK_HEAD", in: escapedDirectory)

        let stashCount = parseLineCount(runCommand("cd \(escapedDirectory) && git stash list").output)

        let remoteBranchExists = isDetachedHead ? nil : remoteBranchExists(for: currentBranch, in: projectDirectory, escapedDirectory: escapedDirectory)
        let associatedPullRequest = isDetachedHead ? nil : loadAssociatedPullRequest(for: currentBranch, in: projectDirectory)
        let insights = buildInsights(
            currentBranch: currentBranch,
            upstreamBranch: upstreamBranch,
            fileState: fileState,
            aheadCount: aheadCount,
            behindCount: behindCount,
            stashCount: stashCount,
            isDetachedHead: isDetachedHead,
            isMerging: isMerging,
            isRebasing: isRebasing,
            isCherryPicking: isCherryPicking,
            remoteBranchExists: remoteBranchExists,
            associatedPullRequest: associatedPullRequest
        )

        return RepoStatusSnapshot(
            currentBranch: currentBranch,
            upstreamBranch: upstreamBranch,
            changedFileCount: fileState.changedFileCount,
            hasWorkingChanges: fileState.changedFileCount > 0,
            hasStagedChanges: fileState.hasStagedChanges,
            hasUnstagedChanges: fileState.hasUnstagedChanges,
            hasUntrackedFiles: fileState.hasUntrackedFiles,
            hasConflicts: fileState.hasConflicts,
            aheadCount: aheadCount,
            behindCount: behindCount,
            stashCount: stashCount,
            isDetachedHead: isDetachedHead,
            isMerging: isMerging,
            isRebasing: isRebasing,
            isCherryPicking: isCherryPicking,
            remoteBranchExists: remoteBranchExists,
            associatedPullRequest: associatedPullRequest,
            insights: insights
        )
    }

    private struct FileState {
        var changedFileCount: Int = 0
        var hasStagedChanges: Bool = false
        var hasUnstagedChanges: Bool = false
        var hasUntrackedFiles: Bool = false
        var hasConflicts: Bool = false
    }

    private static func buildInsights(
        currentBranch: String,
        upstreamBranch: String?,
        fileState: FileState,
        aheadCount: Int,
        behindCount: Int,
        stashCount: Int,
        isDetachedHead: Bool,
        isMerging: Bool,
        isRebasing: Bool,
        isCherryPicking: Bool,
        remoteBranchExists: Bool?,
        associatedPullRequest: RepoAssociatedPullRequest?
    ) -> [RepoInsight] {
        var insights: [RepoInsight] = []

        if isDetachedHead {
            insights.append(
                RepoInsight(
                    severity: .critical,
                    title: "Detached HEAD",
                    detail: "You are not on a branch right now. Create or check out a branch before making more commits."
                )
            )
        }

        if fileState.hasConflicts {
            insights.append(
                RepoInsight(
                    severity: .critical,
                    title: "Merge conflicts detected",
                    detail: "Resolve conflicted files before pulling, pushing, or creating a pull request."
                )
            )
        }

        if isMerging {
            insights.append(
                RepoInsight(
                    severity: .warning,
                    title: "Merge in progress",
                    detail: "Finish the merge commit or abort it before switching contexts."
                )
            )
        }

        if isRebasing {
            insights.append(
                RepoInsight(
                    severity: .warning,
                    title: "Rebase in progress",
                    detail: "Continue, skip, or abort the rebase before taking other branch actions."
                )
            )
        }

        if isCherryPicking {
            insights.append(
                RepoInsight(
                    severity: .warning,
                    title: "Cherry-pick in progress",
                    detail: "Complete or abort the cherry-pick before pushing more changes."
                )
            )
        }

        if fileState.changedFileCount > 0 {
            var details: [String] = []
            if fileState.hasStagedChanges { details.append("staged changes") }
            if fileState.hasUnstagedChanges { details.append("unstaged changes") }
            if fileState.hasUntrackedFiles { details.append("untracked files") }

            insights.append(
                RepoInsight(
                    severity: .info,
                    title: "Working tree has changes",
                    detail: "You have \(fileState.changedFileCount) changed file\(fileState.changedFileCount == 1 ? "" : "s")" + (details.isEmpty ? "." : " including \(details.joined(separator: ", ")).")
                )
            )
        }

        if behindCount > 0 && aheadCount > 0 {
            insights.append(
                RepoInsight(
                    severity: .warning,
                    title: "Branch has diverged",
                    detail: "\(currentBranch) is \(aheadCount) commit\(aheadCount == 1 ? "" : "s") ahead and \(behindCount) behind" + branchSuffix(upstreamBranch) + ". Pull or rebase before pushing."
                )
            )
        } else if behindCount > 0 {
            insights.append(
                RepoInsight(
                    severity: .warning,
                    title: "Remote has new commits",
                    detail: "\(currentBranch) is \(behindCount) commit\(behindCount == 1 ? "" : "s") behind" + branchSuffix(upstreamBranch) + ". Pull before pushing."
                )
            )
        } else if aheadCount > 0 {
            insights.append(
                RepoInsight(
                    severity: .info,
                    title: "Ready to push",
                    detail: "\(currentBranch) is \(aheadCount) commit\(aheadCount == 1 ? "" : "s") ahead" + branchSuffix(upstreamBranch) + "."
                )
            )
        }

        if upstreamBranch == nil && !isDetachedHead {
            if let remoteBranchExists, remoteBranchExists {
                insights.append(
                    RepoInsight(
                        severity: .warning,
                        title: "Branch is not tracking remote",
                        detail: "A remote branch named \(currentBranch) exists, but this local branch has no upstream configured."
                    )
                )
            } else {
                insights.append(
                    RepoInsight(
                        severity: .info,
                        title: "Branch is local only",
                        detail: "Push \(currentBranch) to publish it and set an upstream."
                    )
                )
            }
        }

        if let remoteBranchExists, remoteBranchExists == false, let pr = associatedPullRequest, pr.merged || pr.state == "closed" {
            insights.append(
                RepoInsight(
                    severity: .warning,
                    title: "Branch may have been deleted by a PR",
                    detail: "The remote branch for \(currentBranch) is gone, and PR #\(pr.number) is \(pr.merged ? "merged" : "closed"). You may want to switch back to \(pr.baseRefName ?? "the base branch") and delete the local branch when you are done."
                )
            )
        } else if let pr = associatedPullRequest {
            let prState: String
            if pr.merged {
                prState = "merged"
            } else if pr.isDraft {
                prState = "draft"
            } else {
                prState = pr.state
            }

            insights.append(
                RepoInsight(
                    severity: .info,
                    title: "Associated pull request",
                    detail: "PR #\(pr.number) is \(prState) from \(pr.headRefName ?? currentBranch) into \(pr.baseRefName ?? "unknown")."
                )
            )
        }

        if stashCount > 0 {
            insights.append(
                RepoInsight(
                    severity: .info,
                    title: "Saved stashes available",
                    detail: "You have \(stashCount) stash entr\(stashCount == 1 ? "y" : "ies") you can inspect or apply."
                )
            )
        }

        if insights.isEmpty {
            insights.append(
                RepoInsight(
                    severity: .info,
                    title: "No obvious issues",
                    detail: "The repo looks clean and there are no urgent actions right now."
                )
            )
        }

        return insights
    }

    private static func branchSuffix(_ upstreamBranch: String?) -> String {
        guard let upstreamBranch, !upstreamBranch.isEmpty else { return "" }
        return " relative to \(upstreamBranch)"
    }

    private static func parseBranchHead(from lines: [String]) -> String? {
        guard let raw = lines.first(where: { $0.hasPrefix("# branch.head ") }) else { return nil }
        let value = String(raw.dropFirst("# branch.head ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value == "(detached)" ? "HEAD" : value
    }

    private static func parseUpstreamBranch(from lines: [String]) -> String? {
        guard let raw = lines.first(where: { $0.hasPrefix("# branch.upstream ") }) else { return nil }
        let value = String(raw.dropFirst("# branch.upstream ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func parseAheadBehind(from lines: [String]) -> (Int, Int) {
        guard let raw = lines.first(where: { $0.hasPrefix("# branch.ab ") }) else { return (0, 0) }
        let payload = String(raw.dropFirst("# branch.ab ".count))
        let parts = payload.split(separator: " ")
        var ahead = 0
        var behind = 0

        for part in parts {
            if part.hasPrefix("+") {
                ahead = Int(part.dropFirst()) ?? 0
            } else if part.hasPrefix("-") {
                behind = Int(part.dropFirst()) ?? 0
            }
        }

        return (ahead, behind)
    }

    private static func parseFileState(from lines: [String]) -> FileState {
        var state = FileState()

        for line in lines {
            if line.hasPrefix("1 ") || line.hasPrefix("2 ") {
                state.changedFileCount += 1

                let fields = line.split(separator: " ", omittingEmptySubsequences: false)
                guard fields.count > 1 else { continue }
                let xy = String(fields[1])
                let chars = Array(xy)
                let indexStatus = chars.count > 0 ? chars[0] : "."
                let worktreeStatus = chars.count > 1 ? chars[1] : "."

                if indexStatus != "." {
                    state.hasStagedChanges = true
                }
                if worktreeStatus != "." {
                    state.hasUnstagedChanges = true
                }
            } else if line.hasPrefix("u ") {
                state.changedFileCount += 1
                state.hasConflicts = true
                state.hasStagedChanges = true
                state.hasUnstagedChanges = true
            } else if line.hasPrefix("? ") {
                state.changedFileCount += 1
                state.hasUntrackedFiles = true
            }
        }

        return state
    }

    private static func gitPathExists(_ relativePath: String, in escapedDirectory: String) -> Bool {
        let result = runCommand("cd \(escapedDirectory) && test -e \"$(git rev-parse --git-path \(relativePath))\"")
        return result.status == 0
    }

    private static func remoteBranchExists(for branch: String, in projectDirectory: String, escapedDirectory: String) -> Bool? {
        let remoteResult = runCommand("cd \(escapedDirectory) && git remote")
        let remotes = remoteResult.output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let remote = remotes.contains("origin") ? "origin" : remotes.first
        guard let remote else { return nil }

        let existsResult = runCommand("cd \(shellEscape(projectDirectory)) && git ls-remote --exit-code --heads \(shellEscape(remote)) \(shellEscape(branch))")
        if existsResult.status == 0 { return true }
        if existsResult.status == 2 { return false }
        return nil
    }

    private static func loadAssociatedPullRequest(for branch: String, in projectDirectory: String) -> RepoAssociatedPullRequest? {
        let fields = "number,title,state,url,headRefName,baseRefName,isDraft,mergedAt"
        let result = runGHCommand(["pr", "list", "--head", branch, "--state", "all", "--json", fields, "--limit", "20"], currentDirectory: projectDirectory)
        guard result.status == 0, let data = result.output.data(using: .utf8) else { return nil }

        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !array.isEmpty else {
            return nil
        }

        let candidates: [RepoAssociatedPullRequest] = array.compactMap { object in
            guard let number = object["number"] as? Int else { return nil }
            let title = (object["title"] as? String) ?? "PR #\(number)"
            let state = ((object["state"] as? String) ?? "unknown").lowercased()
            let url = (object["url"] as? String) ?? ""
            let headRefName = object["headRefName"] as? String
            let baseRefName = object["baseRefName"] as? String
            let isDraft = (object["isDraft"] as? Bool) ?? false
            let merged = ((object["mergedAt"] as? String) ?? "").isEmpty == false

            return RepoAssociatedPullRequest(
                number: number,
                title: title,
                state: state,
                isDraft: isDraft,
                merged: merged,
                headRefName: headRefName,
                baseRefName: baseRefName,
                url: url
            )
        }

        return candidates.sorted { lhs, rhs in
            if lhs.merged != rhs.merged {
                return lhs.merged && !rhs.merged
            }
            return lhs.number > rhs.number
        }.first
    }

    private static func parseLineCount(_ output: String) -> Int {
        output
            .split(whereSeparator: \.isNewline)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    private static func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
