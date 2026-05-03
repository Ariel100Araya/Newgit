//
//  ReadmeEditorView.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 5/3/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ReadmeEditorView: View {
    let projectDirectory: String
    let repoTitle: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var markdown: String = ""
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var statusMessage: String = ""
    @State private var headingLevel: ReadmeHeadingLevel = .body
    @State private var showingLinkSheet = false
    @State private var linkText = ""
    @State private var linkURL = ""
    @State private var showingImageSheet = false
    @State private var imageAltText = ""
    @State private var imageURL = ""

    private var readmeURL: URL {
        URL(fileURLWithPath: projectDirectory).appendingPathComponent("README.md")
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()
            formattingBar
            Divider()
            HSplitView {
                editorPane
                    .frame(minWidth: 420)
                previewPane
                    .frame(minWidth: 320)
            }
            Divider()
            footerBar
        }
        .frame(minWidth: 920, minHeight: 640)
        .onAppear(perform: loadReadme)
        .sheet(isPresented: $showingLinkSheet) {
            linkSheet
        }
        .sheet(isPresented: $showingImageSheet) {
            imageURLSheet
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit README")
                    .font(.title2)
                    .bold()
                Text(repoTitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var formattingBar: some View {
        HStack(spacing: 8) {
            Picker("Style", selection: $headingLevel) {
                ForEach(ReadmeHeadingLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .onChange(of: headingLevel) { _, newValue in
                applyHeading(newValue)
            }

            Divider()
                .frame(height: 24)

            toolbarButton("bold", title: "Bold", systemImage: "bold") {
                wrapSelection(prefix: "**", suffix: "**", placeholder: "bold text")
            }
            toolbarButton("italic", title: "Italic", systemImage: "italic") {
                wrapSelection(prefix: "*", suffix: "*", placeholder: "italic text")
            }
            toolbarButton("underline", title: "Underline", systemImage: "underline") {
                wrapSelection(prefix: "<u>", suffix: "</u>", placeholder: "underlined text")
            }

            Divider()
                .frame(height: 24)

            toolbarButton("list.bullet", title: "Bulleted List", systemImage: "list.bullet") {
                prefixSelectedLines(with: "- ")
            }
            toolbarButton("list.number", title: "Numbered List", systemImage: "list.number") {
                numberSelectedLines()
            }
            toolbarButton("quote", title: "Quote", systemImage: "quote.opening") {
                prefixSelectedLines(with: "> ")
            }
            toolbarButton("code", title: "Code", systemImage: "curlybraces") {
                wrapSelection(prefix: "`", suffix: "`", placeholder: "code")
            }

            Divider()
                .frame(height: 24)

            toolbarButton("link", title: "Link", systemImage: "link") {
                prepareLinkSheet()
            }
            toolbarButton("photo", title: "Add Image", systemImage: "photo") {
                addLocalImage()
            }
            Button {
                prepareImageURLSheet()
            } label: {
                Label("Image URL", systemImage: "globe")
            }
            .help("Insert an image from a web URL")

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Write")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 10)
            MarkdownTextView(text: $markdown, selectedRange: $selectedRange)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.18)))
                .padding([.horizontal, .bottom])
        }
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 10)
            ReadmePreview(markdown: markdown, projectDirectory: projectDirectory)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.18)))
            .padding([.horizontal, .bottom])
        }
    }

    private var footerBar: some View {
        HStack {
            Text(statusMessage.isEmpty ? "README.md" : statusMessage)
                .foregroundStyle(statusMessage.isEmpty ? .secondary : .primary)
            Spacer()
            Button("Cancel") {
                dismiss()
            }
            Button("Save") {
                saveReadme()
            }
            Button("Save and Close") {
                saveReadme(closeAfterSave: true)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var linkSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Link")
                .font(.headline)
            TextField("Text people will click", text: $linkText)
                .textFieldStyle(.roundedBorder)
            TextField("https://example.com", text: $linkURL)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") {
                    showingLinkSheet = false
                }
                Button("Insert") {
                    insertLink()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }

    private var imageURLSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Image From URL")
                .font(.headline)
            TextField("Short description", text: $imageAltText)
                .textFieldStyle(.roundedBorder)
            TextField("https://example.com/image.png", text: $imageURL)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") {
                    showingImageSheet = false
                }
                Button("Insert") {
                    insertImageURL()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 460)
    }

    private func toolbarButton(_ id: String, title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 18, height: 18)
        }
        .help(title)
        .accessibilityIdentifier("readme-editor-\(id)-button")
    }

    private func loadReadme() {
        do {
            if FileManager.default.fileExists(atPath: readmeURL.path) {
                markdown = try String(contentsOf: readmeURL, encoding: .utf8)
            } else {
                markdown = """
                # \(repoTitle)

                Write what this project does, how to get started, and anything people should know before they use it.
                """
            }
            statusMessage = "Loaded README.md"
        } catch {
            statusMessage = "Could not load README: \(error.localizedDescription)"
        }
    }

    private func saveReadme(closeAfterSave: Bool = false) {
        do {
            try markdown.write(to: readmeURL, atomically: true, encoding: .utf8)
            statusMessage = "Saved README.md"
            onSave()
            if closeAfterSave {
                dismiss()
            }
        } catch {
            statusMessage = "Could not save README: \(error.localizedDescription)"
        }
    }

    private func selectedText() -> String {
        guard let range = Range(selectedRange, in: markdown) else { return "" }
        return String(markdown[range])
    }

    private func replaceSelection(with replacement: String, selectInsertedText: Bool = false) {
        guard let range = Range(selectedRange, in: markdown) else {
            markdown += replacement
            selectedRange = NSRange(location: markdown.utf16.count, length: 0)
            return
        }

        markdown.replaceSubrange(range, with: replacement)
        let start = selectedRange.location
        selectedRange = NSRange(location: start + replacement.utf16.count, length: 0)
        if selectInsertedText {
            selectedRange = NSRange(location: start, length: replacement.utf16.count)
        }
    }

    private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
        let selected = selectedText()
        if selected.isEmpty {
            replaceSelection(with: prefix + placeholder + suffix, selectInsertedText: true)
        } else {
            replaceSelection(with: prefix + selected + suffix)
        }
    }

    private func applyHeading(_ level: ReadmeHeadingLevel) {
        let targetRange = selectedRange.length == 0 ? currentLineRange() : selectedLineRange()
        guard let range = Range(targetRange, in: markdown) else { return }
        let selectedBlock = String(markdown[range])
        let transformed = selectedBlock
            .components(separatedBy: .newlines)
            .map { line -> String in
                let trimmed = line.replacingOccurrences(of: #"^\s*#{1,6}\s*"#, with: "", options: .regularExpression)
                guard !trimmed.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
                return level.prefix + trimmed
            }
            .joined(separator: "\n")

        markdown.replaceSubrange(range, with: transformed)
        selectedRange = NSRange(location: targetRange.location, length: transformed.utf16.count)
        headingLevel = .body
    }

    private func prefixSelectedLines(with prefix: String) {
        transformSelectedLines { line, _ in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
            return prefix + line
        }
    }

    private func numberSelectedLines() {
        transformSelectedLines { line, index in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
            return "\(index + 1). " + line
        }
    }

    private func transformSelectedLines(_ transform: (String, Int) -> String) {
        let targetRange = selectedRange.length == 0 ? currentLineRange() : selectedLineRange()
        guard let range = Range(targetRange, in: markdown) else { return }
        let lines = String(markdown[range]).components(separatedBy: .newlines)
        let transformed = lines.enumerated().map { transform($0.element, $0.offset) }.joined(separator: "\n")
        markdown.replaceSubrange(range, with: transformed)
        selectedRange = NSRange(location: targetRange.location, length: transformed.utf16.count)
    }

    private func selectedLineRange() -> NSRange {
        (markdown as NSString).lineRange(for: selectedRange)
    }

    private func currentLineRange() -> NSRange {
        let safeLocation = min(selectedRange.location, max((markdown as NSString).length - 1, 0))
        return (markdown as NSString).lineRange(for: NSRange(location: safeLocation, length: 0))
    }

    private func prepareLinkSheet() {
        let selected = selectedText().trimmingCharacters(in: .whitespacesAndNewlines)
        linkText = selected.isEmpty ? "link text" : selected
        linkURL = ""
        showingLinkSheet = true
    }

    private func insertLink() {
        let text = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        replaceSelection(with: "[\(text)](\(url))")
        showingLinkSheet = false
    }

    private func addLocalImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let sourceURL = panel.url {
            do {
                let imageFolder = URL(fileURLWithPath: projectDirectory).appendingPathComponent("readme-images", isDirectory: true)
                try FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
                let destination = uniqueImageDestination(for: sourceURL, in: imageFolder)
                try FileManager.default.copyItem(at: sourceURL, to: destination)
                let relativePath = "readme-images/\(destination.lastPathComponent)"
                let alt = sourceURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ")
                replaceSelection(with: "![\(alt)](\(relativePath))")
                statusMessage = "Added \(destination.lastPathComponent)"
            } catch {
                statusMessage = "Could not add image: \(error.localizedDescription)"
            }
        }
    }

    private func uniqueImageDestination(for sourceURL: URL, in folder: URL) -> URL {
        let base = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        var candidate = folder.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let fileName = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            candidate = folder.appendingPathComponent(fileName)
            counter += 1
        }
        return candidate
    }

    private func prepareImageURLSheet() {
        imageAltText = ""
        imageURL = ""
        showingImageSheet = true
    }

    private func insertImageURL() {
        let alt = imageAltText.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        replaceSelection(with: "![\(alt.isEmpty ? "image" : alt)](\(url))")
        showingImageSheet = false
    }
}

private enum ReadmeHeadingLevel: String, CaseIterable, Identifiable {
    case body
    case heading1
    case heading2
    case heading3

    var id: String { rawValue }

    var title: String {
        switch self {
        case .body: return "Normal text"
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        }
    }

    var prefix: String {
        switch self {
        case .body: return ""
        case .heading1: return "# "
        case .heading2: return "## "
        case .heading3: return "### "
        }
    }
}

private struct ReadmePreview: View {
    let markdown: String
    let projectDirectory: String

    private var blocks: [ReadmePreviewBlock] {
        ReadmePreviewParser.blocks(from: markdown)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
        }
    }

    @ViewBuilder
    private func blockView(_ block: ReadmePreviewBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inlineMarkdown(text))
                .font(headingFont(for: level))
                .bold()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, level == 1 ? 4 : 8)
        case .paragraph(let text):
            Text(inlineMarkdown(text))
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                Text(inlineMarkdown(text))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).")
                    .monospacedDigit()
                Text(inlineMarkdown(text))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 3)
                Text(inlineMarkdown(text))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .code(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .image(let alt, let source):
            ReadmePreviewImage(alt: alt, source: source, projectDirectory: projectDirectory)
        case .space:
            Spacer()
                .frame(height: 8)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title2
        case 3: return .title3
        default: return .headline
        }
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        let parts = text.components(separatedBy: "<u>")
        guard parts.count > 1 else {
            return parsedInlineMarkdown(text)
        }

        var result = AttributedString()
        for (index, part) in parts.enumerated() {
            if index == 0 {
                result += parsedInlineMarkdown(part)
                continue
            }

            let underlineParts = part.components(separatedBy: "</u>")
            if let underlined = underlineParts.first {
                var underlinedText = parsedInlineMarkdown(underlined)
                underlinedText.underlineStyle = .single
                result += underlinedText
            }

            if underlineParts.count > 1 {
                result += parsedInlineMarkdown(underlineParts.dropFirst().joined(separator: "</u>"))
            }
        }
        return result
    }

    private func parsedInlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

private enum ReadmePreviewBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(String)
    case numbered(number: Int, text: String)
    case quote(String)
    case code(String)
    case image(alt: String, source: String)
    case space
}

private enum ReadmePreviewParser {
    static func blocks(from markdown: String) -> [ReadmePreviewBlock] {
        var blocks: [ReadmePreviewBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var isInCodeBlock = false

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
            paragraphLines.removeAll()
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if isInCodeBlock {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                    isInCodeBlock = false
                } else {
                    flushParagraph()
                    isInCodeBlock = true
                }
                continue
            }

            if isInCodeBlock {
                codeLines.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushParagraph()
                if blocks.last?.isSpace != true {
                    blocks.append(.space)
                }
                continue
            }

            if let image = imageBlock(from: line) {
                flushParagraph()
                blocks.append(image)
                continue
            }

            if let heading = headingBlock(from: line) {
                flushParagraph()
                blocks.append(heading)
                continue
            }

            if let bullet = bulletBlock(from: line) {
                flushParagraph()
                blocks.append(bullet)
                continue
            }

            if let numbered = numberedBlock(from: line) {
                flushParagraph()
                blocks.append(numbered)
                continue
            }

            if line.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.quote(String(line.dropFirst(2))))
                continue
            }

            paragraphLines.append(rawLine)
        }

        if isInCodeBlock {
            blocks.append(.code(codeLines.joined(separator: "\n")))
        }
        flushParagraph()
        return blocks
    }

    private static func headingBlock(from line: String) -> ReadmePreviewBlock? {
        let markerCount = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(markerCount) else { return nil }
        let markerEnd = line.index(line.startIndex, offsetBy: markerCount)
        guard markerEnd < line.endIndex, line[markerEnd] == " " else { return nil }
        let textStart = line.index(after: markerEnd)
        return .heading(level: markerCount, text: String(line[textStart...]))
    }

    private static func imageBlock(from line: String) -> ReadmePreviewBlock? {
        guard line.hasPrefix("!["), let altEnd = line.range(of: "]("), line.hasSuffix(")") else { return nil }
        let altStart = line.index(line.startIndex, offsetBy: 2)
        let sourceStart = altEnd.upperBound
        let sourceEnd = line.index(before: line.endIndex)
        return .image(alt: String(line[altStart..<altEnd.lowerBound]), source: String(line[sourceStart..<sourceEnd]))
    }

    private static func bulletBlock(from line: String) -> ReadmePreviewBlock? {
        if line.hasPrefix("- ") {
            return .bullet(String(line.dropFirst(2)))
        }
        if line.hasPrefix("* ") {
            return .bullet(String(line.dropFirst(2)))
        }
        return nil
    }

    private static func numberedBlock(from line: String) -> ReadmePreviewBlock? {
        guard let dot = line.firstIndex(of: ".") else { return nil }
        let numberText = line[..<dot]
        guard let number = Int(numberText), line.index(after: dot) < line.endIndex, line[line.index(after: dot)] == " " else { return nil }
        return .numbered(number: number, text: String(line[line.index(dot, offsetBy: 2)...]))
    }
}

private extension ReadmePreviewBlock {
    var isSpace: Bool {
        if case .space = self { return true }
        return false
    }
}

private struct ReadmePreviewImage: View {
    let alt: String
    let source: String
    let projectDirectory: String

    var body: some View {
        if let url = imageURL {
            if url.isFileURL, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel(alt.isEmpty ? "README image" : alt)
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    case .failure:
                        missingImageLabel
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    @unknown default:
                        missingImageLabel
                    }
                }
                .accessibilityLabel(alt.isEmpty ? "README image" : alt)
            }
        } else {
            missingImageLabel
        }
    }

    private var imageURL: URL? {
        if let url = URL(string: source), url.scheme == "http" || url.scheme == "https" {
            return url
        }
        return URL(fileURLWithPath: projectDirectory).appendingPathComponent(source)
    }

    private var missingImageLabel: some View {
        Label(alt.isEmpty ? source : alt, systemImage: "photo")
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: $selectedRange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
        }
        if textView.selectedRange() != selectedRange, selectedRange.location <= (text as NSString).length {
            textView.setSelectedRange(selectedRange)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var selectedRange: NSRange

        init(text: Binding<String>, selectedRange: Binding<NSRange>) {
            _text = text
            _selectedRange = selectedRange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            selectedRange = textView.selectedRange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            selectedRange = textView.selectedRange()
        }
    }
}
