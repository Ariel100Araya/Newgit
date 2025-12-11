//
//  FirstLaunchView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/8/25.
//

import SwiftUI
import AppKit

struct FirstLaunchView: View {
    // Optional callbacks so the hosting view can present sheets (e.g. set showAddRepo = true).
    // If not provided, the actions fall back to posting notifications (for backward compatibility).
    var onShowAddRepo: (() -> Void)? = nil
    var onShowCloneRepo: (() -> Void)? = nil
    var onShowAddNewRepo: (() -> Void)? = nil

    @State private var hasBrew: Bool? = nil
    @State private var hasGH: Bool? = nil
    @State private var ghAuthenticated: Bool? = nil
    @State private var githubUser: String? = nil
    @State private var githubAvatarURL: URL? = nil
    @State private var isChecking: Bool = false
    @State private var lastError: String? = nil
    // Internal sheet flags (used if the host didn't provide callbacks)
    @State private var showCloneRepoSheet: Bool = false
    @State private var showAddExistingRepoSheet: Bool = false
    @State private var showAddNewRepoSheet: Bool = false

    var body: some View {
        Group {
            // If checks are done and no missing prereqs, show the welcome + repo actions
            if !isChecking && missingPrereqs().isEmpty {
                VStack {
                    // Welcome header (avatar + username)
                    if let user = githubUser {
                        HStack(spacing: 12) {
                            if let avatar = githubAvatarURL {
                                AsyncImage(url: avatar) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .scaledToFit()
                                    @unknown default:
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .scaledToFit()
                                    }
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .frame(width: 64, height: 64)
                            }

                            VStack(alignment: .leading) {
                                Text("Welcome to Newgit,")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text(user + "!")
                                    .font(.largeTitle)
                                    .bold()
                            }
                        }
                    } else {
                        Text("Welcome!")
                            .font(.largeTitle)
                            .bold()
                    }
                    Text("Get started by cloning a repository or creating a new one.")
                        .foregroundColor(.secondary)
                        .padding()
                        .font(.title2)
                    // Action buttons
                    HStack {
                        Button("Clone Repository") {
                            cloneRepo()
                        }
                        .padding()
                        .buttonStyle(.borderless)
                        .glassEffect()
                        Button("Add existing Repository") {
                            addExistingRepo()
                        }
                        .padding()
                        .buttonStyle(.borderless)
                        .glassEffect()
                        Button("Add new Repository") {
                            addNewRepo()
                        }
                        .padding()
                        .buttonStyle(.borderless)
                        .glassEffect()
                    }
                    .padding()
                    .touchBar(content: {
                        Button("Clone Repository") {
                            cloneRepo()
                        }
                        Button("Add existing Repository") {
                            addExistingRepo()
                        }
                        Button("Add new Repository") {
                            addNewRepo()
                        }
                    })
                }
                .padding()
            } else {
                // ...existing environment-check UI...
                VStack(spacing: 16) {
                    Text("Environment check")
                        .font(.title2)
                        .bold()

                    VStack(alignment: .leading, spacing: 12) {
                        statusRow(title: "Homebrew (brew)", present: hasBrew, presentAction: {
                            // Open Homebrew homepage
                            if let url = URL(string: "https://brew.sh") {
                                NSWorkspace.shared.open(url)
                            }
                        }, absentAction: {
                            copyToPasteboard("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
                        })

                        statusRow(title: "GitHub CLI (gh)", present: hasGH, presentAction: {
                            if let url = URL(string: "https://cli.github.com/") {
                                NSWorkspace.shared.open(url)
                            }
                        }, absentAction: {
                            copyToPasteboard("brew install gh")
                        })

                        statusRow(title: "gh authenticated", present: ghAuthenticated, presentAction: {
                            if let url = URL(string: "https://docs.github.com/en/github-cli/authenticating-with-github-cli") {
                                NSWorkspace.shared.open(url)
                            }
                        }, absentAction: {
                            copyToPasteboard("gh auth login")
                        }, absentLabel: "Run 'gh auth login' to authenticate")
                    }
                    .padding()
                    .frame(maxWidth: 720)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)

                    if isChecking {
                        ProgressView("Checking…")
                    }

                    HStack(spacing: 12) {
                        Button(action: { checkPrereqs() }) {
                            Text("Refresh")
                        }
                        .keyboardShortcut("r", modifiers: .command)

                        Button(action: { openTerminalInstructions() }) {
                            Text("Open Terminal")
                        }
                    }

                    // Show a concise summary of missing prerequisites when checks are done
                    if !isChecking {
                        let missing = missingPrereqs()
                        if !missing.isEmpty {
                            Text("Remaining: \(missing.joined(separator: ", "))")
                                .foregroundColor(.secondary)
                                .font(.footnote)
                        } else {
                            // All prerequisites satisfied — if we have an authenticated GH user show welcome
                            if let user = githubUser {
                                HStack(spacing: 12) {
                                    if let avatar = githubAvatarURL {
                                        // AsyncImage is available on macOS 12+
                                        AsyncImage(url: avatar) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            case .failure:
                                                Image(systemName: "person.crop.circle")
                                                    .resizable()
                                                    .scaledToFit()
                                            @unknown default:
                                                Image(systemName: "person.crop.circle")
                                                    .resizable()
                                                    .scaledToFit()
                                            }
                                        }
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .frame(width: 48, height: 48)
                                    }

                                    VStack(alignment: .leading) {
                                        Text("Welcome,")
                                            .font(.title2)
                                        Text(user + "!").bold()
                                            .font(.title)
                                    }
                                }
                                .foregroundColor(.primary)
                                .font(.headline)
                            } else {
                                Text("All prerequisites satisfied")
                                    .foregroundColor(.green)
                                    .font(.footnote)
                            }
                        }
                    }

                    if let err = lastError {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .padding()
        .onAppear { checkPrereqs() }
        // Present sheets locally if callbacks are not provided by the host
        .sheet(isPresented: $showCloneRepoSheet) {
            CloneRepoView()
        }
        .sheet(isPresented: $showAddExistingRepoSheet) {
            AddRepoView()
        }
        .sheet(isPresented: $showAddNewRepoSheet) {
            AddNewRepoView()
        }
    }

    @ViewBuilder
    private func statusRow(title: String, present: Bool?, presentAction: @escaping () -> Void, absentAction: @escaping () -> Void, absentLabel: String? = nil) -> some View {
        HStack {
            Group {
                if present == nil {
                    ProgressView()
                } else if present == true {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading) {
                Text(title).bold()
                if let p = present {
                    if p {
                        Text("Installed").font(.footnote).foregroundColor(.secondary)
                    } else {
                        Text(absentLabel ?? "Not installed").font(.footnote).foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if present == true {
                Button("Open") { presentAction() }
            } else if present == false {
                Button("Copy install") { absentAction() }
            }
        }
    }

    private func copyToPasteboard(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        lastError = "Command copied to clipboard"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            lastError = nil
        }
    }

    private func openTerminalInstructions() {
        // Open Terminal app (user can paste the copied command)
        if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: terminalURL, configuration: config, completionHandler: nil)
        } else if let iTerm = URL(string: "iterm://") {
            NSWorkspace.shared.open(iTerm)
        }
    }

    private func checkPrereqs() {
        isChecking = true
        lastError = nil
        DispatchQueue.global(qos: .utility).async {
            var brewOK = false
            var ghOK = false
            var ghAuthOK = false

            // Check for brew
            let brewRes = runCommand("which brew")
            if brewRes.status == 0 && !brewRes.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                brewOK = true
            }

            // Check for gh
            let ghRes = runCommand("which gh")
            if ghRes.status == 0 && !ghRes.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ghOK = true
            }

            // If gh installed, check auth status
            if ghOK {
                let authRes = runCommand("gh auth status")
                // gh auth status returns nonzero and prints an instruction if not authenticated
                ghAuthOK = (authRes.status == 0)
                if ghAuthOK {
                    // Try to read the logged-in username and avatar URL in one go
                    let userRes = runCommand("gh api user --jq '{login: .login, avatar: .avatar_url}'")
                    if userRes.status == 0 {
                        let raw = userRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
                        // raw will be something like: {login: "username", avatar: "https://..."}
                        // Attempt to extract values simply using --jq for each field as a fallback
                        let loginRes = runCommand("gh api user --jq .login")
                        let avatarRes = runCommand("gh api user --jq .avatar_url")
                        var user: String? = nil
                        var avatarURL: URL? = nil
                        if loginRes.status == 0 {
                            let s = loginRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !s.isEmpty { user = s }
                        }
                        if avatarRes.status == 0 {
                            let s = avatarRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let u = URL(string: s) { avatarURL = u }
                        }

                        DispatchQueue.main.async {
                            self.githubUser = user
                            self.githubAvatarURL = avatarURL
                        }
                    } else {
                        // fallback: attempt separate calls
                        let loginRes = runCommand("gh api user --jq .login")
                        let avatarRes = runCommand("gh api user --jq .avatar_url")
                        var user: String? = nil
                        var avatarURL: URL? = nil
                        if loginRes.status == 0 {
                            let s = loginRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !s.isEmpty { user = s }
                        }
                        if avatarRes.status == 0 {
                            let s = avatarRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let u = URL(string: s) { avatarURL = u }
                        }
                        DispatchQueue.main.async {
                            self.githubUser = user
                            self.githubAvatarURL = avatarURL
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.githubUser = nil
                        self.githubAvatarURL = nil
                    }
                }
            }

            DispatchQueue.main.async {
                self.hasBrew = brewOK
                self.hasGH = ghOK
                self.ghAuthenticated = ghAuthOK
                self.isChecking = false
                // If neither installed, give a small helpful message
                if !brewOK && !ghOK {
                    self.lastError = "Install Homebrew first (https://brew.sh) and then run: brew install gh"
                }
            }
        }
    }

    private func missingPrereqs() -> [String] {
        var arr: [String] = []
        if let b = hasBrew {
            if !b { arr.append("Homebrew") }
        } else {
            // still unknown - don't include
        }
        if let g = hasGH {
            if !g { arr.append("gh (GitHub CLI)") }
        }
        if let auth = ghAuthenticated {
            if hasGH == true && !auth { arr.append("gh authentication") }
        }
        return arr
    }

    // Actions used by the welcome UI — post notifications so the hosting app can handle them.
    private func cloneRepo() {
        if let cb = onShowCloneRepo {
            cb()
        } else {
            // show internal sheet if available
            showCloneRepoSheet = true
        }
    }

    private func addExistingRepo() {
        if let cb = onShowAddRepo {
            cb()
        } else {
            showAddExistingRepoSheet = true
        }
    }

    private func addNewRepo() {
        if let cb = onShowAddNewRepo {
            cb()
        } else {
            showAddNewRepoSheet = true
        }
    }
    
}

#Preview {
    FirstLaunchView()
}
