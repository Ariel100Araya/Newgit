//
//  CloneRepoView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/6/25.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct CloneRepoView: View {
    @State private var projectTitle: String = ""
    @State private var projectDirectory: String = ""
    @State private var projectLink: String = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var savedRepos: [SavedRepo]
    @State private var showSaveAlert: Bool = false
    @State private var saveMessage: String = ""

    // GH repo list state
    struct GHRepo: Codable, Identifiable, Equatable {
        var id: String { name }
        let name: String
        let sshUrl: String
        let url: String // e.g. https://github.com/owner/repo
    }
    @State private var ghRepos: [GHRepo] = []
    @State private var selectedGHRepo: GHRepo? = nil
    @State private var useHTTPS: Bool = true
    @State private var ghAuthMessage: String = ""
    @State private var showGHAuthAlert: Bool = false

    // Cloning state
    @State private var isCloning: Bool = false
    @State private var cloningOutput: String = ""
    @State private var showCloneAlert: Bool = false
    @State private var cloneMessage: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Select repo from menu to clone from GitHub")
                Spacer()
                Button("Refresh") {
                    loadGHRepos()
                }
                .padding(.trailing, 4)

                Button("Sign in with GitHub") {
                    Task { await runGHLogin() }
                }
                .padding(.trailing, 4)
            }

            // GH repo list: selectable buttons
            if ghRepos.isEmpty {
                Text("No GitHub repos found. Make sure 'gh' is installed and authenticated.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
            } else {
                List(ghRepos) { repo in
                    Button(action: {
                        selectGHRepo(repo)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(repo.name)
                                Text(repo.sshUrl)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(repo.url)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedGHRepo == repo {
                                Image(systemName: "checkmark")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 120, idealHeight: 200)
            }

            Toggle("Use HTTPS for clone", isOn: $useHTTPS)
                .padding(.vertical, 6)

            Text("Enter a project directory")
            HStack {
                TextField("Project Directory", text: $projectDirectory)
                    .frame(minWidth: 400)
                Button("Browse") {
                    browseForDirectory()
                }
                .glassEffect()
                .padding(.leading, 6)
                Button("Scan for repos") {
                    scanLocalRepos()
                }
                .padding(.leading, 6)
            }
            Text("Enter a title")
            TextField("Enter a title", text: $projectTitle)
                .padding(.bottom)

            // Allow user to edit the clone link (populated from selection)
            Text("Repo link (SSH)")
            TextField(useHTTPS ? "https://github.com/owner/repo.git" : "git@github.com:owner/repo.git", text: $projectLink)
                .padding(.bottom)

            // Clone controls
            HStack {
                Button("Clone") {
                    Task { await performCloneAndAdd() }
                }
                .disabled(projectLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.bordered)
                .padding(.trailing, 8)

                if isCloning {
                    ProgressView().scaleEffect(0.9)
                }
            }

            if !cloningOutput.isEmpty {
                Text("Clone output:")
                    .font(.caption)
                    .padding(.top, 6)
                ScrollView {
                    Text(cloningOutput)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }
                .frame(maxHeight: 180)
                .border(Color.secondary.opacity(0.2))
            }

            Button("Add Repository") {
                // Validate inputs
                let trimmedTitle = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedPath = projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty, !trimmedPath.isEmpty else {
                    saveMessage = "Please enter both a project title and directory."
                    showSaveAlert = true
                    return
                }

                let repo = SavedRepo(name: trimmedTitle, path: trimmedPath)
                modelContext.insert(repo)
                do {
                    try modelContext.save()
                    saveMessage = "Saved \(trimmedTitle)"
                } catch {
                    saveMessage = "Save failed: \(error.localizedDescription)"
                    print("ModelContext save error: \(error)")
                }
                showSaveAlert = true
                // Clear inputs after adding
                projectTitle = ""
                projectDirectory = ""
                projectLink = ""
                dismiss()
             }
             .buttonStyle(.borderedProminent)
             .glassEffect()
             .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

         
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
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Add Repository")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Add Repository") {
                    // Validate inputs
                    let trimmedTitle = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedPath = projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedTitle.isEmpty, !trimmedPath.isEmpty else {
                        saveMessage = "Please enter both a project title and directory."
                        showSaveAlert = true
                        return
                    }

                    let repo = SavedRepo(name: trimmedTitle, path: trimmedPath)
                    modelContext.insert(repo)
                    do {
                        try modelContext.save()
                        saveMessage = "Saved \(trimmedTitle)"
                    } catch {
                        saveMessage = "Save failed: \(error.localizedDescription)"
                        print("ModelContext save error: \(error)")
                    }
                    showSaveAlert = true
                    // Clear inputs after adding
                    projectTitle = ""
                    projectDirectory = ""
                 }
                 .padding(.horizontal)
                 .buttonStyle(.borderedProminent)
                 .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
             }
         }
        .alert(saveMessage, isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
         }
        .alert(cloneMessage, isPresented: $showCloneAlert) {
            Button("OK", role: .cancel) {}
         }
         .onAppear {
             loadGHRepos()
         }
     }

    // MARK: - Helpers
    private func shellEscape(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func runGHLogin() async {
        DispatchQueue.global(qos: .userInitiated).async {
            let res = runGHCommand(["auth", "login", "--web"]) // opens browser
            DispatchQueue.main.async {
                if res.status == 0 {
                    ghAuthMessage = "GitHub login started (web)."
                } else {
                    ghAuthMessage = "gh auth login failed: \(res.output)"
                }
                showGHAuthAlert = true
                // Try reloading repos after auth attempt
                loadGHRepos()
            }
        }
    }

    private func performCloneSync(repoURL: String, targetPath: String) -> (output: String, status: Int32) {
        // Ensure parent directory exists
        let parent = (targetPath as NSString).deletingLastPathComponent
        let mkCmd = "mkdir -p \(shellEscape(parent))"
        _ = runCommand(mkCmd)

        // Run git clone
        let cloneCmd = "git clone \(shellEscape(repoURL)) \(shellEscape(targetPath))"
        return runCommand(cloneCmd)
    }

    private func performCloneAndAdd() async {
        let link = projectLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty, !base.isEmpty else {
            cloneMessage = "Please provide both repo link and target directory"
            showCloneAlert = true
            return
        }

        // Determine target path
        var targetPath = base
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: base, isDirectory: &isDir)
        if exists && isDir.boolValue {
            // derive repo name
            let derivedName: String
            if !title.isEmpty {
                derivedName = title
            } else {
                // Try to extract repo name from link
                let parts = link.split { $0 == "/" || $0 == ":" }.map { String($0) }
                derivedName = parts.last?.replacingOccurrences(of: ".git", with: "") ?? "repo"
            }
            targetPath = (base as NSString).appendingPathComponent(derivedName)
        } else {
            // base treated as the full target path
            targetPath = base
        }

        DispatchQueue.main.async {
            isCloning = true
            cloningOutput = "Cloning..."
        }

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<(String, Int32), Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let res = performCloneSync(repoURL: link, targetPath: targetPath)
                continuation.resume(returning: (res.output, res.status))
            }
        }

        DispatchQueue.main.async {
            isCloning = false
            cloningOutput = result.0
            if result.1 == 0 {
                let nameToSave = title.isEmpty ? URL(fileURLWithPath: targetPath).lastPathComponent : title
                let repo = SavedRepo(name: nameToSave, path: targetPath)
                modelContext.insert(repo)
                do {
                    try modelContext.save()
                    cloneMessage = "Cloned and saved \(nameToSave)"
                } catch {
                    cloneMessage = "Cloned but failed to save: \(error.localizedDescription)"
                }
                showCloneAlert = true
                projectTitle = ""
                projectLink = ""
                projectDirectory = ""
                dismiss()
            } else {
                cloneMessage = "Clone failed (exit \(result.1)): see output"
                showCloneAlert = true
            }
        }
    }

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
         // On non-macOS platforms we could use fileImporter in SwiftUI; for now do nothing
         #endif
     }

     private func selectGHRepo(_ repo: GHRepo) {
         selectedGHRepo = repo
         projectTitle = repo.name
         if useHTTPS {
             // Use the repo.url (https) and ensure .git suffix
             var http = repo.url
             if !http.hasSuffix(".git") { http += ".git" }
             projectLink = http
         } else {
             projectLink = repo.sshUrl
         }
         // If the sshUrl looks like a local path (from scan), set projectDirectory
         if repo.sshUrl.hasPrefix("/") {
             projectDirectory = repo.sshUrl
             projectLink = ""
         }
     }

     private func loadGHRepos() {
         // Try to use gh CLI to list repos as JSON
         let args = ["repo", "list", "--limit", "100", "--json", "name,sshUrl,url"]
         let out = runGHCommand(args).output
         let data = Data(out.utf8)
         do {
             let decoded = try JSONDecoder().decode([GHRepo].self, from: data)
             DispatchQueue.main.async {
                 ghRepos = decoded
                 if let current = decoded.first {
                     // don't auto-select, but keep selection if already set
                     if selectedGHRepo == nil {
                         // leave unselected
                     }
                 }
             }
         } catch {
             // Fallback: try to parse simple lines (if gh isn't available or output isn't JSON)
             let lines = out.split { $0 == "\n" || $0 == "\r" }.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
             // Try to map lines like "owner/repo\tSSH_URL" or just "owner/repo"
             var parsed: [GHRepo] = []
             for line in lines {
                 // If the line contains whitespace separated values, try to extract last token as URL
                 let parts = line.split(separator: " ").map { String($0) }
                 if parts.count >= 2, parts.last?.contains("@github.com:") == true || parts.last?.contains("github.com") == true {
                     let name = parts.first ?? line
                     let url = parts.last ?? ""
                     // try to infer http url
                     let httpUrl = url.contains("github.com") ? (url.contains("http") ? url : "https://github.com/\(name)") : "https://github.com/\(name)"
                     parsed.append(GHRepo(name: name, sshUrl: url, url: httpUrl))
                 } else {
                     // no URL available, use name and empty URL
                     parsed.append(GHRepo(name: line, sshUrl: "", url: "https://github.com/\(line)"))
                 }
             }
             DispatchQueue.main.async {
                 ghRepos = parsed
             }
         }
     }

    // Scan a base directory for local git repos (folders containing .git)
    private func scanLocalRepos() {
        let base = projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return }
        let shellEscapedBase = base.replacingOccurrences(of: "'", with: "'\\''")
        let finalCmd = "find '\(shellEscapedBase)' -type d -name .git -prune -print"
        let out = runCommand(finalCmd).output
        let lines = out.split { $0 == "\n" || $0 == "\r" }.map { String($0) }
        var found: [GHRepo] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            var repoDir = trimmed
            if repoDir.hasSuffix("/.git") { repoDir = String(repoDir.dropLast(5)) }
            let name = URL(fileURLWithPath: repoDir).lastPathComponent
            // For local repos we set the sshUrl to the local path and provide a file:// URL
            let fileURL = "file://\(repoDir)"
            found.append(GHRepo(name: name, sshUrl: repoDir, url: fileURL))
        }
        if !found.isEmpty {
            DispatchQueue.main.async { ghRepos = found }
        }
    }
 }

 #Preview {
     CloneRepoView()
 }
