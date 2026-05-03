import Testing
@testable import Newgit

@MainActor
struct DiffEditEngineTests {
    @Test("interpret marks unified diff additions and deletions")
    func interpretMarksAdditionsAndDeletions() {
        let diff = """
        diff --git a/hello.txt b/hello.txt
        index 1111111..2222222 100644
        --- a/hello.txt
        +++ b/hello.txt
        @@ -1,3 +1,3 @@
         same
        -old
        +new
        """

        let lines = DiffEditEngine.interpret(diff)
        let hasMetadata = lines.contains { line in line.kind == .metadata && line.text == "diff --git a/hello.txt b/hello.txt" }
        let hasHunkHeader = lines.contains { line in line.kind == .hunkHeader && line.text == "@@ -1,3 +1,3 @@" }
        let hasContext = lines.contains { line in line.kind == .context && line.text == "same" }
        let hasDeletion = lines.contains { line in line.kind == .deletion && line.marker == "-" && line.text == "old" }
        let hasAddition = lines.contains { line in line.kind == .addition && line.marker == "+" && line.text == "new" }
        let misreadPlusHeader = lines.contains { line in line.kind == .addition && line.text.hasPrefix("+++") }
        let misreadMinusHeader = lines.contains { line in line.kind == .deletion && line.text.hasPrefix("---") }

        #expect(hasMetadata)
        #expect(hasHunkHeader)
        #expect(hasContext)
        #expect(hasDeletion)
        #expect(hasAddition)
        #expect(!misreadPlusHeader)
        #expect(!misreadMinusHeader)
    }

    @Test("unifiedDiffForNewFile creates added lines")
    func unifiedDiffForNewFileCreatesAddedLines() {
        let diff = DiffEditEngine.unifiedDiffForNewFile(path: "note.txt", contents: "one\ntwo\n")
        let lines = DiffEditEngine.interpret(diff)
        let hasNullSource = lines.contains { line in line.kind == .metadata && line.text == "--- /dev/null" }
        let addedTexts = lines.filter { line in line.kind == .addition }.map(\.text)

        #expect(hasNullSource)
        #expect(addedTexts == ["one", "two"])
    }

    @Test("visibleLines hides git metadata")
    func visibleLinesHidesGitMetadata() {
        let diff = """
        diff --git a/hello.txt b/hello.txt
        index 1111111..2222222 100644
        --- a/hello.txt
        +++ b/hello.txt
        @@ -1 +1 @@
        -old
        +new
        """

        let visibleLines = DiffEditEngine.visibleLines(from: diff)

        #expect(!visibleLines.contains { line in line.kind == .metadata })
        #expect(visibleLines.map(\.kind) == [.hunkHeader, .deletion, .addition])
    }
}
