import SwiftData
import SwiftUI

enum ActiveSheet: Identifiable {
    case modelSelector
    case promptDetails

    var id: String {
        switch self {
        case .modelSelector: return "modelSelector"
        case .promptDetails: return "promptDetails"
        }
    }
}

struct ContentView: View {
    @State private var store = ChatStore()
    @State private var showMenu = false
    @State private var activeSheet: ActiveSheet?
    @Environment(ModelStore.self) private var modelStore
    @Environment(PromptStore.self) private var promptStore
    @Environment(RecentChatStore.self) private var recentChatStore
    @Environment(SyncGate.self) private var syncGate
    @Environment(SyncManager.self) private var syncManager
    @Environment(AuthManager.self) private var authManager

    private var bgColor: Color { AppColors.background }
    private var secondaryText: Color { AppColors.secondaryText }

    private var activeModelDisplayName: String {
        modelStore.activeModel?.name ?? "No Model"
    }

    private var activeQuantDisplayName: String {
        modelStore.activeQuantization?.name ?? ""
    }

    private var isOCRActive: Bool {
        modelStore.isGLMOCRActive || modelStore.isPaddleOCRActive || modelStore.isAppleVisionOCRActive
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                chatHeader

                if modelStore.activeModel == nil {
                    noModelSelectedView
                } else {
                    // OCR example buttons when an OCR model is active
                    if isOCRActive && store.messages.count <= 1 {
                        ocrExamplesView
                    }
                    MessagesListView(store: store)
                    ChatInputView(store: store, syncGate: syncGate, syncManager: syncManager)
                }
            }

            if showMenu {
                ChatSidebarView(
                    isPresented: $showMenu,
                    onNewChat: {
                        store.messages.removeAll()
                        store.input = ""
                        store.currentAssistantMessage = ""
                        store.hasRecordedChat = false
                        store.currentChatId = nil
                    },
                    onSelectChat: { chat in
                        store.restoreChat(id: chat.id, messages: chat.messages)
                    },
                    onSelectCategory: { _ in },
                    onSelectModel: {
                        activeSheet = .modelSelector
                    },
                    onSelectPrompt: {
                        activeSheet = .promptDetails
                    }
                )
                .transition(.move(edge: .leading))
                .zIndex(10)
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .modelSelector:
                ModelSelectorView()
            case .promptDetails:
                PromptDetailsView()
            }
        }
        .onAppear {
            store.onFirstMessage = { chatId, title in
                let category = modelStore.activeModel?.category.rawValue
                recentChatStore.addChat(id: chatId, title: title, category: category, studentAccountId: authManager.currentUser?.accountId, messages: store.messages)
            }
            store.onMessagesChanged = { chatId, messages in
                recentChatStore.updateMessages(for: chatId, messages: messages)
            }
            // Wire up sync monitoring — use syncManager's shared context so all
            // components read/write to the SAME ModelContext
            if store.modelContext == nil {
                store.modelContext = syncManager.sharedModelContext
                store.syncGate = syncGate
                store.syncManager = syncManager
                store.studentAccountId = authManager.currentUser?.accountId
                print("[ContentView] Sync wired, studentId=\(authManager.currentUser?.accountId.uuidString ?? "nil")")

                // Backfill studentAccountId on legacy chats that don't have it
                if let studentId = authManager.currentUser?.accountId {
                    for i in recentChatStore.recentChats.indices {
                        if recentChatStore.recentChats[i].studentAccountId == nil {
                            recentChatStore.recentChats[i].studentAccountId = studentId
                        }
                    }
                    recentChatStore.save()
                    print("[ContentView] Backfilled studentAccountId on \(recentChatStore.recentChats.filter { $0.studentAccountId == studentId }.count) chats")
                }
            }

            // Update lastActiveAt for online status tracking
            if let studentId = authManager.currentUser?.accountId {
                let descriptor = FetchDescriptor<UserAccount>(
                    predicate: #Predicate<UserAccount> { $0.accountId == studentId }
                )
                if let account = try? syncManager.sharedModelContext.fetch(descriptor).first {
                    account.lastActiveAt = Date()
                    try? syncManager.sharedModelContext.save()
                    print("[ContentView] Updated lastActiveAt for \(account.displayName)")
                }
            }
        }
        // Default model (LFM2.5-VL-1.6B) is pre-downloaded on the home screen
        .onChange(of: modelStore.activeModel?.id) { _, _ in
            if modelStore.isAppleVisionOCRActive {
                store.configureWithAppleVisionOCR(
                    service: modelStore.appleVisionOCRService
                )
            } else if modelStore.isPaddleOCRActive {
                store.configureWithPaddleOCR(
                    service: modelStore.paddleOCRService
                )
            } else if modelStore.isGLMOCRActive {
                store.configureWithGLMOCR(
                    service: modelStore.glmocrService
                )
            } else if modelStore.isLlamaCppActive {
                store.configureWithLlamaCpp(
                    service: modelStore.llamaCppService,
                    systemPrompt: promptStore.systemPrompt
                )
            } else if modelStore.isMLXActive {
                store.configureWithMLX(
                    service: modelStore.mlxService,
                    systemPrompt: promptStore.systemPrompt
                )
            } else if let runner = modelStore.activeModelRunner {
                let ctxSize = modelStore.activeModel.map { Int(modelStore.contextSize(for: $0)) } ?? 4096
                store.configureWithModel(
                    runner: runner,
                    systemPrompt: promptStore.systemPrompt,
                    contextSize: ctxSize
                )
            } else if let model = modelStore.activeModel {
                // VL models may fail Leap.load() but work via MLX fallback
                if model.category == .vision && modelStore.mlxService.isLoaded {
                    store.configureWithMLX(
                        service: modelStore.mlxService,
                        systemPrompt: promptStore.systemPrompt
                    )
                } else if model.category == .vision && modelStore.llamaCppService.isLoaded {
                    store.configureWithLlamaCpp(
                        service: modelStore.llamaCppService,
                        systemPrompt: promptStore.systemPrompt
                    )
                } else {
                    // Try to reload the model via a fallback path
                    print("[ContentView] WARNING: No runner for \(model.name). Attempting MLX load...")
                    Task {
                        if let quant = modelStore.activeQuantization {
                            // Force reload through MLX path
                            modelStore.isMLXActive = true
                            await modelStore.downloadAndLoad(model: model, quantization: quant)
                            if modelStore.isMLXActive, modelStore.mlxService.isLoaded {
                                store.configureWithMLX(service: modelStore.mlxService, systemPrompt: promptStore.systemPrompt)
                            } else {
                                store.configureWithoutRunner(systemPrompt: promptStore.systemPrompt)
                            }
                        } else {
                            store.configureWithoutRunner(systemPrompt: promptStore.systemPrompt)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chat Header

    private var chatHeader: some View {
        HStack {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showMenu.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22))
                    .foregroundColor(secondaryText)
            }
            .accessibilityIdentifier("menuButton")

            // Sync status indicator
            if syncManager.pendingCount > 0 {
                HStack(spacing: 3) {
                    if syncManager.isSyncing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.orange)
                    } else {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                    }
                    Text("\(syncManager.pendingCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }

            Spacer()

            Button {
                activeSheet = .modelSelector
            } label: {
                HStack(spacing: 4) {
                    if modelStore.activeModel != nil {
                        Text(activeModelDisplayName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(secondaryText)
                        if !activeQuantDisplayName.isEmpty {
                            Circle()
                                .fill(secondaryText)
                                .frame(width: 3, height: 3)
                            Text(activeQuantDisplayName)
                                .font(.system(size: 15))
                                .foregroundColor(secondaryText)
                        }
                    } else {
                        Text("Select Model")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(secondaryText)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(secondaryText)
                }
            }
            .accessibilityIdentifier("modelSelectorButton")

            Spacer()

            Button {
                store.messages.removeAll()
                store.input = ""
                store.currentAssistantMessage = ""
                store.hasRecordedChat = false
                store.currentChatId = nil
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 22))
                    .foregroundColor(secondaryText)
            }
            .accessibilityIdentifier("newChatButton")

            Button {
                authManager.logout()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(bgColor)
    }

    // MARK: - No Model Selected

    private var noModelSelectedView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundColor(secondaryText)

            Text("No Model Selected")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Select a model to start chatting")
                .foregroundColor(secondaryText)

            Button {
                activeSheet = .modelSelector
            } label: {
                Label("Browse Models", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.231, green: 0.510, blue: 0.965))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
            }
            .accessibilityIdentifier("browseModelsButton")

            if modelStore.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(modelStore.loadingMessage)
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - OCR Examples

    private var ocrExamplesView: some View {
        VStack(spacing: 6) {
            Text("Try an example image:")
                .font(.system(size: 12))
                .foregroundColor(secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OCRExampleGenerator.examples) { example in
                        Button {
                            let image = example.generator()
                            store.attachedImage = image
                            Task { await store.send() }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: example.icon)
                                    .font(.system(size: 11))
                                Text(example.label)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 6)
    }
}

// Preview disabled — requires SwiftData ModelContainer for SyncGate/SyncManager/AuthManager
