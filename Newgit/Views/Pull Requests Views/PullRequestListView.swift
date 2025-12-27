import SwiftUI

struct PullRequestListView: View {
    var prs: [PullRequest]
    @Binding var selectedPR: PullRequest?

    var body: some View {
        List(prs, id: \.number) { pr in
            Button(action: { selectedPR = pr }) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("#\(pr.number): \(pr.title)")
                            .font(.headline)
                            .lineLimit(2)
                        Text(pr.state.capitalized)
                            .font(.subheadline)
                            .foregroundColor(pr.state == "open" ? .green : .red)
                    }
                    Spacer()
                    if selectedPR?.number == pr.number { Image(systemName: "checkmark") }
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .frame(minWidth: 340, minHeight: 200)
    }
}
