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
                    // Validate inputs
                    let trimmedTitle = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Save-time sanitizer: trim leading/trailing hyphens
                    let sanitizedTitle = sanitizeProjectNameForSave(trimmedTitle)
                    let trimmedPath = projectDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !sanitizedTitle.isEmpty, !trimmedPath.isEmpty else {
                        saveMessage = "Please enter both a project title and directory."
                        showSaveAlert = true
                        return
                    }

                    let repo = SavedRepo(name: sanitizedTitle, path: trimmedPath)
                    modelContext.insert(repo)
                    print("AddRepoView(toolbar): inserted repo \(sanitizedTitle) id=\(repo.id)")
                    do {
                        try modelContext.save()
                        saveMessage = "Saved \(sanitizedTitle)"
                        print("AddRepoView(toolbar): modelContext.save() succeeded. savedRepos count = \(savedRepos.count)")
                    } catch {
                        saveMessage = "Save failed: \(error.localizedDescription)"
                        print("AddRepoView(toolbar): modelContext.save() failed: \(error)")
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
        
        let repo = SavedRepo(name: sanitizedTitle, path: trimmedPath)
        modelContext.insert(repo)
        print("AddRepoView: inserted repo \(sanitizedTitle) id=\(repo.id)")
        do {
            try modelContext.save()
            saveMessage = "Saved \(sanitizedTitle)"
            print("AddRepoView: modelContext.save() succeeded. savedRepos count = \(savedRepos.count)")
        } catch {
            saveMessage = "Save failed: \(error.localizedDescription)"
            print("AddRepoView: modelContext.save() failed: \(error)")
        }
        showSaveAlert = true
        // Clear inputs after adding
        projectTitle = ""
        projectDirectory = ""
        dismiss()
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
}
