import LeapSDK
import PhotosUI
import SwiftData
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
    var glmocrService: GLMOCRService?
    var paddleOCRService: PaddleOCRService?
    var appleVisionOCRService: AppleVisionOCRService?
    var systemPromptForMLX: String?
    var ocrTask: OCRTask = .text

    // Monitoring & sync
    var syncGate: SyncGate?
    var modelContext: ModelContext?
    var syncManager: SyncManager?
    var studentAccountId: UUID?

    // Token tracking
    var estimatedTokensUsed: Int = 0
    var contextWindowSize: Int = 4096

    // Generation control
    @ObservationIgnored private var generationTask: Task<Void, Never>?

    // Throttle streaming UI updates to avoid overwhelming SwiftUI
    @ObservationIgnored private var pendingChunks = ""
    @ObservationIgnored private var lastUIUpdate = Date.distantPast
    @ObservationIgnored private let updateInterval: TimeInterval = 1.0 / 30.0 // 30fps max

    /// Clear all service references — must be called at the start of every configure method
    private func clearAllServices() {
        conversation = nil
        modelRunner = nil
        mlxService = nil
        llamaCppService = nil
        glmocrService = nil
        paddleOCRService = nil
        appleVisionOCRService = nil
        systemPromptForMLX = nil
        messages.removeAll()
        hasRecordedChat = false
        currentChatId = nil
        estimatedTokensUsed = 0
    }

    /// Estimate tokens used based on character count (~4 chars per token for English, ~2 for Chinese)
    func updateTokenEstimate() {
        var totalChars = 0
        for msg in messages {
            totalChars += msg.content.count
        }
        // Rough estimate: ~4 chars per token for English, ~1.5 for CJK
        estimatedTokensUsed = max(totalChars / 3, messages.count * 5)
    }

    @MainActor
    func configureWithModel(runner: ModelRunner, systemPrompt: String?, contextSize: Int = 4096) {
        clearAllServices()
        contextWindowSize = contextSize
        modelRunner = runner

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
        clearAllServices()
        messages.append(
            MessageBubble(
                content:
                    "Model downloaded but inference requires a physical device. On a real device, the model will load and you can chat.",
                isUser: false))
    }

    @MainActor
    func configureWithMLX(service: MLXModelService, systemPrompt: String?) {
        clearAllServices()
        mlxService = service
        systemPromptForMLX = systemPrompt
        messages.append(
            MessageBubble(content: "MLX model loaded. You can start chatting.", isUser: false))
    }

    @MainActor
    func configureWithLlamaCpp(service: LlamaCppService, systemPrompt: String?) {
        clearAllServices()
        llamaCppService = service
        systemPromptForMLX = systemPrompt
        messages.append(
            MessageBubble(content: "Model loaded via llama.cpp. You can start chatting.", isUser: false))
    }

    @MainActor
    func configureWithGLMOCR(service: GLMOCRService) {
        clearAllServices()
        glmocrService = service
        ocrTask = .text
        messages.append(
            MessageBubble(
                content: "GLM-OCR model loaded. Attach an image and send to extract text. You can also type a custom instruction.",
                isUser: false))
    }

    @MainActor
    func configureWithPaddleOCR(service: PaddleOCRService) {
        clearAllServices()
        paddleOCRService = service
        ocrTask = .text
        messages.append(
            MessageBubble(
                content: "PP-OCRv5 model loaded. Attach an image and send to extract text. Supports multilingual text detection and recognition.",
                isUser: false))
    }

    @MainActor
    func configureWithAppleVisionOCR(service: AppleVisionOCRService) {
        clearAllServices()
        appleVisionOCRService = service
        ocrTask = .text
        messages.append(
            MessageBubble(
                content: "Apple Vision OCR ready. Attach an image and send to extract text. Supports English, Chinese, Japanese, Korean, and more. No download required.",
                isUser: false))
    }

    @MainActor
    func send() async {
        // Update student's last active timestamp
        updateLastActive()

        // Sync gate check — block if too many unsynced messages or too long since last sync
        if let gate = syncGate, !gate.canSend() {
            print("[ChatStore] Sync gate blocked: \(gate.blockReason?.userMessage ?? "unknown")")
            return
        }

        print("[ChatStore.send] conversation=\(conversation != nil), llama=\(llamaCppService?.isLoaded ?? false), mlx=\(mlxService?.isLoaded ?? false), input=\(input.prefix(50))")

        // Route to Apple Vision OCR if active
        if let visionOCR = appleVisionOCRService {
            await sendWithAppleVisionOCR(visionOCR)
            return
        }

        // Route to PaddleOCR if active
        if let paddleOCR = paddleOCRService, paddleOCR.isLoaded {
            await sendWithPaddleOCR(paddleOCR)
            return
        }

        // Route to GLM-OCR if active
        if let glmocr = glmocrService, glmocr.isLoaded {
            await sendWithGLMOCR(glmocr)
            return
        }

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

    // MARK: - Apple Vision OCR

    @MainActor
    private func sendWithAppleVisionOCR(_ visionOCR: AppleVisionOCRService) async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard attachedImage != nil || !trimmed.isEmpty else { return }

        guard let image = attachedImage else {
            messages.append(MessageBubble(content: trimmed, isUser: true))
            input = ""
            messages.append(
                MessageBubble(
                    content: "Apple Vision OCR requires an image. Please attach an image and try again.",
                    isUser: false))
            return
        }

        let displayContent = trimmed.isEmpty ? "[Image] OCR" : "[Image] \(trimmed)"
        messages.append(
            MessageBubble(content: displayContent, isUser: true, image: image))
        recordChatIfNeeded(displayContent: displayContent)

        let capturedImage = image
        input = ""
        attachedImage = nil
        isLoading = true
        currentAssistantMessage = ""
        pendingChunks = ""
        lastUIUpdate = Date()

        let stream = visionOCR.generate(image: capturedImage)

        for await chunk in stream {
            pendingChunks.append(chunk)
            flushChunksIfNeeded()
        }

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
    }

    // MARK: - GLM-OCR Generation

    @MainActor
    private func sendWithGLMOCR(_ glmocr: GLMOCRService) async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard attachedImage != nil || !trimmed.isEmpty else { return }

        guard let image = attachedImage else {
            messages.append(MessageBubble(content: trimmed, isUser: true))
            input = ""
            messages.append(
                MessageBubble(
                    content: "GLM-OCR requires an image. Please attach an image and try again.",
                    isUser: false))
            return
        }

        var displayContent = trimmed.isEmpty ? "[Image] OCR" : "[Image] \(trimmed)"
        messages.append(
            MessageBubble(content: displayContent, isUser: true, image: image))
        recordChatIfNeeded(displayContent: displayContent)

        let capturedImage = image
        input = ""
        attachedImage = nil
        isLoading = true
        currentAssistantMessage = ""
        pendingChunks = ""
        lastUIUpdate = Date()

        let stream = glmocr.generate(
            image: capturedImage,
            task: ocrTask,
            userText: trimmed.isEmpty ? nil : trimmed
        )

        for await chunk in stream {
            pendingChunks.append(chunk)
            flushChunksIfNeeded()
        }

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
    }

    // MARK: - PaddleOCR Generation

    @MainActor
    private func sendWithPaddleOCR(_ paddleOCR: PaddleOCRService) async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard attachedImage != nil || !trimmed.isEmpty else { return }

        guard let image = attachedImage else {
            messages.append(MessageBubble(content: trimmed, isUser: true))
            input = ""
            messages.append(
                MessageBubble(
                    content: "PP-OCRv5 requires an image. Please attach an image and try again.",
                    isUser: false))
            return
        }

        let displayContent = trimmed.isEmpty ? "[Image] OCR" : "[Image] \(trimmed)"
        messages.append(
            MessageBubble(content: displayContent, isUser: true, image: image))
        recordChatIfNeeded(displayContent: displayContent)

        let capturedImage = image
        input = ""
        attachedImage = nil
        isLoading = true
        currentAssistantMessage = ""
        pendingChunks = ""
        lastUIUpdate = Date()

        let stream = paddleOCR.generate(image: capturedImage)

        for await chunk in stream {
            pendingChunks.append(chunk)
            flushChunksIfNeeded()
        }

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
        updateTokenEstimate()

        // Persist any new messages for sync tracking (idempotent)
        for (index, bubble) in messages.enumerated() {
            persistSyncableMessageIfNeeded(bubble, sequenceNumber: index)
        }

        // Auto-sync in background after each message exchange
        if let manager = syncManager, !manager.isSyncing {
            Task {
                await manager.performSync()
            }
        }
    }

    @MainActor
    func stopGenerating() {
        generationTask?.cancel()
        generationTask = nil
        if isLoading {
            // Finalize whatever was streamed so far
            if !pendingChunks.isEmpty {
                currentAssistantMessage.append(pendingChunks)
                pendingChunks = ""
            }
            if !currentAssistantMessage.isEmpty {
                messages.append(
                    MessageBubble(content: currentAssistantMessage + "\n\n[Stopped]", isUser: false))
            }
            currentAssistantMessage = ""
            isLoading = false
            persistMessages()
        }
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

    // MARK: - Activity Tracking

    private func updateLastActive() {
        guard let context = modelContext, let studentId = studentAccountId else { return }
        let descriptor = FetchDescriptor<UserAccount>(
            predicate: #Predicate<UserAccount> { $0.accountId == studentId }
        )
        if let account = try? context.fetch(descriptor).first {
            account.lastActiveAt = Date()
            try? context.save()
        }
    }

    // MARK: - Sync Persistence

    /// Persist a message bubble to SwiftData for sync tracking.
    /// Idempotent — skips if messageId already exists.
    func persistSyncableMessageIfNeeded(_ bubble: MessageBubble, sequenceNumber: Int) {
        guard let context = modelContext else {
            print("[Sync] ERROR: modelContext is nil — messages NOT being tracked!")
            return
        }
        guard let chatId = currentChatId else {
            print("[Sync] ERROR: currentChatId is nil — messages NOT being tracked!")
            return
        }
        // Skip system/setup messages (non-user, at index 0, before any real chat)
        if !bubble.isUser && sequenceNumber == 0 && messages.count <= 1 { return }

        // Check if already persisted
        let bubbleId = bubble.id
        var existsDescriptor = FetchDescriptor<SyncableMessage>(
            predicate: #Predicate<SyncableMessage> { $0.messageId == bubbleId }
        )
        existsDescriptor.fetchLimit = 1
        if let count = try? context.fetchCount(existsDescriptor), count > 0 {
            return // Already tracked
        }

        let syncMessage = SyncableMessage(
            messageId: bubble.id,
            chatId: chatId,
            content: bubble.content,
            isUser: bubble.isUser,
            timestamp: bubble.timestamp,
            thumbnailData: bubble.generateThumbnail(),
            thinkingTime: bubble.thinkingTime,
            sequenceNumber: sequenceNumber
        )
        context.insert(syncMessage)

        // Update or create ChatSessionRecord
        let targetChatId = chatId
        var sessionDescriptor = FetchDescriptor<ChatSessionRecord>(
            predicate: #Predicate { $0.chatId == targetChatId }
        )
        sessionDescriptor.fetchLimit = 1

        if let session = try? context.fetch(sessionDescriptor).first {
            session.messageCount += 1
            session.unsyncedCount += 1
            session.updatedAt = Date()
        } else if let studentId = studentAccountId {
            let session = ChatSessionRecord(
                chatId: chatId,
                studentAccountId: studentId,
                title: messages.first?.content.prefix(50).description ?? "Chat",
                createdAt: Date()
            )
            session.messageCount = 1
            session.unsyncedCount = 1
            context.insert(session)
        }

        try? context.save()
        syncManager?.updatePendingCount()
        print("[Sync] Persisted message \(bubble.id) (user=\(bubble.isUser)) — pending: \(syncManager?.pendingCount ?? -1)")
    }
}
