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
func runGHCommand(_ args: [String], currentDirectory: String? = nil) -> (output: String, status: Int32) {
    let task = Process()
    // Run the Homebrew-installed gh binary directly so gh auth and config work correctly
    task.launchPath = "/opt/homebrew/bin/gh"
    task.arguments = args

    if let cwd = currentDirectory {
        task.currentDirectoryPath = cwd
    }

    // Ensure PATH includes common locations so gh can find git and other tools when run from the app
    var env = ProcessInfo.processInfo.environment
    let defaultPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
    let existingPATH = env["PATH"] ?? ""
    // Prepend default paths if they're not already present
    var paths = defaultPaths + existingPATH.split(separator: ":").map { String($0) }
    // Deduplicate while preserving order
    var seen = Set<String>()
    paths = paths.filter { p in
        if seen.contains(p) { return false }
        seen.insert(p)
        return true
    }
    env["PATH"] = paths.joined(separator: ":")
    task.environment = env

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
