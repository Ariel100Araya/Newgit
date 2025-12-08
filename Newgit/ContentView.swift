//
//  ContentView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/6/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var savedRepos: [SavedRepo]
    @Environment(\.modelContext) private var modelContext
    @State var showAddRepo = false
    @State var showAddNewRepo = false
    @State var showCloneRepo = false
    // Deletion state
    @State private var repoToDelete: SavedRepo? = nil
    @State private var showDeleteDialog: Bool = false
    @State private var deleteResultMessage: String = ""
    @State private var showDeleteResultAlert: Bool = false
    var body: some View {
        NavigationSplitView{
            List {
                Text("Repositories")
                    .font(.largeTitle)
                    .bold()
                ForEach(savedRepos, id: \.id) { repo in
                    NavigationLink(destination: RepoView(repoTitle: repo.name, projectDirectory: repo.path)) {
                        Text(repo.name)
                            .font(.title2)
                    }
                    .contextMenu {
                        Button("Delete Repository") {
                            repoToDelete = repo
                            showDeleteDialog = true
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Menu("\(Image(systemName: "plus"))") {
                            Button("Clone Repository") {
                                // Action to clone repo can be implemented here
                                showCloneRepo = true
                            }
                            Button("Add New Repository") {
                                // Action to add a new repo can be implemented here
                                showAddNewRepo = true
                            }
                            Button("Add Existing Repository") {
                                // Action to add a new repo can be implemented here
                                showAddRepo = true
                            }
                        }
                    }
                }
            }
        } detail: {
            TestView()
        }
        .sheet(isPresented: $showAddRepo) {
            AddRepoView()
        }
        .sheet(isPresented: $showCloneRepo) {
            CloneRepoView()
        }
        .sheet(isPresented: $showAddNewRepo) {
            AddNewRepoView()
        }
        // Confirmation dialog offering to delete saved entry or delete and remove files
        .confirmationDialog("Delete Repository", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("Delete saved entry") {
                guard let repo = repoToDelete else { return }
                deleteSavedRepo(repo: repo, removeFiles: false)
            }
            Button("Delete saved entry and remove files", role: .destructive) {
                guard let repo = repoToDelete else { return }
                deleteSavedRepo(repo: repo, removeFiles: true)
            }
            Button("Cancel", role: .cancel) {
                repoToDelete = nil
            }
        } message: {
            if let path = repoToDelete?.path {
                Text("Are you sure you want to delete \(repoToDelete?.name ?? "this repository")?\nPath: \(path)")
            }
        }
        .alert(deleteResultMessage, isPresented: $showDeleteResultAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Deletion helpers
    private func deleteSavedRepo(repo: SavedRepo, removeFiles: Bool) {
        // Optionally remove files on disk first
        if removeFiles {
            do {
                try FileManager.default.removeItem(atPath: repo.path)
            } catch {
                // If file deletion fails, show message but still attempt model deletion
                deleteResultMessage = "Failed to remove repository files: \(error.localizedDescription)"
                showDeleteResultAlert = true
            }
        }

        // Delete the saved repo from SwiftData model
        modelContext.delete(repo)
        do {
            try modelContext.save()
            deleteResultMessage = "Deleted \(repo.name)"
        } catch {
            deleteResultMessage = "Failed to delete saved repo: \(error.localizedDescription)"
            print("ModelContext save error: \(error)")
        }
        showDeleteResultAlert = true
        repoToDelete = nil
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SavedRepo.self])
}
