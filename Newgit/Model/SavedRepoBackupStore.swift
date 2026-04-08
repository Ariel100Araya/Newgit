//
//  SavedRepoBackupStore.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 4/6/26.
//

import Foundation
import SwiftData

struct SavedRepoSnapshot: Codable {
    let id: UUID
    let name: String
    let path: String
    let lastUpdated: Date

    init(id: UUID = UUID(), name: String, path: String, lastUpdated: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.lastUpdated = lastUpdated
    }

    init(repo: SavedRepo) {
        self.id = repo.id
        self.name = repo.name
        self.path = repo.path
        self.lastUpdated = repo.lastUpdated
    }
}

enum SavedRepoRestoreResult {
    case noBackup
    case backupAlreadyEmpty
    case restored(Int)
    case failed(Error)
}

final class SavedRepoBackupStore {
    static let shared = SavedRepoBackupStore()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager
    private let fileURL: URL

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "Newgit"
        let directory = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        self.fileURL = directory.appendingPathComponent("saved-repos-backup.json", isDirectory: false)
    }

    func sync(repos: [SavedRepo]) {
        syncSnapshots(repos.map(SavedRepoSnapshot.init))
    }

    func restoreIfNeeded(into modelContext: ModelContext, currentRepos: [SavedRepo]) -> SavedRepoRestoreResult {
        let snapshots: [SavedRepoSnapshot]
        do {
            snapshots = try loadSnapshots()
        } catch {
            return .failed(error)
        }

        let uniqueSnapshots = deduplicatedSnapshots(from: snapshots)

        guard !uniqueSnapshots.isEmpty else {
            if currentRepos.isEmpty {
                return .backupAlreadyEmpty
            }
            sync(repos: currentRepos)
            return .noBackup
        }

        let currentRepoPaths = Set(currentRepos.map { normalizedPath($0.path) })
        let snapshotsToInsert = uniqueSnapshots.filter { !currentRepoPaths.contains(normalizedPath($0.path)) }

        guard !snapshotsToInsert.isEmpty else {
            sync(repos: currentRepos)
            return .noBackup
        }

        for snapshot in snapshotsToInsert {
            modelContext.insert(
                SavedRepo(
                    id: snapshot.id,
                    name: snapshot.name,
                    path: snapshot.path,
                    lastUpdated: snapshot.lastUpdated
                )
            )
        }

        do {
            try modelContext.save()
            syncSnapshots(deduplicatedSnapshots(from: currentRepos.map(SavedRepoSnapshot.init) + snapshotsToInsert))
            return .restored(snapshotsToInsert.count)
        } catch {
            return .failed(error)
        }
    }

    func upsert(snapshot: SavedRepoSnapshot) {
        var snapshots = (try? loadSnapshots()) ?? []
        let normalizedSnapshotPath = normalizedPath(snapshot.path)
        snapshots.removeAll { existing in
            existing.id == snapshot.id || normalizedPath(existing.path) == normalizedSnapshotPath
        }
        snapshots.append(snapshot)
        syncSnapshots(snapshots)
    }

    func savedSnapshots() -> [SavedRepoSnapshot] {
        deduplicatedSnapshots(from: (try? loadSnapshots()) ?? [])
    }

    private func syncSnapshots(_ snapshots: [SavedRepoSnapshot]) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let data = try encoder.encode(deduplicatedSnapshots(from: snapshots))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("SavedRepoBackupStore sync failed: \(error)")
        }
    }

    private func loadSnapshots() throws -> [SavedRepoSnapshot] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([SavedRepoSnapshot].self, from: data)
    }

    private func deduplicatedSnapshots(from snapshots: [SavedRepoSnapshot]) -> [SavedRepoSnapshot] {
        var seenIDs = Set<UUID>()
        var seenPaths = Set<String>()
        var uniqueSnapshots: [SavedRepoSnapshot] = []

        for snapshot in snapshots {
            let normalizedSnapshotPath = normalizedPath(snapshot.path)
            guard seenIDs.insert(snapshot.id).inserted else { continue }
            guard seenPaths.insert(normalizedSnapshotPath).inserted else { continue }
            uniqueSnapshots.append(snapshot)
        }

        return uniqueSnapshots.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path.lowercased()
    }
}
