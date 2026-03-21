import Foundation
import Hub
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM
import SwiftUI

@Observable
class MLXModelService {
    var isLoaded = false
    @ObservationIgnored private var modelContainer: ModelContainer?
    @ObservationIgnored private var modelCache = NSCache<NSString, ModelContainer>()

    @MainActor
    private(set) var downloadProgress: Progress?

    /// The base directory where HuggingFace models are stored
    private static var hubDownloadBase: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("huggingface")
    }

    func load(
        huggingFaceRepo: String,
        onProgress: @escaping (Double) -> Void = { _ in }
    ) async throws {
        // Check cache first
        if let cached = modelCache.object(forKey: huggingFaceRepo as NSString) {
            modelContainer = cached
            isLoaded = true
            onProgress(1.0)
            return
        }

        // Pre-create the directory structure the Hub library expects
        let modelDir = Self.hubDownloadBase
            .appendingPathComponent("models")
            .appendingPathComponent(huggingFaceRepo)
        let cacheDir = modelDir
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("download")

        try FileManager.default.createDirectory(
            at: cacheDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: modelDir, withIntermediateDirectories: true)

        // Set GPU memory limit to prevent OOM kills
        MLX.Memory.cacheLimit = 20 * 1024 * 1024

        let configuration = ModelConfiguration(id: huggingFaceRepo)
        let hub = HubApi(downloadBase: Self.hubDownloadBase)
        let factory: ModelFactory = VLMModelFactory.shared

        let container = try await factory.loadContainer(
            hub: hub, configuration: configuration
        ) { progress in
            Task { @MainActor in
                self.downloadProgress = progress
                onProgress(progress.fractionCompleted)
            }
        }

        modelCache.setObject(container, forKey: huggingFaceRepo as NSString)
        modelContainer = container
        isLoaded = true
    }

    func generate(
        userText: String,
        systemPrompt: String?,
        imageURLs: [URL] = []
    ) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                guard let container = modelContainer else {
                    continuation.yield("Error: Model not loaded")
                    continuation.finish()
                    return
                }

                var chatMessages: [Chat.Message] = []

                if let systemPrompt, !systemPrompt.isEmpty {
                    chatMessages.append(
                        Chat.Message(role: .system, content: systemPrompt))
                }

                let images: [UserInput.Image] = imageURLs.map { .url($0) }
                chatMessages.append(
                    Chat.Message(
                        role: .user, content: userText,
                        images: images, videos: []))

                let userInput = UserInput(
                    chat: chatMessages,
                    processing: .init(
                        resize: .init(width: 1024, height: 1024)))

                do {
                    let stream = try await container.perform {
                        (context: ModelContext) in
                        let lmInput = try await context.processor.prepare(
                            input: userInput)
                        let parameters = GenerateParameters(temperature: 0.7)
                        return try MLXLMCommon.generate(
                            input: lmInput, parameters: parameters,
                            context: context)
                    }

                    for await generation in stream {
                        switch generation {
                        case .chunk(let chunk):
                            continuation.yield(chunk)
                        case .info:
                            break
                        default:
                            break
                        }
                    }
                } catch {
                    continuation.yield("Error: \(error.localizedDescription)")
                }

                continuation.finish()
            }
        }
    }

    func unload() {
        modelContainer = nil
        isLoaded = false
    }
}
