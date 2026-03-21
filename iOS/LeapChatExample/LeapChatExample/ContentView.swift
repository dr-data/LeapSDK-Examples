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

    private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    private var activeModelDisplayName: String {
        modelStore.activeModel?.name ?? "No Model"
    }

    private var activeQuantDisplayName: String {
        modelStore.activeQuantization?.name ?? ""
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                chatHeader

                if modelStore.activeModel == nil {
                    noModelSelectedView
                } else {
                    MessagesListView(store: store)
                    ChatInputView(store: store)
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
                recentChatStore.addChat(id: chatId, title: title, category: category, messages: store.messages)
            }
            store.onMessagesChanged = { chatId, messages in
                recentChatStore.updateMessages(for: chatId, messages: messages)
            }
        }
        .onChange(of: modelStore.activeModel?.id) { _, _ in
            if modelStore.isLlamaCppActive {
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
                store.configureWithModel(
                    runner: runner,
                    systemPrompt: promptStore.systemPrompt
                )
            } else if modelStore.activeModel != nil {
                store.configureWithoutRunner(systemPrompt: promptStore.systemPrompt)
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
}

#Preview {
    ContentView()
        .environment(ModelStore())
        .environment(PromptStore())
        .environment(CustomBackendStore())
        .environment(RecentChatStore())
}
