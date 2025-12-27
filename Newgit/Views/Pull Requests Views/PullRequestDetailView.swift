import SwiftUI

struct PullRequestDetailView: View {
    let pr: PullRequest?
    let comments: [Comment]
    let isLoadingComments: Bool
    let commentsError: String?
    let onMerge: (PullRequest) -> Void
    let onClose: (PullRequest) -> Void
    let onAdd: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let sel = pr {
                    Text("PR #\(sel.number)")
                        .font(.title3)
                        .bold()

                    Text(sel.title)
                        .font(.headline)
                        .foregroundColor(sel.state == "open" ? .primary : .gray)

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

                    HStack {
                        Spacer()
                        Button("Close") { onClose(sel) }
                        Button("Merge") { onMerge(sel) }
                    }
                    .padding(.top)
                } else {
                    Text("Select a pull request to view details and manage it.")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minWidth: 360, minHeight: 200)
        }
    }
}
