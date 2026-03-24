import Foundation
import SwiftData

@Observable
class SyncGate {
    private(set) var isBlocked = false
    private(set) var blockReason: BlockReason?
    var isForceSyncing = false

    @ObservationIgnored private var syncManager: SyncManager
    // Use syncManager's shared context to ensure all components see the same data
    private var modelContext: ModelContext { syncManager.sharedModelContext }

    enum BlockReason {
        case tooManyUnsynced(count: Int, max: Int)
        case tooLongWithoutSync(elapsed: TimeInterval, max: TimeInterval)
        case forcedByTeacher

        var userMessage: String {
            switch self {
            case .tooManyUnsynced(let count, let max):
                return "You have \(count) unsynced messages (limit: \(max)). Please sync before continuing."
            case .tooLongWithoutSync(let elapsed, let max):
                let elapsedMinutes = Int(elapsed / 60)
                let maxMinutes = Int(max / 60)
                return "It has been \(elapsedMinutes) minutes since your last sync (limit: \(maxMinutes) minutes). Please sync to continue."
            case .forcedByTeacher:
                return "Your teacher has requested a sync. Please sync your messages to continue chatting."
            }
        }
    }

    init(syncManager: SyncManager, modelContext: ModelContext) {
        self.syncManager = syncManager
    }

    func canSend() -> Bool {
        let configDescriptor = FetchDescriptor<SyncConfiguration>()
        guard let config = try? modelContext.fetch(configDescriptor).first else {
            // No config means sync is not set up — allow sending
            isBlocked = false
            blockReason = nil
            return true
        }

        guard config.isEnabled else {
            isBlocked = false
            blockReason = nil
            return true
        }

        let currentPending = syncManager.pendingCount

        // Check teacher-initiated force sync
        if config.forceSyncRequested && currentPending > 0 {
            isBlocked = true
            blockReason = .forcedByTeacher
            return false
        }

        // Check pending message count
        if currentPending >= config.maxUnsyncedMessages {
            isBlocked = true
            blockReason = .tooManyUnsynced(count: currentPending, max: config.maxUnsyncedMessages)
            return false
        }

        // Check time since last sync
        if let lastSync = syncManager.lastSyncDate {
            let elapsed = Date().timeIntervalSince(lastSync)
            if elapsed >= config.maxUnsyncedDuration && currentPending > 0 {
                isBlocked = true
                blockReason = .tooLongWithoutSync(elapsed: elapsed, max: config.maxUnsyncedDuration)
                return false
            }
        } else if currentPending > 0 {
            // Never synced and has pending messages — check against a reasonable window
            let unsyncedDescriptor = FetchDescriptor<SyncableMessage>(
                predicate: #Predicate<SyncableMessage> { message in
                    message.syncStatus == "unsynced"
                },
                sortBy: [SortDescriptor(\.timestamp)]
            )
            if let oldestUnsynced = try? modelContext.fetch(unsyncedDescriptor).first {
                let elapsed = Date().timeIntervalSince(oldestUnsynced.timestamp)
                if elapsed >= config.maxUnsyncedDuration {
                    isBlocked = true
                    blockReason = .tooLongWithoutSync(elapsed: elapsed, max: config.maxUnsyncedDuration)
                    return false
                }
            }
        }

        isBlocked = false
        blockReason = nil
        return true
    }

    @MainActor
    func performForceSync() async -> Bool {
        isForceSyncing = true
        defer { isForceSyncing = false }

        await syncManager.performSync()
        syncManager.updatePendingCount()
        return canSend()
    }
}
