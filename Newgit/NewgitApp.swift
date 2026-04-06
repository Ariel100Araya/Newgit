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
    init() {
        // Small startup log to help diagnose persistence lifecycle
        print("NewgitApp init - starting up")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: [SavedRepo.self])
#if os(macOS)
                .touchBar(content: {
                    Button("Clone Repository") {
                        NotificationCenter.default.post(name: .newgitCloneRepo, object: nil)
                    }
                    Button("Add New Repository") {
                        NotificationCenter.default.post(name: .newgitAddNewRepo, object: nil)
                    }
                    Button("Add Existing Repository") {
                        NotificationCenter.default.post(name: .newgitAddExistingRepo, object: nil)
                    }
                })
#endif
        }
    }

    // Small root view that inspects the saved repos and chooses the initial screen.
    private struct RootView: View {
        @Query private var savedRepos: [SavedRepo]
        @Environment(\.modelContext) private var modelContext
        @Environment(\.scenePhase) private var scenePhase

        // Sheet state lifted to the root so sheets are presented from the same view that manages the app state.
        @State private var showAddRepo: Bool = false
        @State private var showAddNewRepo: Bool = false
        @State private var showCloneRepo: Bool = false
        @State private var isReconcilingPersistence: Bool = false

        var body: some View {
            Group {
                if savedRepos.isEmpty {
                    FirstLaunchView(onShowAddRepo: { showAddRepo = true },
                                    onShowCloneRepo: { showCloneRepo = true },
                                    onShowAddNewRepo: { showAddNewRepo = true })
                } else {
                    ContentView()
                }
            }
            // Diagnostic logging to trace when the savedRepos set changes
            .onAppear {
                reconcilePersistence(reason: "onAppear")
                print("RootView onAppear: savedRepos count = \(savedRepos.count)")
                for r in savedRepos { print("RootView repo: \(r.name) id: \(r.id)") }
            }
            .onChange(of: savedRepos) { old, new in
                print("RootView: savedRepos changed: new count = \(new.count)")
                for r in new { print("RootView repo: \(r.name) id: \(r.id)") }
                SavedRepoBackupStore.shared.sync(repos: new)
                // If repos newly appeared, dismiss any open first-launch sheets so they don't become orphaned.
                if !new.isEmpty {
                    showAddRepo = false
                    showAddNewRepo = false
                    showCloneRepo = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    reconcilePersistence(reason: "scene became active")
                }
            }
            // Present the sheets from the RootView so dismissal is handled consistently when the root view switches.
            .sheet(isPresented: $showAddRepo) {
                AddRepoView()
            }
            .sheet(isPresented: $showAddNewRepo) {
                AddNewRepoView()
            }
            .sheet(isPresented: $showCloneRepo) {
                CloneRepoView()
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
    }
}
