import SwiftUI

struct AppHomeView: View {
    @Environment(ModelStore.self) private var modelStore
    @Environment(PromptStore.self) private var promptStore
    @Environment(AuthManager.self) private var authManager
    @Environment(RecentChatStore.self) private var recentChatStore
    @State private var searchText = ""
    @State private var path = NavigationPath()
    @State private var expandedCategory: String?

    private var bgColor: Color { AppColors.background }
    private var cardColor: Color { AppColors.cardBackground }
    private var secondaryText: Color { AppColors.secondaryText }
    private let accentCyan = Color(red: 0.024, green: 0.714, blue: 0.831)

    struct AppItem: Identifiable {
        let id: String
        let name: String
        let icon: String
        let categoryRaw: String
        let destination: AppDestination
    }

    private let apps: [AppItem] = [
        AppItem(id: "chat", name: "Chat", icon: "message.fill", categoryRaw: ModelCategory.chat.rawValue, destination: .appHome),
        AppItem(id: "math", name: "Math", icon: "function", categoryRaw: ModelCategory.math.rawValue, destination: .mathChat),
        AppItem(id: "rag", name: "RAG", icon: "doc.text.magnifyingglass", categoryRaw: ModelCategory.rag.rawValue, destination: .ragChat),
        AppItem(id: "extract", name: "Extract", icon: "doc.text", categoryRaw: ModelCategory.extract.rawValue, destination: .appHome),
        AppItem(id: "translate", name: "EN-JP Translator", icon: "character.book.closed", categoryRaw: ModelCategory.translate.rawValue, destination: .appHome),
        AppItem(id: "audio", name: "Audio", icon: "mic", categoryRaw: ModelCategory.audio.rawValue, destination: .appHome),
        AppItem(id: "vision", name: "Vision", icon: "eye", categoryRaw: ModelCategory.vision.rawValue, destination: .appHome),
        AppItem(id: "ocr", name: "OCR", icon: "doc.text.viewfinder", categoryRaw: ModelCategory.ocr.rawValue, destination: .appHome),
    ]

    private func chatsForCategory(_ categoryRaw: String) -> [RecentChat] {
        recentChatStore.activeChats(for: categoryRaw)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                bgColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        brandRow

                        // Show model download progress on home screen
                        if modelStore.isLoading {
                            modelDownloadBanner
                        }

                        searchBar
                        appsWithChatsSection
                        recentChatsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                // No auto-download — user chooses model from Browse Models in chat
            }
            .navigationBarHidden(true)
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .appHome:
                    ContentView()
                case .aiProviders:
                    AIProvidersView(path: $path)
                case .openRouterConfig:
                    OpenRouterConfigView()
                case .localModelsBrowser:
                    LocalModelsBrowserView(path: $path)
                case .customBackends:
                    CustomBackendsView()
                case .customBackendEdit(let backend):
                    CustomBackendEditView(existingBackend: backend)
                case .modelDetail(let model):
                    ModelDetailView(model: model, path: $path)
                case .modelDetailPopup(let model):
                    ModelDetailPopupView(model: model)
                case .mathChat:
                    SpecializedChatHistoryView(
                        title: "Math",
                        icon: "function",
                        category: .math,
                        suggestedModelId: "LFM2-350M-Math",
                        defaultQuant: "Q4_K_M",
                        systemPrompt: "You are a math tutor. Help the student solve math problems step by step. Show your work clearly and explain each step. Support both English and Traditional Chinese (繁體中文). Use mathematical notation where appropriate. IMPORTANT: After solving any problem, always VERIFY your answer by substituting it back into the original equation or using an alternative method. Show both the solution and verification steps clearly. If the verification fails, correct your answer before presenting the final result.",
                        examples: SpecializedExamples.math
                    )
                case .ragChat:
                    SpecializedChatHistoryView(
                        title: "RAG",
                        icon: "doc.text.magnifyingglass",
                        category: .rag,
                        suggestedModelId: "LFM2-1.2B-RAG",
                        defaultQuant: "Q4_K_M",
                        systemPrompt: "You are a document analysis assistant for education. You help teachers and students with: generating official documents (通告、校務報告、回覆信), classical Chinese translation (文言文對譯), and vocabulary consolidation (詞彙鞏固). Respond in Traditional Chinese (繁體中文) when the input is Chinese. Be precise and professional.",
                        examples: SpecializedExamples.rag
                    )
                case .teacherDashboard:
                    EmptyView()
                case .adminPanel:
                    EmptyView()
                }
            }
        }
    }

    private var brandRow: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(accentCyan)
                    .frame(width: 10, height: 10)

                Text("APOLLO")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button {
                authManager.logout()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18))
                    .foregroundColor(secondaryText)
            }

            Button {
                path.append(AppDestination.aiProviders)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(secondaryText)
            }
        }
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(secondaryText)
                .font(.system(size: 15))

            TextField("Search", text: $searchText)
                .foregroundColor(.white)
                .font(.system(size: 15))
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Apps with expandable chat history

    private var appsWithChatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPS")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryText)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(apps) { app in
                    let chatCount = chatsForCategory(app.categoryRaw).count
                    let isExpanded = expandedCategory == app.id

                    VStack(spacing: 0) {
                        // Category row
                        HStack(spacing: 14) {
                            // Tap icon area to expand/collapse
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedCategory = isExpanded ? nil : app.id
                                }
                            } label: {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(secondaryText)
                                    .frame(width: 16)
                            }

                            // Tap name to start new chat
                            Button {
                                path.append(app.destination)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: app.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)

                                    Text(app.name)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)

                                    Spacer()

                                    if chatCount > 0 {
                                        Text("\(chatCount)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(secondaryText)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(cardColor)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        // Expanded chat history for this category
                        if isExpanded {
                            let chats = chatsForCategory(app.categoryRaw)

                            VStack(spacing: 0) {
                                // New chat button
                                Button {
                                    path.append(app.destination)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 14))
                                            .foregroundColor(accentCyan)
                                        Text("New \(app.name) Chat")
                                            .font(.system(size: 14))
                                            .foregroundColor(accentCyan)
                                        Spacer()
                                    }
                                    .padding(.leading, 56)
                                    .padding(.trailing, 16)
                                    .padding(.vertical, 10)
                                }

                                if chats.isEmpty {
                                    Text("No chats yet")
                                        .font(.system(size: 13))
                                        .foregroundColor(secondaryText)
                                        .padding(.leading, 56)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    ForEach(chats) { chat in
                                        HStack(spacing: 10) {
                                            Button {
                                                path.append(app.destination)
                                            } label: {
                                                HStack(spacing: 10) {
                                                    Image(systemName: "bubble.left")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(secondaryText)
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(chat.title)
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.white)
                                                            .lineLimit(1)
                                                        Text(chat.timeAgo)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(secondaryText)
                                                    }
                                                    Spacer()
                                                    Text("\(chat.messages.count)")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(secondaryText)
                                                }
                                            }

                                            // Archive button
                                            Button {
                                                recentChatStore.archiveChat(id: chat.id)
                                            } label: {
                                                Image(systemName: "archivebox")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.orange)
                                            }

                                            // Delete button
                                            Button {
                                                recentChatStore.deleteChat(id: chat.id)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(.leading, 56)
                                        .padding(.trailing, 16)
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .background(Color(red: 0.055, green: 0.075, blue: 0.130))
                        }

                        // Divider between categories
                        Divider()
                            .overlay(Color(red: 0.1, green: 0.13, blue: 0.19))
                    }
                }
            }
            .background(cardColor.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Recent Chats (matches hamburger sidebar)

    private var recentChatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT CHATS")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryText)
                .tracking(0.5)

            if recentChatStore.activeChats.isEmpty {
                Text("No chats yet. Start a conversation from the apps above.")
                    .font(.system(size: 14))
                    .foregroundColor(secondaryText)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentChatStore.activeChats.prefix(15)) { chat in
                        Button {
                            // Navigate to the appropriate chat type
                            let dest = destinationForCategory(chat.category)
                            path.append(dest)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: iconForCategory(chat.category))
                                    .font(.system(size: 14))
                                    .foregroundColor(colorForCategory(chat.category))
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(chat.title)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        if let cat = chat.category, !cat.isEmpty,
                                           cat != ModelCategory.chat.rawValue {
                                            Text(labelForCategory(cat))
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(colorForCategory(cat))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(colorForCategory(cat).opacity(0.2))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(chat.timeAgo)
                                        .font(.system(size: 12))
                                        .foregroundColor(secondaryText)
                                }

                                Spacer()

                                Text("\(chat.messages.count)")
                                    .font(.system(size: 11))
                                    .foregroundColor(secondaryText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        if chat.id != recentChatStore.activeChats.prefix(15).last?.id {
                            Divider()
                                .overlay(Color(red: 0.1, green: 0.13, blue: 0.19))
                                .padding(.leading, 48)
                        }
                    }
                }
                .background(cardColor.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func iconForCategory(_ category: String?) -> String {
        guard let c = category else { return "message" }
        switch c {
        case ModelCategory.math.rawValue: return "function"
        case ModelCategory.rag.rawValue: return "doc.text.magnifyingglass"
        case ModelCategory.vision.rawValue: return "eye"
        case ModelCategory.ocr.rawValue: return "doc.text.viewfinder"
        case ModelCategory.translate.rawValue: return "character.book.closed"
        case ModelCategory.extract.rawValue: return "doc.text"
        case ModelCategory.audio.rawValue: return "mic"
        default: return "message"
        }
    }

    private func colorForCategory(_ category: String?) -> Color {
        guard let c = category else { return secondaryText }
        switch c {
        case ModelCategory.math.rawValue: return .purple
        case ModelCategory.rag.rawValue: return .cyan
        default: return secondaryText
        }
    }

    private func labelForCategory(_ category: String) -> String {
        switch category {
        case ModelCategory.math.rawValue: return "Math"
        case ModelCategory.rag.rawValue: return "RAG"
        case ModelCategory.vision.rawValue: return "Vision"
        case ModelCategory.extract.rawValue: return "Extract"
        default: return ""
        }
    }

    private func destinationForCategory(_ category: String?) -> AppDestination {
        guard let c = category else { return .appHome }
        switch c {
        case ModelCategory.math.rawValue: return .mathChat
        case ModelCategory.rag.rawValue: return .ragChat
        default: return .appHome
        }
    }

    private var modelDownloadBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Preparing AI Model")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(modelStore.loadingMessage.isEmpty ? "Loading..." : modelStore.loadingMessage)
                    .font(.system(size: 12))
                    .foregroundColor(secondaryText)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
