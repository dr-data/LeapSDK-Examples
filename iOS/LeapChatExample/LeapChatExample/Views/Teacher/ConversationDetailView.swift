import SwiftUI
import SwiftData

struct ConversationDetailView: View {
    @Query private var allMessages: [SyncableMessage]

    let session: ChatSessionRecord

    private let bgColor = Color(red: 0.067, green: 0.09, blue: 0.137)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    private var messages: [SyncableMessage] {
        allMessages
            .filter { $0.chatId == session.chatId }
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
    }

    private var dateRange: String {
        guard let first = messages.first, let last = messages.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        if Calendar.current.isDate(first.timestamp, inSameDayAs: last.timestamp) {
            return formatter.string(from: first.timestamp)
        }
        let dateOnly = DateFormatter()
        dateOnly.dateStyle = .medium
        return "\(dateOnly.string(from: first.timestamp)) – \(dateOnly.string(from: last.timestamp))"
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(messages, id: \.messageId) { message in
                    ReadOnlyMessageRow(message: message)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let model = session.modelUsed {
                        Label(model, systemImage: "cpu")
                    }
                    Label("\(messages.count) messages", systemImage: "bubble.left.fill")
                    if !dateRange.isEmpty {
                        Label(dateRange, systemImage: "calendar")
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(secondaryText)
                }
            }
        }
    }
}

// MARK: - Read-Only Message Row

struct ReadOnlyMessageRow: View {
    let message: SyncableMessage

    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)

                VStack(alignment: .trailing, spacing: 8) {
                    if let thumbnailData = message.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                        Image(uiImage: uiImage)
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

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(secondaryText)
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

                    if let thumbnailData = message.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                        Image(uiImage: uiImage)
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

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(secondaryText)
                }

                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
    }
}
