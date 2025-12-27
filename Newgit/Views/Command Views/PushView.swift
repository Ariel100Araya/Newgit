//
//  PushView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/7/25.
//

import SwiftUI
import ConfettiSwiftUI
#if os(macOS)
import AppKit
#endif

struct PushView: View {
    @State private var commandInput: String = ""
    @State private var changeDirCommand: String = ""
    @State private var pushTitle: String = ""
    @State var projectDirectory: String
    // Callback invoked on successful push so parent can refresh repository state
    var onSuccess: (() -> Void)? = nil
    @State private var showCommandOutput: Bool = false
    // Error UI state: only used to surface failures
    @State private var showErrorAlert: Bool = false
    @State private var errorSummary: String = ""
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
                        .onSubmit {
                            performPush()
                            trigger += 1
                        }
                    
                    if #available(macOS 26.0, *) {
                        Button(action: {
                            performPush()
                            trigger += 1
                        }) {
                            Text(isProcessing ? "Working..." : "Push")
                        }
                        .glassEffect()
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing)
                        .padding()
                    } else {
                        // Fallback on earlier versions
                        Button(action: {
                            performPush()
                            trigger += 1
                        }) {
                            Text(isProcessing ? "Working..." : "Push")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing)
                        .padding()
                    }
                }
                .padding([.leading, .bottom, .trailing])
            }

            // Show command output only when an error occurred and user wants details
            if showCommandOutput {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Command output")
                            .font(.headline)
                        Spacer()
                        Button("Copy") {
                            #if os(macOS)
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(commandOutput, forType: .string)
                            #endif
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding([.top, .horizontal])

                    ScrollView {
                        Text(commandOutput)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 180, maxHeight: 360)
                    .background(Color(.windowBackgroundColor))
                    .cornerRadius(8)
                    .padding([.leading, .bottom, .trailing])
                }
            }

        }
        // Error alert shows a short summary and an option to view details (which reveals the console)
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Push Failed"),
                  message: Text(errorSummary),
                  primaryButton: .default(Text("OK")),
                  secondaryButton: .default(Text("View Details"), action: {
                    showCommandOutput = true
                  }))
        }
        
     }

     // MARK: - Helpers
     private func shellEscape(_ s: String) -> String {
         return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
     }

     private func performPush() {
         guard !isProcessing else { return }
         isProcessing = true
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
                 // Provide a short error summary and offer details
                 let short = addRes.output.split(separator: "\n").first.map(String.init) ?? "git add failed"
                 DispatchQueue.main.async {
                     self.commandOutput = combined
                     // show console because something went wrong
                     self.showCommandOutput = true
                     self.errorSummary = "git add failed: \(short)"
                     self.showErrorAlert = true
                     self.isProcessing = false
                     self.showSuccessView = false
                 }
                 return
             }

             // git commit
             let commitCmd = "cd \(dir) && git commit -m \(msg)"
             let commitRes = runCommand(commitCmd)
             combined += "$ \(commitCmd)\n" + commitRes.output + "\nexit=\(commitRes.status)\n\n"

             // If commit failed (non-zero) we may still want to push —
             // common case: "nothing to commit" means there were no new local changes but there may be local commits that need pushing.
             var shouldAttemptPushDespiteCommitFailure = false
             if commitRes.status != 0 {
                 let lower = commitRes.output.lowercased()
                 if lower.contains("nothing to commit") || lower.contains("no changes added to commit") || lower.contains("nothing added to commit") || lower.contains("nothing to commit, working tree clean") {
                     shouldAttemptPushDespiteCommitFailure = true
                 }
                 if !shouldAttemptPushDespiteCommitFailure {
                     let short = commitRes.output.split(separator: "\n").first.map(String.init) ?? "git commit failed"
                     DispatchQueue.main.async {
                         self.commandOutput = combined
                         // show console because something went wrong
                         self.showCommandOutput = true
                         self.errorSummary = "git commit failed: \(short)"
                         self.showErrorAlert = true
                         self.isProcessing = false
                         self.showSuccessView = false
                     }
                     return
                 }
             }

             // git push
             let pushCmd = "cd \(dir) && git push"
             let pushRes = runCommand(pushCmd)
             combined += "$ \(pushCmd)\n" + pushRes.output + "\nexit=\(pushRes.status)\n\n"

             // Consider success if push succeeded. If commit succeeded and push succeeded -> success.
             // If commit failed with 'nothing to commit' but push succeeded, it's still a success.
             let success = (pushRes.status == 0)

             DispatchQueue.main.async {
                 self.commandOutput = combined
                 self.isProcessing = false
                 if success {
                    // ensure console is hidden on success so UI remains compact
                    self.showCommandOutput = false
                     self.showSuccessView = true
                     // Notify parent to refresh repository state
                     self.onSuccess?()
                     // show for 5 seconds then dismiss
                     DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                         self.showSuccessView = false
                         self.dismiss()
                     }
                 } else {
                     // Show an error alert with a short summary and allow viewing full details
                     let short = pushRes.output.split(separator: "\n").first.map(String.init) ?? "git push failed (exit=\(pushRes.status))"
                     self.errorSummary = "git push failed: \(short)"
                    // show console because something went wrong
                     self.showCommandOutput = true
                     self.showErrorAlert = true
                     // Keep showing command output for details
                     self.showSuccessView = false
                 }
             }
         }
     }
 }
