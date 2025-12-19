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
    // Start in checking state so the UI shows a spinner immediately on launch
    @State private var isChecking: Bool = true
    @State private var lastError: String? = nil
    // Controls whether the welcome action buttons are visible (fades in after the greeting)
    @State private var showWelcomeActions: Bool = false
    // Controls whether confetti animation is visible (short burst when welcome appears)
    @State private var showConfetti: Bool = false
    // Internal sheet flags (used if the host didn't provide callbacks)
    @State private var showCloneRepoSheet: Bool = false
    @State private var showAddExistingRepoSheet: Bool = false
    @State private var showAddNewRepoSheet: Bool = false

    var body: some View {
        // Use a ZStack so spinner and content can crossfade using opacity transitions
        ZStack {
            // Confetti overlay (appears on top)
//            if showConfetti {
//                ConfettiView()
//                    .allowsHitTesting(false)
//                    .transition(.opacity)
//            }
            // Spinner layer
            if isChecking {
                VStack {
                    Spacer()
                    ProgressView("Get ready…")
                        .scaleEffect(1.1)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .transition(.opacity)
            }

            // Content layer (welcome or env check) — appears when not checking
            if !isChecking {
                // After checks complete: if we have a logged-in GitHub user show the welcome UI, otherwise show the environment-check UI
                if let user = githubUser {
                    VStack {
                        // Welcome header (avatar + username)
                        if let avatar = githubAvatarURL {
                            HStack(spacing: 12) {
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
                        // Action buttons: fade them in after the greeting using showWelcomeActions
                        if showWelcomeActions {
                            HStack {
                                if #available(macOS 26.0, *) {
                                    Button("Clone Repository") {
                                        cloneRepo()
                                    }
                                    .padding()
                                    .buttonStyle(.borderless)
                                    .glassEffect()
                                } else {
                                    // Fallback on earlier versions
                                    Button("Clone Repository") {
                                        cloneRepo()
                                    }
                                    .padding()
                                    .buttonStyle(.borderless)
                                }
                                if #available(macOS 26.0, *) {
                                    Button("Add existing Repository") {
                                        addExistingRepo()
                                    }
                                    .padding()
                                    .buttonStyle(.borderless)
                                    .glassEffect()
                                } else {
                                    // Fallback on earlier versions
                                    Button("Add existing Repository") {
                                        addExistingRepo()
                                    }
                                    .padding()
                                    .buttonStyle(.borderless)
                                }
                                if #available(macOS 26.0, *) {
                                    Button("Add new Repository") {
                                        addNewRepo()
                                    }
                                    .padding()
                                    .buttonStyle(.borderless)
                                    .glassEffect()
                                } else {
                                    // Fallback on earlier versions
                                    Button("Add new Repository") {
                                        addNewRepo()
                                    }
                                    .padding()
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding()
                            .transition(.opacity)
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
        }
        // Animate cross-fade between spinner and content
        .animation(.easeInOut(duration: 0.25), value: isChecking)
        // Animate welcome action appearance
        .animation(.easeInOut(duration: 0.25), value: showWelcomeActions)
        .padding()
        .onAppear {
            // ensure actions are hidden while checking starts
            showWelcomeActions = false
            checkPrereqs()
        }
        // Show welcome actions shortly after a user is detected; also trigger a short confetti burst
        .onChange(of: githubUser) { old, new in
            if new != nil {
                // Delay slightly so the greeting appears first, then fade in actions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation { showWelcomeActions = true }
                }
                // Trigger confetti for a short burst
                withAnimation {
                    showConfetti = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation { showConfetti = false }
                }
            } else {
                withAnimation { showWelcomeActions = false }
                withAnimation { showConfetti = false }
            }
        }
        // If checks start again, hide actions immediately
        .onChange(of: isChecking) { old, checking in
            if checking {
                withAnimation { showWelcomeActions = false }
            }
        }
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

// MARK: - Confetti (macOS)
// Lightweight CAEmitterLayer-based confetti view for macOS.
fileprivate struct ConfettiView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.translatesAutoresizingMaskIntoConstraints = false

        // Create emitter
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterMode = .surface
        emitter.birthRate = 1

        // We'll size/position the emitter in layout pass
        v.layer?.addSublayer(emitter)
        context.coordinator.emitter = emitter

        // When view is added, kick off the burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            guard let superlayer = v.layer else { return }
            emitter.frame = superlayer.bounds
            emitter.emitterPosition = CGPoint(x: superlayer.bounds.midX, y: superlayer.bounds.maxY)
            emitter.emitterSize = CGSize(width: superlayer.bounds.width, height: 1)
            emitter.emitterCells = generateCells()
            // short-lived burst: let cells emit for a moment then stop
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                emitter.birthRate = 0
            }
            // remove emitter after a while
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                emitter.removeFromSuperlayer()
            }
        }

        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // no-op
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var emitter: CAEmitterLayer?
    }

    // Helper: produce several colored CAEmitterCell instances
    private func generateCells() -> [CAEmitterCell] {
        let colors: [NSColor] = [NSColor.systemRed, NSColor.systemBlue, NSColor.systemGreen, NSColor.systemOrange, NSColor.systemPink, NSColor.systemYellow]
        return colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 300
            cell.lifetime = 3.0
            cell.velocity = 200
            cell.velocityRange = 120
            cell.emissionLongitude = -.pi/2
            cell.emissionRange = .pi/3
            cell.spin = 3
            cell.spinRange = 4
            cell.scale = 0.6
            cell.scaleRange = 0.4
            if let img = makeImage(color: color, size: CGSize(width: 10, height: 14)) {
                cell.contents = img
            }
            return cell
        }
    }

    private func makeImage(color: NSColor, size: CGSize) -> CGImage? {
        let w = Int(max(1, size.width))
        let h = Int(max(1, size.height))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        return ctx.makeImage()
    }
}
