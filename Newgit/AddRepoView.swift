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
    @State private var projectDirectory: String = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var savedRepos: [SavedRepo]
    @State private var showSaveAlert: Bool = false
    @State private var saveMessage: String = ""
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
}
