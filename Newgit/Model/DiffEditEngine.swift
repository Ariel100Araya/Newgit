import Foundation

struct DiffEditLine: Identifiable, Equatable {
    enum Kind: Equatable {
        case metadata
        case hunkHeader
        case context
        case addition
        case deletion
        case message
    }

    let id: Int
    let kind: Kind
    let marker: String
    let text: String
}

enum DiffEditEngine {
    static func interpret(_ diff: String) -> [DiffEditLine] {
        let normalizedDiff = diff.replacingOccurrences(of: "\r\n", with: "\n")
        let rawLines = normalizedDiff.components(separatedBy: "\n")
        let lines = normalizedDiff.hasSuffix("\n") ? Array(rawLines.dropLast()) : rawLines

        guard !lines.isEmpty else { return [] }

        return lines.enumerated().map { index, rawLine in
            let kind: DiffEditLine.Kind
            let marker: String
            let text: String

            if rawLine.hasPrefix("@@") {
                kind = .hunkHeader
                marker = "@@"
                text = rawLine
            } else if rawLine.hasPrefix("+"), !rawLine.hasPrefix("+++") {
                kind = .addition
                marker = "+"
                text = String(rawLine.dropFirst())
            } else if rawLine.hasPrefix("-"), !rawLine.hasPrefix("---") {
                kind = .deletion
                marker = "-"
                text = String(rawLine.dropFirst())
            } else if rawLine.hasPrefix("diff --git")
                        || rawLine.hasPrefix("index ")
                        || rawLine.hasPrefix("new file mode")
                        || rawLine.hasPrefix("deleted file mode")
                        || rawLine.hasPrefix("similarity index")
                        || rawLine.hasPrefix("rename from ")
                        || rawLine.hasPrefix("rename to ")
                        || rawLine.hasPrefix("---")
                        || rawLine.hasPrefix("+++") {
                kind = .metadata
                marker = ""
                text = rawLine
            } else if rawLine.hasPrefix(" ") {
                kind = .context
                marker = " "
                text = String(rawLine.dropFirst())
            } else {
                kind = .message
                marker = ""
                text = rawLine
            }

            return DiffEditLine(id: index, kind: kind, marker: marker, text: text)
        }
    }

    static func visibleLines(from diff: String) -> [DiffEditLine] {
        interpret(diff).filter { $0.kind != .metadata }
    }

    static func unifiedDiffForNewFile(path: String, contents: String) -> String {
        let normalizedContents = contents.replacingOccurrences(of: "\r\n", with: "\n")
        let rawLines = normalizedContents.components(separatedBy: "\n")
        let lines = normalizedContents.hasSuffix("\n") ? Array(rawLines.dropLast()) : rawLines
        let hunkLineCount = max(lines.count, 1)
        let body = lines.isEmpty ? ["+"] : lines.map { "+\($0)" }

        return ([
            "diff --git a/\(path) b/\(path)",
            "new file mode 100644",
            "--- /dev/null",
            "+++ b/\(path)",
            "@@ -0,0 +1,\(hunkLineCount) @@"
        ] + body).joined(separator: "\n")
    }
}
