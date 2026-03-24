import SwiftUI

struct MessageRow: View {
    let message: MessageBubble
    var onCopy: ((String) -> Void)?
    var onEdit: ((String) -> Void)?

    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
    private let dividerColor = Color(red: 0.059, green: 0.090, blue: 0.165)

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)

                VStack(alignment: .trailing, spacing: 8) {
                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !message.content.isEmpty {
                        Text(message.content)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .textSelection(.enabled)
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = message.content
                                    onCopy?(message.content)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                Button {
                                    onEdit?(message.content)
                                } label: {
                                    Label("Edit & Resend", systemImage: "pencil")
                                }
                            }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let thinkingTime = message.thinkingTime, thinkingTime > 0 {
                        HStack(spacing: 4) {
                            Text("Thought for \(thinkingTime) seconds")
                                .font(.system(size: 13))
                                .foregroundColor(secondaryText)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(secondaryText)
                        }
                        .padding(.bottom, 2)
                    }

                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !message.content.isEmpty {
                        styledContent(message.content)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .textSelection(.enabled)
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = message.content
                                    onCopy?(message.content)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                Button {
                                    onEdit?(message.content)
                                } label: {
                                    Label("Use as Input", systemImage: "arrow.uturn.up")
                                }
                            }
                    }
                }

                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
    }

    /// Render rich content: code blocks, math, references
    @ViewBuilder
    private func styledContent(_ text: String) -> some View {
        let segments = parseRichContent(text)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let str):
                    styledTextWithRefs(str)
                case .codeBlock(let language, let code):
                    codeBlockView(language: language, code: code)
                case .inlineMath(let math):
                    Text(latexToUnicode(math))
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(.orange)
                case .blockMath(let math):
                    Text(latexToUnicode(math))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    /// Code block with dark background and copy button
    private func codeBlockView(language: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(language.isEmpty ? "code" : language)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.15))

            // Code content with basic syntax highlighting
            Text(attributedCode(code, language: language))
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Basic syntax highlighting
    private func attributedCode(_ code: String, language: String) -> AttributedString {
        var result = AttributedString(code)
        result.foregroundColor = .white

        let keywords: Set<String>
        switch language.lowercased() {
        case "swift": keywords = ["func", "var", "let", "if", "else", "for", "while", "return", "import", "struct", "class", "enum", "guard", "switch", "case", "try", "catch", "throw", "async", "await", "self", "true", "false", "nil", "private", "public"]
        case "python", "py": keywords = ["def", "class", "if", "else", "elif", "for", "while", "return", "import", "from", "try", "except", "with", "as", "True", "False", "None", "self", "print", "lambda", "yield", "async", "await"]
        case "javascript", "js", "typescript", "ts": keywords = ["function", "const", "let", "var", "if", "else", "for", "while", "return", "import", "export", "class", "try", "catch", "throw", "async", "await", "true", "false", "null", "undefined", "this", "new"]
        default: keywords = ["if", "else", "for", "while", "return", "true", "false", "null", "class", "function", "def", "import"]
        }

        // Highlight keywords
        for keyword in keywords {
            var searchRange = result.startIndex..<result.endIndex
            while let range = result[searchRange].range(of: keyword) {
                result[range].foregroundColor = .cyan
                if range.upperBound < result.endIndex {
                    searchRange = range.upperBound..<result.endIndex
                } else {
                    break
                }
            }
        }

        return result
    }

    /// Styled text with [Ref X] and inline math
    @ViewBuilder
    private func styledTextWithRefs(_ text: String) -> some View {
        let parts = parseInlineElements(text)
        parts.reduce(Text("")) { result, part in
            switch part {
            case .plain(let str):
                return result + Text(str).foregroundColor(.primary)
            case .ref(let str):
                return result + Text(str).font(.system(size: 12, weight: .bold)).foregroundColor(.cyan)
            case .math(let str):
                return result + Text(latexToUnicode(str)).font(.system(size: 14, design: .monospaced)).foregroundColor(.orange)
            case .inlineCode(let str):
                return result + Text(str).font(.system(size: 13, design: .monospaced)).foregroundColor(.green)
            }
        }
    }

    // MARK: - Parsing

    enum RichSegment {
        case text(String)
        case codeBlock(language: String, code: String)
        case inlineMath(String)
        case blockMath(String)
    }

    enum InlineElement {
        case plain(String)
        case ref(String)
        case math(String)
        case inlineCode(String)
    }

    private func parseRichContent(_ text: String) -> [RichSegment] {
        var segments: [RichSegment] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var currentText = ""

        while i < lines.count {
            let line = lines[i]

            // Check for code block start
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if !currentText.isEmpty {
                    segments.append(.text(currentText))
                    currentText = ""
                }
                let lang = line.trimmingCharacters(in: .whitespaces).dropFirst(3).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                segments.append(.codeBlock(language: lang, code: codeLines.joined(separator: "\n")))
                i += 1
                continue
            }

            // Check for block math $$...$$
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("$$") {
                if !currentText.isEmpty {
                    segments.append(.text(currentText))
                    currentText = ""
                }
                var mathContent = line.replacingOccurrences(of: "$$", with: "")
                if !mathContent.contains("$$") {
                    i += 1
                    while i < lines.count && !lines[i].contains("$$") {
                        mathContent += "\n" + lines[i]
                        i += 1
                    }
                }
                segments.append(.blockMath(mathContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                i += 1
                continue
            }

            currentText += (currentText.isEmpty ? "" : "\n") + line
            i += 1
        }

        if !currentText.isEmpty {
            segments.append(.text(currentText))
        }

        return segments
    }

    private func parseInlineElements(_ text: String) -> [InlineElement] {
        var elements: [InlineElement] = []
        let pattern = #"(\[Ref\s*\d+\])|(\$[^$]+\$)|(`[^`]+`)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.plain(text)]
        }

        let nsText = text as NSString
        var lastEnd = 0

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            if match.range.location > lastEnd {
                let before = nsText.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                elements.append(.plain(before))
            }
            let matched = nsText.substring(with: match.range)
            if matched.hasPrefix("[Ref") {
                elements.append(.ref(matched))
            } else if matched.hasPrefix("$") {
                let math = String(matched.dropFirst().dropLast())
                elements.append(.math(math))
            } else if matched.hasPrefix("`") {
                let code = String(matched.dropFirst().dropLast())
                elements.append(.inlineCode(code))
            }
            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsText.length {
            elements.append(.plain(nsText.substring(from: lastEnd)))
        }

        return elements
    }

    // MARK: - LaTeX to Unicode

    private func latexToUnicode(_ latex: String) -> String {
        var result = latex
        let replacements: [(String, String)] = [
            ("\\sqrt", "√"), ("\\pm", "±"), ("\\times", "×"), ("\\div", "÷"),
            ("\\neq", "≠"), ("\\leq", "≤"), ("\\geq", "≥"), ("\\approx", "≈"),
            ("\\infty", "∞"), ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"),
            ("\\delta", "δ"), ("\\theta", "θ"), ("\\lambda", "λ"), ("\\mu", "μ"),
            ("\\pi", "π"), ("\\sigma", "σ"), ("\\phi", "φ"), ("\\omega", "ω"),
            ("\\sum", "∑"), ("\\prod", "∏"), ("\\int", "∫"),
            ("\\partial", "∂"), ("\\nabla", "∇"), ("\\forall", "∀"), ("\\exists", "∃"),
            ("\\in", "∈"), ("\\notin", "∉"), ("\\subset", "⊂"), ("\\supset", "⊃"),
            ("\\cup", "∪"), ("\\cap", "∩"), ("\\emptyset", "∅"),
            ("\\Rightarrow", "⇒"), ("\\Leftarrow", "⇐"), ("\\rightarrow", "→"), ("\\leftarrow", "←"),
            ("\\cdot", "·"), ("\\ldots", "…"),
            ("^{2}", "²"), ("^{3}", "³"), ("^2", "²"), ("^3", "³"),
            ("_{0}", "₀"), ("_{1}", "₁"), ("_{2}", "₂"), ("_{n}", "ₙ"),
            ("\\left(", "("), ("\\right)", ")"),
            ("\\left[", "["), ("\\right]", "]"),
            ("\\{", "{"), ("\\}", "}"),
        ]
        for (from, to) in replacements {
            result = result.replacingOccurrences(of: from, with: to)
        }
        // Handle \frac{a}{b} → a/b
        while let range = result.range(of: #"\\frac\{([^}]*)\}\{([^}]*)\}"#, options: .regularExpression) {
            let matched = String(result[range])
            if let fracRegex = try? NSRegularExpression(pattern: #"\\frac\{([^}]*)\}\{([^}]*)\}"#),
               let m = fracRegex.firstMatch(in: matched, range: NSRange(matched.startIndex..., in: matched)) {
                let num = (matched as NSString).substring(with: m.range(at: 1))
                let den = (matched as NSString).substring(with: m.range(at: 2))
                result = result.replacingCharacters(in: range, with: "(\(num)/\(den))")
            } else {
                break
            }
        }
        return result
    }
}
