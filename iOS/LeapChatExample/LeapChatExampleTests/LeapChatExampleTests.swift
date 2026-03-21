import Testing
import UIKit

@testable import LeapChatExample

// MARK: - MessageBubble Tests

struct MessageBubbleTests {

    @Test func testMessageBubbleCreation() {
        let bubble = MessageBubble(content: "Hello", isUser: true)
        #expect(bubble.content == "Hello")
        #expect(bubble.isUser == true)
        #expect(bubble.image == nil)
        #expect(bubble.thinkingTime == nil)
    }

    @Test func testMessageBubbleWithImage() {
        let image = UIImage(systemName: "star")!
        let bubble = MessageBubble(content: "With image", isUser: false, image: image)
        #expect(bubble.image != nil)
        #expect(bubble.content == "With image")
        #expect(bubble.isUser == false)
    }

    @Test func testMessageBubbleWithThinkingTime() {
        let bubble = MessageBubble(content: "Response", isUser: false, thinkingTime: 37)
        #expect(bubble.thinkingTime == 37)
        #expect(bubble.isUser == false)
    }

    @Test func testMessageBubbleUniqueIds() {
        let bubble1 = MessageBubble(content: "A", isUser: true)
        let bubble2 = MessageBubble(content: "B", isUser: false)
        #expect(bubble1.id != bubble2.id)
    }

    @Test func testMessageBubbleTimestamp() {
        let before = Date()
        let bubble = MessageBubble(content: "Test", isUser: true)
        let after = Date()
        #expect(bubble.timestamp >= before)
        #expect(bubble.timestamp <= after)
    }
}

// MARK: - ModelCatalog Tests

struct ModelCatalogTests {

    @Test func testAllModelsNotEmpty() {
        #expect(!ModelCatalog.allModels.isEmpty)
    }

    @Test func testModelsForCategory() {
        for category in ModelCategory.allCases {
            let models = ModelCatalog.models(for: category)
            for model in models {
                #expect(model.category == category)
            }
        }
    }

    @Test func testChatModelsCount() {
        let chatModels = ModelCatalog.models(for: .chat)
        #expect(chatModels.count == 9)
    }

    @Test func testModelDefinitionEquality() {
        let models = ModelCatalog.allModels
        guard models.count >= 2 else { return }
        let model1 = models[0]
        let model1Copy = models[0]
        let model2 = models[1]
        #expect(model1 == model1Copy)
        #expect(model1 != model2)
    }

    @Test func testQuantizationOptionIdentifiable() {
        let quant = QuantizationOption(name: "Q4_0", fileSize: "1.4 GB")
        #expect(quant.id == quant.name)
        #expect(quant.id == "Q4_0")
    }
}

// MARK: - DownloadStatus Tests

struct DownloadStatusTests {

    @Test func testDownloadStatusEquality() {
        #expect(DownloadStatus.notDownloaded == DownloadStatus.notDownloaded)
        #expect(DownloadStatus.downloaded == DownloadStatus.downloaded)
        #expect(DownloadStatus.downloading(progress: 0.5) == DownloadStatus.downloading(progress: 0.5))
        #expect(
            DownloadStatus.failed(message: "error") == DownloadStatus.failed(message: "error"))
    }

    @Test func testDownloadStatusNotEqual() {
        #expect(DownloadStatus.notDownloaded != DownloadStatus.downloaded)
        #expect(
            DownloadStatus.downloading(progress: 0.3) != DownloadStatus.downloading(progress: 0.7))
        #expect(DownloadStatus.notDownloaded != DownloadStatus.downloading(progress: 0.0))
        #expect(
            DownloadStatus.failed(message: "a") != DownloadStatus.failed(message: "b"))
        #expect(DownloadStatus.downloaded != DownloadStatus.failed(message: "x"))
    }
}

// MARK: - AIProvider Tests

struct AIProviderTests {

    @Test func testAllProvidersCount() {
        #expect(AIProvider.allProviders.count == 3)
    }

    @Test func testLocalProviderAvailable() {
        let local = AIProvider.allProviders.first { $0.id == "local" }
        #expect(local != nil)
        #expect(local!.isAvailable == true)
    }

    @Test func testAllProvidersAvailable() {
        for provider in AIProvider.allProviders {
            #expect(provider.isAvailable == true)
        }
    }

    @Test func testProviderIds() {
        let ids = AIProvider.allProviders.map(\.id)
        #expect(ids.contains("openrouter"))
        #expect(ids.contains("local"))
        #expect(ids.contains("custom"))
    }
}

// MARK: - PromptStore Tests

struct PromptStoreTests {

    @Test func testDefaultValues() {
        let store = PromptStore()
        #expect(store.title == "Apollo")
        #expect(store.systemPrompt.contains("Apollo"))
        #expect(store.fileInstructionEnabled == false)
        #expect(store.imageInstructionEnabled == false)
        #expect(store.audioInstructionEnabled == false)
    }

    @Test func testMutableProperties() {
        let store = PromptStore()
        store.title = "Custom"
        store.systemPrompt = "You are a test bot."
        #expect(store.title == "Custom")
        #expect(store.systemPrompt == "You are a test bot.")
    }
}

// MARK: - ChatStore Tests

struct ChatStoreTests {

    @Test func testInitialState() {
        let store = ChatStore()
        #expect(store.input == "")
        #expect(store.messages.isEmpty)
        #expect(store.isLoading == false)
        #expect(store.attachedImage == nil)
    }

    @Test func testRemoveAttachedImage() {
        let store = ChatStore()
        store.attachedImage = UIImage(systemName: "star")
        #expect(store.attachedImage != nil)
        store.removeAttachedImage()
        #expect(store.attachedImage == nil)
    }

    @Test @MainActor func testSendGuardNoConversation() async {
        let store = ChatStore()
        store.input = "Hello"
        await store.send()
        #expect(store.messages.count == 2)
        #expect(store.messages[0].isUser == true)
        #expect(store.messages[0].content == "Hello")
        #expect(store.messages[1].isUser == false)
        #expect(store.messages[1].content.contains("physical device"))
    }

    @Test @MainActor func testSendGuardEmptyInput() async {
        let store = ChatStore()
        store.input = ""
        await store.send()
        #expect(store.messages.isEmpty)
    }

    @Test func testIsImageLoadingInitiallyFalse() {
        let store = ChatStore()
        #expect(store.isImageLoading == false)
    }

    @Test @MainActor func testSendImageOnlyNoConversation() async {
        let store = ChatStore()
        store.attachedImage = UIImage(systemName: "star")
        await store.send()
        #expect(store.messages.count == 2)
        #expect(store.messages[0].content == "[Image]")
        #expect(store.messages[0].image != nil)
        #expect(store.messages[0].isUser == true)
        #expect(store.messages[1].isUser == false)
        #expect(store.messages[1].content.contains("physical device"))
        #expect(store.attachedImage == nil)
    }

    @Test @MainActor func testSendWithMLXNotLoaded() async {
        let store = ChatStore()
        store.mlxService = MLXModelService()
        store.input = "Hello"
        await store.send()
        #expect(store.messages.count == 2)
        #expect(store.messages[0].isUser == true)
        #expect(store.messages[1].content.contains("still loading"))
    }

    @Test @MainActor func testSendEmptyInputNoImage() async {
        let store = ChatStore()
        store.input = "   "
        await store.send()
        #expect(store.messages.isEmpty)
    }
}

// MARK: - ModelStore Tests

struct ModelStoreTests {

    @Test func testInitialState() {
        let store = ModelStore()
        #expect(store.activeModelRunner == nil)
        #expect(store.activeModel == nil)
        #expect(store.isLoading == false)
    }

    @Test func testDownloadKey() {
        let store = ModelStore()
        let model = ModelCatalog.allModels[0]
        let quant = model.quantizations[0]
        let key = store.downloadKey(model: model, quantization: quant)
        #expect(key == "\(model.id)_\(quant.name)")
    }

    @Test func testStatusDefault() {
        let store = ModelStore()
        let model = ModelCatalog.allModels[0]
        let quant = model.quantizations[0]
        let status = store.status(for: model, quantization: quant)
        #expect(status == .notDownloaded)
    }

    @Test func testIsModelDownloaded() {
        let store = ModelStore()
        let model = ModelCatalog.allModels[0]
        #expect(store.isModelDownloaded(model) == false)
    }
}

// MARK: - CustomBackend Tests

struct CustomBackendTests {

    @Test func testDefaultValues() {
        let backend = CustomBackend()
        #expect(backend.name == "Custom Backend")
        #expect(backend.baseURL == "")
        #expect(backend.chatPath == "/v1/chat/completions")
        #expect(backend.modelsPath == "/v1/models")
        #expect(backend.authType == .bearerToken)
        #expect(backend.authToken == "")
        #expect(backend.customModelId == "")
    }

    @Test func testAuthTypeCases() {
        let allCases = AuthType.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.bearerToken))
        #expect(allCases.contains(.apiKey))
        #expect(allCases.contains(.none))
    }

    @Test func testAuthTypeRawValues() {
        #expect(AuthType.bearerToken.rawValue == "Bearer Token")
        #expect(AuthType.apiKey.rawValue == "API Key")
        #expect(AuthType.none.rawValue == "None")
    }

    @Test func testCustomBackendHashable() {
        let backend1 = CustomBackend()
        var backend2 = CustomBackend()
        backend2.name = "Other"
        #expect(backend1 != backend2)
    }
}

// MARK: - CustomBackendStore Tests

struct CustomBackendStoreTests {

    @Test func testAddBackend() {
        let store = CustomBackendStore()
        store.backends = []
        var backend = CustomBackend()
        backend.name = "Test Server"
        backend.baseURL = "http://localhost:8080"
        store.addBackend(backend)
        #expect(store.backends.count == 1)
        #expect(store.backends[0].name == "Test Server")
    }

    @Test func testDeleteBackend() {
        let store = CustomBackendStore()
        store.backends = []
        let backend = CustomBackend()
        store.addBackend(backend)
        #expect(store.backends.count == 1)
        store.deleteBackend(backend)
        #expect(store.backends.isEmpty)
    }

    @Test func testUpdateBackend() {
        let store = CustomBackendStore()
        store.backends = []
        var backend = CustomBackend()
        backend.name = "Original"
        store.addBackend(backend)
        var updated = store.backends[0]
        updated.name = "Updated"
        store.updateBackend(updated)
        #expect(store.backends[0].name == "Updated")
    }

    @Test func testSaveOpenRouterKey() {
        let store = CustomBackendStore()
        store.saveOpenRouterKey("sk-test-key")
        #expect(store.openRouterAPIKey == "sk-test-key")
        #expect(store.isOpenRouterLoggedIn == true)
    }

    @Test func testEmptyOpenRouterKey() {
        let store = CustomBackendStore()
        store.saveOpenRouterKey("")
        #expect(store.openRouterAPIKey == "")
        #expect(store.isOpenRouterLoggedIn == false)
    }
}

// MARK: - RecentChat Tests

struct RecentChatTests {

    @Test func testRecentChatCreation() {
        let chat = RecentChat(id: UUID(), title: "Test Chat", timestamp: Date())
        #expect(chat.title == "Test Chat")
        #expect(!chat.timeAgo.isEmpty)
    }

    @Test func testRecentChatHashable() {
        let id = UUID()
        let chat1 = RecentChat(id: id, title: "Chat", timestamp: Date())
        let chat2 = RecentChat(id: id, title: "Chat", timestamp: Date())
        #expect(chat1 == chat2)
    }
}

// MARK: - RecentChatStore Tests

struct RecentChatStoreTests {

    @Test func testAddChat() {
        let store = RecentChatStore()
        store.recentChats = []
        store.addChat(title: "What's quantum computing?")
        #expect(store.recentChats.count == 1)
        #expect(store.recentChats[0].title == "What's quantum computing?")
    }

    @Test func testAddChatInsertsAtFront() {
        let store = RecentChatStore()
        store.recentChats = []
        store.addChat(title: "First")
        store.addChat(title: "Second")
        #expect(store.recentChats[0].title == "Second")
        #expect(store.recentChats[1].title == "First")
    }

    @Test func testMaxRecentChats() {
        let store = RecentChatStore()
        store.recentChats = []
        for i in 0..<25 {
            store.addChat(title: "Chat \(i)")
        }
        #expect(store.recentChats.count == 20)
    }
}

// MARK: - AppDestination Tests

struct AppDestinationTests {

    @Test func testAppDestinationHashable() {
        let dest1 = AppDestination.aiProviders
        let dest2 = AppDestination.aiProviders
        #expect(dest1 == dest2)
    }

    @Test func testModelDetailDestination() {
        let model = ModelCatalog.allModels[0]
        let dest = AppDestination.modelDetail(model)
        if case .modelDetail(let m) = dest {
            #expect(m == model)
        } else {
            Issue.record("Expected modelDetail destination")
        }
    }
}
