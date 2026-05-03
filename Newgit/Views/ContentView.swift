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
    @EnvironmentObject private var commandCenter: AppCommandCenter
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

    private enum PendingNavigation {
        case issues(String)
        case release(String)
    }

    @State private var pendingNavigation: PendingNavigation? = nil

    private var selectedRepositoryPath: String? {
        if let id = selectionID, let repo = savedRepos.first(where: { $0.id == id }) {
            return repo.path
        }
        return commandCenter.selectedRepositoryPath
    }

    private var hasSelectedRepository: Bool {
        selectedRepositoryPath?.isEmpty == false
    }

    var body: some View {
        // Build the split view into a local variable to reduce expression complexity for the compiler
        let nav = NavigationSplitView {
            sidebar
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Menu {
                            Button("Clone Repository") { showCloneRepo = true }
                            Button("Add New Repository") { showAddNewRepo = true }
                            Button("Add Existing Repository") { showAddRepo = true }
                        } label: { Image(systemName: "plus").padding(.trailing) }
                    }
                }
        } detail: {
            detailView
        }

        // Apply modifiers in small steps using AnyView to avoid type-checking complexity
        var anyView = AnyView(nav)

        anyView = AnyView(anyView.onChange(of: selectionID) { old, new in
            print("selectionID changed from \(old?.uuidString ?? "nil") to \(new?.uuidString ?? "nil")")
            if let id = new, let r = savedRepos.first(where: { $0.id == id }) {
                print("resolved to repo: \(r.name) (id: \(r.id))")
                handlePendingNavigation(for: r.path)
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
            syncSelectedRepository()
            #if os(macOS)
            NotificationCenter.default.addObserver(forName: .newgitCloneRepo, object: nil, queue: .main) { _ in
                showCloneRepo = true
            }
            NotificationCenter.default.addObserver(forName: .newgitAddNewRepo, object: nil, queue: .main) { _ in
                showAddNewRepo = true
            }
            NotificationCenter.default.addObserver(forName: .newgitAddExistingRepo, object: nil, queue: .main) { _ in
                showAddRepo = true
            }
            #endif
        })

        anyView = AnyView(anyView.onDisappear {
            #if os(macOS)
            NotificationCenter.default.removeObserver(self, name: .newgitCloneRepo, object: nil)
            NotificationCenter.default.removeObserver(self, name: .newgitAddNewRepo, object: nil)
            NotificationCenter.default.removeObserver(self, name: .newgitAddExistingRepo, object: nil)
            #endif
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
            syncSelectedRepository()
        })

        anyView = AnyView(anyView.onChange(of: selectionID) { old, new in
            if let id = new, let repo = savedRepos.first(where: { $0.id == id }) {
                debugSelectedName = repo.name
            }
            syncSelectedRepository()
        })
        anyView = AnyView(anyView.onReceive(NotificationCenter.default.publisher(for: .newgitOpenRepository)) { notification in
            guard let path = notification.object as? String else { return }
            openRepository(at: path)
        })
        anyView = AnyView(anyView.onReceive(NotificationCenter.default.publisher(for: .newgitOpenIssues)) { notification in
            guard let path = notification.object as? String else { return }
            openRepository(at: path)
            pendingNavigation = .issues(path)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .newgitOpenIssuesInSelectedRepo, object: path)
            }
        })
        anyView = AnyView(anyView.onReceive(NotificationCenter.default.publisher(for: .newgitOpenRelease)) { notification in
            guard let path = notification.object as? String else { return }
            openRepository(at: path)
            pendingNavigation = .release(path)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .newgitOpenReleaseInSelectedRepo, object: path)
            }
        })
        anyView = AnyView(anyView.onReceive(NotificationCenter.default.publisher(for: .newgitCreateIssue)) { notification in
            guard let path = notification.object as? String else { return }
            openRepository(at: path)
            pendingNavigation = .issues(path)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .newgitOpenIssuesInSelectedRepo, object: path)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(name: .newgitCreateIssueInSelectedRepo, object: path)
                }
            }
        })

        // Provide a top-level Touch Bar on macOS so items appear in the responder chain
#if os(macOS)
        anyView = AnyView(anyView.touchBar(content: {
            contentTouchBar
        }))
#endif

        return anyView
    }

    // MARK: - Small subviews to help type-checking
    @ViewBuilder
    private var sidebar: some View {
        // Sidebar with liquid glass look
        VStack(spacing: 0) {
            HStack {
                Text("Repositories")
                    .font(.largeTitle)
                    .padding([.leading,.bottom, .trailing])
                    .bold()
                Spacer()
            }
            List(selection: $selectionID) {
                ForEach(savedRepos, id: \.id) { repo in
                    Text(repo.name)
                        .tag(repo.id)
                        .font(.title2)
                        .accessibilityIdentifier("sidebar-repo-\(repo.name)")
                        .contextMenu { Button("Delete Repository") { repoToDelete = repo; showDeleteDialog = true } }
                }
            }
            .listStyle(.sidebar)
            .accessibilityIdentifier("repositories-sidebar")
            .touchBar(content: {
                contentTouchBar
            })
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
                    .accessibilityIdentifier("select-repository-placeholder")
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

        print("ContentView: deleting repo id=\(repo.id) name=\(repo.name)")
        modelContext.delete(repo)
        do {
            try modelContext.save()
            SavedRepoBackupStore.shared.sync(repos: savedRepos.filter { $0.id != repo.id })
            deleteResultMessage = "Deleted \(repo.name)"
            print("ContentView: modelContext.save() succeeded")
        } catch {
            deleteResultMessage = "Failed to delete saved repo: \(error.localizedDescription)"
            print("ContentView: modelContext.save() failed: \(error)")
        }
        showDeleteResultAlert = true
        repoToDelete = nil
    }

    private func openRepository(at path: String) {
        guard let repo = savedRepos.first(where: { $0.path == path }) else { return }
        selectionID = repo.id
        debugSelectedName = repo.name
        syncSelectedRepository()
    }

    private func handlePendingNavigation(for path: String) {
        guard let pendingNavigation else { return }
        switch pendingNavigation {
        case .issues(let pendingPath) where pendingPath == path:
            NotificationCenter.default.post(name: .newgitOpenIssuesInSelectedRepo, object: path)
            self.pendingNavigation = nil
        case .release(let pendingPath) where pendingPath == path:
            NotificationCenter.default.post(name: .newgitOpenReleaseInSelectedRepo, object: path)
            self.pendingNavigation = nil
        default:
            break
        }
    }

    private func syncSelectedRepository() {
        guard let id = selectionID,
              let repo = savedRepos.first(where: { $0.id == id }) else {
            commandCenter.selectedRepositoryPath = savedRepos.first?.path
            return
        }

        commandCenter.selectedRepositoryPath = repo.path
    }

    @ViewBuilder
    private var contentTouchBar: some View {
        HStack(spacing: 10) {
            touchBarButton("Clone") { showCloneRepo = true }
            touchBarButton("Add Existing") { showAddRepo = true }
            touchBarButton("Add New") { showAddNewRepo = true }
            touchBarButton("Push", disabled: !hasSelectedRepository) {
                guard let selectedRepositoryPath else { return }
                NotificationCenter.default.post(name: .newgitShowPushInSelectedRepo, object: selectedRepositoryPath)
            }
            touchBarButton("Pull", disabled: !hasSelectedRepository) {
                guard let selectedRepositoryPath else { return }
                NotificationCenter.default.post(name: .newgitPullInSelectedRepo, object: selectedRepositoryPath)
            }
            touchBarButton("Stash", disabled: !hasSelectedRepository) {
                guard let selectedRepositoryPath else { return }
                NotificationCenter.default.post(name: .newgitShowStashInSelectedRepo, object: selectedRepositoryPath)
            }
            touchBarButton("Issues", disabled: !hasSelectedRepository) {
                guard let selectedRepositoryPath else { return }
                NotificationCenter.default.post(name: .newgitOpenIssues, object: selectedRepositoryPath)
            }
            touchBarButton("PRs", disabled: !hasSelectedRepository) {
                guard let selectedRepositoryPath else { return }
                NotificationCenter.default.post(name: .newgitShowPullRequestsInSelectedRepo, object: selectedRepositoryPath)
            }
            touchBarButton("New Issue", disabled: !hasSelectedRepository) {
                guard let selectedRepositoryPath else { return }
                NotificationCenter.default.post(name: .newgitCreateIssue, object: selectedRepositoryPath)
            }
            touchBarButton("New PR", disabled: !hasSelectedRepository) {
                guard let selectedRepositoryPath else { return }
                NotificationCenter.default.post(name: .newgitShowCreatePullRequestInSelectedRepo, object: selectedRepositoryPath)
            }
            touchBarButton("Release", disabled: !hasSelectedRepository) {
                guard let selectedRepositoryPath else { return }
                NotificationCenter.default.post(name: .newgitOpenRelease, object: selectedRepositoryPath)
            }
            touchBarButton("Ignored", disabled: !hasSelectedRepository) {
                guard let selectedRepositoryPath else { return }
                NotificationCenter.default.post(name: .newgitOpenIgnoredFilesInSelectedRepo, object: selectedRepositoryPath)
            }
            touchBarButton("Refresh", disabled: !hasSelectedRepository) {
                guard let selectedRepositoryPath else { return }
                NotificationCenter.default.post(name: .newgitRefreshSelectedRepo, object: selectedRepositoryPath)
            }
        }
        .buttonStyle(.plain)
        .tint(.primary)
    }

    private func touchBarButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.clear)
                .foregroundStyle(disabled ? .secondary : .primary)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SavedRepo.self])
}
