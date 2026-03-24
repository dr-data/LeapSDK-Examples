import Foundation

struct ConversationPayload: Codable {
    let studentId: UUID
    let studentName: String
    let deviceId: String
    let classroomCode: String
    let conversationId: UUID
    let conversationTitle: String
    let modelUsed: String?
    let messages: [SyncMessagePayload]
    let totalMessageCount: Int
    let timestamp: Date
}

struct SyncMessagePayload: Codable, Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let hasImage: Bool
    let thumbnailData: Data?
    let thinkingTime: Int?
    let sequenceNumber: Int
}

struct SyncResponse: Codable {
    let success: Bool
    let acknowledged: [String]
    let failed: [SyncFailure]
    let configuration: SyncConfigUpdate?
    let serverTimestamp: Date
}

struct SyncFailure: Codable {
    let messageId: String
    let error: String
}

struct SyncConfigUpdate: Codable {
    let maxUnsyncedMessages: Int?
    let maxUnsyncedDuration: TimeInterval?
    let isEnabled: Bool?
}

struct SyncStatusResponse: Codable {
    let isSyncRequired: Bool
    let unsyncedCount: Int
    let lastSyncTimestamp: Date?
}
