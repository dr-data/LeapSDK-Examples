import LeapSDK
import PhotosUI
import SwiftUI

@Observable
class ChatStore {
    var input: String = ""
    var messages: [MessageBubble] = []
    var isLoading = false
    var isModelLoading = false
    var currentAssistantMessage = ""
    var attachedImage: UIImage?
    var isImageLoading = false
    var hasRecordedChat = false
    var currentChatId: UUID?
    var onFirstMessage: ((UUID, String) -> Void)?
    var onMessagesChanged: ((UUID, [MessageBubble]) -> Void)?

    var conversation: Conversation?
    var modelRunner: ModelRunner?
    var mlxService: MLXModelService?
    var llamaCppService: LlamaCppService?
    var systemPromptForMLX: String?

    // Throttle streaming UI updates to avoid overwhelming SwiftUI
    @ObservationIgnored private var pendingChunks = ""
    @ObservationIgnored private var lastUIUpdate = Date.distantPast
    @ObservationIgnored private let updateInterval: TimeInterval = 1.0 / 30.0 // 30fps max

    @MainActor
    func configureWithModel(runner: ModelRunner, systemPrompt: String?) {
        modelRunner = runner
        messages.removeAll()
        hasRecordedChat = false
        currentChatId = nil

        var history: [ChatMessage] = []
        if let systemPrompt, !systemPrompt.isEmpty {
            history.append(ChatMessage(role: .system, content: [.text(systemPrompt)]))
        }

        conversation = Conversation(modelRunner: runner, history: history)
        messages.append(
            MessageBubble(content: "Model loaded. You can start chatting.", isUser: false))
    }

    @MainActor
    func configureWithoutRunner(systemPrompt: String?) {
        modelRunner = nil
        conversation = nil
        messages.removeAll()
        hasRecordedChat = false
        currentChatId = nil
        messages.append(
            MessageBubble(
                content:
                    "Model downloaded but inference requires a physical device. On a real device, the model will load and you can chat.",
                isUser: false))
    }

    @MainActor
    func configureWithMLX(service: MLXModelService, systemPrompt: String?) {
        mlxService = service
        conversation = nil
        modelRunner = nil
        systemPromptForMLX = systemPrompt
        messages.removeAll()
        hasRecordedChat = false
        currentChatId = nil
        messages.append(
            MessageBubble(content: "MLX model loaded. You can start chatting.", isUser: false))
    }

    @MainActor
    func configureWithLlamaCpp(service: LlamaCppService, systemPrompt: String?) {
        llamaCppService = service
        mlxService = nil
        conversation = nil
        modelRunner = nil
        systemPromptForMLX = systemPrompt
        messages.removeAll()
        hasRecordedChat = false
        currentChatId = nil
        messages.append(
            MessageBubble(content: "GLM-OCR model loaded. You can start chatting.", isUser: false))
    }

    @MainActor
    func send() async {
        // Route to direct llama.cpp if active
        if let llama = llamaCppService, llama.isLoaded {
            await sendWithLlamaCpp(llama)
            return
        }

        // Route to MLX if active
        if let mlx = mlxService, mlx.isLoaded {
            await sendWithMLX(mlx)
            return
        }

        // If MLX service is configured but not yet loaded, show loading message
        if mlxService != nil && conversation == nil {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty || attachedImage != nil else { return }

            var displayContent = trimmed
            if attachedImage != nil {
                displayContent = displayContent.isEmpty ? "[Image]" : "[Image] \(displayContent)"
            }
            messages.append(
                MessageBubble(content: displayContent, isUser: true, image: attachedImage))
            input = ""
            attachedImage = nil
            messages.append(
                MessageBubble(
                    content:
                        "The model is still loading. Please wait for it to finish before sending messages.",
                    isUser: false))
            return
        }

        guard conversation != nil else {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty || attachedImage != nil else { return }

            var displayContent = trimmed
            if attachedImage != nil {
                displayContent = displayContent.isEmpty ? "[Image]" : "[Image] \(displayContent)"
            }
            messages.append(
                MessageBubble(content: displayContent, isUser: true, image: attachedImage))
            input = ""
            attachedImage = nil
            messages.append(
                MessageBubble(
                    content:
                        "Cannot generate response — model inference is not available on this device. Please run on a physical device with Apple Silicon.",
                    isUser: false))
            return
        }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachedImage != nil else { return }

        var messageContent: [ChatMessageContent] = []

        if let image = attachedImage {
            do {
                let imageContent = try ChatMessageContent.fromUIImage(image)
                messageContent.append(imageContent)
            } catch {
                print("Error converting image: \(error)")
                messages.append(
                    MessageBubble(
                        content:
                            "Failed to process image: \(error.localizedDescription). Please try a different image.",
                        isUser: false))
                attachedImage = nil
                if trimmed.isEmpty {
                    return
                }
            }
        }

        if !trimmed.isEmpty {
            messageContent.append(ChatMessageContent.text(trimmed))
        }

        let userMessage = ChatMessage(role: .user, content: messageContent)

        var displayContent = trimmed
        if attachedImage != nil {
            displayContent = displayContent.isEmpty ? "[Image]" : "[Image] \(displayContent)"
        }

        messages.append(
            MessageBubble(content: displayContent, isUser: true, image: attachedImage))
        recordChatIfNeeded(displayContent: displayContent)
        input = ""
        attachedImage = nil
        isLoading = true
        currentAssistantMessage = ""
        pendingChunks = ""
        lastUIUpdate = Date()

        let stream = conversation!.generateResponse(
            message: userMessage, generationOptions: nil)
        do {
            for try await resp in stream {
                switch resp {
                case .reasoningChunk: break
                case .chunk(let str):
                    pendingChunks.append(str)
                    flushChunksIfNeeded()
                case .audioSample:
                    break
                case .complete(let completion):
                    // Flush any remaining chunks
                    if !pendingChunks.isEmpty {
                        currentAssistantMessage.append(pendingChunks)
                        pendingChunks = ""
                    }
                    let finalText = completion.message.content.compactMap {
                        content -> String? in
                        if case .text(let text) = content {
                            return text
                        }
                        return nil
                    }.joined()
                    if !finalText.isEmpty {
                        currentAssistantMessage = finalText
                    }
                    if !currentAssistantMessage.isEmpty {
                        messages.append(
                            MessageBubble(
                                content: currentAssistantMessage, isUser: false))
                    }
                    currentAssistantMessage = ""
                    isLoading = false
                    persistMessages()
                case .functionCall:
                    break
                }
            }
        } catch {
            if !pendingChunks.isEmpty {
                currentAssistantMessage.append(pendingChunks)
                pendingChunks = ""
            }
            currentAssistantMessage = "Error: \(error.localizedDescription)"
            messages.append(
                MessageBubble(content: currentAssistantMessage, isUser: false))
            currentAssistantMessage = ""
            isLoading = false
            persistMessages()
        }
    }

    private func flushChunksIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastUIUpdate) >= updateInterval else { return }
        currentAssistantMessage.append(pendingChunks)
        pendingChunks = ""
        lastUIUpdate = now
    }

    // MARK: - Direct llama.cpp Generation

    @MainActor
    private func sendWithLlamaCpp(_ llama: LlamaCppService) async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(MessageBubble(content: trimmed, isUser: true))
        recordChatIfNeeded(displayContent: trimmed)
        input = ""
        isLoading = true
        currentAssistantMessage = ""
        pendingChunks = ""
        lastUIUpdate = Date()

        // Build prompt with chat template
        var prompt = ""
        if let sys = systemPromptForMLX, !sys.isEmpty {
            prompt += "<|im_start|>system\n\(sys)<|im_end|>\n"
        }
        prompt += "<|im_start|>user\n\(trimmed)<|im_end|>\n<|im_start|>assistant\n"

        let stream = llama.generate(prompt: prompt, maxTokens: 1024)
        for await chunk in stream {
            pendingChunks.append(chunk)
            flushChunksIfNeeded()
        }

        if !pendingChunks.isEmpty {
            currentAssistantMessage.append(pendingChunks)
            pendingChunks = ""
        }

        if !currentAssistantMessage.isEmpty {
            messages.append(MessageBubble(content: currentAssistantMessage, isUser: false))
        }
        currentAssistantMessage = ""
        isLoading = false
        persistMessages()
    }

    // MARK: - MLX Generation

    @MainActor
    private func sendWithMLX(_ mlx: MLXModelService) async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachedImage != nil else { return }

        var displayContent = trimmed
        if attachedImage != nil {
            displayContent = displayContent.isEmpty ? "[Image]" : "[Image] \(displayContent)"
        }

        messages.append(
            MessageBubble(content: displayContent, isUser: true, image: attachedImage))
        recordChatIfNeeded(displayContent: displayContent)

        // Save image to temp file for MLX VLM
        var imageURLs: [URL] = []
        if let image = attachedImage {
            let jpegData = image.jpegData(compressionQuality: 0.8)
            let pngData = jpegData == nil ? image.pngData() : nil
            let imageData = jpegData ?? pngData
            let ext = jpegData != nil ? "jpg" : "png"

            if let data = imageData {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".\(ext)")
                do {
                    try data.write(to: tempURL)
                    imageURLs.append(tempURL)
                } catch {
                    messages.append(
                        MessageBubble(
                            content:
                                "Failed to prepare image for processing: \(error.localizedDescription)",
                            isUser: false))
                    if trimmed.isEmpty {
                        isLoading = false
                        return
                    }
                }
            } else {
                messages.append(
                    MessageBubble(
                        content: "Could not convert image to a supported format.",
                        isUser: false))
                if trimmed.isEmpty {
                    isLoading = false
                    return
                }
            }
        }

        input = ""
        attachedImage = nil
        isLoading = true
        currentAssistantMessage = ""
        pendingChunks = ""
        lastUIUpdate = Date()

        let stream = mlx.generate(
            userText: trimmed.isEmpty ? "Describe this image." : trimmed,
            systemPrompt: systemPromptForMLX,
            imageURLs: imageURLs
        )

        for await chunk in stream {
            pendingChunks.append(chunk)
            flushChunksIfNeeded()
        }

        // Flush remaining
        if !pendingChunks.isEmpty {
            currentAssistantMessage.append(pendingChunks)
            pendingChunks = ""
        }

        if !currentAssistantMessage.isEmpty {
            messages.append(
                MessageBubble(content: currentAssistantMessage, isUser: false))
        }
        currentAssistantMessage = ""
        isLoading = false
        persistMessages()

        // Clean up temp images
        for url in imageURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @MainActor
    func loadImageFrom(item: PhotosPickerItem) async {
        isImageLoading = true
        defer { isImageLoading = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else {
            print("Failed to load image from PhotosPickerItem")
            return
        }
        attachedImage = image
    }

    private func recordChatIfNeeded(displayContent: String) {
        guard !hasRecordedChat else { return }
        hasRecordedChat = true
        let chatId = UUID()
        currentChatId = chatId
        let title = displayContent.isEmpty ? "New Chat" : String(displayContent.prefix(50))
        onFirstMessage?(chatId, title)
    }

    private func persistMessages() {
        guard let chatId = currentChatId else { return }
        onMessagesChanged?(chatId, messages)
    }

    func removeAttachedImage() {
        attachedImage = nil
    }

    @MainActor
    func restoreChat(id: UUID, messages: [MessageBubble]) {
        self.messages = messages
        self.currentChatId = id
        self.hasRecordedChat = true
        self.input = ""
        self.currentAssistantMessage = ""
    }
}
