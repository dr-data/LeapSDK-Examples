import SwiftUI

@main
struct LeapChatExampleApp: App {
    @State private var modelStore = ModelStore()
    @State private var promptStore = PromptStore()
    @State private var customBackendStore = CustomBackendStore()
    @State private var recentChatStore = RecentChatStore()

    var body: some Scene {
        WindowGroup {
            AppHomeView()
                .environment(modelStore)
                .environment(promptStore)
                .environment(customBackendStore)
                .environment(recentChatStore)
                .preferredColorScheme(.dark)
        }
    }
}
