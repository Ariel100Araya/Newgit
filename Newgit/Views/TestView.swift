//
//  TestView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/6/25.
//

import SwiftUI
import SwiftData

struct TestView: View {
    @State private var commandInput: String = ""
    @State private var projectDirectory: String = ""
    @State private var showCommandOutput: Bool = false
    @State private var isGHCommand: Bool = false
    @State private var gitPush: Bool =  false
    var body: some View {
        VStack {
            Text("Enter a project directory")
                .padding()
            TextField("Project Directory", text: $projectDirectory)
                .padding()
            Text("Enter a command to run")
                .padding()
            TextField("Enter command", text: $commandInput)
                .padding()
            HStack {
                Text("Run Command in terminal")
                    .onTapGesture {
                        showCommandOutput = true
                        isGHCommand = false
                    }
                    .padding()
                    .glassEffect()
                Text("Run Command in GH CLI")
                    .onTapGesture {
                        showCommandOutput = true
                        isGHCommand = true
                    }
                    .padding()
                    .glassEffect()
                Text("Push")
                    .onTapGesture {
                        showCommandOutput = true
                        gitPush = true
                    }
                    .padding()
                    .glassEffect()
            }
            HStack {
                Text("Sign into GitHub CLI")
                    .onTapGesture {
                        showCommandOutput = true
                        isGHCommand = true
                    }
                    .padding()
                    .glassEffect()
            }
            Text("Command Output will appear here")
                .padding()
        .navigationTitle("Test View")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Push") {
                    showCommandOutput = true
                    isGHCommand = true
                }
                .padding(.horizontal)
                .buttonStyle(.borderedProminent)
            }
        }
        }
    }
}

/*
 struct TestView: View {
     var body: some View {
         VStack {
             Text("Hoi")
                 .padding()
         }
         .navigationTitle("Newgit")
         .toolbar {
             ToolbarItemGroup(placement: .primaryAction) {
                 Button("Ariel Araya-Madrigal") {
                 }
                 .padding(.horizontal)
             }
         }
     }
 }

 */
