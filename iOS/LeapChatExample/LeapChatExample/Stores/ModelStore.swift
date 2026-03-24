import Hub
import LeapSDK
import SwiftUI

@Observable
class ModelStore: NSObject {
    var activeModelRunner: ModelRunner?
    var activeModel: ModelDefinition?
    var activeQuantization: QuantizationOption?
    var isLoading = false
    var loadingMessage = ""
    var downloadStatuses: [String: DownloadStatus] = [:]

    // MLX backend
    let mlxService = MLXModelService()
    var isMLXActive = false

    // Direct llama.cpp backend (for models not in LeapSDK registry)
    let llamaCppService = LlamaCppService()
    var isLlamaCppActive = false

    // GLM-OCR via MLX Swift backend
    let glmocrService = GLMOCRService()
    var isGLMOCRActive = false

    // PaddleOCR backend
    let paddleOCRService = PaddleOCRService()
    var isPaddleOCRActive = false

    // Apple Vision OCR (built-in, no download)
    let appleVisionOCRService = AppleVisionOCRService()
    var isAppleVisionOCRActive = false

    @ObservationIgnored private var activeDownloads: [String: URLSessionDownloadTask] = [:]
    @ObservationIgnored private var downloadContinuations: [String: CheckedContinuation<URL, Error>] = [:]
    @ObservationIgnored private var downloadProgressHandlers: [String: (Double) -> Void] = [:]
    @ObservationIgnored private var downloadSession: URLSession!

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        scanForDownloadedModels()
    }

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

    // MARK: - Local File Management

    private static var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func localModelPath(model: ModelDefinition, quantization: QuantizationOption) -> URL {
        Self.modelsDirectory.appendingPathComponent("\(model.id)-\(quantization.name).gguf")
    }

    private func isModelFilePresent(model: ModelDefinition, quantization: QuantizationOption) -> Bool {
        FileManager.default.fileExists(atPath: localModelPath(model: model, quantization: quantization).path)
    }

    private func scanForDownloadedModels() {
        for model in ModelCatalog.allModels {
            for quant in model.quantizations {
                if isModelFilePresent(model: model, quantization: quant) {
                    downloadStatuses[downloadKey(model: model, quantization: quant)] = .downloaded
                }
            }
        }
    }

    // MARK: - Delete Model

    @MainActor
    func deleteModel(model: ModelDefinition, quantization: QuantizationOption) {
        let path = localModelPath(model: model, quantization: quantization)
        let key = downloadKey(model: model, quantization: quantization)
        try? FileManager.default.removeItem(at: path)
        downloadStatuses[key] = .notDownloaded

        // Clear active model if it's the one being deleted
        if activeModel?.id == model.id {
            activeModel = nil
            activeModelRunner = nil
            activeQuantization = nil
        }
        print("[ModelStore] Deleted \(model.id)-\(quantization.name)")
    }

    func modelFileSize(model: ModelDefinition, quantization: QuantizationOption) -> String? {
        let path = localModelPath(model: model, quantization: quantization)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              let size = attrs[.size] as? Int64 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    // MARK: - Model Flags

    /// Clear all backend flags — call at start of every load method
    private func clearAllModelFlags() {
        isMLXActive = false
        isLlamaCppActive = false
        isGLMOCRActive = false
        isPaddleOCRActive = false
        isAppleVisionOCRActive = false
    }

    // MARK: - Download & Load

    /// Context size per model — larger models and RAG/math get more context
    func contextSize(for model: ModelDefinition) -> UInt32 {
        switch model.category {
        case .rag, .extract:
            return 16384
        case .math:
            return 8192
        case .ocr:
            // GLM-OCR supports 131K but we use 32K for practical on-device use
            if model.id.contains("GLM") {
                return 32768
            }
            return 4096
        default:
            // Larger chat models get more context
            if model.id.contains("2.6B") || model.id.contains("1.2B") || model.id.contains("1.7B") {
                return 8192
            }
            return 4096
        }
    }

    @MainActor
    func downloadAndLoad(model: ModelDefinition, quantization: QuantizationOption) async {
        let key = downloadKey(model: model, quantization: quantization)

        // Apple Vision OCR — built-in, no download needed
        if model.id == "Apple-Vision-OCR" {
            clearAllModelFlags()
            isAppleVisionOCRActive = true
            activeModel = model
            activeQuantization = quantization
            activeModelRunner = nil
            downloadStatuses[key] = .downloaded
            print("[ModelStore] Apple Vision OCR activated (built-in)")
            return
        }

        // HuggingFace-only download (ONNX models, etc.)
        if model.isHuggingFaceOnly {
            await loadHuggingFaceOnly(model: model, quantization: quantization)
            return
        }

        // PaddleOCR models use a dedicated pipeline
        if model.isPaddleOCR {
            await loadPaddleOCR(model: model, quantization: quantization)
            return
        }

        // GLM-OCR models use the custom MLX-based GLMOCRPipeline
        if model.isGLMOCR {
            await loadGLMOCR(model: model, quantization: quantization)
            return
        }

        // MLX models use a separate loading path
        if model.isMLX {
            await loadMLXModel(model: model, quantization: quantization)
            return
        }

        // Direct llama.cpp models: download GGUF then load directly
        if model.useDirectLlamaCpp {
            await loadDirectLlamaCpp(model: model, quantization: quantization)
            return
        }

        // If already downloaded, try to load directly
        if isModelFilePresent(model: model, quantization: quantization) {
            await loadModel(model: model, quantization: quantization)
            return
        }

        // First try LeapSDK's built-in download+load (works on physical device)
        isLoading = true
        loadingMessage = "Downloading \(model.name) (\(quantization.name))..."
        downloadStatuses[key] = .downloading(progress: 0)

        // Try LeapSDK load with the model ID (may need lowercase for LEAP platform)
        let modelIds = [model.id, model.id.lowercased()]
        for modelId in modelIds {
            do {
                print("[ModelStore] Trying Leap.load(model: \"\(modelId)\", quantization: \"\(quantization.name)\")")
                let runner = try await Leap.load(
                    model: modelId,
                    quantization: quantization.name,
                    options: LiquidInferenceEngineManifestOptions(contextSize: contextSize(for: model))
                ) { [weak self] progress, _ in
                    Task { @MainActor in
                        self?.downloadStatuses[key] = progress < 1.0
                            ? .downloading(progress: Double(progress))
                            : .downloading(progress: 1.0)
                        self?.loadingMessage = progress < 1.0
                            ? "Downloading: \(Int(progress * 100))%"
                            : "Loading model into memory..."
                    }
                }

                clearAllModelFlags()
                activeModelRunner = runner
                activeModel = model
                activeQuantization = quantization
                downloadStatuses[key] = .downloaded
                loadingMessage = ""
                isLoading = false
                print("[ModelStore] Leap.load SUCCESS with modelId=\(modelId)")
                return
            } catch {
                print("[ModelStore] Leap.load FAILED for modelId=\(modelId): \(error)")
            }
        }

        // Fallback: Direct download from HuggingFace
        await downloadFromHuggingFace(model: model, quantization: quantization)
    }

    @MainActor
    private func downloadFromHuggingFace(model: ModelDefinition, quantization: QuantizationOption) async {
        let key = downloadKey(model: model, quantization: quantization)

        guard let downloadURL = model.downloadURL(for: quantization) else {
            downloadStatuses[key] = .failed(message: "No download URL available")
            loadingMessage = "No download URL"
            isLoading = false
            return
        }

        downloadStatuses[key] = .downloading(progress: 0)
        loadingMessage = "Downloading from HuggingFace..."

        do {
            let localURL = try await downloadFile(
                from: downloadURL,
                key: key
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadStatuses[key] = .downloading(progress: progress)
                    self?.loadingMessage = "Downloading: \(Int(progress * 100))%"
                }
            }

            // Move to models directory
            let destination = localModelPath(model: model, quantization: quantization)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: localURL, to: destination)

            downloadStatuses[key] = .downloaded
            loadingMessage = ""

            // Try to load the model (will work on device, fail on simulator)
            await loadModel(model: model, quantization: quantization)
        } catch {
            downloadStatuses[key] = .failed(message: error.localizedDescription)
            loadingMessage = "Download failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Direct llama.cpp Loading

    @MainActor
    private func loadDirectLlamaCpp(model: ModelDefinition, quantization: QuantizationOption) async {
        let key = downloadKey(model: model, quantization: quantization)
        let localPath = localModelPath(model: model, quantization: quantization)

        isLoading = true
        clearAllModelFlags()

        // Download if not already present
        if !isModelFilePresent(model: model, quantization: quantization) {
            guard let downloadURL = model.downloadURL(for: quantization) else {
                downloadStatuses[key] = .failed(message: "No download URL")
                isLoading = false
                return
            }

            downloadStatuses[key] = .downloading(progress: 0)
            loadingMessage = "Downloading \(model.name)..."

            do {
                let tempURL = try await downloadFile(from: downloadURL, key: key) { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadStatuses[key] = .downloading(progress: progress)
                        self?.loadingMessage = "Downloading: \(Int(progress * 100))%"
                    }
                }

                try? FileManager.default.removeItem(at: localPath)
                try FileManager.default.moveItem(at: tempURL, to: localPath)
            } catch {
                downloadStatuses[key] = .failed(message: error.localizedDescription)
                loadingMessage = "Download failed"
                isLoading = false
                return
            }
        }

        // Load via direct llama.cpp
        loadingMessage = "Loading \(model.name) via llama.cpp..."
        downloadStatuses[key] = .downloading(progress: 0.99)

        do {
            let service = self.llamaCppService
            let path = localPath.path
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        service.unload()
                        try service.load(ggufPath: path)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            activeModelRunner = nil
            activeModel = model
            activeQuantization = quantization
            isLlamaCppActive = true
            downloadStatuses[key] = .downloaded
            loadingMessage = ""
        } catch {
            downloadStatuses[key] = .failed(message: error.localizedDescription)
            loadingMessage = "Load failed: \(error.localizedDescription)"
            print("LlamaCpp load error: \(error)")
        }

        isLoading = false
    }

    // MARK: - HuggingFace-Only Download (ONNX models)

    @MainActor
    private func loadHuggingFaceOnly(model: ModelDefinition, quantization: QuantizationOption) async {
        let key = downloadKey(model: model, quantization: quantization)
        guard let repo = model.huggingFaceRepo else {
            downloadStatuses[key] = .failed(message: "No HuggingFace repo specified")
            return
        }

        clearAllModelFlags()
        isLoading = true
        loadingMessage = "Downloading \(model.name) from HuggingFace..."
        downloadStatuses[key] = .downloading(progress: 0)

        do {
            let hub = HubApi(downloadBase: Self.modelsDirectory)
            let hubRepo = Hub.Repo(id: repo)

            // Download all files from the repo
            let snapshotURL = try await hub.snapshot(from: hubRepo, matching: ["*"]) { progress in
                Task { @MainActor in
                    self.downloadStatuses[key] = .downloading(progress: progress.fractionCompleted)
                    self.loadingMessage = progress.fractionCompleted < 1.0
                        ? "Downloading: \(Int(progress.fractionCompleted * 100))%"
                        : "Download complete"
                }
            }

            activeModelRunner = nil
            activeModel = model
            activeQuantization = quantization
            downloadStatuses[key] = .downloaded
            loadingMessage = ""
            print("[ModelStore] HuggingFace download complete: \(snapshotURL.path)")

            // For ONNX OCR models, configure as Apple Vision OCR fallback for now
            // until custom ONNX inference is implemented
            isAppleVisionOCRActive = true
            messages(model)
        } catch {
            downloadStatuses[key] = .failed(message: error.localizedDescription)
            loadingMessage = "Download failed: \(error.localizedDescription)"
            print("[ModelStore] HuggingFace download error: \(error)")
        }

        isLoading = false
    }

    private func messages(_ model: ModelDefinition) {
        // placeholder for future ONNX inference integration
        print("[ModelStore] \(model.name) downloaded. ONNX inference integration pending.")
    }

    // MARK: - PaddleOCR Loading

    @MainActor
    private func loadPaddleOCR(model: ModelDefinition, quantization: QuantizationOption) async {
        let key = downloadKey(model: model, quantization: quantization)
        guard let repo = model.huggingFaceRepo else {
            downloadStatuses[key] = .failed(message: "No HuggingFace repo for PaddleOCR model")
            return
        }

        let backend: PaddleOCRBackend = model.paddleOCRBackend == "coreml" ? .coreml : .onnx

        clearAllModelFlags()
        isPaddleOCRActive = true
        isLoading = true
        loadingMessage = "Downloading \(model.name)..."
        downloadStatuses[key] = .downloading(progress: 0)

        do {
            print("[PaddleOCR] Starting load: repo=\(repo), backend=\(backend)")
            try await paddleOCRService.load(backend: backend, huggingFaceRepo: repo) { [weak self] fraction in
                Task { @MainActor in
                    self?.downloadStatuses[key] = .downloading(progress: fraction)
                    self?.loadingMessage = fraction < 1.0
                        ? "Downloading: \(Int(fraction * 100))%"
                        : "Loading PaddleOCR model..."
                }
            }

            activeModelRunner = nil
            activeModel = model
            activeQuantization = quantization
            downloadStatuses[key] = .downloaded
            loadingMessage = ""
            print("[PaddleOCR] Load SUCCESS")
        } catch {
            isPaddleOCRActive = false
            downloadStatuses[key] = .failed(message: error.localizedDescription)
            loadingMessage = "PaddleOCR load failed: \(error.localizedDescription)"
            print("[PaddleOCR] Load FAILED: \(error)")
            print("[PaddleOCR] Error details: \(String(describing: error))")
        }

        isLoading = false
    }

    // MARK: - GLM-OCR Loading

    @MainActor
    private func loadGLMOCR(model: ModelDefinition, quantization: QuantizationOption) async {
        let key = downloadKey(model: model, quantization: quantization)
        guard let repo = model.huggingFaceRepo else {
            downloadStatuses[key] = .failed(message: "No HuggingFace repo for GLM-OCR model")
            return
        }

        clearAllModelFlags()
        isGLMOCRActive = true
        isLoading = true
        loadingMessage = "Downloading \(model.name) via MLX..."
        downloadStatuses[key] = .downloading(progress: 0)

        do {
            try await glmocrService.load(huggingFaceRepo: repo) { [weak self] fraction in
                Task { @MainActor in
                    self?.downloadStatuses[key] = .downloading(progress: fraction)
                    self?.loadingMessage = fraction < 1.0
                        ? "Downloading: \(Int(fraction * 100))%"
                        : "Loading GLM-OCR model..."
                }
            }

            activeModelRunner = nil
            activeModel = model
            activeQuantization = quantization
            downloadStatuses[key] = .downloaded
            loadingMessage = ""
        } catch {
            isGLMOCRActive = false
            downloadStatuses[key] = .failed(message: error.localizedDescription)
            loadingMessage = "GLM-OCR load failed: \(error.localizedDescription)"
            print("GLM-OCR load error: \(error)")
        }

        isLoading = false
    }

    // MARK: - MLX Model Loading

    @MainActor
    private func loadMLXModel(model: ModelDefinition, quantization: QuantizationOption) async {
        let key = downloadKey(model: model, quantization: quantization)
        guard let repo = model.huggingFaceRepo else {
            downloadStatuses[key] = .failed(message: "No HuggingFace repo for MLX model")
            return
        }

        clearAllModelFlags()
        isMLXActive = true
        isLoading = true
        loadingMessage = "Downloading \(model.name) via MLX..."
        downloadStatuses[key] = .downloading(progress: 0)

        do {
            try await mlxService.load(huggingFaceRepo: repo) { [weak self] fraction in
                Task { @MainActor in
                    self?.downloadStatuses[key] = .downloading(progress: fraction)
                    self?.loadingMessage = fraction < 1.0
                        ? "Downloading: \(Int(fraction * 100))%"
                        : "Loading model..."
                }
            }

            activeModelRunner = nil
            activeModel = model
            activeQuantization = quantization
            downloadStatuses[key] = .downloaded
            loadingMessage = ""
        } catch {
            isMLXActive = false
            downloadStatuses[key] = .failed(message: error.localizedDescription)
            loadingMessage = "MLX load failed: \(error.localizedDescription)"
            print("MLX load error: \(error)")
        }

        isLoading = false
    }

    @MainActor
    private func loadModel(model: ModelDefinition, quantization: QuantizationOption) async {
        let key = downloadKey(model: model, quantization: quantization)
        isMLXActive = false
        isPaddleOCRActive = false
        isGLMOCRActive = false
        isLoading = true
        loadingMessage = "Loading model into memory..."

        do {
            let runner = try await Leap.load(
                model: model.id,
                quantization: quantization.name,
                options: LiquidInferenceEngineManifestOptions(contextSize: contextSize(for: model))
            ) { _, _ in }

            activeModelRunner = runner
            activeModel = model
            activeQuantization = quantization
            downloadStatuses[key] = .downloaded
            loadingMessage = ""
        } catch {
            // Model is downloaded but can't load via LeapSDK
            activeModelRunner = nil
            activeModel = model
            activeQuantization = quantization
            downloadStatuses[key] = .downloaded
            loadingMessage = "Model downloaded. LeapSDK load not available for this model."
            print("LeapSDK loadModel failed: \(error)")
        }

        isLoading = false
    }

    // MARK: - URLSession Download

    private func downloadFile(
        from url: URL,
        key: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            downloadProgressHandlers[key] = progressHandler
            let task = downloadSession.downloadTask(with: url)
            task.taskDescription = key
            downloadContinuations[key] = continuation
            activeDownloads[key] = task
            task.resume()
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelStore: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let key = downloadTask.taskDescription else { return }

        // Check for HTTP errors
        if let response = downloadTask.response as? HTTPURLResponse,
           response.statusCode >= 400 {
            let error = NSError(
                domain: "ModelDownload",
                code: response.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(response.statusCode): Download failed"]
            )
            downloadContinuations[key]?.resume(throwing: error)
            downloadContinuations.removeValue(forKey: key)
            activeDownloads.removeValue(forKey: key)
            downloadProgressHandlers.removeValue(forKey: key)
            return
        }

        // Move temp file to a safe location before the continuation resumes
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".gguf")
        do {
            try FileManager.default.moveItem(at: location, to: tempFile)
            downloadContinuations[key]?.resume(returning: tempFile)
        } catch {
            downloadContinuations[key]?.resume(throwing: error)
        }

        downloadContinuations.removeValue(forKey: key)
        activeDownloads.removeValue(forKey: key)
        downloadProgressHandlers.removeValue(forKey: key)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let key = downloadTask.taskDescription,
              totalBytesExpectedToWrite > 0 else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        downloadProgressHandlers[key]?(progress)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let key = task.taskDescription, let error = error else { return }
        downloadContinuations[key]?.resume(throwing: error)
        downloadContinuations.removeValue(forKey: key)
        activeDownloads.removeValue(forKey: key)
        downloadProgressHandlers.removeValue(forKey: key)
    }
}
