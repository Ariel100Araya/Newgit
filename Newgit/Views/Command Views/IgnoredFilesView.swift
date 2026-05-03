import SwiftUI
import AppKit

struct IgnoredFilesView: View {
    let projectDirectory: String

    @State private var entries: [GitIgnoreEntry] = []
    @State private var ignoredPaths: [String] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var gitignoreExists: Bool = false
    @State private var showCreateConfirmation: Bool = false

    private var gitignoreURL: URL {
        URL(fileURLWithPath: projectDirectory).appendingPathComponent(".gitignore")
    }

    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading ignored files...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if !gitignoreExists {
                missingGitignoreView
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ignoredFilesContent
            }
        }
        .padding()
        .navigationTitle("Ignored Files")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    choosePathToIgnore()
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add a file or folder to .gitignore")

                Button {
                    loadIgnoredFiles()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh ignored files")

                if gitignoreExists {
                    Button {
                        NSWorkspace.shared.open(gitignoreURL)
                    } label: {
                        Image(systemName: "doc.text")
                    }
                    .help("Open .gitignore")
                }
            }
        }
        .confirmationDialog("Create .gitignore?", isPresented: $showCreateConfirmation) {
            Button("Create .gitignore") {
                createGitignore()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(".gitignore tells Git which local, generated, or temporary files it should leave untracked so they do not show up as changes or get committed by accident.")
        }
        .onAppear {
            loadIgnoredFiles()
        }
    }

    private var missingGitignoreView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 38))
                    .foregroundStyle(.secondary)

                Text("No .gitignore found")
                    .font(.title)
                    .bold()

                Text(".gitignore tells Git which local, generated, or temporary files it should ignore. It is commonly used for build folders, editor settings, logs, and dependency caches that should stay out of commits.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Create .gitignore") {
                    showCreateConfirmation = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.top, 48)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var ignoredFilesContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(".gitignore Entries")
                    .font(.title2)
                    .bold()

                if entries.isEmpty {
                    Text(".gitignore is empty or only contains comments.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    List(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(entry.pattern)
                                    .font(.system(.body, design: .monospaced))
                                if entry.isNegation {
                                    Text("allowed")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text("Line \(entry.lineNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                        .contextMenu {
                            Button("Remove from .gitignore") {
                                removePatternFromGitignore(entry.pattern)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 220, idealWidth: 300, maxWidth: 360)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Ignored Paths")
                    .font(.title2)
                    .bold()

                if ignoredPaths.isEmpty {
                    Text("No currently ignored paths were found in this repository.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    List(ignoredPaths, id: \.self) { path in
                        Text(path)
                            .font(.system(.body, design: .monospaced))
                            .padding(.vertical, 2)
                            .contextMenu {
                                Button("Remove from .gitignore") {
                                    removePatternFromGitignore(path)
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 260, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func loadIgnoredFiles() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let exists = FileManager.default.fileExists(atPath: gitignoreURL.path)
            var loadedEntries: [GitIgnoreEntry] = []
            var loadedIgnoredPaths: [String] = []
            var loadError: String? = nil

            if exists {
                do {
                    let contents = try String(contentsOf: gitignoreURL, encoding: .utf8)
                    loadedEntries = parseGitignore(contents)
                    loadedIgnoredPaths = loadIgnoredPathsFromGit()
                } catch {
                    loadError = "Could not read .gitignore: \(error.localizedDescription)"
                }
            }

            DispatchQueue.main.async {
                self.gitignoreExists = exists
                self.entries = loadedEntries
                self.ignoredPaths = loadedIgnoredPaths
                self.errorMessage = loadError
                self.isLoading = false
            }
        }
    }

    private func createGitignore() {
        let template = """
        # macOS
        .DS_Store

        # Xcode
        DerivedData/
        build/
        *.xcuserstate
        xcuserdata/

        # Logs
        *.log
        """

        do {
            try template.write(to: gitignoreURL, atomically: true, encoding: .utf8)
            loadIgnoredFiles()
        } catch {
            errorMessage = "Could not create .gitignore: \(error.localizedDescription)"
        }
    }

    private func choosePathToIgnore() {
        let panel = NSOpenPanel()
        panel.title = "Choose a file or folder to ignore"
        panel.prompt = "Ignore"
        panel.directoryURL = URL(fileURLWithPath: projectDirectory)
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        do {
            let pattern = try gitignorePattern(for: selectedURL)
            try addPatternToGitignore(pattern)
            loadIgnoredFiles()
            showAlert(title: "Added to .gitignore", message: "\(pattern) was added to .gitignore.")
        } catch {
            showAlert(title: "Could not add ignored file", message: error.localizedDescription)
        }
    }

    private func gitignorePattern(for selectedURL: URL) throws -> String {
        let repoURL = URL(fileURLWithPath: projectDirectory).standardizedFileURL
        let repoPath = repoURL.path.hasSuffix("/") ? repoURL.path : repoURL.path + "/"
        let selectedPath = selectedURL.standardizedFileURL.path

        guard selectedPath == repoURL.path || selectedPath.hasPrefix(repoPath) else {
            throw GitIgnoreUpdateError.pathOutsideRepository
        }

        var relativePath = selectedPath == repoURL.path
            ? "."
            : String(selectedPath.dropFirst(repoPath.count))

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: selectedPath, isDirectory: &isDirectory), isDirectory.boolValue, !relativePath.hasSuffix("/") {
            relativePath += "/"
        }

        return relativePath
    }

    private func addPatternToGitignore(_ pattern: String) throws {
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPattern.isEmpty else { return }

        let existingContents: String
        if FileManager.default.fileExists(atPath: gitignoreURL.path) {
            existingContents = try String(contentsOf: gitignoreURL, encoding: .utf8)
        } else {
            existingContents = ""
        }

        let existingEntries = Set(
            existingContents
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        guard !existingEntries.contains(trimmedPattern) else {
            throw GitIgnoreUpdateError.duplicate(trimmedPattern)
        }

        var updatedContents = existingContents
        if !updatedContents.isEmpty, !updatedContents.hasSuffix("\n") {
            updatedContents += "\n"
        }
        updatedContents += trimmedPattern + "\n"

        try updatedContents.write(to: gitignoreURL, atomically: true, encoding: .utf8)
    }

    private func removePatternFromGitignore(_ pattern: String) {
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPattern.isEmpty else { return }

        do {
            guard FileManager.default.fileExists(atPath: gitignoreURL.path) else {
                showAlert(title: "No .gitignore found", message: "There is no .gitignore file to update.")
                return
            }

            let existingContents = try String(contentsOf: gitignoreURL, encoding: .utf8)
            let lines = existingContents.components(separatedBy: .newlines)
            var removed = false
            let updatedLines = lines.filter { line in
                let linePattern = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if linePattern == trimmedPattern {
                    removed = true
                    return false
                }
                return true
            }

            guard removed else {
                showAlert(title: "No exact .gitignore entry", message: "\(trimmedPattern) was not found as an exact line in .gitignore.")
                return
            }

            var updatedContents = updatedLines.joined(separator: "\n")
            if !updatedContents.isEmpty, !updatedContents.hasSuffix("\n") {
                updatedContents += "\n"
            }

            try updatedContents.write(to: gitignoreURL, atomically: true, encoding: .utf8)
            loadIgnoredFiles()
            showAlert(title: "Removed from .gitignore", message: "\(trimmedPattern) was removed from .gitignore.")
        } catch {
            showAlert(title: "Could not update .gitignore", message: error.localizedDescription)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        if let window = NSApplication.shared.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    private func parseGitignore(_ contents: String) -> [GitIgnoreEntry] {
        contents
            .components(separatedBy: .newlines)
            .enumerated()
            .compactMap { index, rawLine in
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
                return GitIgnoreEntry(
                    lineNumber: index + 1,
                    pattern: trimmed,
                    isNegation: trimmed.hasPrefix("!")
                )
            }
    }

    private func loadIgnoredPathsFromGit() -> [String] {
        let cmd = "cd \(shellEscape(projectDirectory)) && git status --ignored --short --untracked-files=all"
        let result = runCommand(cmd)
        guard result.status == 0 else { return [] }

        var seen = Set<String>()
        return result.output
            .components(separatedBy: .newlines)
            .compactMap { line in
                guard line.hasPrefix("!! ") else { return nil }
                let path = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !path.isEmpty, !seen.contains(path) else { return nil }
                seen.insert(path)
                return path
            }
    }

    private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\'\''") + "'"
    }
}

private struct GitIgnoreEntry: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let pattern: String
    let isNegation: Bool
}

private enum GitIgnoreUpdateError: LocalizedError {
    case pathOutsideRepository
    case duplicate(String)

    var errorDescription: String? {
        switch self {
        case .pathOutsideRepository:
            return "Choose a file or folder inside this repository."
        case .duplicate(let pattern):
            return "\(pattern) is already in .gitignore."
        }
    }
}

#Preview {
    NavigationStack {
        IgnoredFilesView(projectDirectory: ".")
    }
}
