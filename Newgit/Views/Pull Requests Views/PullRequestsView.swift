import SwiftUI
import AppKit

// A PullRequestsView modeled closely after IssuesView but using gh pr commands
struct PullRequestsView: View {
    let projectDirectory: String

    @State private var prs: [PullRequest] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var selectedPR: PullRequest? = nil
    @State private var comments: [Comment] = []
    @State private var isLoadingComments: Bool = false
    @State private var commentsError: String? = nil
    @State private var showAllPRs: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                ProgressView("Loading pull requests...")
                    .padding()
            } else if let err = errorMessage {
                Text("Error loading pull requests: \(err)")
                    .foregroundColor(.red)
                    .padding()
            } else if prs.isEmpty {
                Text("No pull requests found.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                HStack(spacing: 12) {
                    prListView

                    Divider()

                    prDetailView
                }
            }
        }
        .padding()
        .onAppear { fetchPullRequests() }
        .onChange(of: selectedPR) { old, new in
            if let s = new { fetchComments(for: s) }
            else { comments = []; commentsError = nil; isLoadingComments = false }
        }
        .onChange(of: selectedPR) { old, new in
            // Also fetch PR detail bits (merged state) when a PR is selected. We handle this separately
            // because some `gh` versions do not allow requesting `merged` from `pr list` and will error.
            if let s = new { fetchPRMergedStatus(for: s) }
        }
        .navigationTitle("Pull Requests")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    showAllPRs.toggle()
                    fetchPullRequests()
                }) {
                    Image(systemName: showAllPRs ? "eye.fill" : "eye")
                }
                .help(showAllPRs ? "Showing all PRs (including closed/merged)" : "Show closed/merged PRs")

                // Refresh
                Button(action: { fetchPullRequests() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh PR list")

                // Actions: Merge/Close based on selection
                Button(action: {
                    guard let p = selectedPR else { return }
                    if p.state == "open" {
                        mergePR(p)
                    } else {
                        closePR(p)
                    }
                }) {
                    Image(systemName: selectedPR?.state == "open" ? "hammer" : "xmark")
                }
                .disabled(selectedPR == nil)
            }
        }
    }

    private func fetchPullRequests() {
        isLoading = true
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let stateArg = showAllPRs ? "all" : "open"
            // Request only fields supported across gh versions; `merged` may not be supported in `pr list` on some versions
            let args = ["pr", "list", "--state", stateArg, "--json", "number,title,state,url,body,author,assignees,headRefName,baseRefName", "--limit", "100"]
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            let raw = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.isLoading = false
                if res.status != 0 {
                    self.prs = []
                    self.errorMessage = raw.isEmpty ? "gh returned an error (exit \(res.status))." : raw
                    return
                }
                guard let data = raw.data(using: .utf8) else {
                    self.prs = []
                    self.errorMessage = "Failed to decode gh output"
                    return
                }
                do {
                    if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        var mapped: [PullRequest] = []
                        for obj in arr {
                            guard let number = obj["number"] as? Int else { continue }
                            let title = (obj["title"] as? String) ?? "(no title)"
                            let state = (obj["state"] as? String ?? "").lowercased()
                            let url = (obj["url"] as? String) ?? ""
                            let body = obj["body"] as? String
                            var author: String? = nil
                            if let a = obj["author"] as? [String: Any], let login = a["login"] as? String { author = login }
                            var assignees: [String] = []
                            if let asArr = obj["assignees"] as? [[String: Any]] {
                                for a in asArr { if let login = a["login"] as? String { assignees.append(login) } }
                            }
                            let head = obj["headRefName"] as? String
                            let base = obj["baseRefName"] as? String
                            // merged is intentionally left unknown here; we fetch it per-PR when selected
                            mapped.append(PullRequest(number: number, title: title, state: state, url: url, body: body, webUrl: nil, author: author, assignees: assignees, headRefName: head, baseRefName: base, merged: nil))
                        }
                        self.prs = mapped
                        self.selectedPR = mapped.first
                    } else {
                        self.prs = []
                        self.errorMessage = "Failed to parse gh output"
                    }
                } catch {
                    self.prs = []
                    self.errorMessage = "Failed to parse gh output: \(error.localizedDescription)"
                }
            }
        }
    }

    private func fetchComments(for pr: PullRequest) {
        comments = []
        commentsError = nil
        isLoadingComments = true
        DispatchQueue.global(qos: .userInitiated).async {
            let args = ["pr", "view", "\(pr.number)", "--json", "comments"]
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            let raw = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.isLoadingComments = false
                if res.status != 0 {
                    self.comments = []
                    self.commentsError = raw.isEmpty ? "gh returned an error (exit \(res.status))." : raw
                    return
                }
                guard let data = raw.data(using: .utf8) else {
                    self.comments = []
                    self.commentsError = "Failed to decode gh output"
                    return
                }
                do {
                    if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any], let arr = obj["comments"] as? [[String: Any]] {
                        var mapped: [Comment] = []
                        for c in arr {
                            let body = (c["body"] as? String) ?? ""
                            var author = ""
                            if let a = c["author"] as? [String: Any], let login = a["login"] as? String { author = login }
                            let createdAt = (c["createdAt"] as? String) ?? ""
                            mapped.append(Comment(id: UUID(), author: author.isEmpty ? "unknown" : author, body: body, createdAtRaw: createdAt))
                        }
                        self.comments = mapped
                        self.commentsError = nil
                    } else {
                        self.comments = []
                        self.commentsError = "Failed to parse gh output"
                    }
                } catch {
                    self.comments = []
                    self.commentsError = "Failed to parse gh output: \(error.localizedDescription)"
                }
            }
        }
    }

    private func mergePR(_ pr: PullRequest) {
        DispatchQueue.global(qos: .userInitiated).async {
            let args = ["pr", "merge", "\(pr.number)"]
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            DispatchQueue.main.async {
                if res.status == 0 {
                    showAlert(title: "PR merged", message: "Merged PR #\(pr.number)")
                    fetchPullRequests()
                } else {
                    showAlert(title: "Failed to merge PR", message: res.output)
                }
            }
        }
    }

    private func closePR(_ pr: PullRequest) {
        DispatchQueue.global(qos: .userInitiated).async {
            let args = ["pr", "close", "\(pr.number)"]
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            DispatchQueue.main.async {
                if res.status == 0 {
                    showAlert(title: "PR closed", message: "Closed PR #\(pr.number)")
                    fetchPullRequests()
                } else {
                    showAlert(title: "Failed to close PR", message: res.output)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            if let window = NSApplication.shared.keyWindow {
                alert.beginSheetModal(for: window, completionHandler: nil)
            } else {
                alert.runModal()
            }
        }
    }

    private var prListView: some View {
        PullRequestListView(prs: prs, selectedPR: $selectedPR)
    }

    @ViewBuilder
    private var prDetailView: some View {
        PullRequestDetailView(
            pr: selectedPR,
            comments: comments,
            isLoadingComments: isLoadingComments,
            commentsError: commentsError,
            onMerge: mergePR,
            onClose: closePR,
            onAdd: { }
        )
    }

    // Fetch a single PR's `merged` status using `gh pr view <number> --json merged`.
    // We intentionally request this per-PR to avoid requesting `merged` in the bulk `pr list` call,
    // which can cause errors on older `gh` versions.
    private func fetchPRMergedStatus(for pr: PullRequest) {
        DispatchQueue.global(qos: .userInitiated).async {
            let args = ["pr", "view", "\(pr.number)", "--json", "merged"]
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            let raw = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if res.status != 0 {
                // ignore failure; leave merged as nil
                return
            }
            guard let data = raw.data(using: .utf8) else { return }
            do {
                if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any], let mergedVal = obj["merged"] as? Bool {
                    DispatchQueue.main.async {
                        // Update the PR in our list with the merged value if present
                        if let idx = self.prs.firstIndex(where: { $0.number == pr.number }) {
                            let existing = self.prs[idx]
                            let updated = PullRequest(number: existing.number, title: existing.title, state: existing.state, url: existing.url, body: existing.body, webUrl: existing.webUrl, author: existing.author, assignees: existing.assignees, headRefName: existing.headRefName, baseRefName: existing.baseRefName, merged: mergedVal)
                            self.prs[idx] = updated
                            // If the selectedPR is the same PR, update that reference too so detail view sees it
                            if self.selectedPR?.number == existing.number { self.selectedPR = updated }
                        }
                    }
                }
            } catch {
                // parsing failed, ignore
            }
        }
    }
}
