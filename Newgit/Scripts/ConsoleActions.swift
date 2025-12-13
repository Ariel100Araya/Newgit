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
    // Use modern APIs and executableURL so errors can be surfaced with try
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", command]

    // Ensure PATH includes common locations so git and other tools are found when invoked from the app
    var env = ProcessInfo.processInfo.environment
    let defaultPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
    let existingPATH = env["PATH"] ?? ""
    var paths = defaultPaths + existingPATH.split(separator: ":").map { String($0) }
    var seen = Set<String>()
    paths = paths.filter { p in
        if seen.contains(p) { return false }
        seen.insert(p)
        return true
    }
    env["PATH"] = paths.joined(separator: ":")
    task.environment = env

    let outPipe = Pipe()
    let errPipe = Pipe()
    task.standardOutput = outPipe
    task.standardError = errPipe

    do {
        try task.run()
    } catch {
        let msg = "Failed to launch bash: \(error.localizedDescription)"
        print("runCommand ERROR: \(msg) -- cmd=\(command)")
        return (msg, -1)
    }

    // Wait for the process to exit before reading data to avoid partial reads
    task.waitUntilExit()

    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

    let stdout = String(data: outData, encoding: .utf8) ?? ""
    let stderr = String(data: errData, encoding: .utf8) ?? ""

    // Combine stdout and stderr for backward compatibility but keep them separate in logs
    let combined = stdout + (stderr.isEmpty ? "" : "\n[stderr]\n" + stderr)

    print("runCommand: cmd=\(command)\nexit=\(task.terminationStatus)\nstdout=\(stdout)\nstderr=\(stderr)")

    return (combined, task.terminationStatus)
}

@discardableResult
func runGHCommand(_ args: [String], currentDirectory: String? = nil) -> (output: String, status: Int32) {
    // Build a shell-escaped argument list and call via the safer runCommand(...) helper.
    func shellEscape(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\\'\'") + "'"
    }

    let escapedArgs = args.map { shellEscape($0) }.joined(separator: " ")
    var cmd = "gh"
    if !escapedArgs.isEmpty { cmd += " " + escapedArgs }
    if let cwd = currentDirectory, !cwd.isEmpty {
        let escapedCwd = shellEscape(cwd)
        cmd = "cd \(escapedCwd) && \(cmd)"
    }

    return runCommand(cmd)
}
