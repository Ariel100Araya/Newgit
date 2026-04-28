import Foundation
import SwiftData

enum UITestLaunchConfiguration {
    struct SeededRepo: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let path: String
    }

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-TESTING")
    }

    static var firstLaunchUser: String? {
        environmentValue(for: "NEWGIT_UI_FIRST_LAUNCH_USER")
    }

    static var forcedScreen: String? {
        environmentValue(for: "NEWGIT_UI_SCREEN")
    }

    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([SavedRepo.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isEnabled)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    static func seededRepositories() -> [SeededRepo] {
        guard let value = environmentValue(for: "NEWGIT_UI_SEEDED_REPOS") else {
            return []
        }

        return value
            .split(separator: ";")
            .compactMap { entry in
                let parts = entry.split(separator: "|", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return nil }
                return SeededRepo(name: parts[0], path: parts[1])
            }
    }

    private static func environmentValue(for key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
