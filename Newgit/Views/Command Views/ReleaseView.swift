//
//  ReleaseView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/6/25.
//

import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif
import ConfettiSwiftUI

struct ReleaseView: View {
    let projectDirectory: String
    @Environment(\.dismiss) private var dismiss

    @State private var tag: String = ""
    @State private var releaseTitle: String = ""
    @State private var notes: String = ""
    @State private var selectedFiles: [URL] = []

    @State private var isCreating: Bool = false
    @State private var showOutput: Bool = false
    @State private var commandOutput: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var errorSummary: String = ""

    // File importer flag (fallback to pick files)
    @State private var showFileImporter: Bool = false

    // Optimistic UI state: show a success panel immediately when release starts
    @State private var showSuccessView: Bool = false
    @State private var trigger: Int = 0 // for triggering confetti

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showSuccessView {
                // Compact PushView-style success UI: show only the checkmark + message and confetti.
                VStack {
                    Image(systemName: "checkmark.circle")
                        .imageScale(.large)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.green)
                        .font(.largeTitle)
                        .padding()
                        .confettiCannon(trigger: $trigger)
                    Text("It’s on it’s way!")
                        .padding()
                        .font(.system(.title2, weight: .bold))
                }
                .padding()
            } else {
                // Regular form
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Tag (e.g. v1.0.0)", text: $tag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("Title (optional)", text: $releaseTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Text("Notes / Description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextEditor(text: $notes)
                            .frame(height: 50)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                    }
                    .navigationTitle("Create GitHub Release")
                    .toolbar {
                        ToolbarItemGroup(placement: .automatic) {
                            // Toggle show closed/all issues
                            Button(action: { createRelease() }) {
                                Text(isCreating ? "Creating…" : "Create Release")
                            }
                            .disabled(isCreating || tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .keyboardShortcut(.defaultAction)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    // Drag & drop area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assets")
                            .font(.headline)
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2)
                                .background(Color(NSColor.windowBackgroundColor))
                                .frame(minHeight: 60)

                            VStack {
                                if selectedFiles.isEmpty {
                                    Text("Drag and drop files here or click \"Add files\"")
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                } else {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(selectedFiles, id: \.self) { url in
                                                HStack {
                                                    Image(nsImage: iconForFile(url))
                                                        .resizable()
                                                        .frame(width: 18, height: 18)
                                                    Text(url.lastPathComponent)
                                                    Spacer()
                                                    Button(action: { removeFile(url) }) {
                                                        Image(systemName: "xmark.circle")
                                                    }
                                                    .buttonStyle(BorderlessButtonStyle())
                                                }
                                                .padding(.vertical, 2)
                                            }
                                        }
                                        .padding()
                                    }
                                }

                                HStack {
                                    Spacer()
                                    Button(action: { showFileImporter = true }) {
                                        Text("Add files…")
                                    }
                                    .padding(.trailing)

                                    Button(action: { clearFiles() }) {
                                        Text("Clear")
                                    }
                                    .disabled(selectedFiles.isEmpty)
                                }
                                .padding([.bottom, .trailing])
                            }
                            .padding()
                        }
                        .onDrop(of: [UTType.fileURL.identifier as String], isTargeted: nil) { providers in
                            handleDrop(providers)
                        }
                    }
                    if showOutput {
                        Divider()
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Command output")
                                    .font(.headline)
                                Spacer()
                                Button("Copy") { copyToPasteboard(commandOutput) }
                            }
                            ScrollView {
                                Text(commandOutput)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(minHeight: 160, maxHeight: 360)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for u in urls { addFile(u) }
            case .failure(let err):
                print("fileImporter error: \(err)")
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Release Failed"), message: Text(errorSummary), dismissButton: .default(Text("OK")))
        }
        .frame(minWidth: 600, minHeight: 50)
    }

    // MARK: - File helpers
    private func addFile(_ url: URL) {
        guard !selectedFiles.contains(url) else { return }
        selectedFiles.append(url)
    }

    private func removeFile(_ url: URL) {
        selectedFiles.removeAll { $0 == url }
    }

    private func clearFiles() {
        selectedFiles.removeAll()
    }

    #if os(macOS)
    private func iconForFile(_ url: URL) -> NSImage {
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    #endif

    private func copyToPasteboard(_ s: String) {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
        #endif
    }

    // MARK: - Drag handling
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for prov in providers {
            if prov.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier as String) {
                prov.loadItem(forTypeIdentifier: UTType.fileURL.identifier as String, options: nil) { (item, error) in
                    if let err = error {
                        print("drop loadItem error: \(err)")
                        return
                    }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async { addFile(url) }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async { addFile(url) }
                    } else if let nsurl = item as? NSURL, let url = nsurl as URL? {
                        DispatchQueue.main.async { addFile(url) }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    // MARK: - Action
    private func createRelease() {
        guard !isCreating else { return }
        let t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        isCreating = true
        // Optimistic UI: hide the form and show the compact "it's on it's way" view
        // immediately so the user sees the action is underway.
        showOutput = false
        commandOutput = ""
        withAnimation {
            self.showSuccessView = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var args: [String] = ["release", "create", t]
            if !releaseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                args.append("--title")
                args.append(releaseTitle)
            }
            if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                args.append("--notes")
                args.append(notes)
            }

            // Prepare assets in a unique temporary directory for this run. This lets us:
            // - create zip files named exactly like the original bundle (e.g. Newgit.app.zip)
            // - copy regular files into the temp dir so uploads originate from a single, unique location
            // This avoids using `--name` and prevents filename collisions when multiple releases run concurrently.
            let runTmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            var assetPaths: [String] = []
            do {
                try FileManager.default.createDirectory(at: runTmpDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DispatchQueue.main.async {
                    self.isCreating = false
                    self.commandOutput = "Failed to create temporary directory: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
                return
            }

            for f in selectedFiles {
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: f.path, isDirectory: &isDir)

                if !exists {
                    DispatchQueue.main.async {
                        self.commandOutput += "\nAsset not found: \(f.path). Skipping."
                    }
                    continue
                }

                if isDir.boolValue {
                    // Create a zip in the run temp dir named <bundle>.zip so GitHub will display that basename.
                    let zipName = "\(f.lastPathComponent).zip"
                    let zipURL = runTmpDir.appendingPathComponent(zipName)

                    // Zip from the bundle's parent so the archive contains the bundle directory
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                    proc.currentDirectoryURL = f.deletingLastPathComponent()
                    proc.arguments = ["-r", zipURL.path, f.lastPathComponent]

                    do {
                        try proc.run()
                        proc.waitUntilExit()
                        if proc.terminationStatus == 0 {
                            assetPaths.append(zipURL.path)
                        } else {
                            DispatchQueue.main.async {
                                self.commandOutput += "\nFailed to zip \(f.lastPathComponent) (zip exit \(proc.terminationStatus)). Skipping this asset."
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.commandOutput += "\nError creating zip for \(f.lastPathComponent): \(error). Skipping this asset."
                        }
                    }
                } else {
                    // Regular file - copy into the run tmp dir so it has the correct basename and uploads from a unique location
                    let dest = runTmpDir.appendingPathComponent(f.lastPathComponent)
                    do {
                        // Remove any existing file at destination then copy
                        if FileManager.default.fileExists(atPath: dest.path) {
                            try FileManager.default.removeItem(at: dest)
                        }
                        try FileManager.default.copyItem(at: f, to: dest)
                        assetPaths.append(dest.path)
                    } catch {
                        DispatchQueue.main.async {
                            self.commandOutput += "\nFailed to copy \(f.lastPathComponent) to temp dir: \(error). Skipping."
                        }
                    }
                }
            }

            // Do not append asset paths to the create command. We create the release first
            // and upload assets individually so we can control their displayed names and
            // handle gh versions that don't support --name.

            // Run gh
            let createRes = runGHCommand(args, currentDirectory: projectDirectory)
            let createRaw = createRes.output.trimmingCharacters(in: .whitespacesAndNewlines)

            var uploadErrors: [String] = []
            if createRes.status == 0 {
                for p in assetPaths {
                    let basename = URL(fileURLWithPath: p).lastPathComponent
                    // Upload using the file's basename as the asset name. We prepared files
                    // in a unique temp dir using the desired basenames, so `gh` will use
                    // that basename for the asset. Use --clobber to overwrite existing assets.
                    let upArgs: [String] = ["release", "upload", t, p, "--clobber"]
                    let upRes = runGHCommand(upArgs, currentDirectory: projectDirectory)
                    let upOut = upRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    DispatchQueue.main.async {
                        self.commandOutput += "\n[upload \(basename)] \(upOut)"
                    }
                    if upRes.status != 0 {
                        uploadErrors.append("Failed to upload \(basename): exit \(upRes.status).")
                    }
                }
            }

            // cleanup run temp directory
            try? FileManager.default.removeItem(at: runTmpDir)

            DispatchQueue.main.async {
                self.isCreating = false

                // Preserve create output and any appended per-upload output in the console
                let currentUploadsOutput = self.commandOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                self.commandOutput = createRaw + (currentUploadsOutput.isEmpty ? "" : "\n" + currentUploadsOutput)

                if createRes.status == 0 && uploadErrors.isEmpty {
                    self.showErrorAlert = false
                    // Release succeeded. Show confetti then dismiss after a short delay.
                    withAnimation {
                        self.trigger += 1 // fire confetti once
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                } else {
                    // Failure: hide the optimistic success view, show the form/console with details
                    self.showSuccessView = false
                    // ensure the console is visible so the user can see output
                    self.showOutput = true

                    // Build a concise error summary
                    if !uploadErrors.isEmpty {
                        self.errorSummary = uploadErrors.joined(separator: "\n")
                    } else if !createRaw.isEmpty {
                        self.errorSummary = createRaw
                    } else {
                        self.errorSummary = "gh returned an error (exit \(createRes.status))."
                    }
                    self.showErrorAlert = true
                }
            }
        }
    }
}

#if DEBUG
struct ReleaseView_Previews: PreviewProvider {
    static var previews: some View {
        ReleaseView(projectDirectory: ".")
    }
}
#endif
