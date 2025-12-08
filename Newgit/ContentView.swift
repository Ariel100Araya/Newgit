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
    // Use a UUID-based selection so SwiftUI can properly track changes
    @State private var selectionID: UUID? = nil
    // Deletion state
    @State private var repoToDelete: SavedRepo? = nil
    @State private var showDeleteDialog: Bool = false
    @State private var deleteResultMessage: String = ""
    @State private var showDeleteResultAlert: Bool = false
    @State private var debugSelectedName: String = ""

    var body: some View {
        // Build the split view into a local variable to reduce expression complexity for the compiler
        let nav = NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }

        // Apply modifiers in small steps using AnyView to avoid type-checking complexity
        var anyView = AnyView(nav)

        anyView = AnyView(anyView.onChange(of: selectionID) { old, new in
            print("selectionID changed from \(old?.uuidString ?? "nil") to \(new?.uuidString ?? "nil")")
            if let id = new, let r = savedRepos.first(where: { $0.id == id }) {
                print("resolved to repo: \(r.name) (id: \(r.id))")
            } else {
                print("selection did not resolve to a repo")
            }
        })

        anyView = AnyView(anyView.sheet(isPresented: $showAddRepo) { AddRepoView() })
        anyView = AnyView(anyView.sheet(isPresented: $showCloneRepo) { CloneRepoView() })
        anyView = AnyView(anyView.sheet(isPresented: $showAddNewRepo) { AddNewRepoView() })

        anyView = AnyView(anyView.confirmationDialog("Delete Repository", isPresented: $showDeleteDialog) {
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
        })

        anyView = AnyView(anyView.alert(deleteResultMessage, isPresented: $showDeleteResultAlert) { Button("OK", role: .cancel) {} })

        anyView = AnyView(anyView.onAppear {
            print("onAppear: savedRepos count = \(savedRepos.count)")
            for r in savedRepos { print("repo: \(r.name) id: \(r.id)") }
            if selectionID == nil, let first = savedRepos.first {
                selectionID = first.id
            }
        })

        anyView = AnyView(anyView.onChange(of: savedRepos) { oldRepos, newRepos in
            print("savedRepos changed: new count = \(newRepos.count)")
            for r in newRepos { print("repo: \(r.name) id: \(r.id)") }
            // If selection is nil, select first. If selected id was removed, clear it.
            if selectionID == nil, let first = newRepos.first {
                selectionID = first.id
            }
            if let sel = selectionID, !newRepos.contains(where: { $0.id == sel }) {
                print("current selection id \(sel) not present in new repos -> clearing selection")
                selectionID = nil
            }
        })

        anyView = AnyView(anyView.onChange(of: selectionID) { old, new in
            if let id = new, let repo = savedRepos.first(where: { $0.id == id }) {
                debugSelectedName = repo.name
            }
        })

        return anyView
    }

    // MARK: - Small subviews to help type-checking
    @ViewBuilder
    private var sidebar: some View {
        // Sidebar with liquid glass look
        VStack(spacing: 0) {
            HStack {
                Text("Repositories")
                    .font(.headline)
                    .padding(.leading)
                Spacer()
                Menu {
                    Button("Clone Repository") { showCloneRepo = true }
                    Button("Add New Repository") { showAddNewRepo = true }
                    Button("Add Existing Repository") { showAddRepo = true }
                } label: { Image(systemName: "plus").padding(.trailing) }
            }
            List(selection: $selectionID) {
                ForEach(savedRepos, id: \.id) { repo in
                    Text(repo.name)
                        .tag(repo.id)
                        .contextMenu { Button("Delete Repository") { repoToDelete = repo; showDeleteDialog = true } }
                }
            }
            .listStyle(.sidebar)
        }
        .cornerRadius(12)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
    }

    @ViewBuilder
    private var detailView: some View {
        if let id = selectionID, let repo = savedRepos.first(where: { $0.id == id }) {
            RepoView(repoTitle: repo.name, projectDirectory: repo.path)
                .id(repo.id)
        } else {
            VStack(alignment: .leading) {
                Text("Select a repository")
                    .foregroundStyle(.secondary)
                if !debugSelectedName.isEmpty {
                    Text("Last resolved: \(debugSelectedName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        // If the deleted repo is currently selected, clear the selectionID so the detail updates
        if selectionID == repo.id {
            selectionID = nil
        }

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
