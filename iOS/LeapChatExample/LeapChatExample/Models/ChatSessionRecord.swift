import Foundation
import SwiftData

@Model
final class ChatSessionRecord {
    @Attribute(.unique) var chatId: UUID
    var studentAccountId: UUID
    var title: String
    var modelUsed: String?
    var category: String?
    var createdAt: Date
    var updatedAt: Date
    var messageCount: Int
    var unsyncedCount: Int
    var lastSyncedAt: Date?

    init(
        chatId: UUID = UUID(),
        studentAccountId: UUID,
        title: String,
        modelUsed: String? = nil,
        category: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messageCount: Int = 0,
        unsyncedCount: Int = 0,
        lastSyncedAt: Date? = nil
    ) {
        self.chatId = chatId
        self.studentAccountId = studentAccountId
        self.title = title
        self.modelUsed = modelUsed
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.unsyncedCount = unsyncedCount
        self.lastSyncedAt = lastSyncedAt
    }
}
