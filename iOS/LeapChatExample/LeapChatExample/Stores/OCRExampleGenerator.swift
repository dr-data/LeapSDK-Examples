import UIKit

/// Generates sample images for OCR testing — no bundled files needed.
enum OCRExampleGenerator {

    struct OCRExample: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let generator: () -> UIImage
    }

    static let examples: [OCRExample] = [
        OCRExample(label: "中文文字", icon: "character.book.closed", generator: chineseTextExample),
        OCRExample(label: "English Text", icon: "textformat.abc", generator: englishTextExample),
        OCRExample(label: "Table", icon: "tablecells", generator: tableExample),
        OCRExample(label: "Math Formula", icon: "x.squareroot", generator: mathFormulaExample),
        OCRExample(label: "Chemistry", icon: "atom", generator: chemistryExample),
        OCRExample(label: "手寫中文", icon: "pencil.line", generator: { cachedOrFallback(.chineseHandwriting) }),
        OCRExample(label: "Handwriting", icon: "pencil", generator: { cachedOrFallback(.englishHandwriting) }),
        OCRExample(label: "Layout", icon: "rectangle.split.2x2", generator: layoutExample),
    ]

    // MARK: - Real Handwriting Images

    enum HandwritingType {
        case chineseHandwriting
        case englishHandwriting

        var url: URL {
            switch self {
            case .chineseHandwriting:
                // Public Chinese calligraphy/handwriting sample from Wikimedia Commons
                return URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a8/Lantingxu.jpg/440px-Lantingxu.jpg")!
            case .englishHandwriting:
                // Public English handwriting sample from Wikimedia Commons
                return URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0a/Handwriting_of_Swami_Vivekananda.jpg/440px-Handwriting_of_Swami_Vivekananda.jpg")!
            }
        }

        var cacheKey: String {
            switch self {
            case .chineseHandwriting: return "ocr_hw_chinese.jpg"
            case .englishHandwriting: return "ocr_hw_english.jpg"
            }
        }
    }

    private static var imageCache: [String: UIImage] = [:]

    /// Return cached image or generate fallback
    static func cachedOrFallback(_ type: HandwritingType) -> UIImage {
        // Check memory cache
        if let cached = imageCache[type.cacheKey] {
            return cached
        }

        // Check disk cache
        let cacheDir = FileManager.default.temporaryDirectory
        let cachePath = cacheDir.appendingPathComponent(type.cacheKey)
        if let data = try? Data(contentsOf: cachePath), let image = UIImage(data: data) {
            imageCache[type.cacheKey] = image
            return image
        }

        // Trigger async download for next time
        Task {
            await downloadHandwritingImage(type)
        }

        // Return generated fallback for now
        switch type {
        case .chineseHandwriting: return handwritingChineseExample()
        case .englishHandwriting: return handwritingEnglishExample()
        }
    }

    /// Download and cache a real handwriting image
    static func downloadHandwritingImage(_ type: HandwritingType) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: type.url)
            if let image = UIImage(data: data) {
                let cachePath = FileManager.default.temporaryDirectory.appendingPathComponent(type.cacheKey)
                try? data.write(to: cachePath)
                await MainActor.run {
                    imageCache[type.cacheKey] = image
                }
                print("[OCRExamples] Downloaded real handwriting: \(type.cacheKey)")
            }
        } catch {
            print("[OCRExamples] Download failed for \(type.cacheKey): \(error)")
        }
    }

    /// Pre-download all handwriting images (call on app launch)
    static func preloadHandwritingImages() {
        Task {
            await downloadHandwritingImage(.chineseHandwriting)
            await downloadHandwritingImage(.englishHandwriting)
        }
    }

    // MARK: - Generators

    static func chineseTextExample() -> UIImage {
        let text = """
        第一章　緒論

        本研究旨在探討人工智能技術在教育領域的應用，
        特別是針對中學生的學習需求。隨著科技的發展，
        越來越多的學校開始引入智能教學輔助系統。

        研究背景：近年來，全球教育界面臨著前所未有的
        變革。傳統的教學模式已無法完全滿足現代學生的
        多元化學習需求。人工智能技術的快速發展為教育
        改革提供了新的可能性。

        研究目的：
        一、分析人工智能在教育中的應用現況
        二、評估智能教學系統的教學效果
        三、提出改善建議及未來發展方向
        """
        return renderText(text, font: .systemFont(ofSize: 16), size: CGSize(width: 400, height: 500))
    }

    static func englishTextExample() -> UIImage {
        let text = """
        Chapter 1: Introduction

        Artificial intelligence has rapidly transformed the
        landscape of modern education. This paper examines
        the integration of AI-powered tools in secondary
        school classrooms across Hong Kong.

        Background:
        The education sector has witnessed significant
        technological advancement in recent years. Machine
        learning algorithms now power adaptive learning
        platforms, automated grading systems, and
        intelligent tutoring solutions.

        Key Findings:
        1. Student engagement increased by 35%
        2. Test scores improved by an average of 12%
        3. Teacher workload reduced by approximately 20%
        """
        return renderText(text, font: .systemFont(ofSize: 15), size: CGSize(width: 400, height: 450))
    }

    static func tableExample() -> UIImage {
        let size = CGSize(width: 450, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let headers = ["Subject", "Students", "Pass Rate", "Avg Score"]
            let rows = [
                ["Mathematics", "156", "92%", "78.5"],
                ["English", "156", "88%", "72.3"],
                ["Chinese", "156", "95%", "81.2"],
                ["Science", "156", "85%", "69.8"],
                ["History", "156", "91%", "75.4"],
            ]

            let colWidths: [CGFloat] = [120, 80, 90, 90]
            let rowHeight: CGFloat = 35
            let startX: CGFloat = 20
            let startY: CGFloat = 20

            UIColor.black.setStroke()
            let headerFont = UIFont.boldSystemFont(ofSize: 13)
            let cellFont = UIFont.systemFont(ofSize: 13)

            // Draw header
            var x = startX
            for (i, header) in headers.enumerated() {
                let rect = CGRect(x: x, y: startY, width: colWidths[i], height: rowHeight)
                UIColor.lightGray.setFill()
                UIBezierPath(rect: rect).fill()
                UIColor.black.setStroke()
                UIBezierPath(rect: rect).stroke()
                (header as NSString).draw(in: rect.insetBy(dx: 5, dy: 8), withAttributes: [.font: headerFont, .foregroundColor: UIColor.black])
                x += colWidths[i]
            }

            // Draw rows
            for (rowIdx, row) in rows.enumerated() {
                x = startX
                let y = startY + rowHeight * CGFloat(rowIdx + 1)
                for (i, cell) in row.enumerated() {
                    let rect = CGRect(x: x, y: y, width: colWidths[i], height: rowHeight)
                    UIColor.white.setFill()
                    UIBezierPath(rect: rect).fill()
                    UIColor.black.setStroke()
                    UIBezierPath(rect: rect).stroke()
                    (cell as NSString).draw(in: rect.insetBy(dx: 5, dy: 8), withAttributes: [.font: cellFont, .foregroundColor: UIColor.black])
                    x += colWidths[i]
                }
            }
        }
    }

    static func mathFormulaExample() -> UIImage {
        let text = """
        Mathematics Examination Paper

        Question 1: Solve the quadratic equation
           x² + 5x - 14 = 0

        Question 2: Find the derivative
           f(x) = 3x³ - 2x² + 7x - 5
           f'(x) = ?

        Question 3: Evaluate the integral
           ∫₀² (4x³ + 3x² - 2x + 1) dx

        Question 4: Simplify
           (a + b)² - (a - b)² = ?

        Question 5: Given sin(θ) = 3/5,
           find cos(θ) and tan(θ)

        Question 6: Calculate
           lim(x→0) [sin(x) / x] = ?
        """
        return renderText(text, font: .systemFont(ofSize: 15), size: CGSize(width: 400, height: 500))
    }

    static func chemistryExample() -> UIImage {
        let text = """
        Chemistry Equations

        1. Combustion of methane:
           CH₄ + 2O₂ → CO₂ + 2H₂O

        2. Photosynthesis:
           6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂

        3. Neutralization:
           HCl + NaOH → NaCl + H₂O

        4. Oxidation of iron:
           4Fe + 3O₂ → 2Fe₂O₃

        5. Electrolysis of water:
           2H₂O → 2H₂ + O₂

        Molecular Weights:
        • H₂O = 18 g/mol
        • CO₂ = 44 g/mol
        • NaCl = 58.44 g/mol
        • C₆H₁₂O₆ = 180 g/mol
        """
        return renderText(text, font: .systemFont(ofSize: 14), size: CGSize(width: 400, height: 500))
    }

    static func handwritingChineseExample() -> UIImage {
        let lines = [
            "學而時習之，不亦說乎？",
            "有朋自遠方來，不亦樂乎？",
            "人不知而不慍，不亦君子乎？",
            "",
            "三人行，必有我師焉。",
            "擇其善者而從之，",
            "其不善者而改之。",
            "",
            "知之為知之，不知為不知，",
            "是知也。",
        ]
        return renderHandwriting(lines: lines, size: CGSize(width: 420, height: 400),
                                  baseSize: 22, inkColor: UIColor(red: 0.15, green: 0.1, blue: 0.05, alpha: 0.85),
                                  isChinese: true)
    }

    static func handwritingEnglishExample() -> UIImage {
        let lines = [
            "Dear Teacher,",
            "",
            "Thank you for the wonderful",
            "lesson today. I learned a lot",
            "about the history of Hong Kong",
            "and its development over the",
            "past century.",
            "",
            "The most interesting part was",
            "learning about the cultural",
            "traditions that have been",
            "preserved through generations.",
            "",
            "Best regards,",
            "Student Name",
        ]
        return renderHandwriting(lines: lines, size: CGSize(width: 420, height: 480),
                                  baseSize: 17, inkColor: UIColor(red: 0.05, green: 0.05, blue: 0.35, alpha: 0.9),
                                  isChinese: false)
    }

    /// Render text with simulated handwriting — each character individually placed
    /// with random jitter, rotation, size variation, and baseline wobble.
    private static func renderHandwriting(
        lines: [String], size: CGSize, baseSize: CGFloat,
        inkColor: UIColor, isChinese: Bool
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Slightly off-white paper with subtle texture
            UIColor(red: 0.97, green: 0.95, blue: 0.91, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

            // Draw faint ruled lines
            UIColor(red: 0.8, green: 0.82, blue: 0.85, alpha: 0.4).setStroke()
            let lineSpacing: CGFloat = isChinese ? 38 : 28
            for i in 1...Int(size.height / lineSpacing) {
                let y = CGFloat(i) * lineSpacing + 15
                let ruleLine = UIBezierPath()
                ruleLine.move(to: CGPoint(x: 15, y: y))
                ruleLine.addLine(to: CGPoint(x: size.width - 15, y: y))
                ruleLine.lineWidth = 0.5
                ruleLine.stroke()
            }

            // Draw each character with handwriting simulation
            var cursorY: CGFloat = 25
            let leftMargin: CGFloat = 25

            for line in lines {
                if line.isEmpty {
                    cursorY += lineSpacing * 0.6
                    continue
                }

                var cursorX: CGFloat = leftMargin + CGFloat.random(in: -3...3)

                for char in line {
                    let charStr = String(char)

                    // Random variations to simulate handwriting
                    let sizeJitter = CGFloat.random(in: -2...2)
                    let font = UIFont(name: isChinese ? "PingFangSC-Regular" : "Georgia", size: baseSize + sizeJitter)
                        ?? .systemFont(ofSize: baseSize + sizeJitter)
                    let xJitter = CGFloat.random(in: -1.5...1.5)
                    let yJitter = CGFloat.random(in: -2...2)
                    let rotationAngle = CGFloat.random(in: -0.06...0.06) // ~3 degrees

                    // Varying opacity for ink pressure simulation
                    let alphaJitter = CGFloat.random(in: -0.15...0.05)
                    let charColor = inkColor.withAlphaComponent(min(1, max(0.5, inkColor.cgColor.alpha + alphaJitter)))

                    // Calculate character size
                    let attrStr = NSAttributedString(string: charStr, attributes: [.font: font])
                    let charSize = attrStr.size()

                    // Save context, apply rotation
                    ctx.cgContext.saveGState()
                    let charCenter = CGPoint(x: cursorX + charSize.width / 2, y: cursorY + charSize.height / 2)
                    ctx.cgContext.translateBy(x: charCenter.x, y: charCenter.y)
                    ctx.cgContext.rotate(by: rotationAngle)
                    ctx.cgContext.translateBy(x: -charCenter.x, y: -charCenter.y)

                    // Draw character
                    (charStr as NSString).draw(
                        at: CGPoint(x: cursorX + xJitter, y: cursorY + yJitter),
                        withAttributes: [.font: font, .foregroundColor: charColor]
                    )

                    ctx.cgContext.restoreGState()

                    // Advance cursor with slight spacing variation
                    let spacing = isChinese
                        ? charSize.width + CGFloat.random(in: -1...3)
                        : charSize.width + CGFloat.random(in: -0.5...1)
                    cursorX += spacing

                    // Wrap if near edge
                    if cursorX > size.width - 40 {
                        cursorX = leftMargin + CGFloat.random(in: -3...3)
                        cursorY += lineSpacing + CGFloat.random(in: -2...2)
                    }
                }

                cursorY += lineSpacing + CGFloat.random(in: -2...3)
            }
        }
    }

    static func layoutExample() -> UIImage {
        let size = CGSize(width: 450, height: 550)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Title
            let titleFont = UIFont.boldSystemFont(ofSize: 20)
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let captionFont = UIFont.italicSystemFont(ofSize: 10)

            ("School Newsletter — March 2026" as NSString).draw(
                at: CGPoint(x: 20, y: 15),
                withAttributes: [.font: titleFont, .foregroundColor: UIColor.black]
            )

            // Separator
            UIColor.black.setStroke()
            let line = UIBezierPath()
            line.move(to: CGPoint(x: 20, y: 45))
            line.addLine(to: CGPoint(x: 430, y: 45))
            line.lineWidth = 2
            line.stroke()

            // Left column
            let leftCol = """
            Academic Excellence

            This term, our students
            achieved outstanding results
            in the HKDSE examination.
            The overall pass rate reached
            95%, with 12 students scoring
            5** in multiple subjects.

            Principal's Message:
            "I am extremely proud of
            our students' dedication
            and hard work this year."
            """
            (leftCol as NSString).draw(
                in: CGRect(x: 20, y: 55, width: 195, height: 400),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
            )

            // Vertical separator
            let vline = UIBezierPath()
            vline.move(to: CGPoint(x: 225, y: 55))
            vline.addLine(to: CGPoint(x: 225, y: 480))
            vline.lineWidth = 0.5
            UIColor.gray.setStroke()
            vline.stroke()

            // Right column
            let rightCol = """
            Upcoming Events

            • Apr 2 — Parents' Day
            • Apr 15 — Sports Day
            • Apr 20 — Science Fair
            • May 1 — Labour Day Holiday
            • May 10 — Book Fair

            校園活動

            • 四月二日 — 家長日
            • 四月十五日 — 運動會
            • 四月二十日 — 科學展覽
            • 五月一日 — 勞動節假期
            • 五月十日 — 書展
            """
            (rightCol as NSString).draw(
                in: CGRect(x: 235, y: 55, width: 195, height: 400),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
            )

            // Footer
            ("© 2026 School Name. All rights reserved." as NSString).draw(
                at: CGPoint(x: 120, y: 520),
                withAttributes: [.font: captionFont, .foregroundColor: UIColor.gray]
            )
        }
    }

    // MARK: - Helpers

    private static func renderText(_ text: String, font: UIFont, size: CGSize, textColor: UIColor = .black) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4

            (text as NSString).draw(
                in: CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40),
                withAttributes: [
                    .font: font,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle,
                ]
            )
        }
    }
}
