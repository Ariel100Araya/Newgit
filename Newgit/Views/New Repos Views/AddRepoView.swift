//
//  TestView2.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/6/25.
//
import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct AddRepoView: View {
    @State private var projectTitle: String = ""
    @State private var projectDirectory: String = "\(NSHomeDirectory())/Documents/Projects/"
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var savedRepos: [SavedRepo]
    @State private var showSaveAlert: Bool = false
    @State private var saveMessage: String = ""

    // New states for git/init flow
    @State private var showInitConfirm: Bool = false
    @State private var showGitMissingAlert: Bool = false
    @State private var gitMissingMessage: String = ""
    @State private var pendingInitPath: String = ""
    @State private var pendingInitTitle: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("Enter a project directory")
            HStack {
                TextField("Project Directory", text: $projectDirectory)
                    .frame(minWidth: 400)
                if #available(macOS 26.0, *) {
                    Button("Browse") {
                        browseForDirectory()
                    }
                    .glassEffect()
                    .padding(.leading, 6)
                } else {
                    // Fallback on earlier versions
                    Button("Browse") {
                        browseForDirectory()
                    }
                    .padding(.leading, 6)
                }
            }
            .padding(.bottom)
            Text("Enter a title")
            TextField("Enter a title", text: Binding(get: { projectTitle }, set: { new in
                // Typing sanitizer: convert whitespace runs to hyphens immediately so pressing Space inserts '-'
                projectTitle = sanitizeProjectNameForTyping(new)
            }))
            .padding(.bottom)
            if #available(macOS 26.0, *) {
                Button("Add Repository") {
                    addRepo()
                }
                .buttonStyle(.borderedProminent)
                .glassEffect()
                .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                // Fallback on earlier versions
                Button("Add Repository") {
                    addRepo()
                }
                .buttonStyle(.borderedProminent)
                .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
         
            // Show the saved repos and allow deleting
            List {
                ForEach(savedRepos, id: \.id) { repo in
                    VStack(alignment: .leading) {
                        Text(repo.name)
                        Text(repo.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indices in
                    for index in indices {
                        let repo = savedRepos[index]
                        modelContext.delete(repo)
                        print("AddRepoView: deleted repo id=\(repo.id)")
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Add Repository")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Add Repository") {
                    // Use the same validated code path as the main Add button
                    addRepo()
                }
                .padding(.horizontal)
                .buttonStyle(.borderedProminent)
                .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        // Generic save/failure alert
        .alert(saveMessage, isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        }
        // Alert when git is missing
        .alert(gitMissingMessage, isPresented: $showGitMissingAlert) {
            Button("OK", role: .cancel) {}
        }
        // Confirmation to initialize a repo when directory is not a git repo
        .alert("Initialize repository?", isPresented: $showInitConfirm) {
            Button("Initialize Repository") {
                // Perform initialization and save
                initializeRepo(path: pendingInitPath, title: pendingInitTitle)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This folder is not a git repository. Would you like to initialize a new git repository here?")
        }
    }
    
    // Typing sanitizer: replace runs of whitespace with a single hyphen (keeps leading/trailing hyphens so space key yields '-')
    private func sanitizeProjectNameForTyping(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
        out = out.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return out
    }

    // Save-time sanitizer: similar to typing sanitizer but also trims leading/trailing hyphens
    private func sanitizeProjectNameForSave(_ s: String) -> String {
        var out = sanitizeProjectNameForTyping(s)
        while out.hasPrefix("-") { out.removeFirst() }
        while out.hasSuffix("-") { out.removeLast() }
        return out
    }
    
    // Add Repo
    private func addRepo() {
        let trimmedTitle = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        // Save-time sanitizer: trim leading/trailing hyphens
        let sanitizedTitle = sanitizeProjectNameForSave(trimmedTitle)
        let trimmedPath = projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedTitle.isEmpty, !trimmedPath.isEmpty else {
            saveMessage = "Please enter both a project title and directory."
            showSaveAlert = true
            return
        }

        // Check whether git is available in the environment
        if !isGitAvailable() {
            gitMissingMessage = "Git is not installed or not available in the app's PATH. Please install Git or make it available to the app."
            showGitMissingAlert = true
            return
        }

        // If it's already a git repo, save normally
        if isGitRepository(trimmedPath) {
            let repo = SavedRepo(name: sanitizedTitle, path: trimmedPath)
            modelContext.insert(repo)
            print("AddRepoView: inserted repo \(sanitizedTitle) id=\(repo.id)")
            do {
                try modelContext.save()
                saveMessage = "Saved \(sanitizedTitle)"
                print("AddRepoView: modelContext.save() succeeded. savedRepos count = \(savedRepos.count)")
                showSaveAlert = true
                // Clear inputs after adding and dismiss only on successful save
                projectTitle = ""
                projectDirectory = ""
                dismiss()
            } catch {
                saveMessage = "Save failed: \(error.localizedDescription)"
                print("AddRepoView: modelContext.save() failed: \(error)")
                showSaveAlert = true
            }
            return
        }

        // Git is available but folder isn't a repo: offer to initialize
        pendingInitPath = trimmedPath
        pendingInitTitle = sanitizedTitle
        saveMessage = "The specified directory is not a git repository."
        showInitConfirm = true
    }

    // Check whether git is available in the app environment
    private func isGitAvailable() -> Bool {
        let res = runCommand("git --version 2>/dev/null")
        return res.status == 0
    }

    // Initialize a git repository at the given path, then save the repo entry on success
    private func initializeRepo(path: String, title: String) {
        // Ensure path exists and is a directory
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            saveMessage = "The specified path does not exist or is not a directory."
            showSaveAlert = true
            return
        }

        let cmd = "cd \(shellEscape(path)) && git init"
        let res = runCommand(cmd)
        if res.status == 0 {
            // After successful init, save the repo
            let repo = SavedRepo(name: title, path: path)
            modelContext.insert(repo)
            do {
                try modelContext.save()
                saveMessage = "Initialized and saved \(title)"
                print("AddRepoView: git init succeeded and saved repo \(title)")
                showSaveAlert = true
                projectTitle = ""
                projectDirectory = ""
                dismiss()
            } catch {
                saveMessage = "Repository initialized but failed to save: \(error.localizedDescription)"
                showSaveAlert = true
            }
        } else {
            saveMessage = "Failed to initialize git repository: \(res.output)"
            showSaveAlert = true
        }
    }

    // Browse for directory helper (macOS)
    private func browseForDirectory() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    projectDirectory = url.path
                }
            }
        }
        #else
        // no-op on other platforms
        #endif
    }

    // Helper: safely quote a path for use in shell commands
    private func shellEscape(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\\'\''") + "'"
    }

    // Helper: determine whether a path is a git repository. Fast path checks for a .git folder, otherwise falls back to `git rev-parse`.
    private func isGitRepository(_ path: String) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }

        // Fast heuristic: if a .git directory exists, treat it as a git repo
        if fm.fileExists(atPath: (path as NSString).appendingPathComponent(".git")) {
            return true
        }

        // Fallback: run git rev-parse --is-inside-work-tree to be robust for non-standard repos
        let cmd = "cd \(shellEscape(path)) && git rev-parse --is-inside-work-tree 2>/dev/null"
        let res = runCommand(cmd)
        if res.status == 0 {
            let out = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return out == "true"
        }
        return false
    }
}
