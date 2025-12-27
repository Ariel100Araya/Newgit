import SwiftUI
import AppKit

// A standalone view to display and manage GitHub issues for a repository
struct IssuesView: View {
    let projectDirectory: String
    
    @State private var issues: [Issue] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var selectedIssue: Issue? = nil
    // Thread/Comments for the selected issue
    @State private var comments: [Comment] = []
    @State private var isLoadingComments: Bool = false
    @State private var commentsError: String? = nil
    // showAddIssueSheet flag (Bool) used to present the create issue sheet
    @State private var showAddIssueSheet: Bool = false
    // Active sheet enum kept for compatibility with earlier code (still useful if needed)
    enum ActiveSheet: Identifiable {
        case createIssue
        var id: Int { hashValue }
    }
    @State private var activeSheet: ActiveSheet? = nil
    // Create issue state
    @State private var newIssueTitle: String = ""
    @State private var newIssueBody: String = ""
    @State private var isCreatingIssue: Bool = false
    // Reply/comment state for the detail view
    @State private var replyText: String = ""
    @State private var isPostingComment: Bool = false
    // Whether to include closed issues in the list
    @State private var showAllIssues: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                ProgressView("Loading issues...")
                    .padding()
            } else if let err = errorMessage {
                Text("Error loading issues: \(err)")
                    .foregroundColor(.red)
                    .padding()
            } else if issues.isEmpty {
                Text("No issues found.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                HStack(spacing: 12) {
                    issueListView
                    
                    Divider()
                    
                    issueDetailView
                }
            }
        }
        .padding()
        .onAppear { fetchIssues() }
        .onChange(of: selectedIssue) { old, new in
            if let s = new {
                fetchComments(for: s)
            } else {
                comments = []
                commentsError = nil
                isLoadingComments = false
            }
        }
        .onChange(of: activeSheet) { new in
            print("activeSheet changed -> \(String(describing: new))")
            if new != nil {
                DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
            }
        }
        .navigationTitle("Issues")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Toggle show closed/all issues
                Button(action: {
                    showAllIssues.toggle()
                    fetchIssues()
                }) {
                    Image(systemName: showAllIssues ? "eye.fill" : "eye")
                }
                .help(showAllIssues ? "Showing all issues (including closed)" : "Show closed issues")
                
                // Add issue
                Button(action: {
                    print("Toolbar Add Issue tapped")
                    DispatchQueue.main.async {
                        activeSheet = .createIssue
                        showAddIssueSheet = true
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }) {
                    Image(systemName: "plus")
                }
                .help("Create a new issue")
                
                // Mark as done / Reopen for the selected issue
                Button(action: {
                    guard let sel = selectedIssue else { return }
                    if sel.state == "open" {
                        closeIssue(sel)
                    } else {
                        reopenIssue(sel)
                    }
                }) {
                    Image(systemName: selectedIssue?.state == "open" ? "checkmark.circle" : "arrow.uturn.left.circle")
                }
                .help(selectedIssue?.state == "open" ? "Mark selected issue as done" : "Reopen selected issue")
                .disabled(selectedIssue == nil)
            }
        }
        // Present create issue sheet using a Bool binding (more straightforward)
        .sheet(isPresented: $showAddIssueSheet, onDismiss: { activeSheet = nil }) {
            createIssueSheet
                .onAppear {
                    print("createIssueSheet onAppear")
                    newIssueTitle = ""
                    newIssueBody = ""
                }
        }
    }
    
    // MARK: - Networking / actions
    private func fetchIssues() {
        isLoading = true
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            // Request either only open issues or all issues
            let stateArg = showAllIssues ? "all" : "open"
            // include author and assignees so we can display who opened and who is assigned
            let args = ["issue", "list", "--state", stateArg, "--json", "number,title,state,url,body,author,assignees", "--limit", "100"]
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            let raw = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.isLoading = false
                if res.status != 0 {
                    self.issues = []
                    self.errorMessage = raw.isEmpty ? "gh returned an error (exit \(res.status))." : raw
                    return
                }
                guard let data = raw.data(using: .utf8) else {
                    self.issues = []
                    self.errorMessage = "Failed to decode gh output"
                    return
                }
                do {
                    if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        var mapped: [Issue] = []
                        for obj in arr {
                            guard let number = obj["number"] as? Int else { continue }
                            let title = (obj["title"] as? String) ?? "(no title)"
                            let state = (obj["state"] as? String ?? "").lowercased()
                            let url = (obj["url"] as? String) ?? ""
                            let body = obj["body"] as? String
                            // parse author
                            var author: String? = nil
                            if let a = obj["author"] as? [String: Any], let login = a["login"] as? String {
                                author = login
                            }
                            // parse assignees
                            var assignees: [String] = []
                            if let asArr = obj["assignees"] as? [[String: Any]] {
                                for a in asArr {
                                    if let login = a["login"] as? String { assignees.append(login) }
                                }
                            }

                            mapped.append(Issue(number: number, title: title, state: state, url: url, body: body, webUrl: nil, author: author, assignees: assignees))
                        }
                        self.issues = mapped
                        self.selectedIssue = mapped.first
                    } else {
                        self.issues = []
                        self.errorMessage = "Failed to parse gh output"
                    }
                } catch {
                    self.issues = []
                    self.errorMessage = "Failed to parse gh output: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func closeIssue(_ issue: Issue) {
        DispatchQueue.global(qos: .userInitiated).async {
            let args = ["issue", "close", "\(issue.number)"]
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            DispatchQueue.main.async {
                if res.status == 0 {
                    showAlert(title: "Issue closed", message: "Closed issue #\(issue.number)")
                    fetchIssues()
                } else {
                    showAlert(title: "Failed to close issue", message: res.output)
                }
            }
        }
    }
    
    private func reopenIssue(_ issue: Issue) {
        DispatchQueue.global(qos: .userInitiated).async {
            let args = ["issue", "reopen", "\(issue.number)"]
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            DispatchQueue.main.async {
                if res.status == 0 {
                    showAlert(title: "Issue reopened", message: "Reopened issue #\(issue.number)")
                    fetchIssues()
                } else {
                    showAlert(title: "Failed to reopen issue", message: res.output)
                }
            }
        }
    }
    
    // Fetch comments (thread) for a specific issue number using `gh issue view --json comments`
    private func fetchComments(for issue: Issue) {
        comments = []
        commentsError = nil
        isLoadingComments = true
        DispatchQueue.global(qos: .userInitiated).async {
            let args = ["issue", "view", "\(issue.number)", "--json", "comments"]
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
                            if let a = c["author"] as? [String: Any], let login = a["login"] as? String {
                                author = login
                            }
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
    
    private var issueListView: some View {
        IssueListView(issues: issues, selectedIssue: $selectedIssue)
    }
    
    @ViewBuilder
    private var issueDetailView: some View {
        IssueDetailView(
            issue: selectedIssue,
            comments: comments,
            isLoadingComments: isLoadingComments,
            commentsError: commentsError,
            onClose: closeIssue,
            onReopen: reopenIssue,
            onAdd: {
                print("Detail Add tapped")
                DispatchQueue.main.async {
                    activeSheet = .createIssue
                    showAddIssueSheet = true
                    NSApp.activate(ignoringOtherApps: true)
                }
            },
            replyBody: $replyText,
            isPostingComment: isPostingComment,
            onPost: { body in postComment(body: body) }
        )
    }
    
    // Create issue sheet UI
    private var createIssueSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Issue")
                .font(.headline)
            
            TextField("Title", text: $newIssueTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextEditor(text: $newIssueBody)
                .frame(height: 220)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
            
            HStack {
                Spacer()
                Button("Cancel") { print("Cancel Create tapped"); activeSheet = nil; showAddIssueSheet = false }
                Button(isCreatingIssue ? "Creating…" : "Create") {
                    let title = newIssueTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let body = newIssueBody.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else { return }
                    createIssue(title: title, body: body)
                }
                .disabled(isCreatingIssue || newIssueTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 320)
    }
    
    // Create issue via `gh issue create`
    private func createIssue(title: String, body: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { self.isCreatingIssue = true }
            let args = ["issue", "create", "--title", title, "--body", body]
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            DispatchQueue.main.async {
                self.isCreatingIssue = false
                if res.status == 0 {
                    showAlert(title: "Issue created", message: "Created issue: \(title)")
                    self.newIssueTitle = ""
                    self.newIssueBody = ""
                    self.activeSheet = nil
                    self.showAddIssueSheet = false
                    self.fetchIssues()
                } else {
                    showAlert(title: "Failed to create issue", message: res.output)
                }
            }
        }
    }
    
    // Post a comment to the selected issue using `gh issue comment` and refresh the thread
    private func postComment(body: String) {
        guard let sel = selectedIssue else {
            showAlert(title: "No issue selected", message: "Select an issue first.")
            return
        }
        isPostingComment = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Use gh to post a comment
            let args = ["issue", "comment", "\(sel.number)", "--body", body]
            let res = runGHCommand(args, currentDirectory: projectDirectory)
            DispatchQueue.main.async {
                self.isPostingComment = false
                if res.status == 0 {
                    self.replyText = ""
                    showAlert(title: "Comment posted", message: "Posted comment to issue #\(sel.number)")
                    // Refresh comments
                    fetchComments(for: sel)
                } else {
                    showAlert(title: "Failed to post comment", message: res.output)
                }
            }
        }
    }
}
