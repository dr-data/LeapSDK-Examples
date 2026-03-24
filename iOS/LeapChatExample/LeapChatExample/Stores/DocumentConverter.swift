import AEXML
import Foundation
import PDFKit
import ZIPFoundation

/// Converts PDF and DOCX files to structured Markdown for RAG model consumption.
enum DocumentConverter {

    // MARK: - PDF to Markdown

    static func pdfToMarkdown(url: URL) -> String {
        guard let document = PDFDocument(url: url) else { return "" }
        var markdown = ""
        let pageCount = min(document.pageCount, 50)

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }

            if pageCount > 1 {
                markdown += "\n---\n**Page \(i + 1)**\n\n"
            }

            // Try attributed string for structure detection
            if let attributed = page.attributedString {
                markdown += extractMarkdownFromAttributed(attributed)
            } else if let text = page.string {
                // Fallback to plain text with paragraph preservation
                markdown += formatPlainText(text)
            }
        }

        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract markdown from NSAttributedString by detecting font sizes for headings
    private static func extractMarkdownFromAttributed(_ attributed: NSAttributedString) -> String {
        var result = ""
        var defaultFontSize: CGFloat = 12

        // First pass: find the most common font size (body text)
        var fontSizes: [CGFloat: Int] = [:]
        attributed.enumerateAttribute(.font, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let font = value as? UIFont {
                fontSizes[font.pointSize, default: 0] += 1
            }
        }
        if let mostCommon = fontSizes.max(by: { $0.value < $1.value }) {
            defaultFontSize = mostCommon.key
        }

        // Second pass: build markdown
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
            let text = (attributed.string as NSString).substring(with: range)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if text.contains("\n") { result += "\n" }
                return
            }

            let font = attrs[.font] as? UIFont
            let fontSize = font?.pointSize ?? defaultFontSize
            let isBold = font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
            let isItalic = font?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Detect headings by font size relative to body
            if fontSize >= defaultFontSize * 1.8 {
                result += "\n# \(trimmed)\n\n"
            } else if fontSize >= defaultFontSize * 1.4 {
                result += "\n## \(trimmed)\n\n"
            } else if fontSize >= defaultFontSize * 1.2 || (isBold && text.hasSuffix("\n")) {
                result += "\n### \(trimmed)\n\n"
            } else {
                var formatted = trimmed
                if isBold { formatted = "**\(formatted)**" }
                if isItalic { formatted = "*\(formatted)*" }
                result += formatted
                if text.hasSuffix("\n") { result += "\n" }
                else { result += " " }
            }
        }

        return result
    }

    private static func formatPlainText(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                result += "\n"
            } else {
                result += trimmed + "\n"
            }
        }

        return result
    }

    // MARK: - DOCX to Markdown

    static func docxToMarkdown(url: URL) -> String {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("docx_\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: url, to: tempDir)

            let documentXML = tempDir
                .appendingPathComponent("word")
                .appendingPathComponent("document.xml")

            guard FileManager.default.fileExists(atPath: documentXML.path) else {
                return "[Error: Could not find document.xml in DOCX]"
            }

            let data = try Data(contentsOf: documentXML)
            let xmlDoc = try AEXMLDocument(xml: data)

            return parseDocumentXML(xmlDoc)
        } catch {
            print("[DocumentConverter] DOCX error: \(error)")
            return "[Error reading DOCX: \(error.localizedDescription)]"
        }
    }

    private static func parseDocumentXML(_ doc: AEXMLDocument) -> String {
        var markdown = ""

        guard let body = doc.root["w:body"].first else {
            return "[Error: No body element in document.xml]"
        }

        for element in body.children {
            switch element.name {
            case "w:p":
                markdown += parseParagraph(element) + "\n"
            case "w:tbl":
                markdown += parseTable(element) + "\n"
            default:
                break
            }
        }

        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseParagraph(_ para: AEXMLElement) -> String {
        var text = ""
        var headingLevel = 0
        var isList = false

        // Check paragraph style for heading level
        if let pStyle = para["w:pPr"]["w:pStyle"].first {
            let styleVal = pStyle.attributes["w:val"] ?? ""
            if styleVal.hasPrefix("Heading") || styleVal.hasPrefix("heading") {
                let num = styleVal.filter { $0.isNumber }
                headingLevel = Int(num) ?? 0
            } else if styleVal.contains("Title") || styleVal.contains("title") {
                headingLevel = 1
            } else if styleVal.contains("Subtitle") || styleVal.contains("subtitle") {
                headingLevel = 2
            }
        }

        // Check for list
        if para["w:pPr"]["w:numPr"].first != nil {
            isList = true
        }

        // Extract text runs
        for run in para.children where run.name == "w:r" {
            let runText = run["w:t"].first?.value ?? ""
            guard !runText.isEmpty else { continue }

            let isBold = run["w:rPr"]["w:b"].first != nil
            let isItalic = run["w:rPr"]["w:i"].first != nil
            let isUnderline = run["w:rPr"]["w:u"].first != nil

            var formatted = runText
            if isBold && isItalic {
                formatted = "***\(formatted)***"
            } else if isBold {
                formatted = "**\(formatted)**"
            } else if isItalic {
                formatted = "*\(formatted)*"
            } else if isUnderline {
                formatted = "_\(formatted)_"
            }

            text += formatted
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if headingLevel > 0 && headingLevel <= 6 {
            let prefix = String(repeating: "#", count: headingLevel)
            return "\n\(prefix) \(trimmed)\n"
        } else if isList {
            return "- \(trimmed)"
        } else {
            return trimmed
        }
    }

    private static func parseTable(_ table: AEXMLElement) -> String {
        var rows: [[String]] = []

        for row in table.children where row.name == "w:tr" {
            var cells: [String] = []
            for cell in row.children where cell.name == "w:tc" {
                var cellText = ""
                for para in cell.children where para.name == "w:p" {
                    let paraText = parseParagraph(para)
                    if !paraText.isEmpty {
                        cellText += paraText
                    }
                }
                cells.append(cellText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            rows.append(cells)
        }

        guard !rows.isEmpty else { return "" }

        // Build markdown table
        var md = "\n"
        let colCount = rows.map { $0.count }.max() ?? 0

        for (i, row) in rows.enumerated() {
            let paddedRow = row + Array(repeating: "", count: max(0, colCount - row.count))
            md += "| " + paddedRow.joined(separator: " | ") + " |\n"

            // Header separator after first row
            if i == 0 {
                md += "| " + Array(repeating: "---", count: colCount).joined(separator: " | ") + " |\n"
            }
        }

        return md
    }

    // MARK: - Chunking for RAG

    struct DocumentChunk: Identifiable {
        let id: Int
        let heading: String
        let content: String
        let source: String  // document name
    }

    /// Split markdown into chunks by headings or paragraph groups
    static func chunkDocument(markdown: String, source: String, maxChunkChars: Int = 500) -> [DocumentChunk] {
        var chunks: [DocumentChunk] = []
        var currentHeading = "Document"
        var currentContent = ""
        var chunkId = 1

        let lines = markdown.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect heading
            if trimmed.hasPrefix("#") {
                // Flush current chunk
                if !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    chunks.append(DocumentChunk(id: chunkId, heading: currentHeading, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines), source: source))
                    chunkId += 1
                    currentContent = ""
                }
                currentHeading = trimmed.drop(while: { $0 == "#" || $0 == " " }).description
                continue
            }

            currentContent += line + "\n"

            // Split if chunk is too large
            if currentContent.count >= maxChunkChars {
                chunks.append(DocumentChunk(id: chunkId, heading: currentHeading, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines), source: source))
                chunkId += 1
                currentContent = ""
            }
        }

        // Flush remaining
        if !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(DocumentChunk(id: chunkId, heading: currentHeading, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines), source: source))
        }

        return chunks
    }

    // MARK: - Simple Keyword Relevance

    private static let stopwords: Set<String> = [
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did", "will", "would", "could",
        "should", "may", "might", "shall", "can", "need", "dare", "ought",
        "in", "on", "at", "to", "for", "of", "with", "by", "from", "as",
        "into", "through", "during", "before", "after", "above", "below",
        "and", "but", "or", "nor", "not", "so", "yet", "both", "either",
        "neither", "each", "every", "all", "any", "few", "more", "most",
        "other", "some", "such", "no", "only", "own", "same", "than",
        "too", "very", "just", "because", "if", "when", "while", "how",
        "what", "which", "who", "whom", "this", "that", "these", "those",
        "i", "me", "my", "we", "us", "our", "you", "your", "he", "him",
        "she", "her", "it", "its", "they", "them", "their",
        "的", "了", "在", "是", "我", "有", "和", "就", "不", "人", "都",
        "一", "一個", "上", "也", "很", "到", "說", "要", "去", "你",
    ]

    /// Find top-K most relevant chunks for a query using keyword overlap
    static func findRelevantChunks(query: String, chunks: [DocumentChunk], topK: Int = 5) -> [DocumentChunk] {
        let queryTokens = tokenize(query)
        guard !queryTokens.isEmpty else { return Array(chunks.prefix(topK)) }

        let scored = chunks.map { chunk -> (chunk: DocumentChunk, score: Double) in
            let chunkTokens = tokenize(chunk.content + " " + chunk.heading)
            let overlap = queryTokens.intersection(chunkTokens)
            let score = Double(overlap.count) / Double(max(queryTokens.count, 1))
            return (chunk, score)
        }

        let sorted = scored.sorted { $0.score > $1.score }
        let result = sorted.prefix(topK).map { $0.chunk }

        // If no good matches, return first chunks
        let allZero = result.allSatisfy { chunk in
            scored.first(where: { s in s.chunk.id == chunk.id })?.score == 0
        }
        if allZero {
            return Array(chunks.prefix(topK))
        }

        return Array(result)
    }

    private static func tokenize(_ text: String) -> Set<String> {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "一-龥")).inverted)
            .filter { $0.count > 1 && !stopwords.contains($0) }
        return Set(words)
    }

    /// Format chunks as numbered references for the RAG system prompt
    static func formatChunksAsReferences(_ chunks: [DocumentChunk]) -> String {
        var result = ""
        for chunk in chunks {
            result += """
            <ref\(chunk.id) source="\(chunk.source)" section="\(chunk.heading)">
            \(chunk.content)
            </ref\(chunk.id)>

            """
        }
        return result
    }
}
