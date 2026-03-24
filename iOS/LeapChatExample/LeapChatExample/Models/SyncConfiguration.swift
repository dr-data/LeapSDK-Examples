import Foundation
import SwiftData

@Model
final class SyncConfiguration {
    @Attribute(.unique) var configId: UUID
    var maxUnsyncedMessages: Int
    var maxUnsyncedDuration: TimeInterval
    var isEnabled: Bool
    var teacherEndpointURL: String?
    var lastUpdatedAt: Date
    var forceSyncRequested: Bool
    var forceSyncRequestedAt: Date?

    init(
        configId: UUID = UUID(),
        maxUnsyncedMessages: Int = 10,
        maxUnsyncedDuration: TimeInterval = 3600,
        isEnabled: Bool = true,
        teacherEndpointURL: String? = nil,
        lastUpdatedAt: Date = Date(),
        forceSyncRequested: Bool = false,
        forceSyncRequestedAt: Date? = nil
    ) {
        self.configId = configId
        self.maxUnsyncedMessages = maxUnsyncedMessages
        self.maxUnsyncedDuration = maxUnsyncedDuration
        self.isEnabled = isEnabled
        self.teacherEndpointURL = teacherEndpointURL
        self.lastUpdatedAt = lastUpdatedAt
        self.forceSyncRequested = forceSyncRequested
        self.forceSyncRequestedAt = forceSyncRequestedAt
    }

    static func defaultConfiguration() -> SyncConfiguration {
        SyncConfiguration()
    }
}
