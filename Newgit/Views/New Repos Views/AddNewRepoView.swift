//
//  AddNewRepoView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/7/25.
//

import SwiftUI
import SwiftData

struct AddNewRepoView: View {
    @State private var projectTitle: String = ""
    @State private var projectDirectory: String = "\(NSHomeDirectory())/Documents/Projects/"
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var savedRepos: [SavedRepo]
    @State private var showSaveAlert: Bool = false
    @State private var saveMessage: String = ""
    // Publish state
    @State private var makePrivate: Bool = false
    @State private var isPublishing: Bool = false
    @State private var publishOutput: String = ""
    @State private var showPublishAlert: Bool = false
    @State private var publishMessage: String = ""
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
                // Convert spaces to hyphens as the user types so pressing Space inserts '-'
                projectTitle = sanitizeProjectName(new)
            }))
            .padding(.bottom)
            Toggle(isOn: $makePrivate) {
                Text("Make repository private on GitHub")
            }
            .padding(.bottom)

            HStack {
                Button("Create & Publish") {
                    Task { await createAndPublishRepo() }
                }
                .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPublishing)
                .buttonStyle(.borderedProminent)

                if isPublishing {
                    ProgressView().scaleEffect(0.9)
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
                    let sanitizedTitle = sanitizeProjectName(trimmedTitle)
                    let trimmedPath = projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !sanitizedTitle.isEmpty, !trimmedPath.isEmpty else {
                        saveMessage = "Please enter both a project title and directory."
                        showSaveAlert = true
                        return
                    }

                    let repo = SavedRepo(name: sanitizedTitle, path: trimmedPath)
                    modelContext.insert(repo)
                    do {
                        try modelContext.save()
                        saveMessage = "Saved \(sanitizedTitle)"
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
        .alert(publishMessage, isPresented: $showPublishAlert) {
            Button("OK", role: .cancel) {}
         }
     }

    // MARK: - Helpers
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

    // Shell-escape a string for use inside single-quoted shell arguments
    private func shellEscape(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // sanitize the user-provided project name into a repo-friendly form
    private func sanitizeProjectName(_ s: String) -> String {
        let comps = s.split{ $0.isWhitespace }
        let joined = comps.joined(separator: "-")
        var out = joined.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        while out.hasPrefix("-") { out.removeFirst() }
        while out.hasSuffix("-") { out.removeLast() }
        return out
    }

    // Create a local git repo, initialize with README, and publish to GitHub using gh
    private func createAndPublishRepo() async {
        let title = sanitizeProjectName(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines))
        let dir = projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !dir.isEmpty else {
            publishMessage = "Please enter both a title and directory"
            showPublishAlert = true
            return
        }

        DispatchQueue.main.async {
            isPublishing = true
            publishOutput = "Starting create & publish for \(title) at \(dir)\n"
        }

        // Ensure directory exists
        let mk = "mkdir -p \(shellEscape(dir))"
        let _ = runCommand(mk)

        // Prepare repo: create README if missing, init git if needed, commit
        var cmds = "cd \(shellEscape(dir))\n"
        // Initialize git if needed
        cmds += "if [ ! -d .git ]; then git init; fi\n"
        // Ensure git user.name/email are set locally (fall back to global if available)
        cmds += "GNAME=$(git config user.name 2>/dev/null || true)\n"
        cmds += "if [ -z \"$GNAME\" ]; then GNAME=$(git config --global user.name 2>/dev/null || true); fi\n"
        cmds += "if [ -n \"$GNAME\" ]; then git config user.name \"$GNAME\"; fi\n"
        cmds += "GEMAIL=$(git config user.email 2>/dev/null || true)\n"
        cmds += "if [ -z \"$GEMAIL\" ]; then GEMAIL=$(git config --global user.email 2>/dev/null || true); fi\n"
        cmds += "if [ -n \"$GEMAIL\" ]; then git config user.email \"$GEMAIL\"; fi\n"
        // Create README if missing
        cmds += "if [ ! -f README.md ]; then printf '# %s\n' \"\(title)\" > README.md; fi\n"
        cmds += "git add .\n"
        cmds += "git commit -m \"Initial commit\" || true\n"

        let prepRes = runCommand(cmds)
        DispatchQueue.main.async {
            publishOutput += "Prepare output:\n\(prepRes.output)\n"
        }

        // Use gh to create the remote and push. Run inside the directory.
        let visibility = makePrivate ? "--private" : "--public"

        // Ensure there's a commit and a branch name gh can detect
        let isWorkTree = runCommand("cd \(shellEscape(dir)) && git rev-parse --is-inside-work-tree")
        DispatchQueue.main.async { publishOutput += "git work-tree: \(isWorkTree.output.trimmingCharacters(in: .whitespacesAndNewlines)) (code \(isWorkTree.status))\n" }

        var hasHead = runCommand("cd \(shellEscape(dir)) && git rev-parse --verify HEAD")
        if hasHead.status != 0 {
            // create an explicit commit if none exists (allow-empty if needed)
            let commitRes = runCommand("cd \(shellEscape(dir)) && git commit --allow-empty -m \"Initial commit\"")
            DispatchQueue.main.async { publishOutput += "Created empty commit output:\n\(commitRes.output)\n" }
            hasHead = runCommand("cd \(shellEscape(dir)) && git rev-parse --verify HEAD")
        }

        // Ensure branch exists and is named (switch to main)
        var branchRes = runCommand("cd \(shellEscape(dir)) && git rev-parse --abbrev-ref HEAD")
        var branch = branchRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if branch.isEmpty || branch == "HEAD" {
            let setBranch = runCommand("cd \(shellEscape(dir)) && git branch -M main")
            DispatchQueue.main.async { publishOutput += "Set branch output:\n\(setBranch.output)\n" }
            branch = "main"
        }
        DispatchQueue.main.async { publishOutput += "Using branch: \(branch)\n" }

        // Try gh --source flow first (requires running in the repo dir)
        let ghArgs = ["repo", "create", title, visibility, "--source", ".", "--remote", "origin", "--push"]
        var ghRes = runGHCommand(ghArgs, currentDirectory: dir)
        DispatchQueue.main.async { publishOutput += "gh output:\n\(ghRes.output)\n" }

        // Fallback: if gh couldn't detect the local repo, create remote then add remote + push manually
        if ghRes.status != 0 {
            DispatchQueue.main.async { publishOutput += "gh --source flow failed, attempting fallback...\n" }
            let ghCreateArgs = ["repo", "create", title, visibility, "--confirm"]
            let ghCreateRes = runGHCommand(ghCreateArgs, currentDirectory: nil)
            DispatchQueue.main.async { publishOutput += "gh create (no source) output:\n\(ghCreateRes.output)\n" }

            if ghCreateRes.status == 0 {
                // Resolve remote URL (prefer https)
                let viewRes = runGHCommand(["repo", "view", title, "--json", "url,sshUrl", "--jq", ".url"], currentDirectory: nil)
                var remoteURL = viewRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if remoteURL.isEmpty {
                    let viewSsh = runGHCommand(["repo", "view", title, "--json", "sshUrl", "--jq", ".sshUrl"], currentDirectory: nil)
                    remoteURL = viewSsh.output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                DispatchQueue.main.async { publishOutput += "Resolved remote URL: \(remoteURL)\n" }

                if !remoteURL.isEmpty {
                    let addRemote = runCommand("cd \(shellEscape(dir)) && git remote add origin \(shellEscape(remoteURL)) || git remote set-url origin \(shellEscape(remoteURL))")
                    DispatchQueue.main.async { publishOutput += "git remote add/set output:\n\(addRemote.output)\n" }
                    let pushRes = runCommand("cd \(shellEscape(dir)) && git push -u origin \(shellEscape(branch))")
                    DispatchQueue.main.async { publishOutput += "git push output:\n\(pushRes.output)\n" }
                    ghRes = (pushRes.output, pushRes.status)
                } else {
                    DispatchQueue.main.async { publishOutput += "Failed to resolve remote URL from gh.\n" }
                }
            } else {
                DispatchQueue.main.async { publishOutput += "gh repo create fallback failed.\n" }
            }
        }

        // If gh succeeded (status 0) save the repo entry
        DispatchQueue.main.async {
            isPublishing = false
            if ghRes.status == 0 {
                let repo = SavedRepo(name: title, path: dir)
                modelContext.insert(repo)
                do {
                    try modelContext.save()
                    publishMessage = "Created and published \(title)"
                } catch {
                    publishMessage = "Published but failed to save: \(error.localizedDescription)"
                }
            } else {
                publishMessage = "Failed to publish: see output"
            }
            showPublishAlert = true
            dismiss()
        }
    }
}
