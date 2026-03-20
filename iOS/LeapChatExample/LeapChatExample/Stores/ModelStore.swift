import LeapSDK
import SwiftUI

@Observable
class ModelStore {
  var activeModelRunner: ModelRunner?
  var activeModel: ModelDefinition?
  var activeQuantization: QuantizationOption?
  var isLoading = false
  var loadingMessage = ""
  var downloadStatuses: [String: DownloadStatus] = [:]

  func downloadKey(model: ModelDefinition, quantization: QuantizationOption) -> String {
    "\(model.id)_\(quantization.name)"
  }

  func status(for model: ModelDefinition, quantization: QuantizationOption) -> DownloadStatus {
    downloadStatuses[downloadKey(model: model, quantization: quantization)] ?? .notDownloaded
  }

  func isModelDownloaded(_ model: ModelDefinition) -> Bool {
    model.quantizations.contains { quantization in
      status(for: model, quantization: quantization) == .downloaded
    }
  }

  @MainActor
  func downloadAndLoad(model: ModelDefinition, quantization: QuantizationOption) async {
    let key = downloadKey(model: model, quantization: quantization)
    isLoading = true
    loadingMessage = "Downloading \(model.name) (\(quantization.name))..."
    downloadStatuses[key] = .downloading(progress: 0)

    do {
      let runner = try await Leap.load(
        model: model.id,
        quantization: quantization.name,
        options: LiquidInferenceEngineManifestOptions(
          contextSize: 4096
        )
      ) { [weak self] progress, _ in
        Task { @MainActor in
          self?.downloadStatuses[key] = progress < 1.0
            ? .downloading(progress: Double(progress))
            : .downloading(progress: 1.0)
          self?.loadingMessage =
            progress < 1.0
            ? "Downloading: \(Int(progress * 100))%"
            : "Loading model into memory..."
        }
      }

      activeModelRunner = runner
      activeModel = model
      activeQuantization = quantization
      downloadStatuses[key] = .downloaded
      loadingMessage = ""
    } catch {
      downloadStatuses[key] = .failed(message: error.localizedDescription)
      loadingMessage = "Failed: \(error.localizedDescription)"
    }

    isLoading = false
  }
}
