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
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: [SavedRepo.self])
        }
    }
}

// Small root view that inspects the saved repos and chooses the initial screen.
private struct RootView: View {
    @Query private var savedRepos: [SavedRepo]

    var body: some View {
        Group {
            if savedRepos.isEmpty {
                FirstLaunchView()
            } else {
                ContentView()
            }
        }
    }
}
