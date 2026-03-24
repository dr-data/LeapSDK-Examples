import SwiftUI
import SwiftData

struct StudentConversationsView: View {
    @Query private var allSessions: [ChatSessionRecord]
    @Query private var allMessages: [SyncableMessage]

    let student: UserAccount

    private let bgColor = Color(red: 0.067, green: 0.09, blue: 0.137)
    private let cardBg = Color(red: 0.098, green: 0.125, blue: 0.184)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    private var conversations: [ChatSessionRecord] {
        allSessions
            .filter { $0.studentAccountId == student.accountId }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        Group {
            if conversations.isEmpty {
                emptyState
            } else {
                List(conversations, id: \.chatId) { session in
                    NavigationLink {
                        ConversationDetailView(session: session)
                    } label: {
                        ConversationRow(
                            session: session,
                            syncedCount: syncedCount(for: session),
                            totalCount: totalMessageCount(for: session)
                        )
                    }
                    .listRowBackground(cardBg)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle("\(student.displayName)'s Conversations")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(secondaryText)
            Text("No conversations yet")
                .font(.title3)
                .foregroundColor(.white)
            Text("Conversations will appear here once this student starts chatting.")
                .font(.subheadline)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Data Helpers

    private func syncedCount(for session: ChatSessionRecord) -> Int {
        allMessages.filter { $0.chatId == session.chatId && $0.syncStatus == MessageSyncStatus.synced.rawValue }.count
    }

    private func totalMessageCount(for session: ChatSessionRecord) -> Int {
        allMessages.filter { $0.chatId == session.chatId }.count
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let session: ChatSessionRecord
    let syncedCount: Int
    let totalCount: Int

    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Text(session.updatedAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(secondaryText)
            }

            HStack(spacing: 12) {
                if let model = session.modelUsed {
                    Text(model)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.3))
                        .clipShape(Capsule())
                }

                Label("\(session.messageCount)", systemImage: "bubble.left.fill")
                    .font(.caption2)
                    .foregroundColor(secondaryText)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: syncedCount == totalCount ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundColor(syncedCount == totalCount ? .green : .orange)
                    Text("\(syncedCount)/\(totalCount)")
                        .font(.caption2)
                        .foregroundColor(secondaryText)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
