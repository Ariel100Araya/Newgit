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
    @State private var projectDirectory: String = ""
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
                Button("Browse") {
                    browseForDirectory()
                }
                .glassEffect()
                .padding(.leading, 6)
            }
            .padding(.bottom)
            Text("Enter a title")
            TextField("Enter a title", text: $projectTitle)
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

            if !publishOutput.isEmpty {
                Text("Publish output:")
                    .font(.caption)
                    .padding(.top, 6)
                ScrollView {
                    Text(publishOutput)
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
                dismiss()
             }
             .buttonStyle(.borderedProminent)
             .glassEffect()
             .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    // Create a local git repo, initialize with README, and publish to GitHub using gh
    private func createAndPublishRepo() async {
        let title = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
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
        cmds += "git init \n"
        cmds += "if [ ! -f README.md ]; then echo '# \(title)' > README.md; fi\n"
        cmds += "if [ ! -d .git ]; then git init; fi\n"
        cmds += "git add . \n"
        cmds += "git commit -m \"Initial commit\" || true\n"

        let prepRes = runCommand(cmds)
        DispatchQueue.main.async {
            publishOutput += "Prepare output:\n\(prepRes.output)\n"
        }

        // Use gh to create the remote and push. Run inside the directory.
        let visibility = makePrivate ? "--private" : "--public"
        // Use gh repo create with --source=. --remote=origin --push to create remote from local dir
        let ghArgs = ["repo", "create", title, visibility, "--source", ".", "--remote", "origin", "--push"]
        let ghRes = runGHCommand(ghArgs)
        DispatchQueue.main.async {
            publishOutput += "gh output:\n\(ghRes.output)\n"
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
        }
    }
}
