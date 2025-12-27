import SwiftUI

// A small extracted IssueDetailView used by IssuesView
struct IssueDetailView: View {
    let issue: Issue?
    let comments: [Comment]
    let isLoadingComments: Bool
    let commentsError: String?
    let onClose: (Issue) -> Void
    let onReopen: (Issue) -> Void
    let onAdd: () -> Void

    // Reply box binding and state
    let replyBody: Binding<String>
    let isPostingComment: Bool
    let onPost: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let sel = issue {
                    // Issue header
                    Text("Issue #\(sel.number)")
                        .font(.title3)
                        .bold()

                    Text(sel.title)
                        .font(.headline)
                        .foregroundColor(sel.state == "open" ? .primary : .gray)

                    // Author and assignees metadata
                    HStack(spacing: 8) {
                        if let author = sel.author {
                            Text("Opened by \(author)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Opened by unknown")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if !sel.assignees.isEmpty {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Assigned to ")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            // list assignees
                            ForEach(sel.assignees, id: \String.self) { a in
                                Text(a)
                                    .font(.subheadline)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                        } else {
                            Text("• Unassigned")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    if let body = sel.body, !body.isEmpty {
                        Text(body)
                            .font(.body)
                            .padding(.top, 4)
                    } else {
                        Text("(No description provided)")
                            .italic()
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    Divider()

                    // Thread / comments
                    Text("Thread")
                        .font(.headline)

                    if isLoadingComments {
                        ProgressView("Loading thread...")
                            .padding(.top, 4)
                    } else if let cErr = commentsError {
                        Text("Error loading thread: \(cErr)")
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    } else if comments.isEmpty {
                        Text("No comments yet.")
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(comments, id: \ .id) { c in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Text(c.author)
                                            .font(.subheadline)
                                            .bold()
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text(c.formattedString())
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(c.body)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(8)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.02))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Reply box
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reply")
                            .font(.headline)
                        TextEditor(text: replyBody)
                            .frame(minHeight: 100)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))

                        HStack {
                            Button("Cancel") { replyBody.wrappedValue = "" }
                                .disabled(isPostingComment)
                            Spacer()
                            Button(isPostingComment ? "Posting…" : "Post") {
                                let trimmed = replyBody.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                onPost(trimmed)
                            }
                            .disabled(isPostingComment || replyBody.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.top)

                    // Actions: add, close/reopen
                    HStack {
                        Button(action: onAdd) {
                            Label("Add", systemImage: "plus")
                        }
                        .keyboardShortcut("N", modifiers: [.command])

                        Spacer()

                        Button(sel.state == "open" ? "Mark as done" : "Reopen") {
                            if sel.state == "open" { onClose(sel) } else { onReopen(sel) }
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.top)

                } else {
                    Text("Select an issue to view details and manage it.")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minWidth: 360, minHeight: 200)
        }
    }
}
