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
            ContentView()
                .modelContainer(for: [SavedRepo.self])
        }
    }
}
