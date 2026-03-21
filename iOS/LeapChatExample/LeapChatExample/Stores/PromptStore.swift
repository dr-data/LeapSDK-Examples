import SwiftUI

@Observable
class PromptStore {
  var title: String = "Apollo"
  var systemPrompt: String =
    "You are Apollo, a chat assistant made by Liquid AI for fully private and local large language models. You are chatting with a user via the Apollo iOS app. Your replies should be short and conversational. Do the requested task to the best of your ability."
  var fileInstructionEnabled: Bool = false
  var imageInstructionEnabled: Bool = false
  var audioInstructionEnabled: Bool = false
}
