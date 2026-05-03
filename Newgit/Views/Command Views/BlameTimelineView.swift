//
//  BlameTimelineView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 5/3/26.
//

import SwiftUI

struct BlameTimelineView: View {
    let projectDirectory: String

    @State private var trackedFiles: [String] = []
    @State private var selectedFile: String? = nil
    @State private var commits: [BlameTimelineCommit] = []
    @State private var contributors: [BlameContributor] = []
    @State private var isLoadingFiles = false
    @State private var isLoadingTimeline = false
    @State private var message: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            fileSidebar
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 380)

            Divider()

            timelineContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Blame Timeline")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh blame timeline")
                .disabled(isLoadingFiles || isLoadingTimeline)
            }
        }
        .onAppear {
            loadTrackedFiles()
        }
    }

    private var fileSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tracked Files")
                    .font(.headline)
                Spacer()
                if isLoadingFiles {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding([.horizontal, .top])

            if trackedFiles.isEmpty && !isLoadingFiles {
                Text("No tracked files found.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Spacer()
            } else {
                List(trackedFiles, id: \.self) { file in
                    Button {
                        selectedFile = file
                        loadTimeline(for: file)
                    } label: {
                        HStack {
                            Text(file)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            if selectedFile == file {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selectedFile == file
                            ? Color.accentColor.opacity(0.14)
                            : Color.clear
                    )
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var timelineContent: some View {
        if let selectedFile {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(for: selectedFile)

                    if isLoadingTimeline {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Building timeline...")
                                .foregroundStyle(.secondary)
                        }
                    } else if let message {
                        Text(message)
                            .foregroundStyle(.secondary)
                    } else {
                        contributorStrip
                        timeline
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
                Text("Choose a file to see its blame timeline")
                    .font(.title3)
                    .bold()
                Text("Newgit will show the commits that shaped that file and who owns the current lines.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func header(for file: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(file)
                .font(.title2)
                .bold()
                .textSelection(.enabled)
            Text("\(commits.count) commit\(commits.count == 1 ? "" : "s") in file history")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var contributorStrip: some View {
        if !contributors.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Current Line Ownership")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(contributors) { contributor in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle()
                                    .fill(color(for: contributor.name))
                                    .frame(width: 10, height: 10)
                                Text(contributor.name)
                                    .font(.subheadline)
                                    .bold()
                                    .lineLimit(1)
                            }
                            Text("\(contributor.lineCount) line\(contributor.lineCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ProgressView(value: contributor.share)
                                .tint(color(for: contributor.name))
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("File History")
                .font(.headline)
                .padding(.bottom, 8)

            ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(color(for: commit.authorName))
                            .frame(width: 12, height: 12)
                        if index < commits.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.28))
                                .frame(width: 2, height: 74)
                        }
                    }
                    .frame(width: 16)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(commit.subject)
                            .font(.headline)
                            .textSelection(.enabled)
                        HStack(spacing: 8) {
                            Text(commit.shortHash)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            Text(commit.authorName)
                                .font(.subheadline)
                                .bold()
                            Text(commit.formattedDate)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(commit.hash)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.bottom, index < commits.count - 1 ? 18 : 0)

                    Spacer(minLength: 12)
                }
            }
        }
    }

    private func refresh() {
        loadTrackedFiles(selecting: selectedFile)
    }

    private func loadTrackedFiles(selecting preferredFile: String? = nil) {
        isLoadingFiles = true
        message = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let command = "cd \(Self.shellEscape(projectDirectory)) && git ls-files"
            let result = Self.runBlameTimelineCommand(command)
            let files = result.output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            DispatchQueue.main.async {
                self.isLoadingFiles = false
                self.trackedFiles = files

                guard result.status == 0 else {
                    self.message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    return
                }

                let nextSelection = preferredFile.flatMap { files.contains($0) ? $0 : nil } ?? files.first
                self.selectedFile = nextSelection
                if let nextSelection {
                    self.loadTimeline(for: nextSelection)
                }
            }
        }
    }

    private func loadTimeline(for file: String) {
        isLoadingTimeline = true
        message = nil
        commits = []
        contributors = []

        DispatchQueue.global(qos: .userInitiated).async {
            let escapedDirectory = Self.shellEscape(projectDirectory)
            let escapedFile = Self.shellEscape(file)
            let logFormat = "%H%x1f%h%x1f%an%x1f%ae%x1f%ad%x1f%s"
            let logCommand = "cd \(escapedDirectory) && git --no-pager log --follow --date=iso-strict --format=\(Self.shellEscape(logFormat)) -- \(escapedFile)"
            let blameCommand = "cd \(escapedDirectory) && git --no-pager blame --line-porcelain -- \(escapedFile)"

            let logResult = Self.runBlameTimelineCommand(logCommand)
            let blameResult = Self.runBlameTimelineCommand(blameCommand)
            let parsedCommits = parseLog(logResult.output)
            let parsedContributors = parseContributors(blameResult.output)

            DispatchQueue.main.async {
                self.isLoadingTimeline = false
                self.commits = parsedCommits
                self.contributors = parsedContributors

                if logResult.status != 0 {
                    self.message = logResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if parsedCommits.isEmpty {
                    self.message = "No commit history found for this file."
                }
            }
        }
    }

    private func parseLog(_ output: String) -> [BlameTimelineCommit] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line in
                let parts = line.components(separatedBy: "\u{1f}")
                guard parts.count >= 6 else { return nil }
                return BlameTimelineCommit(
                    hash: parts[0],
                    shortHash: parts[1],
                    authorName: parts[2].isEmpty ? "Unknown" : parts[2],
                    authorEmail: parts[3],
                    date: ISO8601DateFormatter.gitDateFormatter.date(from: parts[4]) ?? ISO8601DateFormatter.gitDateWithFractionalSecondsFormatter.date(from: parts[4]),
                    rawDate: parts[4],
                    subject: parts[5].isEmpty ? "(no commit message)" : parts[5]
                )
            }
    }

    private func parseContributors(_ output: String) -> [BlameContributor] {
        var counts: [String: Int] = [:]

        for line in output.components(separatedBy: .newlines) {
            guard line.hasPrefix("author ") else { continue }
            let name = String(line.dropFirst("author ".count))
            counts[name, default: 0] += 1
        }

        let total = counts.values.reduce(0, +)
        guard total > 0 else { return [] }

        return counts
            .map { name, count in
                BlameContributor(name: name.isEmpty ? "Unknown" : name, lineCount: count, share: Double(count) / Double(total))
            }
            .sorted {
                if $0.lineCount == $1.lineCount {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.lineCount > $1.lineCount
            }
    }

    private static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\'\''") + "'"
    }

    private static func runBlameTimelineCommand(_ command: String) -> (output: String, status: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]

        var env = ProcessInfo.processInfo.environment
        let defaultPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let existingPATH = env["PATH"] ?? ""
        var paths = defaultPaths + existingPATH.split(separator: ":").map { String($0) }
        var seen = Set<String>()
        paths = paths.filter { path in
            if seen.contains(path) { return false }
            seen.insert(path)
            return true
        }
        env["PATH"] = paths.joined(separator: ":")
        task.environment = env

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            return ("Failed to launch bash: \(error.localizedDescription)", -1)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        return (String(data: data, encoding: .utf8) ?? "", task.terminationStatus)
    }

    private func color(for value: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .pink, .purple, .teal, .red, .indigo]
        let scalarTotal = value.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[abs(scalarTotal) % colors.count]
    }
}

private struct BlameTimelineCommit: Identifiable {
    let hash: String
    let shortHash: String
    let authorName: String
    let authorEmail: String
    let date: Date?
    let rawDate: String
    let subject: String

    var id: String { hash }

    var formattedDate: String {
        if let date {
            return DateFormatter.blameTimelineDate.string(from: date)
        }
        return rawDate
    }
}

private struct BlameContributor: Identifiable {
    let name: String
    let lineCount: Int
    let share: Double

    var id: String { name }
}

private extension ISO8601DateFormatter {
    static let gitDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let gitDateWithFractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension DateFormatter {
    static let blameTimelineDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
