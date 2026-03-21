import SwiftUI

struct MessageRow: View {
    let message: MessageBubble

    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
    private let dividerColor = Color(red: 0.059, green: 0.090, blue: 0.165)

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)

                VStack(alignment: .trailing, spacing: 8) {
                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !message.content.isEmpty {
                        Text(message.content)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let thinkingTime = message.thinkingTime, thinkingTime > 0 {
                        HStack(spacing: 4) {
                            Text("Thought for \(thinkingTime) seconds")
                                .font(.system(size: 13))
                                .foregroundColor(secondaryText)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(secondaryText)
                        }
                        .padding(.bottom, 2)
                    }

                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !message.content.isEmpty {
                        Text(message.content)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }

                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
    }
}
