import SwiftUI

// A small extracted IssueListView used by IssuesView
struct IssueListView: View {
    var issues: [Issue]
    @Binding var selectedIssue: Issue?

    var body: some View {
        List(issues, id: \.number) { issue in
            Button(action: { selectedIssue = issue }) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("#\(issue.number): \(issue.title)")
                            .font(.headline)
                            .lineLimit(2)
                        Text(issue.state.capitalized)
                            .font(.subheadline)
                            .foregroundColor(issue.state == "open" ? .green : .red)
                    }
                    Spacer()
                    if selectedIssue?.number == issue.number { Image(systemName: "checkmark") }
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .frame(minWidth: 340, minHeight: 200)
    }
}
