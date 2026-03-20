import SwiftUI

@main
struct LeapChatExampleApp: App {
  @State private var modelStore = ModelStore()
  @State private var promptStore = PromptStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(modelStore)
        .environment(promptStore)
        .preferredColorScheme(.dark)
    }
  }
}
