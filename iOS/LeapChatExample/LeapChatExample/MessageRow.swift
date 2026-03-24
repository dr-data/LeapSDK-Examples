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

    /// Render text with [Ref X] citations styled as colored badges
    @ViewBuilder
    private func styledContent(_ text: String) -> some View {
        let parts = parseReferences(text)
        if parts.count <= 1 {
            // No references, plain text
            Text(text)
                .foregroundColor(.primary)
        } else {
            parts.reduce(Text("")) { result, part in
                if part.isRef {
                    return result + Text(part.text)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)
                } else {
                    return result + Text(part.text)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    private struct TextPart {
        let text: String
        let isRef: Bool
    }

    private func parseReferences(_ text: String) -> [TextPart] {
        var parts: [TextPart] = []
        let pattern = #"\[Ref\s*\d+\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [TextPart(text: text, isRef: false)]
        }

        let nsText = text as NSString
        var lastEnd = 0

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            if match.range.location > lastEnd {
                let before = nsText.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                parts.append(TextPart(text: before, isRef: false))
            }
            let ref = nsText.substring(with: match.range)
            parts.append(TextPart(text: ref, isRef: true))
            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd)
            parts.append(TextPart(text: remaining, isRef: false))
        }

        return parts
    }
}
