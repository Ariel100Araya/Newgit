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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let sel = issue {
                    Text("Issue #\(sel.number)")
                        .font(.title3)
                        .bold()
                    
                    Text(sel.title)
                        .font(.headline)
                        .foregroundColor(sel.state == "open" ? .primary : .gray)
                    
                    if let body = sel.body, !body.isEmpty {
                        Text(body)
                            .font(.body)
                            .padding(.top, 4)
                    }
                } else {
                    Text("Select an issue to view details and manage it.")
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 360, minHeight: 200)
        }
    }
}
