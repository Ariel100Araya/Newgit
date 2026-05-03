//
//  NewgitApp.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/6/25.
//

import SwiftUI
import SwiftData

@main
struct NewgitApp: App {
    @StateObject private var commandCenter = AppCommandCenter()
    private let modelContainer = UITestLaunchConfiguration.makeModelContainer()

    init() {
        // Small startup log to help diagnose persistence lifecycle
        print("NewgitApp init - starting up")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(commandCenter)
                .modelContainer(modelContainer)
#if os(macOS)
                .touchBar(content: {
                    HStack(spacing: 10) {
                        touchBarButton("Clone") {
                            NotificationCenter.default.post(name: .newgitCloneRepo, object: nil)
                        }
                        touchBarButton("Add Existing") {
                            NotificationCenter.default.post(name: .newgitAddExistingRepo, object: nil)
                        }
                        touchBarButton("Add New") {
                            NotificationCenter.default.post(name: .newgitAddNewRepo, object: nil)
                        }
                    }
                    .buttonStyle(.plain)
                    .tint(.primary)
                })
#endif
        }
#if os(macOS)
        .commands {
            NewgitMenuCommands(commandCenter: commandCenter)
        }
#endif
    }

    // Small root view that inspects the saved repos and chooses the initial screen.
    private struct RootView: View {
        @Query private var savedRepos: [SavedRepo]
        @Environment(\.modelContext) private var modelContext
        @Environment(\.scenePhase) private var scenePhase
        @EnvironmentObject private var commandCenter: AppCommandCenter

        // Sheet state lifted to the root so sheets are presented from the same view that manages the app state.
        @State private var showAddRepo: Bool = false
        @State private var showAddNewRepo: Bool = false
        @State private var showCloneRepo: Bool = false
        @State private var isReconcilingPersistence: Bool = false
        @State private var pendingAddRepoPath: String? = nil

        var body: some View {
            Group {
                if UITestLaunchConfiguration.forcedScreen == "first-launch" {
                    FirstLaunchView(onShowAddRepo: { showAddRepo = true },
                                    onShowCloneRepo: { showCloneRepo = true },
                                    onShowAddNewRepo: { showAddNewRepo = true })
                    .accessibilityIdentifier("first-launch-screen")
                } else if UITestLaunchConfiguration.forcedScreen == "content-view" {
                    UITestContentView(repos: UITestLaunchConfiguration.seededRepositories())
                } else if savedRepos.isEmpty {
                    FirstLaunchView(onShowAddRepo: { showAddRepo = true },
                                    onShowCloneRepo: { showCloneRepo = true },
                                    onShowAddNewRepo: { showAddNewRepo = true })
                    .accessibilityIdentifier("first-launch-screen")
                } else {
                    ContentView()
                        .accessibilityIdentifier("content-view-screen")
                }
            }
            // Diagnostic logging to trace when the savedRepos set changes
            .onAppear {
                if !UITestLaunchConfiguration.isEnabled {
                    reconcilePersistence(reason: "onAppear")
                }
                print("RootView onAppear: savedRepos count = \(savedRepos.count)")
                for r in savedRepos { print("RootView repo: \(r.name) id: \(r.id)") }
            }
            .onChange(of: savedRepos) { old, new in
                print("RootView: savedRepos changed: new count = \(new.count)")
                for r in new { print("RootView repo: \(r.name) id: \(r.id)") }
                if !UITestLaunchConfiguration.isEnabled {
                    SavedRepoBackupStore.shared.sync(repos: new)
                }
                // If repos newly appeared, dismiss any open first-launch sheets so they don't become orphaned.
                if !new.isEmpty {
                    showAddRepo = false
                    showAddNewRepo = false
                    showCloneRepo = false
                } else if UITestLaunchConfiguration.forcedScreen != "content-view" {
                    commandCenter.selectedRepositoryPath = nil
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, !UITestLaunchConfiguration.isEnabled {
                    reconcilePersistence(reason: "scene became active")
                }
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            // Present the sheets from the RootView so dismissal is handled consistently when the root view switches.
            .sheet(isPresented: $showAddRepo) {
                AddRepoView(initialDirectory: pendingAddRepoPath)
            }
            .sheet(isPresented: $showAddNewRepo) {
                AddNewRepoView()
            }
            .sheet(isPresented: $showCloneRepo) {
                CloneRepoView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .newgitIntentAddExistingRepo)) { _ in
                pendingAddRepoPath = nil
                showAddRepo = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .newgitIntentAddNewRepo)) { _ in
                showAddNewRepo = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .newgitIntentCloneRepo)) { _ in
                showCloneRepo = true
            }
        }

        private struct UITestContentView: View {
            let repos: [UITestLaunchConfiguration.SeededRepo]
            @State private var selectedRepoID: UITestLaunchConfiguration.SeededRepo.ID?

            private var selectedRepo: UITestLaunchConfiguration.SeededRepo? {
                let fallback = repos.first
                let selected = repos.first(where: { $0.id == selectedRepoID })
                return selected ?? fallback
            }

            var body: some View {
                NavigationSplitView {
                    List(repos, selection: $selectedRepoID) { repo in
                        Text(repo.name)
                            .tag(repo.id)
                    }
                    .accessibilityIdentifier("ui-test-repo-list")
                } detail: {
                    if let repo = selectedRepo {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(repo.name)
                                .font(.title)
                            Text(repo.path)
                                .foregroundStyle(.secondary)
                            Text("UI test detail view")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding()
                        .navigationTitle(repo.name)
                        .accessibilityIdentifier("ui-test-repo-detail-\(repo.name)")
                    } else {
                        Text("No repositories seeded for UI tests")
                            .accessibilityIdentifier("ui-test-empty-content")
                    }
                }
                .accessibilityIdentifier("content-view-screen")
                .onAppear {
                    if selectedRepoID == nil {
                        selectedRepoID = repos.first?.id
                    }
                }
            }
        }

        private func reconcilePersistence(reason: String) {
            guard !isReconcilingPersistence else { return }
            isReconcilingPersistence = true
            defer { isReconcilingPersistence = false }

            let result = SavedRepoBackupStore.shared.restoreIfNeeded(into: modelContext, currentRepos: savedRepos)
            switch result {
            case .noBackup:
                print("RootView persistence check (\(reason)): SwiftData already had \(savedRepos.count) repos")
            case .backupAlreadyEmpty:
                print("RootView persistence check (\(reason)): no repos in SwiftData and backup is intentionally empty")
            case .restored(let count):
                print("RootView persistence check (\(reason)): restored \(count) repos from backup")
            case .failed(let error):
                print("RootView persistence check (\(reason)) failed: \(error)")
            }
        }

        private func handleIncomingURL(_ url: URL) {
            guard url.scheme == "newgit" else { return }
            guard url.host == "add-repository" else { return }

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let path = components?.queryItems?.first(where: { $0.name == "path" })?.value

            print("RootView incoming URL path = \(path ?? "nil")")

            pendingAddRepoPath = path
            showAddRepo = true
        }
    }
}

#if os(macOS)
private func touchBarButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.clear)
            .foregroundStyle(.primary)
    }
    .buttonStyle(.plain)
}
#endif

#if os(macOS)
private struct NewgitMenuCommands: Commands {
    @ObservedObject var commandCenter: AppCommandCenter

    private var selectedPath: String? {
        commandCenter.selectedRepositoryPath
    }

    private var hasSelection: Bool {
        selectedPath?.isEmpty == false
    }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Section("Repositories") {
                Button("Clone Repo") {
                    NotificationCenter.default.post(name: .newgitCloneRepo, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Add Existing") {
                    NotificationCenter.default.post(name: .newgitAddExistingRepo, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Add New") {
                    NotificationCenter.default.post(name: .newgitAddNewRepo, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }

        CommandGroup(after: .pasteboard) {
            Section("Git") {
                Button("Push") {
                    guard let selectedPath else { return }
                    NotificationCenter.default.post(name: .newgitShowPushInSelectedRepo, object: selectedPath)
                }
                .disabled(!hasSelection)

                Button("Pull") {
                    guard let selectedPath else { return }
                    NotificationCenter.default.post(name: .newgitPullInSelectedRepo, object: selectedPath)
                }
                .disabled(!hasSelection)

                Button("Stash") {
                    guard let selectedPath else { return }
                    NotificationCenter.default.post(name: .newgitShowStashInSelectedRepo, object: selectedPath)
                }
                .disabled(!hasSelection)
            }
        }

        CommandGroup(after: .toolbar) {
            Section("Repository Views") {
                Button("Show Issues") {
                    guard let selectedPath else { return }
                    NotificationCenter.default.post(name: .newgitOpenIssues, object: selectedPath)
                }
                .disabled(!hasSelection)
                .keyboardShortcut("1", modifiers: [.command])

                Button("Show Pull Requests") {
                    guard let selectedPath else { return }
                    NotificationCenter.default.post(name: .newgitShowPullRequestsInSelectedRepo, object: selectedPath)
                }
                .disabled(!hasSelection)
                .keyboardShortcut("2", modifiers: [.command])

                Button("Show Ignored Files") {
                    guard let selectedPath else { return }
                    NotificationCenter.default.post(name: .newgitOpenIgnoredFilesInSelectedRepo, object: selectedPath)
                }
                .disabled(!hasSelection)
                .keyboardShortcut("3", modifiers: [.command])

                Button("Edit README") {
                    guard let selectedPath else { return }
                    NotificationCenter.default.post(name: .newgitOpenReadmeEditorInSelectedRepo, object: selectedPath)
                }
                .disabled(!hasSelection)
                .keyboardShortcut("4", modifiers: [.command])
            }
        }

        CommandMenu("New") {
            Button("New Issue") {
                guard let selectedPath else { return }
                NotificationCenter.default.post(name: .newgitCreateIssue, object: selectedPath)
            }
            .disabled(!hasSelection)

            Button("New Pull Request") {
                guard let selectedPath else { return }
                NotificationCenter.default.post(name: .newgitShowCreatePullRequestInSelectedRepo, object: selectedPath)
            }
            .disabled(!hasSelection)

            Button("New Release") {
                guard let selectedPath else { return }
                NotificationCenter.default.post(name: .newgitOpenRelease, object: selectedPath)
            }
            .disabled(!hasSelection)
        }

        CommandMenu("Repository") {
            Button("Refresh Repository") {
                guard let selectedPath else { return }
                NotificationCenter.default.post(name: .newgitRefreshSelectedRepo, object: selectedPath)
            }
            .disabled(!hasSelection)
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Open in Finder") {
                guard let selectedPath else { return }
                NotificationCenter.default.post(name: .newgitOpenFinderInSelectedRepo, object: selectedPath)
            }
            .disabled(!hasSelection)

            Button("Open in Terminal") {
                guard let selectedPath else { return }
                NotificationCenter.default.post(name: .newgitOpenTerminalInSelectedRepo, object: selectedPath)
            }
            .disabled(!hasSelection)

            Button("Open on GitHub") {
                guard let selectedPath else { return }
                NotificationCenter.default.post(name: .newgitOpenGitHubInSelectedRepo, object: selectedPath)
            }
            .disabled(!hasSelection)
        }
    }
}
#endif
