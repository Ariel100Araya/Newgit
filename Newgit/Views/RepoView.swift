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
                }
                 Menu("Actions") {
                     Button("Pull") {
                         
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
            PushView(projectDirectory: projectDirectory)
        }
         // Load the changed files when the view appears
         .onAppear {
            loadChangedFiles()
            loadBranches()
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
 }
