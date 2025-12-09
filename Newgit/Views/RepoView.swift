//
//  RepoView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/6/25.
//

import SwiftUI
import AppKit

struct RepoView: View {
    // Make these immutable inputs instead of @State so they update predictably when parent passes new values
    let repoTitle: String
    let projectDirectory: String
    @State private var pushTitle: String = ""
    @State private var showCommandOutput: Bool = false
    @State private var gitPush: Bool =  false
    @State private var showPush: Bool = false

    // New state to drive selectable list + selected diff
    @State private var changedFiles: [String] = []
    @State private var selectedFile: String? = nil
    @State private var selectedFileDiff: String = ""
    // Cache raw command output for the fallback UI to avoid running commands while building the view
    @State private var changedFilesFallbackOutput: String = ""

    // Branch state
    @State private var branches: [String] = []
    @State private var currentBranch: String = ""
    // Remote update state
    @State private var needsPull: Bool = false
    @State private var needsPullCount: Int = 0
    // New branch UI state
    @State private var showNewBranchSheet: Bool = false
    @State private var newBranchName: String = ""
    @State private var newBranchError: String? = nil

    var body: some View {
        VStack {
            HStack {
                // Left pane: selectable list of changed files
                VStack { // Removed ScrollView to avoid embedding List inside a ScrollView which can collapse the list
                    if changedFiles.isEmpty {
                        VStack {
                            Text("It seems like there isn't any changed files. Time to get to work!")
                                .font(.title)
                                .multilineTextAlignment(.center)
                                .padding()
                                .bold()
                            // I should probably add some buttons for common actions here like Open in Finder, terminal, etc.
                            HStack {
                                Menu("Open") {
                                    Button("Open workspace in Finder") {
                                        let homeURL = URL(fileURLWithPath: projectDirectory)
                                        NSWorkspace.shared.activateFileViewerSelecting([homeURL])
                                    }
                                    Button("Open workspace in Xcode") {
                                        if let xcodeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode") {
                                            let config = NSWorkspace.OpenConfiguration()
                                            config.arguments = [projectDirectory]
                                            NSWorkspace.shared.openApplication(at: xcodeURL, configuration: config)
                                        }
                                    }
                                    Button("Open workspace in Visual Studio Code") {
                                        let vsCodeURL = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
                                        let config = NSWorkspace.OpenConfiguration()
                                        config.arguments = [projectDirectory]
                                        NSWorkspace.shared.openApplication(at: vsCodeURL, configuration: config)
                                    }
                                }
                                .padding()
                                .glassEffect()
                                .buttonStyle(.borderless)
                                Button("Open directory in Terminal") {
                                    if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                                        let config = NSWorkspace.OpenConfiguration()
                                        config.arguments = [projectDirectory]
                                        NSWorkspace.shared.openApplication(at: terminalURL, configuration: config)
                                    } else {
                                        // Fallback URL scheme
                                        let url = URL(string: "terminal://\(projectDirectory)")!
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .padding()
                                .buttonStyle(.borderless)
                                .glassEffect()
                                Button("Open repository in GitHub") {
                                    openRepositoryInGitHub()
                                }
                                .padding()
                                .buttonStyle(.borderless)
                                .glassEffect()
                            }
                        }
                    }
                    VStack(alignment: .leading) {
                        if changedFiles.isEmpty {
                            
                        } else {
                            Text("Changed Files:")
                                .padding()
                                .font(.title)
                                .bold()
                            List(changedFiles, id: \.self) { file in
                                Button(action: {
                                    selectFile(file)
                                }) {
                                    HStack {
                                        Text(file)
                                            .font(.title3)
                                            .foregroundColor(.primary)
                                            .padding(.horizontal)
                                        Spacer()
                                        if selectedFile == file {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .listStyle(.plain)
                            .frame(minWidth: 240)
                        }
                    }
                }
                // Right pane: show the diff for the selected file
                if !changedFiles.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Selected File:")
                                .padding()
                                .font(.title)
                                .bold()
                            
                            if let selected = selectedFile {
                                Text(selected)
                                    .padding(.horizontal)
                                    .font(.title3)
                                    .bold()
                                
                                ScrollView {
                                    // Use monospaced font so diffs look readable
                                    if selectedFileDiff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Loading diff...")
                                            .italic()
                                            .padding(.horizontal)
                                            .font(.system(.body, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        Text(selectedFileDiff)
                                            .padding(.horizontal)
                                            .font(.system(.body, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            } else {
                                Text("Click on a file to select it and see its changes")
                                    .padding(.horizontal)
                                    .font(.title3)
                            }
                        }
                    }
                    Spacer()
                }
            }
            /*
            VStack (alignment: .leading) {
                Text("Enter a push title")
                    .padding()
                TextField("Enter a push title", text: $pushTitle)
                    .padding()
                if showCommandOutput {
                    let changeDirCommand = "cd \(projectDirectory) && git add . && git commit -m \"\(pushTitle)\" && git push"
                    Text(runCommand(changeDirCommand).output)
                }
            }
             */
        }
        .navigationTitle(repoTitle)
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                // Branch menu: dynamically list branches and allow checkout
                Menu("Branch: \(currentBranch.isEmpty ? "Main" : currentBranch)") {
                    Button("New Branch...") {
                        // clear previous state and present a sheet
                        newBranchName = ""
                        newBranchError = nil
                        showNewBranchSheet = true
                    }
                    Divider()
                    // Idea: add new branch action and pull request creation/view
                    // Push current branch into main and delete branch (visible when we have a branch selected)
                    if !currentBranch.isEmpty {
                        Button("Push to main and delete branch") {
                            performPushToMain()
                        }
                        Divider()
                    }
                    ForEach(branches, id: \.self) { branch in
                        Button(action: {
                            checkoutBranch(branch)
                        }) {
                            HStack {
                                Text(branch)
                                Spacer()
                                if branch == currentBranch {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Create Pull Request") {
                        openCreatePullRequest()
                    }
                    if branches.isEmpty {
                        Button("No branches found") { }
                    }
                }
                 Menu("Actions") {
                     Button("Pull") {
                         performPull()
                     }
                     Button("Push") {
                         showPush = true
                     }
                     Divider()
                     // Idea: other git actions like fetch, stash
                 }
                 Menu("Open") {
                     Button("Open workspace in Finder") {
                         let homeURL = URL(fileURLWithPath: projectDirectory)
                         NSWorkspace.shared.activateFileViewerSelecting([homeURL])
                     }
                     Divider()
                     Button("Open workspace in Xcode") {
                         if let xcodeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode") {
                             let config = NSWorkspace.OpenConfiguration()
                             config.arguments = [projectDirectory]
                             NSWorkspace.shared.openApplication(at: xcodeURL, configuration: config)
                         }
                     }
                     Button("Open workspace in Visual Studio Code") {
                         let vsCodeURL = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
                         let config = NSWorkspace.OpenConfiguration()
                         config.arguments = [projectDirectory]
                         NSWorkspace.shared.openApplication(at: vsCodeURL, configuration: config)
                     }
                     Divider()
                     Button("Open directory in Terminal") {
                         if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                             let config = NSWorkspace.OpenConfiguration()
                             config.arguments = [projectDirectory]
                             NSWorkspace.shared.openApplication(at: terminalURL, configuration: config)
                         } else {
                             // Fallback URL scheme
                             let url = URL(string: "terminal://\(projectDirectory)")!
                             NSWorkspace.shared.open(url)
                         }
                     }
                     Divider()
                     Button("Open repository in GitHub") {
                         openRepositoryInGitHub()
                     }
                 }
             }
             ToolbarItemGroup(placement: .primaryAction) {
                 // Quick pull button shown when remote has new commits for the current branch
                 if needsPull {
                     Button(action: { performPull() }) {
                         HStack {
                             Image(systemName: "arrow.down.circle.fill")
                             Text("Pull (\(needsPullCount))")
                         }
                     }
                     .padding(.horizontal)
                     .buttonStyle(.borderless)
                 }
                 Button("Push") {
                         showPush = true
                 }
                 .padding(.horizontal)
                 .buttonStyle(.borderedProminent)
             }
         }
        .sheet(isPresented: $showPush) {
            PushView(projectDirectory: projectDirectory, onSuccess: {
                // Optimistically clear the local changed-files UI so the user sees updated state immediately.
                DispatchQueue.main.async {
                    self.changedFiles = []
                    self.selectedFile = nil
                    self.selectedFileDiff = ""
                    self.changedFilesFallbackOutput = ""
                }
                // Also kick off a more robust refresh sequence to reconcile with git on disk.
                refreshRepositoryState()
             })
         }
        // Sheet for creating a new branch
        .sheet(isPresented: $showNewBranchSheet) {
            VStack(alignment: .leading) {
                Text("Create New Branch")
                    .font(.headline)
                    .padding(.bottom, 8)
                TextField("Branch name", text: $newBranchName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 8)
                if let err = newBranchError {
                    Text(err)
                        .foregroundColor(.red)
                        .padding(.bottom, 8)
                }
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showNewBranchSheet = false
                        newBranchName = ""
                        newBranchError = nil
                    }
                    Button("Create") {
                        // basic validation
                        let trimmed = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else {
                            newBranchError = "Branch name cannot be empty"
                            return
                        }
                        showNewBranchSheet = false
                        createNewBranch(trimmed)
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .frame(width: 420)
        }
        // Load the changed files when the view appears
         .onAppear {
            loadChangedFiles()
            loadBranches()
            // Also check for remote updates at view open
            DispatchQueue.global(qos: .utility).async {
                self.checkRemoteUpdates()
            }
         }
        // When the push sheet is dismissed, refresh changed files & branches.
        .onChange(of: showPush) { oldValue, newValue in
            if newValue == false {
                refreshRepositoryState()
            }
        }
     }

     // MARK: - Helpers
     private func shellEscape(_ s: String) -> String {
         // Safely single-quote a string for use in bash -c
         return "'" + s.replacingOccurrences(of: "'", with: "'\\'\''") + "'"
     }

    // Try to open the repository page on GitHub if a GitHub remote is configured.
    private func openRepositoryInGitHub() {
        // Attempt to read the origin remote first
        let getOrigin = "cd \(shellEscape(projectDirectory)) && git remote get-url origin"
        print("RepoView.openRepositoryInGitHub: running: \(getOrigin)")
        var res = runCommand(getOrigin)
        var candidate = res.output.trimmingCharacters(in: .whitespacesAndNewlines)

        if candidate.isEmpty {
            // Fallback: inspect git remote -v and pick the first URL
            let listRemotes = "cd \(shellEscape(projectDirectory)) && git remote -v"
            print("RepoView.openRepositoryInGitHub: running fallback: \(listRemotes)")
            res = runCommand(listRemotes)
            let lines = res.output.split { $0 == "\n" || $0 == "\r" }.map { String($0) }
            for line in lines {
                // expected format: "origin\t<url> (fetch)" or similar
                let parts = line.split(separator: "\t", maxSplits: 1).map { String($0) }
                if parts.count >= 2 {
                    // take the url portion and trim any trailing " (fetch)" text
                    var urlPart = parts[1]
                    if let paren = urlPart.range(of: " (fetch)") {
                        urlPart = String(urlPart[..<paren.lowerBound])
                    } else if let paren2 = urlPart.range(of: " (push)") {
                        urlPart = String(urlPart[..<paren2.lowerBound])
                    }
                    candidate = urlPart.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !candidate.isEmpty { break }
                }
            }
        }

        if candidate.isEmpty {
            showAlert(title: "No remote found", message: "This repository has no configured git remotes.")
            return
        }

        if let url = convertGitRemoteToGitHubWebURL(candidate) {
            print("RepoView.openRepositoryInGitHub: opening url: \(url.absoluteString)")
            NSWorkspace.shared.open(url)
        } else {
            showAlert(title: "Not a GitHub remote", message: "The configured remote does not appear to point to GitHub: \(candidate)")
        }
    }

    private func convertGitRemoteToGitHubWebURL(_ remote: String) -> URL? {
        var s = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove .git suffix if present
        if s.hasSuffix(".git") {
            s = String(s.dropLast(4))
        }

        // git@github.com:owner/repo  -> https://github.com/owner/repo
        if s.hasPrefix("git@github.com:") {
            let path = String(s.dropFirst("git@github.com:".count))
            return URL(string: "https://github.com/\(path)")
        }

        // ssh://git@github.com/owner/repo -> https://github.com/owner/repo
        if s.hasPrefix("ssh://") || s.contains("git@github.com") {
            if let range = s.range(of: "github.com") {
                let after = s[range.upperBound...]
                let path = after.hasPrefix("/") ? String(after) : "/" + String(after)
                return URL(string: "https://github.com\(path)")
            }
        }

        // http(s)://...github.com/owner/repo
        if s.contains("github.com") {
            // Ensure scheme
            if s.hasPrefix("http://") || s.hasPrefix("https://") {
                return URL(string: s)
            } else if s.hasPrefix("github.com/") {
                return URL(string: "https://\(s)")
            } else {
                // Unknown but contains github.com
                if let idx = s.range(of: "github.com") {
                    let suffix = s[idx.lowerBound...]
                    let trimmed = suffix.hasPrefix("github.com") ? String(suffix) : String(suffix)
                    if trimmed.hasPrefix("github.com") {
                        return URL(string: "https://\(trimmed)")
                    }
                }
            }
        }

        return nil
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
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
    }

     private func loadChangedFiles() {
         // Use `git status --porcelain` to capture staged, unstaged and untracked files.
         let cmd = "cd \(shellEscape(projectDirectory)) && git status --porcelain"
         print("RepoView.loadChangedFiles: running: \(cmd)")
         let res = runCommand(cmd)
         let out = res.output
         print("RepoView.loadChangedFiles: exit=\(res.status) output=\(out)")

         // Parse porcelain output lines like: "XY <path>". For renames the format can contain "->".
         var parsedFiles: [String] = []
         let lines = out.split { $0 == "\n" || $0 == "\r" }.map { String($0) }
         for line in lines {
             // Don't trim leading whitespace here: git porcelain uses fixed columns for status
             // Keep leading spaces so we can drop the exact first 3 chars (two status cols + space)
             let raw = line.trimmingCharacters(in: .newlines)
             if raw.isEmpty { continue }
             // porcelain: first two chars are status, then a space, then path (or old -> new for renames)
             var pathPortion: String
             if raw.count >= 3 {
                 let idx2 = raw.index(raw.startIndex, offsetBy: 2)
                 if raw[idx2] == " " {
                     // Expected format: two status chars + space
                     pathPortion = String(raw[raw.index(idx2, offsetBy: 1)...]).trimmingCharacters(in: .whitespaces)
                 } else {
                     // Fallback for odd lines: preserve filename by starting at first non-space char
                     if let firstNonSpace = raw.firstIndex(where: { $0 != " " && $0 != "\t" }) {
                         pathPortion = String(raw[firstNonSpace...]).trimmingCharacters(in: .whitespaces)
                     } else {
                         continue
                     }
                 }
             } else {
                 // Very short lines: fallback to first non-space
                 if let firstNonSpace = raw.firstIndex(where: { $0 != " " && $0 != "\t" }) {
                     pathPortion = String(raw[firstNonSpace...]).trimmingCharacters(in: .whitespaces)
                 } else {
                     continue
                 }
             }
             if pathPortion.contains(" -> ") {
                 // For renames, take the destination path (after ->)
                 if let arrowRange = pathPortion.range(of: " -> ") {
                     pathPortion = String(pathPortion[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                 }
             }
             if !pathPortion.isEmpty {
                 parsedFiles.append(pathPortion)
             }
         }

         // Cache raw output and update state on main thread
         DispatchQueue.main.async {
             self.changedFilesFallbackOutput = out
             // Deduplicate while preserving order
             var seen = Set<String>()
             self.changedFiles = parsedFiles.filter { f in
                 if seen.contains(f) { return false }
                 seen.insert(f)
                 return true
             }

             // reset selection if current selection is no longer present
             if let sel = self.selectedFile, !self.changedFiles.contains(sel) {
                 self.selectedFile = nil
                 self.selectedFileDiff = ""
             }

             // If nothing is selected but we have changed files, auto-select the first one
             if self.selectedFile == nil, let first = self.changedFiles.first {
                 self.selectedFile = first
                 // load diff for the newly selected file
                 DispatchQueue.global(qos: .userInitiated).async {
                     self.loadDiff(for: first)
                 }
             }
         }
     }

    private func loadBranches() {
        // Load local branches and current branch
        let listCmd = "cd \(shellEscape(projectDirectory)) && git branch --format=\"%(refname:short)\""
        print("RepoView.loadBranches: running: \(listCmd)")
        let listRes = runCommand(listCmd)
        let listOut = listRes.output
        print("RepoView.loadBranches: exit=\(listRes.status) output=\(listOut)")
        let listLines = listOut.split { $0 == "\n" || $0 == "\r" }.map { String($0) }
        DispatchQueue.main.async {
            self.branches = listLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        let currentCmd = "cd \(shellEscape(projectDirectory)) && git rev-parse --abbrev-ref HEAD"
        let currentRes = runCommand(currentCmd)
        let currentOut = currentRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
        print("RepoView.loadBranches: current exit=\(currentRes.status) output=\(currentOut)")
        DispatchQueue.main.async {
            if !currentOut.isEmpty {
                self.currentBranch = currentOut
            } else if self.branches.count > 0 {
                self.currentBranch = self.branches[0]
            }
            // After branch resolved, check remote for updates in background
            DispatchQueue.global(qos: .utility).async {
                self.checkRemoteUpdates()
            }
        }
    }

    private func checkoutBranch(_ branch: String) {
        let cmd = "cd \(shellEscape(projectDirectory)) && git checkout \(shellEscape(branch))"
        print("RepoView.checkoutBranch: running: \(cmd)")
        let res = runCommand(cmd)
        print("RepoView.checkoutBranch: exit=\(res.status) output=\(res.output)")
        // Refresh branch list and changed files after checkout
        loadBranches()
        loadChangedFiles()
    }
    
    /// Create a new branch with the given name and check it out.
    private func createNewBranch(_ name: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let cmd = "cd \(shellEscape(projectDirectory)) && git checkout -b \(shellEscape(name))"
            print("RepoView.createNewBranch: running: \(cmd)")
            let res = runCommand(cmd)
            print("RepoView.createNewBranch: exit=\(res.status) output=\(res.output)")

            DispatchQueue.main.async {
                if res.status == 0 {
                    // success: refresh branches and set current branch
                    self.refreshRepositoryState()
                    self.currentBranch = name
                    self.showAlert(title: "Branch created", message: "Created and switched to branch \(name)")
                } else {
                    let msg = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.showAlert(title: "Failed to create branch", message: msg.isEmpty ? "git checkout -b returned an error." : msg)
                }
            }
        }
    }

    /// Open the repository's GitHub page to create a pull request for the current branch.
    private func openCreatePullRequest() {
        guard !currentBranch.isEmpty else {
            showAlert(title: "No branch selected", message: "Select a branch first.")
            return
        }

        // Try to determine the GitHub web URL for the origin remote.
        let getOrigin = "cd \(shellEscape(projectDirectory)) && git remote get-url origin"
        let res = runCommand(getOrigin)
        let remote = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if remote.isEmpty {
            showAlert(title: "No remote found", message: "This repository has no configured origin remote.")
            return
        }

        guard var web = convertGitRemoteToGitHubWebURL(remote) else {
            showAlert(title: "Not a GitHub remote", message: "The configured remote does not appear to point to GitHub: \(remote)")
            return
        }

        // Construct a pull request creation URL: /pull/new/<branch>
        // Ensure we don't double-append a trailing slash
        var base = web.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        let prURLString = "\(base)/pull/new/\(currentBranch)"
        if let prURL = URL(string: prURLString) {
            NSWorkspace.shared.open(prURL)
        } else {
            showAlert(title: "Couldn't open PR", message: "Failed to construct a valid pull request URL for \(web.absoluteString)")
        }
    }

    /// Heuristically pick the repository's main branch name (prefer 'main' then 'master').
    private func pickMainBranchName() -> String {
        let candidates = ["main", "master"]
        for c in candidates {
            if branches.contains(c) { return c }
        }
        // fallback to 'main'
        return "main"
    }

    /// Confirm and perform a merge of the current branch into main, push main, delete the branch locally and remotely (if present).
    private func performPushToMain() {
        let source = currentBranch
        let mainBranch = pickMainBranchName()

        if source.isEmpty {
            showAlert(title: "No branch selected", message: "Select a branch to push to main.")
            return
        }

        if source == mainBranch {
            showAlert(title: "Already on main", message: "You are already on \(mainBranch).")
            return
        }

        // Ask for confirmation on main thread
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Push \(source) to \(mainBranch) and delete branch?"
            alert.informativeText = "This will checkout \(mainBranch), merge \(source) into \(mainBranch), push \(mainBranch) to remote, and delete branch \(source) locally (and remotely if present)."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Push & Delete")
            alert.addButton(withTitle: "Cancel")
            if let window = NSApplication.shared.keyWindow {
                alert.beginSheetModal(for: window) { response in
                    if response == .alertFirstButtonReturn {
                        // User confirmed
                        DispatchQueue.global(qos: .userInitiated).async {
                            self.executePushToMain(sourceBranch: source, mainBranch: mainBranch)
                        }
                    }
                }
            } else {
                let resp = alert.runModal()
                if resp == .alertFirstButtonReturn {
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.executePushToMain(sourceBranch: source, mainBranch: mainBranch)
                    }
                }
            }
        }
    }

    private func executePushToMain(sourceBranch: String, mainBranch: String) {
        var summary = ""

        // 1) Checkout main
        let checkoutMain = "cd \(shellEscape(projectDirectory)) && git checkout \(shellEscape(mainBranch))"
        print("RepoView.executePushToMain: running: \(checkoutMain)")
        let res1 = runCommand(checkoutMain)
        summary += "checkout: \(res1.output)\n"
        if res1.status != 0 {
            DispatchQueue.main.async {
                self.showAlert(title: "Failed to checkout \(mainBranch)", message: res1.output)
            }
            return
        }

        // 2) Merge source into main (attempt a no-ff merge)
        let mergeCmd = "cd \(shellEscape(projectDirectory)) && git merge --no-ff --no-edit \(shellEscape(sourceBranch))"
        print("RepoView.executePushToMain: running: \(mergeCmd)")
        let res2 = runCommand(mergeCmd)
        summary += "merge: \(res2.output)\n"
        if res2.status != 0 {
            // Merge failed (possibly conflicts). Try to go back to source branch to leave user in a safe state.
            let backCmd = "cd \(shellEscape(projectDirectory)) && git checkout \(shellEscape(sourceBranch))"
            _ = runCommand(backCmd)
            DispatchQueue.main.async {
                self.showAlert(title: "Merge failed", message: "Merge failed: \(res2.output)\nChecked out back to \(sourceBranch). Resolve conflicts manually.")
            }
            return
        }

        // 3) Push main to origin
        let pushMain = "cd \(shellEscape(projectDirectory)) && git push origin \(shellEscape(mainBranch))"
        print("RepoView.executePushToMain: running: \(pushMain)")
        let res3 = runCommand(pushMain)
        summary += "push: \(res3.output)\n"
        if res3.status != 0 {
            DispatchQueue.main.async {
                self.showAlert(title: "Failed to push \(mainBranch)", message: res3.output)
            }
            return
        }

        // 4) Delete local branch
        let delLocal = "cd \(shellEscape(projectDirectory)) && git branch -d \(shellEscape(sourceBranch))"
        print("RepoView.executePushToMain: running: \(delLocal)")
        let res4 = runCommand(delLocal)
        summary += "delete-local: \(res4.output)\n"

        // 5) If remote branch exists, delete remote branch
        let remoteCheck = "cd \(shellEscape(projectDirectory)) && git ls-remote --heads origin \(shellEscape(sourceBranch))"
        let remRes = runCommand(remoteCheck)
        if !remRes.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let delRemote = "cd \(shellEscape(projectDirectory)) && git push origin --delete \(shellEscape(sourceBranch))"
            print("RepoView.executePushToMain: running: \(delRemote)")
            let res5 = runCommand(delRemote)
            summary += "delete-remote: \(res5.output)\n"
        } else {
            summary += "delete-remote: (no remote branch found)\n"
        }

        // Refresh state
        self.refreshRepositoryState()
        self.checkRemoteUpdates()

        // Show summary
        DispatchQueue.main.async {
            self.showAlert(title: "Push to main completed", message: summary)
        }
    }
 
     private func selectFile(_ file: String) {
         selectedFile = file
         loadDiff(for: file)
     }

     private func loadDiff(for file: String) {
         // Try to show the most helpful diff for the file:
         // 1) Changes against HEAD (includes staged + unstaged differences)
         // 2) If empty, try staged diff explicitly
         // 3) If still empty and file is untracked, show the file contents
         let escapedFile = shellEscape(file)
         let baseCmd = "cd \(shellEscape(projectDirectory)) && git --no-pager"

         let diffHeadCmd = "\(baseCmd) diff HEAD -- \(escapedFile)"
         print("RepoView.loadDiff: running: \(diffHeadCmd)")
         let resHead = runCommand(diffHeadCmd)
         print("RepoView.loadDiff: headDiff exit=\(resHead.status) outputLength=\(resHead.output.count)")

         var finalOutput = resHead.output

         if finalOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
             // Try staged diff explicitly
             let stagedCmd = "\(baseCmd) diff --staged -- \(escapedFile)"
             print("RepoView.loadDiff: running staged: \(stagedCmd)")
             let resStaged = runCommand(stagedCmd)
             print("RepoView.loadDiff: stagedDiff exit=\(resStaged.status) outputLength=\(resStaged.output.count)")
             if !resStaged.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                 finalOutput = resStaged.output
             } else {
                 // Check if file is untracked; if so, show its contents
                 let untrackedCmd = "cd \(shellEscape(projectDirectory)) && git ls-files --others --exclude-standard -- \(escapedFile)"
                 print("RepoView.loadDiff: checking untracked: \(untrackedCmd)")
                 let resUntracked = runCommand(untrackedCmd)
                 let isUntracked = !resUntracked.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 print("RepoView.loadDiff: untracked exit=\(resUntracked.status) isUntracked=\(isUntracked)")
                 if isUntracked {
                     // Show file contents as a preview for the new file
                     let catCmd = "cd \(shellEscape(projectDirectory)) && cat \(escapedFile)"
                     print("RepoView.loadDiff: running cat for untracked file: \(catCmd)")
                     let resCat = runCommand(catCmd)
                     if !resCat.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                         finalOutput = "(New file) Contents:\n\n" + resCat.output
                     } else {
                         finalOutput = "(New file) No readable contents or file is binary."
                     }
                 } else {
                     finalOutput = "No diff available for this file. It may be unchanged in the working tree, or the changes are binary. Try checking staged changes."
                 }
             }
         }

         DispatchQueue.main.async {
             self.selectedFileDiff = finalOutput
         }
     }

    // Run an immediate refresh in the background and schedule follow-up refreshes
    // to handle any timing races with git or other processes.
    private func refreshRepositoryState() {
        DispatchQueue.global(qos: .userInitiated).async {
            loadChangedFiles()
            loadBranches()
        }

        // Retry after a short delay to handle async state changes on disk or background hooks
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
            loadChangedFiles()
            loadBranches()
        }

        // One more retry slightly later
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3.0) {
            loadChangedFiles()
            loadBranches()
        }
    }

    /// Check whether the current branch is behind its upstream (needs pull).
    /// This runs a `git fetch` then compares HEAD to the upstream to compute behind count.
    private func checkRemoteUpdates() {
        guard !currentBranch.isEmpty else {
            DispatchQueue.main.async {
                self.needsPull = false
                self.needsPullCount = 0
            }
            return
        }

        // Fetch the remote refs so we can compare without pulling changes
        let fetchCmd = "cd \(shellEscape(projectDirectory)) && git fetch --no-tags --prune origin"
        print("RepoView.checkRemoteUpdates: running: \(fetchCmd)")
        _ = runCommand(fetchCmd)

        // Resolve the upstream reference for the current branch (@{u}), falling back to origin/<branch>
        var upstream: String? = nil
        let upTry = "cd \(shellEscape(projectDirectory)) && git rev-parse --abbrev-ref --symbolic-full-name @{u}"
        let upRes = runCommand(upTry)
        if upRes.status == 0 {
            let out = upRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !out.isEmpty { upstream = out }
        }
        if upstream == nil {
            upstream = "origin/\(currentBranch)"
        }

        guard let upstreamRef = upstream else {
            DispatchQueue.main.async {
                self.needsPull = false
                self.needsPullCount = 0
            }
            return
        }

        // Compare HEAD with upstream: returns "<ahead>\t<behind>"
        let cmp = "cd \(shellEscape(projectDirectory)) && git rev-list --left-right --count HEAD...\(shellEscape(upstreamRef))"
        print("RepoView.checkRemoteUpdates: running: \(cmp)")
        let cmpRes = runCommand(cmp)
        let cmpOut = cmpRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
        print("RepoView.checkRemoteUpdates: exit=\(cmpRes.status) output=\(cmpOut)")

        var behind = 0
        if cmpRes.status == 0 && !cmpOut.isEmpty {
            let parts = cmpOut.split { $0 == "\t" || $0 == " " }.map { String($0) }.filter { !$0.isEmpty }
            if parts.count >= 2, let b = Int(parts[1]) { behind = b }
        }

        DispatchQueue.main.async {
            self.needsPullCount = behind
            self.needsPull = (behind > 0)
        }
    }

    /// Perform a git pull and refresh UI state afterwards.
    private func performPull() {
        DispatchQueue.global(qos: .userInitiated).async {
            let pullCmd = "cd \(shellEscape(projectDirectory)) && git pull --no-rebase"
            print("RepoView.performPull: running: \(pullCmd)")
            let res = runCommand(pullCmd)
            print("RepoView.performPull: exit=\(res.status) output=\(res.output)")

            // Refresh local state and re-check remote
            self.refreshRepositoryState()
            self.checkRemoteUpdates()

            DispatchQueue.main.async {
                let msg = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if res.status == 0 {
                    self.showAlert(title: "Pull completed", message: msg.isEmpty ? "Pulled changes successfully." : msg)
                } else {
                    self.showAlert(title: "Pull failed", message: msg.isEmpty ? "git pull returned an error." : msg)
                }
            }
        }
    }
 }
