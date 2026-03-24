import Foundation
import SwiftData

enum MessageSyncStatus: String, Codable {
    case unsynced
    case syncing
    case synced
    case failed
}

@Model
final class SyncableMessage {
    @Attribute(.unique) var messageId: UUID
    var chatId: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date
    var thumbnailData: Data?
    var thinkingTime: Int?
    var syncStatus: String
    var syncAttempts: Int
    var lastSyncAttempt: Date?
    var syncError: String?
    var sequenceNumber: Int

    var status: MessageSyncStatus {
        MessageSyncStatus(rawValue: syncStatus) ?? .unsynced
    }

    init(
        messageId: UUID = UUID(),
        chatId: UUID,
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        thumbnailData: Data? = nil,
        thinkingTime: Int? = nil,
        syncStatus: MessageSyncStatus = .unsynced,
        syncAttempts: Int = 0,
        lastSyncAttempt: Date? = nil,
        syncError: String? = nil,
        sequenceNumber: Int = 0
    ) {
        self.messageId = messageId
        self.chatId = chatId
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.thumbnailData = thumbnailData
        self.thinkingTime = thinkingTime
        self.syncStatus = syncStatus.rawValue
        self.syncAttempts = syncAttempts
        self.lastSyncAttempt = lastSyncAttempt
        self.syncError = syncError
        self.sequenceNumber = sequenceNumber
    }
}
