import UIKit
import Vision

/// OCR using Apple's built-in Vision framework. No model download needed.
@Observable
class AppleVisionOCRService {
    var isLoaded = true  // Always available — no download required

    /// Recognize text from an image using VNRecognizeTextRequest
    func generate(image: UIImage) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task.detached(priority: .userInitiated) {
                let result = await self.recognizeText(from: image)
                continuation.yield(result)
                continuation.finish()
            }
        }
    }

    /// Public direct access for fallback usage from other OCR services
    func recognizeTextDirect(from image: UIImage) async -> String {
        return await recognizeText(from: image)
    }

    private func recognizeText(from image: UIImage) async -> String {
        // Convert UIImage to CGImage properly
        guard let cgImage = image.cgImage ?? self.createCGImage(from: image) else {
            print("[AppleVisionOCR] ERROR: Could not get CGImage")
            return "[Error: Could not process image]"
        }

        let imageWidth = cgImage.width
        let imageHeight = cgImage.height
        print("[AppleVisionOCR] Processing image: \(imageWidth)x\(imageHeight)")

        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("[AppleVisionOCR] Error: \(error)")
                    cont.resume(returning: "[Error: \(error.localizedDescription)]")
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    print("[AppleVisionOCR] No results")
                    cont.resume(returning: "[No text detected]")
                    return
                }

                print("[AppleVisionOCR] Found \(observations.count) text observations")

                // Sort by vertical position (top to bottom, Vision uses bottom-left origin)
                let sorted = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }

                var lines: [String] = []
                for observation in sorted {
                    if let candidate = observation.topCandidates(1).first {
                        // Only include results with reasonable confidence
                        if candidate.confidence > 0.3 {
                            lines.append(candidate.string)
                        } else {
                            print("[AppleVisionOCR] Low confidence (\(candidate.confidence)): \(candidate.string)")
                        }
                    }
                }

                if lines.isEmpty {
                    cont.resume(returning: "[No text detected in image]")
                } else {
                    let text = lines.joined(separator: "\n")
                    print("[AppleVisionOCR] Recognized \(lines.count) lines")
                    cont.resume(returning: text)
                }
            }

            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Use automatic language detection instead of specifying many languages
            // Specifying too many conflicting scripts causes garbled output
            if #available(iOS 16.0, *) {
                request.automaticallyDetectsLanguage = true
            } else {
                // Fallback: just English + Chinese
                request.recognitionLanguages = ["en-US", "zh-Hant", "zh-Hans"]
            }

            // Set revision for best results
            request.revision = VNRecognizeTextRequestRevision3

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: .up,
                options: [:]
            )
            do {
                try handler.perform([request])
            } catch {
                print("[AppleVisionOCR] Perform error: \(error)")
                cont.resume(returning: "[Error: \(error.localizedDescription)]")
            }
        }
    }

    /// Fallback CGImage creation when .cgImage is nil (e.g. for CIImage-backed UIImages)
    private func createCGImage(from image: UIImage) -> CGImage? {
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)  // opaque=true, scale=1.0
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    }
}
