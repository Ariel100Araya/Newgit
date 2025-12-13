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

    // New states for branch actions
    @State private var showAddBranchSheet: Bool = false
    @State private var newBranchName: String = ""

    @State private var showMergeSheet: Bool = false
    @State private var mergeTargetBranch: String = ""

    @State private var showPRSheet: Bool = false
    @State private var prTitle: String = ""
    @State private var prBody: String = ""
    @State private var prBaseBranch: String = ""

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
                    if branches.isEmpty {
                        Button("No branches found") { }
                    }
                    Divider()
                    Button("Add Branch...") {
                        newBranchName = ""
                        print("Branch menu: Add Branch tapped")
                        print("NSApp windows: \(NSApp.windows.map { $0.title }) keyWindow: \(String(describing: NSApp.keyWindow)) mainWindow: \(String(describing: NSApp.mainWindow))")
                        // slightly longer delay to ensure the NSMenu closes before sheet presentation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            print("Presenting AddBranch sheet now")
                            showAddBranchSheet = true
                        }
                    }
                    Button("Merge current into…") {
                        // Default to first branch that's not the current one
                        mergeTargetBranch = branches.first(where: { $0 != currentBranch }) ?? ""
                        print("Branch menu: Merge tapped, target=\(mergeTargetBranch)")
                        print("NSApp windows: \(NSApp.windows.map { $0.title }) keyWindow: \(String(describing: NSApp.keyWindow)) mainWindow: \(String(describing: NSApp.mainWindow))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            print("Presenting Merge sheet now")
                            showMergeSheet = true
                        }
                    }
                    Button("Create Pull Request") {
                        prTitle = ""
                        prBody = ""
                        prBaseBranch = branches.first(where: { $0 != currentBranch }) ?? (branches.first ?? "main")
                        print("Branch menu: Create PR tapped, base=\(prBaseBranch)")
                        print("NSApp windows: \(NSApp.windows.map { $0.title }) keyWindow: \(String(describing: NSApp.keyWindow)) mainWindow: \(String(describing: NSApp.mainWindow))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            print("Presenting PR sheet now")
                            showPRSheet = true
                        }
                    }
                 }
                  Menu("Actions") {
                      Button("Pull") {
                          performPull()
                      }
                      Button("Push") {
                          showPush = true
                      }
                      Button("Commit Changes") {
                          
                      }
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
         // Add Branch sheet
         .sheet(isPresented: $showAddBranchSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Create a new branch")
                    .font(.headline)
                TextField("Branch name", text: $newBranchName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showAddBranchSheet = false
                    }
                    Button("Create") {
                        let name = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        showAddBranchSheet = false
                        createBranch(name)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(minWidth: 420, minHeight: 140)
        }

        // Merge sheet
        .sheet(isPresented: $showMergeSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Merge current branch into…")
                    .font(.headline)

                if branches.filter({ $0 != currentBranch }).isEmpty {
                    Text("No other branches available to merge into.")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Target branch", selection: $mergeTargetBranch) {
                        ForEach(branches.filter({ $0 != currentBranch }), id: \.self) { b in
                            Text(b).tag(b)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Spacer()
                    Button("Cancel") {
                        showMergeSheet = false
                    }
                    Button("Merge") {
                        let target = mergeTargetBranch.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !target.isEmpty else { return }
                        showMergeSheet = false
                        mergeCurrentInto(target)
                    }
                    .disabled(mergeTargetBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(minWidth: 480, minHeight: 160)
        }

        // Pull Request sheet
        .sheet(isPresented: $showPRSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Create Pull Request")
                    .font(.headline)

                TextField("PR title", text: $prTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextEditor(text: $prBody)
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))

                Picker("Base branch", selection: $prBaseBranch) {
                    ForEach(branches.filter({ $0 != currentBranch }), id: \.self) { b in
                        Text(b).tag(b)
                    }
                    // fallback
                    ForEach(branches, id: \.self) { b in
                        if branches.filter({ $0 != currentBranch }).isEmpty { Text(b).tag(b) }
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Spacer()
                    Button("Cancel") {
                        showPRSheet = false
                    }
                    Button("Create PR") {
                        let title = prTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let body = prBody.trimmingCharacters(in: .whitespacesAndNewlines)
                        let base = prBaseBranch.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty, !base.isEmpty else { return }
                        showPRSheet = false
                        createPullRequest(base: base, title: title, body: body)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(prTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prBaseBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(minWidth: 520, minHeight: 320)
        }
         // Load the changed files when the view appears (do heavy work off the main thread so UI remains responsive)
         .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                loadChangedFiles()
                loadBranches()
            }
         }
        // When the push sheet is dismissed, refresh changed files & branches.
        .onChange(of: showPush) { oldValue, newValue in
            if newValue == false {
                refreshRepositoryState()
            }
        }
        // Debug: log when our sheet flags change so we can see whether presentation state flips
        .onChange(of: showAddBranchSheet) { newValue in
            print("showAddBranchSheet changed -> \(newValue)")
            if newValue == false { refreshRepositoryState() }
        }
        .onChange(of: showMergeSheet) { newValue in
            print("showMergeSheet changed -> \(newValue)")
            if newValue == false { refreshRepositoryState() }
        }
        .onChange(of: showPRSheet) { newValue in
            print("showPRSheet changed -> \(newValue)")
            if newValue == false { refreshRepositoryState() }
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

    /// Perform a git pull and refresh UI state afterwards.
    private func performPull() {
        DispatchQueue.global(qos: .userInitiated).async {
            let pullCmd = "cd \(shellEscape(projectDirectory)) && git pull --no-rebase"
            print("RepoView.performPull: running: \(pullCmd)")
            let res = runCommand(pullCmd)
            print("RepoView.performPull: exit=\(res.status) output=\(res.output)")

            // Refresh local state
            self.refreshRepositoryState()

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

    // MARK: - Branch action helpers
    private func createBranch(_ branch: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let cmd = "cd \(shellEscape(projectDirectory)) && git checkout -b \(shellEscape(branch))"
            print("RepoView.createBranch: running: \(cmd)")
            let res = runCommand(cmd)
            print("RepoView.createBranch: exit=\(res.status) output=\(res.output)")
            DispatchQueue.main.async {
                if res.status == 0 {
                    loadBranches()
                    currentBranch = branch
                    showAlert(title: "Branch created", message: "Created and checked out branch \(branch)")
                } else {
                    showAlert(title: "Create branch failed", message: res.output)
                }
            }
        }
    }

    private func mergeCurrentInto(_ target: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Checkout the target and merge current branch into it
            let cmd = "cd \(shellEscape(projectDirectory)) && git checkout \(shellEscape(target)) && git merge --no-ff \(shellEscape(currentBranch)) -m \"Merge branch '\(currentBranch)' into \(target)\""
            print("RepoView.mergeCurrentInto: running: \(cmd)")
            let res = runCommand(cmd)
            print("RepoView.mergeCurrentInto: exit=\(res.status) output=\(res.output)")
            DispatchQueue.main.async {
                if res.status == 0 {
                    loadBranches()
                    loadChangedFiles()
                    showAlert(title: "Merge succeeded", message: res.output.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    showAlert(title: "Merge failed", message: res.output)
                }
            }
        }
    }

    private func createPullRequest(base: String, title: String, body: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let args = ["pr", "create", "--title", title, "--body", body, "--base", base, "--head", currentBranch]
            print("RepoView.createPullRequest: running gh \(args)")
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            print("RepoView.createPullRequest: exit=\(res.status) output=\(res.output)")
            DispatchQueue.main.async {
                if res.status == 0 {
                    showAlert(title: "Pull request created", message: res.output.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    showAlert(title: "gh pr create failed", message: res.output)
                }
            }
        }
    }

 }
