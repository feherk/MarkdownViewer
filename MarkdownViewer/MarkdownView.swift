import SwiftUI

struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(parseBlocks(text).enumerated()), id: \.offset) { _, block in
                block
            }
        }
    }

    // Fast check for numbered list (e.g., "1. ", "12. ") - replaces slow regex
    private func parseNumberedListPrefix(_ line: String) -> (prefix: String, content: String)? {
        var idx = line.startIndex
        // Check for digits at start
        while idx < line.endIndex && line[idx].isNumber {
            idx = line.index(after: idx)
        }
        // Must have at least one digit
        guard idx > line.startIndex else { return nil }
        // Check for ". " after digits
        guard idx < line.endIndex && line[idx] == "." else { return nil }
        let afterDot = line.index(after: idx)
        guard afterDot < line.endIndex && line[afterDot] == " " else { return nil }
        let prefixEnd = line.index(after: afterDot)
        return (String(line[..<prefixEnd]), String(line[prefixEnd...]))
    }

    private func parseBlocks(_ text: String) -> [AnyView] {
        var views: [AnyView] = []
        var lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Empty line - skip
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }

            // Code block (``` ... ```) - supports indented blocks
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("```") {
                // Determine indentation
                let indentation = line.prefix(while: { $0 == " " }).count

                // Identify language (e.g. ```bash -> "bash")
                let language = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                let isTerminal = ["bash", "sh", "shell", "zsh", "terminal", "console"].contains(language)

                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    // Remove common indentation from code
                    var codeLine = lines[i]
                    if codeLine.prefix(indentation).allSatisfy({ $0 == " " }) {
                        codeLine = String(codeLine.dropFirst(indentation))
                    }
                    codeLines.append(codeLine)
                    i += 1
                }
                i += 1 // skip closing ```
                views.append(AnyView(
                    CodeBlockView(code: codeLines.joined(separator: "\n"), isTerminal: isTerminal)
                        .padding(.leading, CGFloat(indentation) * 2.5)
                ))
                continue
            }

            // H1
            if line.hasPrefix("# ") {
                let content = String(line.dropFirst(2))
                views.append(AnyView(
                    InlineMarkdownText(text: content, fontSize: 28, fontWeight: .bold)
                ))
                i += 1
                continue
            }

            // H2
            if line.hasPrefix("## ") {
                let content = String(line.dropFirst(3))
                views.append(AnyView(
                    InlineMarkdownText(text: content, fontSize: 22, fontWeight: .bold)
                ))
                i += 1
                continue
            }

            // H3
            if line.hasPrefix("### ") {
                let content = String(line.dropFirst(4))
                views.append(AnyView(
                    InlineMarkdownText(text: content, fontSize: 18, fontWeight: .semibold)
                ))
                i += 1
                continue
            }

            // H4
            if line.hasPrefix("#### ") {
                let content = String(line.dropFirst(5))
                views.append(AnyView(
                    InlineMarkdownText(text: content, fontSize: 16, fontWeight: .semibold)
                ))
                i += 1
                continue
            }

            // Horizontal rule
            if line == "---" || line == "***" || line == "___" {
                views.append(AnyView(
                    Divider().padding(.vertical, 4)
                ))
                i += 1
                continue
            }

            // Blockquote - join related lines
            if line.hasPrefix("> ") {
                var quoteLines: [String] = []
                while i < lines.count && lines[i].hasPrefix("> ") {
                    quoteLines.append(String(lines[i].dropFirst(2)))
                    i += 1
                }
                let content = quoteLines.joined(separator: " ")
                views.append(AnyView(
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 3)
                        InlineMarkdownText(text: content)
                            .italic()
                            .foregroundColor(.secondary)
                            .padding(.leading, 12)
                    }
                ))
                continue
            }

            // List item
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var listItems: [String] = []
                while i < lines.count && (lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ")) {
                    listItems.append(String(lines[i].dropFirst(2)))
                    i += 1
                }
                views.append(AnyView(
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(listItems.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                InlineMarkdownText(text: item)
                            }
                        }
                    }
                ))
                continue
            }

            // Numbered list
            if parseNumberedListPrefix(line) != nil {
                var listItems: [(String, String)] = []
                while i < lines.count, let parsed = parseNumberedListPrefix(lines[i]) {
                    listItems.append((parsed.prefix, parsed.content))
                    i += 1
                }
                views.append(AnyView(
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(listItems.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 4) {
                                Text(item.0)
                                    .frame(width: 24, alignment: .leading)
                                InlineMarkdownText(text: item.1)
                            }
                        }
                    }
                ))
                continue
            }

            // Table detection (lines with | characters)
            if isTableRow(line) {
                var tableLines: [String] = []
                while i < lines.count && isTableRow(lines[i]) {
                    tableLines.append(lines[i])
                    i += 1
                }
                if tableLines.count >= 2 {
                    // Parse table
                    let parsedTable = parseTable(tableLines)
                    if !parsedTable.headers.isEmpty {
                        views.append(AnyView(
                            TableBlockView(headers: parsedTable.headers, rows: parsedTable.rows, alignments: parsedTable.alignments)
                        ))
                        continue
                    }
                }
                // If not a valid table, treat as regular text
                for tableLine in tableLines {
                    views.append(AnyView(
                        InlineMarkdownText(text: tableLine)
                    ))
                }
                continue
            }

            // ASCII art detection (box-drawing characters)
            if containsBoxDrawingCharacters(line) {
                var asciiArtLines: [String] = []
                while i < lines.count {
                    let currentLine = lines[i]
                    // Stop at empty line or markdown elements
                    if currentLine.trimmingCharacters(in: .whitespaces).isEmpty ||
                       currentLine.hasPrefix("#") ||
                       currentLine.hasPrefix("```") ||
                       currentLine.hasPrefix("> ") {
                        break
                    }
                    // Continue if current line has box-drawing chars or is part of the block
                    if containsBoxDrawingCharacters(currentLine) ||
                       (!currentLine.hasPrefix("- ") && !currentLine.hasPrefix("* ") && parseNumberedListPrefix(currentLine) == nil) {
                        asciiArtLines.append(currentLine)
                        i += 1
                    } else {
                        break
                    }
                }
                if !asciiArtLines.isEmpty {
                    views.append(AnyView(
                        AsciiArtBlockView(content: asciiArtLines.joined(separator: "\n"))
                    ))
                }
                continue
            }

            // Normal paragraph - join related lines
            var paragraphLines: [String] = []
            while i < lines.count {
                let currentLine = lines[i]
                // If empty line or special element follows, stop
                if currentLine.trimmingCharacters(in: .whitespaces).isEmpty ||
                   currentLine.hasPrefix("#") ||
                   currentLine.hasPrefix("```") ||
                   currentLine.hasPrefix("> ") ||
                   currentLine.hasPrefix("- ") ||
                   currentLine.hasPrefix("* ") ||
                   currentLine == "---" ||
                   currentLine == "***" ||
                   currentLine == "___" ||
                   parseNumberedListPrefix(currentLine) != nil {
                    break
                }
                paragraphLines.append(currentLine)
                i += 1
            }
            if !paragraphLines.isEmpty {
                let content = paragraphLines.joined(separator: " ")
                views.append(AnyView(
                    InlineMarkdownText(text: content)
                ))
            }
        }

        return views
    }

    private func codeBlockView(_ code: String) -> some View {
        CodeBlockView(code: code)
    }

    // Check if line is a table row (contains | and is not in code block)
    private func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Must contain at least one |
        guard trimmed.contains("|") else { return false }
        // Should not be a code block
        guard !trimmed.hasPrefix("```") else { return false }
        return true
    }

    // Check if line is a table separator (|---|---|)
    private func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Remove all valid separator characters
        let cleaned = trimmed.replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
        return cleaned.isEmpty && trimmed.contains("-")
    }

    // Parse table alignment from separator row
    private func parseAlignment(_ cell: String) -> Alignment {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        let hasLeft = trimmed.hasPrefix(":")
        let hasRight = trimmed.hasSuffix(":")
        if hasLeft && hasRight { return .center }
        if hasRight { return .trailing }
        return .leading
    }

    // Parse table cells from a row
    private func parseTableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        // Remove leading and trailing |
        if trimmed.hasPrefix("|") {
            trimmed = String(trimmed.dropFirst())
        }
        if trimmed.hasSuffix("|") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // Parse complete table
    private func parseTable(_ lines: [String]) -> (headers: [String], rows: [[String]], alignments: [Alignment]) {
        guard lines.count >= 2 else { return ([], [], []) }

        // Find separator row
        var separatorIndex = -1
        for (index, line) in lines.enumerated() {
            if isTableSeparator(line) {
                separatorIndex = index
                break
            }
        }

        // If no separator found, treat as simple table without header
        if separatorIndex == -1 {
            let allRows = lines.map { parseTableCells($0) }
            let maxCols = allRows.map { $0.count }.max() ?? 0
            let alignments = Array(repeating: Alignment.leading, count: maxCols)
            return ([], allRows, alignments)
        }

        // Parse header (row before separator)
        var headers: [String] = []
        if separatorIndex > 0 {
            headers = parseTableCells(lines[separatorIndex - 1])
        }

        // Parse alignments from separator
        let separatorCells = parseTableCells(lines[separatorIndex])
        let alignments = separatorCells.map { parseAlignment($0) }

        // Parse data rows (after separator)
        var rows: [[String]] = []
        for i in (separatorIndex + 1)..<lines.count {
            let cells = parseTableCells(lines[i])
            rows.append(cells)
        }

        return (headers, rows, alignments)
    }

    // Check if line contains box-drawing characters (Unicode box drawing block)
    private func containsBoxDrawingCharacters(_ text: String) -> Bool {
        // Box Drawing characters: U+2500 to U+257F
        // Block Elements: U+2580 to U+259F
        // Geometric Shapes: U+25A0 to U+25FF (includes ▼ ▲ etc.)
        // Arrows: U+2190 to U+21FF
        for char in text.unicodeScalars {
            let value = char.value
            if (value >= 0x2500 && value <= 0x257F) ||  // Box Drawing
               (value >= 0x2580 && value <= 0x259F) ||  // Block Elements
               (value >= 0x25A0 && value <= 0x25FF) ||  // Geometric Shapes
               (value >= 0x2190 && value <= 0x21FF) {   // Arrows
                return true
            }
        }
        return false
    }
}

// MARK: - Code Block with Copy Button

struct CodeBlockView: View {
    let code: String
    var isTerminal: Bool = false
    @State private var copied = false

    var body: some View {
        // Replace spaces with non-breaking spaces to preserve alignment
        let preservedCode = code.replacingOccurrences(of: " ", with: "\u{00A0}")
        ZStack(alignment: .topTrailing) {
            Text(preservedCode)
                .font(Font.custom("Monaco", size: 16))
                .foregroundColor(isTerminal ? Color(red: 0.1, green: 0.5, blue: 0.2) : .primary)
                .padding(12)
                .padding(.trailing, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isTerminal
                        ? Color(NSColor.systemGray).opacity(0.25)
                        : Color(NSColor.systemGray).opacity(0.15)
                )
                .cornerRadius(6)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "square.on.square")
                    .foregroundColor(copied ? .green : (isTerminal ? .gray : .secondary))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
    }
}

// MARK: - ASCII Art Block (for box-drawing characters)

struct AsciiArtBlockView: View {
    let content: String

    var body: some View {
        // Replace regular spaces with non-breaking spaces to preserve alignment
        let preservedContent = content.replacingOccurrences(of: " ", with: "\u{00A0}")
        Text(preservedContent)
            .font(Font.custom("Monaco", size: 16))
            .foregroundColor(.primary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.systemGray).opacity(0.1))
            .cornerRadius(6)
    }
}

// MARK: - Table Block View

struct TableBlockView: View {
    let headers: [String]
    let rows: [[String]]
    let alignments: [Alignment]

    var body: some View {
        let columnCount = max(headers.count, rows.first?.count ?? 0, alignments.count)

        VStack(alignment: .leading, spacing: 0) {
            // Header row
            if !headers.isEmpty {
                HStack(spacing: 0) {
                    ForEach(0..<columnCount, id: \.self) { colIndex in
                        let text = colIndex < headers.count ? headers[colIndex] : ""
                        let alignment = colIndex < alignments.count ? alignments[colIndex] : .leading
                        Text(text)
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: alignment)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.systemGray).opacity(0.2))
                    }
                }
                .overlay(
                    Rectangle()
                        .stroke(Color(NSColor.systemGray).opacity(0.3), lineWidth: 1)
                )
            }

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(0..<columnCount, id: \.self) { colIndex in
                        let text = colIndex < row.count ? row[colIndex] : ""
                        let alignment = colIndex < alignments.count ? alignments[colIndex] : .leading
                        InlineMarkdownText(text: text)
                            .frame(maxWidth: .infinity, alignment: alignment)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(rowIndex % 2 == 0 ? Color.clear : Color(NSColor.systemGray).opacity(0.05))
                    }
                }
                .overlay(
                    Rectangle()
                        .stroke(Color(NSColor.systemGray).opacity(0.2), lineWidth: 0.5)
                )
            }
        }
        .background(Color(NSColor.systemGray).opacity(0.05))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.systemGray).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Inline Markdown Text with styled code spans

struct InlineMarkdownText: View {
    let text: String
    var fontSize: CGFloat = 14
    var fontWeight: Font.Weight = .regular

    var body: some View {
        createTextView()
    }

    private func createTextView() -> Text {
        let segments = parseSegments(text)
        var result = Text("")

        for segment in segments {
            switch segment {
            case .plain(let str):
                result = result + Text(parseBasicMarkdown(str))
                    .font(.system(size: fontSize, weight: fontWeight))
            case .code(let str):
                var attrStr = AttributedString(" \(str) ")
                attrStr.font = .system(size: fontSize - 1, weight: .medium, design: .monospaced)
                attrStr.backgroundColor = Color(NSColor.systemGray).opacity(0.25)
                result = result + Text(attrStr)
            }
        }

        return result
    }

    private enum Segment {
        case plain(String)
        case code(String)
    }

    private func parseSegments(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var remaining = text

        while let backtickRange = remaining.range(of: "`") {
            let before = String(remaining[..<backtickRange.lowerBound])
            if !before.isEmpty {
                segments.append(.plain(before))
            }

            let afterBacktick = String(remaining[backtickRange.upperBound...])
            if let closingRange = afterBacktick.range(of: "`") {
                let codeContent = String(afterBacktick[..<closingRange.lowerBound])
                segments.append(.code(codeContent))
                remaining = String(afterBacktick[closingRange.upperBound...])
            } else {
                segments.append(.plain("`" + afterBacktick))
                break
            }
        }

        if !remaining.isEmpty {
            segments.append(.plain(remaining))
        }

        return segments
    }

    private func parseBasicMarkdown(_ text: String) -> AttributedString {
        do {
            return try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            ))
        } catch {
            return AttributedString(text)
        }
    }
}

#Preview {
    ScrollView {
        MarkdownView(text: """
        # Markdown Viewer

        A simple and elegant **Markdown viewer** for macOS. Open any `.md` file and see it rendered beautifully.

        ## Features

        - Live preview of Markdown files
        - Support for `inline code` and code blocks
        - Syntax highlighting for terminal commands

        > Tip: Use the editor toggle button in the toolbar to edit your documents.

        ### Code Blocks

        Regular code block:

        ```
        let greeting = "Hello, World!"
        print(greeting)
        ```

        Terminal/bash commands appear in green:

        ```bash
        echo "Hello from the terminal"
        ```

        ---

        Made with SwiftUI for macOS.
        """)
        .padding()
    }
    .frame(width: 600, height: 700)
}
