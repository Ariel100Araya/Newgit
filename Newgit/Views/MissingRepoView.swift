//
//  MissingRepoView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 6/25/26.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct MissingRepoView: View {
    let repo: SavedRepo
    var onRelocated: (String) -> Void
    var onCloneAgain: () -> Void
    var onDelete: () -> Void

    @State private var isShowCloneForm: Bool = false
    @State private var cloneURL: String = ""
    @State private var destinationPath: String = ""
    @State private var isCloning: Bool = false
    @State private var cloningOutput: String = ""
    @State private var showCloneAlert: Bool = false
    @State private var cloneAlertMessage: String = ""

    init(repo: SavedRepo, onRelocated: @escaping (String) -> Void, onCloneAgain: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.repo = repo
        self.onRelocated = onRelocated
        self.onCloneAgain = onCloneAgain
        self.onDelete = onDelete
        
        // Suggest destination path based on the last known path
        _destinationPath = State(initialValue: repo.path)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header card
                HStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(repo.name)
                            .font(.largeTitle)
                            .bold()
                        Text("Repository Location Missing")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 16)

                // Detail message
                VStack(alignment: .leading, spacing: 12) {
                    Text("The repository folder could not be found at its saved path:")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(repo.path)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                }

                Divider()

                // Options Section
                Text("Select an action to resolve this:")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(spacing: 16) {
                    // Option 1: Relocate
                    Button(action: browseForNewLocation) {
                        HStack(spacing: 16) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Relocate Repository")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Select the new folder location on your hard drive if it was moved.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    // Option 2: Clone Again
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: {
                            withAnimation(.easeInOut) {
                                isShowCloneForm.toggle()
                            }
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "icloud.and.arrow.down")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Clone Repository Again")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Re-clone the repository from a remote URL to your hard drive.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: isShowCloneForm ? "chevron.down" : "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        if isShowCloneForm {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Git URL")
                                    .font(.caption)
                                    .bold()
                                TextField("https://github.com/owner/repo.git or git@github.com:owner/repo.git", text: $cloneURL)
                                    .textFieldStyle(.roundedBorder)

                                Text("Destination Path")
                                    .font(.caption)
                                    .bold()
                                HStack {
                                    TextField("Target Directory", text: $destinationPath)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Browse...") {
                                        browseForCloneDirectory()
                                    }
                                }

                                if isCloning {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Cloning repository...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 4)
                                } else {
                                    Button("Start Clone") {
                                        Task {
                                            await performClone()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                    .disabled(cloneURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || destinationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }

                                if !cloningOutput.isEmpty {
                                    Text(cloningOutput)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .cornerRadius(6)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                            .padding()
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .transition(.opacity)
                        }
                    }

                    // Option 3: Delete
                    Button(action: onDelete) {
                        HStack(spacing: 16) {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Remove from Newgit")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text("Remove this saved entry from the repository list. Does not modify disk.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
        }
        .alert(cloneAlertMessage, isPresented: $showCloneAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Handlers

    private func browseForNewLocation() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Relocate Repository"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    onRelocated(url.path)
                }
            }
        }
        #endif
    }

    private func browseForCloneDirectory() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Select Clone Destination"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    destinationPath = url.path
                }
            }
        }
        #endif
    }

    private func shellEscape(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func performClone() async {
        let url = cloneURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !url.isEmpty, !target.isEmpty else { return }

        DispatchQueue.main.async {
            isCloning = true
            cloningOutput = "Cloning repository..."
        }

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<(String, Int32), Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                // Ensure parent directory exists
                let parent = (target as NSString).deletingLastPathComponent
                let mkCmd = "mkdir -p \(self.shellEscape(parent))"
                _ = runCommand(mkCmd)

                // Run clone
                let cloneCmd = "git clone \(self.shellEscape(url)) \(self.shellEscape(target))"
                let res = runCommand(cloneCmd)
                continuation.resume(returning: (res.output, res.status))
            }
        }

        DispatchQueue.main.async {
            isCloning = false
            cloningOutput = result.0
            if result.1 == 0 {
                cloneAlertMessage = "Repository cloned successfully."
                showCloneAlert = true
                // Relocate the repo to the newly cloned location!
                onRelocated(target)
            } else {
                cloneAlertMessage = "Clone failed with exit status \(result.1)."
                showCloneAlert = true
            }
        }
    }
}
