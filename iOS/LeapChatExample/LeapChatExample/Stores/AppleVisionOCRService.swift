import UIKit
import Vision

/// OCR using Apple's built-in Vision framework. No model download needed.
@Observable
class AppleVisionOCRService {
    var isLoaded = true  // Always available — no download required

    /// Recognize text from an image using VNRecognizeTextRequest
    func generate(image: UIImage) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                let result = await recognizeText(from: image)
                continuation.yield(result)
                continuation.finish()
            }
        }
    }

    private func recognizeText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else {
            return "[Error: Could not process image]"
        }

        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    cont.resume(returning: "[Error: \(error.localizedDescription)]")
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    cont.resume(returning: "[No text detected]")
                    return
                }

                // Sort by vertical position (top to bottom)
                let sorted = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }

                var lines: [String] = []
                for observation in sorted {
                    if let candidate = observation.topCandidates(1).first {
                        lines.append(candidate.string)
                    }
                }

                if lines.isEmpty {
                    cont.resume(returning: "[No text detected in image]")
                } else {
                    let text = lines.joined(separator: "\n")
                    cont.resume(returning: text)
                }
            }

            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Support multiple languages including Chinese
            request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "fr-FR", "de-DE", "es-ES"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(returning: "[Error: \(error.localizedDescription)]")
            }
        }
    }
}
