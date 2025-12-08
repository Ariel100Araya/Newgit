//
//  ConsoleActions.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/7/25.
//
import Foundation

@discardableResult
func runCommand(_ command: String) -> (output: String, status: Int32) {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    task.launch()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()

    let output = String(data: data, encoding: .utf8) ?? ""
    return (output, task.terminationStatus)
}

@discardableResult
func runGHCommand(_ args: [String]) -> (output: String, status: Int32) {
    let task = Process()
    // Run the Homebrew-installed gh binary directly so gh auth and config work correctly
    task.launchPath = "/opt/homebrew/bin/gh"
    task.arguments = args

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    do {
        try task.run()
    } catch {
        return ("Failed to launch gh: \(error.localizedDescription)", -1)
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()

    let output = String(data: data, encoding: .utf8) ?? ""
    return (output, task.terminationStatus)
}
