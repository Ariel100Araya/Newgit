//
//  PushView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/7/25.
//

import SwiftUI
import ConfettiSwiftUI

struct PushView: View {
    @State private var commandInput: String = ""
    @State private var changeDirCommand: String = ""
    @State private var pushTitle: String = ""
    @State var projectDirectory: String
    @State private var showCommandOutput: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var showSuccessView: Bool = false
    @State private var commandOutput: String = ""
    @State private var isProcessing: Bool = false
    @State private var trigger: Int = 0
    var body: some View {
        VStack (alignment: .leading) {
            // MARK: if succeded, have a 5 second success view
            if showSuccessView {
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
                Text("Enter a push title")
                    .padding([.leading, .top, .trailing])
                    .font(.title2)
                    .bold()
                HStack {
                    TextField("Enter a push title", text: $pushTitle)
                        .padding(.trailing)
                    Button(action: {
                        performPush()
                        trigger += 1
                    }) {
                        Text(isProcessing ? "Working..." : "Push")
                    }
                    .disabled(isProcessing)
                    .padding()
                    .glassEffect()
                }
                .padding([.leading, .bottom, .trailing])
            }
            if showCommandOutput {
                ScrollView {
                    Text(commandOutput)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            }
        }
    }

    // MARK: - Helpers
    private func shellEscape(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func performPush() {
        guard !isProcessing else { return }
        isProcessing = true
        showCommandOutput = true
        commandOutput = "Starting..."

        // Run git commands on a background queue to avoid blocking the UI
        DispatchQueue.global(qos: .userInitiated).async {
            let dir = shellEscape(projectDirectory)
            let msg = shellEscape(pushTitle)

            var combined = ""

            // git add
            let addCmd = "cd \(dir) && git add ."
            let addRes = runCommand(addCmd)
            combined += "$ \(addCmd)\n" + addRes.output + "\nexit=\(addRes.status)\n\n"
            if addRes.status != 0 {
                DispatchQueue.main.async {
                    self.commandOutput = combined
                    self.isProcessing = false
                    self.showSuccessView = false
                }
                return
            }

            // git commit
            let commitCmd = "cd \(dir) && git commit -m \(msg)"
            let commitRes = runCommand(commitCmd)
            combined += "$ \(commitCmd)\n" + commitRes.output + "\nexit=\(commitRes.status)\n\n"

            // If commit failed (non-zero), show output and do not show success view
            if commitRes.status != 0 {
                DispatchQueue.main.async {
                    self.commandOutput = combined
                    self.isProcessing = false
                    self.showSuccessView = false
                }
                return
            }

            // git push
            let pushCmd = "cd \(dir) && git push"
            let pushRes = runCommand(pushCmd)
            combined += "$ \(pushCmd)\n" + pushRes.output + "\nexit=\(pushRes.status)\n\n"

            let success = (commitRes.status == 0 && pushRes.status == 0)

            DispatchQueue.main.async {
                self.commandOutput = combined
                self.isProcessing = false
                if success {
                    self.showSuccessView = true
                    // show for 5 seconds then dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.showSuccessView = false
                        self.dismiss()
                    }
                } else {
                    // Keep showing command output; don't show success
                    self.showSuccessView = false
                }
            }
        }
    }
}
