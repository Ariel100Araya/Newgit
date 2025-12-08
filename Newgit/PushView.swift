//
//  PushView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/7/25.
//

import SwiftUI

struct PushView: View {
    @State private var commandInput: String = ""
    @State private var changeDirCommand: String = ""
    @State private var pushTitle: String = ""
    @State var projectDirectory: String
    @State private var showCommandOutput: Bool = false
    var body: some View {
        VStack (alignment: .leading) {
            Text("Enter a push title")
                .padding()
            TextField("Enter a push title", text: $pushTitle)
                .padding()
            Text("Push")
                .onTapGesture {
                    showCommandOutput = true
                }
                .padding()
                .glassEffect()
            if showCommandOutput {
                let changeDirCommand = "cd \(projectDirectory) && git add . && git commit -m \"\(pushTitle)\" && git push"
                Text(runCommand(changeDirCommand).output)
            }
        }
    }
}
