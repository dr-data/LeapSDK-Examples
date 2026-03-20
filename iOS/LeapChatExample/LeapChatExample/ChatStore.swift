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

  var conversation: Conversation?
  var modelRunner: ModelRunner?

  @MainActor
  func configureWithModel(runner: ModelRunner, systemPrompt: String?) {
    modelRunner = runner
    messages.removeAll()

    var history: [ChatMessage] = []
    if let systemPrompt, !systemPrompt.isEmpty {
      history.append(ChatMessage(role: .system, content: [.text(systemPrompt)]))
    }

    conversation = Conversation(modelRunner: runner, history: history)
    messages.append(
      MessageBubble(content: "Model loaded. You can start chatting.", isUser: false))
  }

  @MainActor
  func send() async {
    guard conversation != nil else { return }

    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty || attachedImage != nil else { return }

    // Create message content array
    var messageContent: [ChatMessageContent] = []

    // Add image if present
    if let image = attachedImage {
      do {
        let imageContent = try ChatMessageContent.fromUIImage(image)
        messageContent.append(imageContent)
      } catch {
        print("Error converting image: \(error)")
        return
      }
    }

    // Add text if present
    if !trimmed.isEmpty {
      messageContent.append(ChatMessageContent.text(trimmed))
    }

    let userMessage = ChatMessage(role: .user, content: messageContent)

    // Create display content for the message bubble
    var displayContent = trimmed
    if attachedImage != nil {
      displayContent = displayContent.isEmpty ? "[Image]" : "[Image] \(displayContent)"
    }

    messages.append(MessageBubble(content: displayContent, isUser: true, image: attachedImage))
    input = ""
    attachedImage = nil
    isLoading = true
    currentAssistantMessage = ""

    let stream = conversation!.generateResponse(message: userMessage, generationOptions: nil)
    do {
      for try await resp in stream {
        switch resp {
        case .reasoningChunk: break
        case .chunk(let str):
          currentAssistantMessage.append(str)
        case .audioSample:
          break
        case .complete(let completion):
          let finalText = completion.message.content.compactMap { content -> String? in
            if case .text(let text) = content {
              return text
            }
            return nil
          }.joined()
          if !finalText.isEmpty {
            currentAssistantMessage = finalText
          }
          if !currentAssistantMessage.isEmpty {
            messages.append(MessageBubble(content: currentAssistantMessage, isUser: false))
          }
          currentAssistantMessage = ""
          isLoading = false
        case .functionCall:
          break
        }
      }
    } catch {
      currentAssistantMessage = "Error: \(error.localizedDescription)"
      messages.append(MessageBubble(content: currentAssistantMessage, isUser: false))
      currentAssistantMessage = ""
      isLoading = false
    }
  }

  @MainActor
  func loadImageFrom(item: PhotosPickerItem) async {
    guard let data = try? await item.loadTransferable(type: Data.self),
      let image = UIImage(data: data)
    else {
      print("Failed to load image from PhotosPickerItem")
      return
    }
    attachedImage = image
  }

  func removeAttachedImage() {
    attachedImage = nil
  }
}
