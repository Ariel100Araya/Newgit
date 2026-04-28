import Foundation
import Testing
@testable import Newgit

struct RepoIntentSupportTests {
    @Test("normalizedCloneURL normalizes GitHub HTTPS links")
    func normalizedCloneURLNormalizesGitHubLinks() {
        #expect(RepoIntentSupport.normalizedCloneURL(" https://github.com/octocat/Hello-World ") == "https://github.com/octocat/Hello-World.git")
        #expect(RepoIntentSupport.normalizedCloneURL("https://github.com/octocat/Hello-World/") == "https://github.com/octocat/Hello-World.git")
        #expect(RepoIntentSupport.normalizedCloneURL("https://github.com/octocat/Hello-World?tab=readme#top") == "https://github.com/octocat/Hello-World.git")
        #expect(RepoIntentSupport.normalizedCloneURL("git@github.com:octocat/Hello-World.git") == "git@github.com:octocat/Hello-World.git")
    }

    @Test("inferredRepositoryName sanitizes the repo name from clone URLs")
    func inferredRepositoryNameSanitizes() {
        #expect(RepoIntentSupport.inferredRepositoryName(from: "https://github.com/octocat/hello world.git") == "hello-world")
        #expect(RepoIntentSupport.inferredRepositoryName(from: "git@github.com:octocat/fancy_repo.git") == "fancy_repo")
    }

    @Test("cleanedOutput trims surrounding whitespace and collapses blank lines once")
    func cleanedOutputTrimsAndCollapses() {
        let output = "\n  first line\n\nsecond line  \n"
        #expect(RepoIntentSupport.cleanedOutput(output) == "first line\nsecond line")
    }

    @Test("shellEscape wraps single quotes safely")
    func shellEscapeEscapesQuotes() {
        #expect(RepoIntentSupport.shellEscape("O'Brien") == "'O'\\''Brien'")
    }

    @Test("branchEntities returns the current branch marker")
    func branchEntitiesMarksCurrentBranch() throws {
        let repo = try TestRepo()
        try repo.run("git checkout -b feature/test")

        let branches = try RepoIntentSupport.branchEntities(at: repo.path)

        #expect(branches.contains(where: { $0.name == "feature/test" && $0.isCurrent }))
        #expect(branches.contains(where: { $0.name == "main" && !$0.isCurrent }))
    }

    @Test("commitRepository commits tracked changes on the selected branch")
    func commitRepositoryCreatesCommit() throws {
        let repo = try TestRepo()

        try repo.write(file: "README.md", contents: "updated\n")
        let message = try RepoIntentSupport.commitRepository(
            at: repo.path,
            branch: "main",
            message: "Add README update"
        )

        #expect(message.contains("Add README update"))
        #expect(try repo.output("git rev-list --count HEAD") == "2")
    }

    @Test("mergeRepository merges a source branch into the target branch")
    func mergeRepositoryMergesBranches() throws {
        let repo = try TestRepo()
        try repo.run("git checkout -b feature/test")
        try repo.write(file: "feature.txt", contents: "feature work\n")
        _ = try RepoIntentSupport.commitRepository(
            at: repo.path,
            branch: "feature/test",
            message: "Add feature"
        )

        let message = try RepoIntentSupport.mergeRepository(
            at: repo.path,
            sourceBranch: "feature/test",
            targetBranch: "main"
        )

        #expect(message.localizedCaseInsensitiveContains("feature"))
        #expect(FileManager.default.fileExists(atPath: (repo.path as NSString).appendingPathComponent("feature.txt")))
        #expect(try repo.output("git branch --show-current") == "main")
    }
}

private struct TestRepo {
    let directoryURL: URL

    var path: String { directoryURL.path }

    init() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        directoryURL = parent

        try run("git init -b main")
        try run("git config user.name 'Newgit Tests'")
        try run("git config user.email 'newgit-tests@example.com'")
        try write(file: "README.md", contents: "initial\n")
        try run("git add README.md")
        try run("git commit -m 'Initial commit'")
    }

    func write(file: String, contents: String) throws {
        let url = directoryURL.appendingPathComponent(file)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    @discardableResult
    func run(_ command: String) throws -> String {
        let result = runCommand("cd \(RepoIntentSupport.shellEscape(path)) && \(command)")
        guard result.status == 0 else {
            throw TestRepoError.commandFailed(command: command, output: result.output)
        }
        return RepoIntentSupport.cleanedOutput(result.output)
    }

    func output(_ command: String) throws -> String {
        try run(command)
    }
}

private enum TestRepoError: Error {
    case commandFailed(command: String, output: String)
}
