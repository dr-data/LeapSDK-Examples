import SwiftUI
import UniformTypeIdentifiers

/// Example prompt template for specialized chat
struct ExamplePrompt: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let prompt: String
}

/// An imported document for RAG context
struct ImportedDocument: Identifiable {
    let id = UUID()
    let name: String
    let content: String
    let fileType: String
    let chunks: [DocumentConverter.DocumentChunk]
}

/// A dedicated chat view for specialized tasks (Math, RAG, etc.)
/// Shows model picker with suggested model, example buttons, and back navigation.
struct SpecializedChatView: View {
    let title: String
    let suggestedModelId: String
    let defaultQuant: String
    let systemPrompt: String
    let examples: [ExamplePrompt]
    var restoreChat: RecentChat? = nil

    @State private var store = ChatStore()
    @State private var showModelPicker = false
    @State private var isModelReady = false
    @State private var hasStartedChatting = false
    @State private var showFileImporter = false
    @State private var importedDocuments: [ImportedDocument] = []
    @State private var selectedDocumentIds: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss
    @Environment(ModelStore.self) private var modelStore
    @Environment(PromptStore.self) private var promptStore
    @Environment(RecentChatStore.self) private var recentChatStore
    @Environment(SyncGate.self) private var syncGate
    @Environment(SyncManager.self) private var syncManager
    @Environment(AuthManager.self) private var authManager

    private var bgColor: Color { AppColors.background }
    private var cardColor: Color { AppColors.cardBackground }
    private var secondaryText: Color { AppColors.secondaryText }
    private let accentBlue = AppColors.accentBlue

    private var category: ModelCategory {
        title == "Math" ? .math : .rag
    }

    private var availableModels: [ModelDefinition] {
        ModelCatalog.models(for: category)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if modelStore.isLoading {
                    loadingView
                } else if !isModelReady {
                    modelSelectionView
                } else {
                    // Show examples until user sends first message
                    if !hasStartedChatting {
                        examplesView
                    }
                    // Document bar for RAG
                    if category == .rag {
                        documentBar
                    }
                    MessagesListView(store: store)
                    ChatInputView(store: store, syncGate: syncGate, syncManager: syncManager)
                }
            }
        }
        .navigationBarHidden(true)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .plainText, .rtf, .data],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .onAppear {
            store.onFirstMessage = { chatId, chatTitle in
                hasStartedChatting = true
                // Update RAG references with the actual query before first message
                if category == .rag && !selectedDocumentIds.isEmpty {
                    updateRAGSystemPrompt()
                }
                recentChatStore.addChat(id: chatId, title: chatTitle, category: category.rawValue, studentAccountId: authManager.currentUser?.accountId, messages: store.messages)
            }
            store.onMessagesChanged = { chatId, messages in
                recentChatStore.updateMessages(for: chatId, messages: messages)
            }
            if store.modelContext == nil {
                store.modelContext = syncManager.sharedModelContext
                store.syncGate = syncGate
                store.syncManager = syncManager
                store.studentAccountId = authManager.currentUser?.accountId
            }
            // If a model for this category is already loaded, mark ready
            if let active = modelStore.activeModel, active.category == category, !modelStore.isLoading {
                configureStoreWithActiveModel()
                isModelReady = true
            }
            // Restore previous chat if provided
            if let chat = restoreChat {
                store.restoreChat(id: chat.id, messages: chat.messages)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16))
                }
                .foregroundColor(accentBlue)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: title == "Math" ? "function" : "doc.text.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(accentBlue)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            if syncManager.pendingCount > 0 {
                HStack(spacing: 3) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text("\(syncManager.pendingCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }

            Button {
                store.messages.removeAll()
                store.input = ""
                store.currentAssistantMessage = ""
                store.hasRecordedChat = false
                store.currentChatId = nil
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20))
                    .foregroundColor(secondaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(bgColor)
    }

    // MARK: - Model Selection (no auto-download)

    private var modelSelectionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: title == "Math" ? "function" : "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(accentBlue)

            Text("Select a Model for \(title)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Recommended: \(suggestedModelId)")
                .font(.subheadline)
                .foregroundColor(secondaryText)

            VStack(spacing: 10) {
                ForEach(availableModels) { model in
                    let isSuggested = model.id == suggestedModelId
                    let isDownloaded = modelStore.isModelDownloaded(model)

                    Button {
                        Task {
                            let quant = model.quantizations.first(where: { $0.name == defaultQuant })
                                ?? model.quantizations.first!
                            print("[SpecChat] Loading model: \(model.id) quant: \(quant.name)")
                            await modelStore.downloadAndLoad(model: model, quantization: quant)
                            print("[SpecChat] Model loaded. activeModel=\(modelStore.activeModel?.id ?? "nil"), runner=\(modelStore.activeModelRunner != nil), llama=\(modelStore.isLlamaCppActive), mlx=\(modelStore.isMLXActive)")
                            configureStoreWithActiveModel()
                            isModelReady = true
                            print("[SpecChat] Store configured. messages=\(store.messages.count), conversation=\(store.conversation != nil)")
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(model.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                    if isSuggested {
                                        Text("Recommended")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                }
                                Text("\(model.parameterCount) params \(isDownloaded ? "- Downloaded" : "")")
                                    .font(.caption)
                                    .foregroundColor(isDownloaded ? .green : secondaryText)
                            }
                            Spacer()
                            Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                                .foregroundColor(isDownloaded ? .green : accentBlue)
                        }
                        .padding(14)
                        .background(isSuggested ? accentBlue.opacity(0.15) : cardColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Example Buttons

    private var examplesView: some View {
        VStack(spacing: 8) {
            if category == .rag && importedDocuments.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 13))
                    Text("Upload a file first, then use these examples to analyze it")
                        .font(.system(size: 13))
                }
                .foregroundColor(secondaryText)
                .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(examples) { example in
                    Button {
                        store.input = example.prompt
                        hasStartedChatting = true
                        // Update RAG references based on the example query
                        if category == .rag && !selectedDocumentIds.isEmpty {
                            updateRAGSystemPrompt()
                        }
                        Task { await store.send() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: example.icon)
                                .font(.system(size: 12))
                            Text(example.label)
                                .font(.system(size: 13))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: 180)
                        .background(cardColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: title == "Math" ? "function" : "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(accentBlue)
            Text("Loading model...")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            if !modelStore.loadingMessage.isEmpty {
                Text(modelStore.loadingMessage)
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
            }
            ProgressView().tint(.white).padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Document Bar (RAG)

    private var documentBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Add document button
                    Button { showFileImporter = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Add File")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(accentBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(accentBlue.opacity(0.15))
                        .clipShape(Capsule())
                    }

                    // Imported documents (multi-select)
                    ForEach(importedDocuments) { doc in
                        let isSelected = selectedDocumentIds.contains(doc.id)
                        Button {
                            if isSelected {
                                selectedDocumentIds.remove(doc.id)
                            } else {
                                selectedDocumentIds.insert(doc.id)
                            }
                            updateRAGSystemPrompt()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(isSelected ? .green : secondaryText)
                                Image(systemName: iconForFileType(doc.fileType))
                                    .font(.system(size: 12))
                                Text(doc.name)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Text("(\(doc.content.count > 1000 ? "\(doc.content.count / 1000)K" : "\(doc.content.count)") chars)")
                                    .font(.system(size: 10))
                                    .foregroundColor(secondaryText)

                                Button {
                                    importedDocuments.removeAll { $0.id == doc.id }
                                    selectedDocumentIds.remove(doc.id)
                                    updateRAGSystemPrompt()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(secondaryText)
                                }
                            }
                            .foregroundColor(isSelected ? .white : secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(isSelected ? accentBlue.opacity(0.3) : cardColor)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? accentBlue : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 6)
            .background(bgColor)
        }
    }

    private func iconForFileType(_ type: String) -> String {
        switch type {
        case "pdf": return "doc.fill"
        case "docx", "doc": return "doc.richtext"
        case "txt", "text": return "doc.plaintext"
        default: return "doc"
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            let fileName = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            var content = ""

            if ext == "pdf" {
                content = DocumentConverter.pdfToMarkdown(url: url)
            } else if ext == "docx" || ext == "doc" {
                content = DocumentConverter.docxToMarkdown(url: url)
            } else if ext == "txt" || ext == "text" || ext == "md" || ext == "rtf" {
                content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            } else {
                content = (try? String(contentsOf: url, encoding: .utf8)) ?? "[Unsupported format]"
            }

            if !content.isEmpty {
                let chunks = DocumentConverter.chunkDocument(markdown: content, source: fileName)
                let doc = ImportedDocument(name: fileName, content: content, fileType: ext, chunks: chunks)
                importedDocuments.append(doc)
                // Auto-select newly imported documents so RAG always references them
                selectedDocumentIds.insert(doc.id)
                print("[RAG] Imported '\(fileName)': \(content.count) chars, \(chunks.count) chunks — auto-selected")
            }
        }

        // Update system prompt with newly imported documents
        if !selectedDocumentIds.isEmpty {
            updateRAGSystemPrompt()
        }
    }

    /// Update the system prompt with relevant document chunks as numbered references.
    /// Uses keyword relevance scoring to select the most relevant passages.
    private func updateRAGSystemPrompt() {
        let selectedDocs = importedDocuments.filter { selectedDocumentIds.contains($0.id) }

        var ragSystemPrompt = systemPrompt

        if !selectedDocs.isEmpty {
            // Collect all chunks from selected documents
            let allChunks = selectedDocs.flatMap { $0.chunks }

            // Find relevant chunks based on current input (if any), otherwise use first chunks
            let query = store.input.trimmingCharacters(in: .whitespacesAndNewlines)
            let relevantChunks: [DocumentConverter.DocumentChunk]
            if query.isEmpty {
                relevantChunks = Array(allChunks.prefix(8))
            } else {
                relevantChunks = DocumentConverter.findRelevantChunks(query: query, chunks: allChunks, topK: 8)
            }

            ragSystemPrompt += """

            \nThe following document excerpts may help answer the question.
            When answering, cite your sources using [Ref X] notation to indicate which excerpt you used.
            Use temperature=0 for factual grounding.

            \(DocumentConverter.formatChunksAsReferences(relevantChunks))
            """

            print("[RAG] System prompt updated: \(relevantChunks.count) chunks from \(selectedDocs.count) docs")
        }

        // Reconfigure the model with updated system prompt
        configureStoreWithSystemPrompt(ragSystemPrompt)
    }

    // MARK: - Helpers

    private func configureStoreWithActiveModel() {
        configureStoreWithSystemPrompt(systemPrompt)
    }

    private func configureStoreWithSystemPrompt(_ prompt: String) {
        print("[SpecChat] configureWithSystemPrompt: runner=\(modelStore.activeModelRunner != nil), llama=\(modelStore.isLlamaCppActive), mlx=\(modelStore.isMLXActive)")
        if let runner = modelStore.activeModelRunner {
            print("[SpecChat] Using LeapSDK runner")
            store.configureWithModel(runner: runner, systemPrompt: prompt)
        } else if modelStore.isLlamaCppActive {
            print("[SpecChat] Using llama.cpp")
            store.configureWithLlamaCpp(service: modelStore.llamaCppService, systemPrompt: prompt)
        } else if modelStore.isMLXActive {
            print("[SpecChat] Using MLX")
            store.configureWithMLX(service: modelStore.mlxService, systemPrompt: prompt)
        } else {
            print("[SpecChat] WARNING: No runner available — configureWithoutRunner")
            store.configureWithoutRunner(systemPrompt: prompt)
        }
    }
}

// MARK: - Predefined Examples

enum SpecializedExamples {
    static let math: [ExamplePrompt] = [
        ExamplePrompt(
            label: "Solve: x² + 3x - 10 = 0",
            icon: "x.squareroot",
            prompt: "Solve the equation x² + 3x - 10 = 0. Show step-by-step working."
        ),
        ExamplePrompt(
            label: "手寫公式辨識",
            icon: "pencil.and.outline",
            prompt: "I have a handwritten formula. Please help me identify and solve it step by step. The formula is: ∫(2x + 3)dx from 0 to 5"
        ),
        ExamplePrompt(
            label: "中文數學題",
            icon: "character.book.closed",
            prompt: "請解答以下數學題：一個長方形的長是12厘米，闊是8厘米。求它的面積和周界。請用中文詳細解釋每一步。"
        ),
        ExamplePrompt(
            label: "Geometry Problem",
            icon: "triangle",
            prompt: "A triangle has sides of length 3, 4, and 5. Prove it is a right triangle and calculate its area."
        ),
        ExamplePrompt(
            label: "分數運算",
            icon: "divide",
            prompt: "計算以下分數運算，並展示詳細步驟：2/3 + 3/4 - 1/6 = ?"
        ),
    ]

    static let rag: [ExamplePrompt] = [
        ExamplePrompt(
            label: "擬通告",
            icon: "doc.text",
            prompt: "根據已上傳的文件內容，請幫我擬一份學校通告。請引用文件中的相關資料，並標註來源 [Ref X]。"
        ),
        ExamplePrompt(
            label: "擬校務報告",
            icon: "doc.richtext",
            prompt: "根據已上傳的文件，請幫我擬一份校務報告摘要。請從文件中提取關鍵數據和資訊，並引用來源 [Ref X]。"
        ),
        ExamplePrompt(
            label: "回覆投訴信",
            icon: "envelope.open",
            prompt: "根據已上傳的文件內容，請幫我草擬一封正式回覆信。請參考文件中的相關政策或資料，並標註引用來源 [Ref X]。"
        ),
        ExamplePrompt(
            label: "文言文對譯",
            icon: "character.book.closed",
            prompt: "請根據已上傳的文言文文件，提供逐字對譯。分析語譯難點，並提供更多參考例句幫助學生記憶。請引用文件中的原文 [Ref X]。"
        ),
        ExamplePrompt(
            label: "詞彙鞏固",
            icon: "textformat.abc",
            prompt: "請分析已上傳的文件，偵測適合中學程度的重點詞彙，標記常用詞彙和需要新學的詞彙，並為每個詞彙提供例句。請引用文件來源 [Ref X]。"
        ),
        ExamplePrompt(
            label: "Document Summary",
            icon: "doc.plaintext",
            prompt: "Please summarize the uploaded document(s). Highlight key points and cite specific sections using [Ref X] notation."
        ),
    ]
}
