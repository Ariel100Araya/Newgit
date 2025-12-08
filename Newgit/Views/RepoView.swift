//
//  RepoView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/6/25.
//

import SwiftUI

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
        VStack(alignment: .leading) {
            HStack {
                // Left pane: selectable list of changed files
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("Changed Files:")
                            .padding()
                            .font(.title)
                            .bold()
                        
                        if changedFiles.isEmpty {
                            HStack {
                                VStack {
                                    // Show raw output as fallback while loading or if none
                                    Text(changedFilesFallbackOutput)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(nil)
                                    Text("It seems like there isn't any changed files. Time to get to work!")
                                        .font(.title3)
                                        .padding()
                                }
                                Spacer()
                            }
                        } else {
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
                                    Text(selectedFileDiff)
                                        .padding(.horizontal)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
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
                         
                     }
                     Button("Commit Changes") {
                         
                     }
                 }
                 Menu("Open") {
                     Button("Open workspace in Finder") {
                         
                     }
                     Button("Open workspace in Xcode") {
                         
                     }
                     Button("Open workspace in Visual Studio Code") {
                         
                     }
                     Button("Open repository in GitHub") {
                         
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
         return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
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
             let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
             if trimmed.isEmpty { continue }
             // porcelain: first two chars are status, then a space, then path (or old -> new for renames)
             let startIndex = trimmed.index(trimmed.startIndex, offsetBy: min(3, trimmed.count))
             var pathPortion = String(trimmed[startIndex...]).trimmingCharacters(in: .whitespaces)
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
         let cmd = "cd \(shellEscape(projectDirectory)) && git --no-pager diff -- \(shellEscape(file))"
         print("RepoView.loadDiff: running: \(cmd)")
         let res = runCommand(cmd)
         print("RepoView.loadDiff: exit=\(res.status) outputLength=\(res.output.count)")
         DispatchQueue.main.async {
             self.selectedFileDiff = res.output
         }
     }
 }
