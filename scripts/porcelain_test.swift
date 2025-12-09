#!/usr/bin/env swift
import Foundation

let samples = [
    " M apple.txt",
    " M AnotherFile.txt",
    "MM file2.txt",
    "A  newfile.txt",
    "?? new_untracked.txt",
    " R oldname -> newname.txt",
    " D deleted.txt",
    "  spaced_start.txt", // edge case: two leading spaces then filename starts immediately
    " M a.txt"
]

func parseLine(_ line: String) -> String? {
    // Mirror the parsing in RepoView.loadChangedFiles()
    let raw = line.trimmingCharacters(in: .newlines)
    if raw.isEmpty { return nil }
    var pathPortion: String
    if raw.count >= 3 {
        let idx2 = raw.index(raw.startIndex, offsetBy: 2)
        if raw[idx2] == " " {
            // Expected format: two status chars + space
            pathPortion = String(raw[raw.index(idx2, offsetBy: 1)...]).trimmingCharacters(in: .whitespaces)
        } else {
            // Fallback for odd lines: preserve filename by starting at first non-space char
            if let firstNonSpace = raw.firstIndex(where: { $0 != " " && $0 != "\t" }) {
                pathPortion = String(raw[firstNonSpace...]).trimmingCharacters(in: .whitespaces)
            } else {
                return nil
            }
        }
    } else {
        // Very short lines: fallback to first non-space
        if let firstNonSpace = raw.firstIndex(where: { $0 != " " && $0 != "\t" }) {
            pathPortion = String(raw[firstNonSpace...]).trimmingCharacters(in: .whitespaces)
        } else {
            return nil
        }
    }

    if pathPortion.contains(" -> ") {
        if let arrowRange = pathPortion.range(of: " -> ") {
            pathPortion = String(pathPortion[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
    }
    return pathPortion.isEmpty ? nil : pathPortion
}

print("Testing porcelain parsing:\n")
for s in samples {
    let parsed = parseLine(s) ?? "<nil>"
    print("raw:\t\(s)\nparsed:\t\(parsed)\n---")
}
