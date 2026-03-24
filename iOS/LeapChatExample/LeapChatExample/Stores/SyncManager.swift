import Foundation
import Network
import SwiftData

struct SyncRetryPolicy {
    static let maxAttempts = 5
    static let baseDelay: TimeInterval = 5
    static let maxDelay: TimeInterval = 300

    static func delay(for attempt: Int) -> TimeInterval {
        let exponential = baseDelay * pow(2.0, Double(attempt))
        return min(exponential, maxDelay)
    }
}

@Observable
class SyncManager {
    var isSyncing = false
    var lastSyncDate: Date?
    var syncProgress: Double = 0.0
    var syncError: String?
    var pendingCount: Int = 0
    private(set) var isNetworkAvailable = false

    @ObservationIgnored private let networkMonitor = NWPathMonitor()
    @ObservationIgnored private let monitorQueue = DispatchQueue(label: "com.leap.chat.networkMonitor")
    // Public so ChatStore can use the SAME context (critical for sync visibility)
    let sharedModelContext: ModelContext
    @ObservationIgnored private var urlSession: URLSession
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var autoSyncTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.sharedModelContext = modelContext

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)

        reconcileStuckMessages()
        updatePendingCount()
        startNetworkMonitoring()
        startAutoSync()
    }

    deinit {
        networkMonitor.cancel()
        syncTask?.cancel()
        autoSyncTask?.cancel()
    }

    /// Periodic auto-sync every 30 seconds
    private func startAutoSync() {
        autoSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { break }
                await MainActor.run {
                    self.updatePendingCount()
                    if self.pendingCount > 0 && !self.isSyncing {
                        self.triggerAutoSync()
                    }
                }
            }
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied
                if !wasAvailable && self.isNetworkAvailable {
                    self.triggerAutoSync()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Sync Operations

    @MainActor
    func performSync() async {
        guard !isSyncing else {
            print("[Sync] Already syncing, skipping")
            return
        }

        isSyncing = true
        syncError = nil
        syncProgress = 0.0

        defer {
            isSyncing = false
            updatePendingCount()
            print("[Sync] Done. Pending count: \(pendingCount)")
        }

        let unsyncedMessages = fetchUnsyncedMessages()
        guard !unsyncedMessages.isEmpty else {
            syncProgress = 1.0
            lastSyncDate = Date()
            print("[Sync] No unsynced messages")
            return
        }

        print("[Sync] Starting sync of \(unsyncedMessages.count) messages")

        // Check if a remote endpoint is configured
        let configDescriptor = FetchDescriptor<SyncConfiguration>()
        let hasRemoteEndpoint: Bool = {
            guard let config = try? sharedModelContext.fetch(configDescriptor).first,
                  let endpoint = config.teacherEndpointURL,
                  !endpoint.isEmpty else {
                return false
            }
            return true
        }()

        if hasRemoteEndpoint && isNetworkAvailable {
            // Remote sync via network
            let batches = createBatches(from: unsyncedMessages)
            let totalBatches = Double(batches.count)

            for (index, batch) in batches.enumerated() {
                markMessagesAsSyncing(batch)

                do {
                    let response = try await uploadBatch(batch)
                    handleSyncResponse(response, for: batch)
                } catch {
                    markMessagesAsFailed(batch, error: error.localizedDescription)
                }

                syncProgress = Double(index + 1) / totalBatches
            }
        } else {
            // Local sync — mark all unsynced as synced (same-device sharing via SwiftData)
            print("[Sync] Local sync mode — marking \(unsyncedMessages.count) messages as synced")
            for (index, message) in unsyncedMessages.enumerated() {
                message.syncStatus = MessageSyncStatus.synced.rawValue
                message.lastSyncAttempt = Date()

                // Update ChatSessionRecord
                let chatId = message.chatId
                let sessionDescriptor = FetchDescriptor<ChatSessionRecord>(
                    predicate: #Predicate<ChatSessionRecord> { $0.chatId == chatId }
                )
                if let session = try? sharedModelContext.fetch(sessionDescriptor).first {
                    if session.unsyncedCount > 0 {
                        session.unsyncedCount -= 1
                    }
                    session.lastSyncedAt = Date()
                }

                syncProgress = Double(index + 1) / Double(unsyncedMessages.count)
            }
            try? sharedModelContext.save()

            // Clear force-sync flag after successful sync
            if let config = try? sharedModelContext.fetch(configDescriptor).first, config.forceSyncRequested {
                config.forceSyncRequested = false
                config.forceSyncRequestedAt = nil
                try? sharedModelContext.save()
                print("[Sync] Force-sync flag cleared")
            }
        }

        lastSyncDate = Date()
        print("[Sync] Completed at \(lastSyncDate!)")
    }

    func updatePendingCount() {
        let descriptor = FetchDescriptor<SyncableMessage>(
            predicate: #Predicate<SyncableMessage> { message in
                message.syncStatus == "unsynced" || message.syncStatus == "failed"
            }
        )
        pendingCount = (try? sharedModelContext.fetchCount(descriptor)) ?? 0
    }

    func triggerAutoSync() {
        guard !isSyncing && pendingCount > 0 else { return }
        syncTask?.cancel()
        syncTask = Task {
            await performSync()
        }
    }

    // MARK: - Private Helpers

    private func reconcileStuckMessages() {
        let descriptor = FetchDescriptor<SyncableMessage>(
            predicate: #Predicate<SyncableMessage> { message in
                message.syncStatus == "syncing"
            }
        )
        guard let stuckMessages = try? sharedModelContext.fetch(descriptor) else { return }
        for message in stuckMessages {
            message.syncStatus = MessageSyncStatus.unsynced.rawValue
        }
        try? sharedModelContext.save()
    }

    private func fetchUnsyncedMessages() -> [SyncableMessage] {
        let descriptor = FetchDescriptor<SyncableMessage>(
            predicate: #Predicate<SyncableMessage> { message in
                message.syncStatus == "unsynced" || message.syncStatus == "failed"
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? sharedModelContext.fetch(descriptor)) ?? []
    }

    private func createBatches(from messages: [SyncableMessage]) -> [[SyncableMessage]] {
        var batches: [[SyncableMessage]] = []
        var currentBatch: [SyncableMessage] = []
        var imageCount = 0

        for message in messages {
            let hasImage = message.thumbnailData != nil
            let textLimit = 50
            let imageLimit = 10

            if hasImage {
                if imageCount >= imageLimit || currentBatch.count >= textLimit {
                    if !currentBatch.isEmpty {
                        batches.append(currentBatch)
                    }
                    currentBatch = [message]
                    imageCount = 1
                } else {
                    currentBatch.append(message)
                    imageCount += 1
                }
            } else {
                if currentBatch.count >= textLimit {
                    batches.append(currentBatch)
                    currentBatch = [message]
                    imageCount = 0
                } else {
                    currentBatch.append(message)
                }
            }
        }

        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }

        return batches
    }

    private func markMessagesAsSyncing(_ messages: [SyncableMessage]) {
        for message in messages {
            message.syncStatus = MessageSyncStatus.syncing.rawValue
        }
        try? sharedModelContext.save()
    }

    private func markMessagesAsFailed(_ messages: [SyncableMessage], error: String) {
        for message in messages {
            message.syncStatus = MessageSyncStatus.failed.rawValue
            message.syncAttempts += 1
            message.lastSyncAttempt = Date()
            message.syncError = error
        }
        try? sharedModelContext.save()
    }

    private func uploadBatch(_ messages: [SyncableMessage]) async throws -> SyncResponse {
        let configDescriptor = FetchDescriptor<SyncConfiguration>()
        guard let config = try? sharedModelContext.fetch(configDescriptor).first,
              let endpointString = config.teacherEndpointURL,
              let baseURL = URL(string: endpointString) else {
            throw SyncError.noEndpointConfigured
        }

        let url = baseURL.appendingPathComponent("/api/sync")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Group messages by chat
        var chatMessages: [UUID: [SyncableMessage]] = [:]
        for message in messages {
            chatMessages[message.chatId, default: []].append(message)
        }

        let deviceId = DeviceIdentifier.getOrCreate()

        var payloads: [ConversationPayload] = []
        for (chatId, chatMsgs) in chatMessages {
            let sessionDescriptor = FetchDescriptor<ChatSessionRecord>(
                predicate: #Predicate<ChatSessionRecord> { record in
                    record.chatId == chatId
                }
            )
            let session = try? sharedModelContext.fetch(sessionDescriptor).first

            let messagePayloads = chatMsgs.map { msg in
                SyncMessagePayload(
                    id: msg.messageId,
                    content: msg.content,
                    isUser: msg.isUser,
                    timestamp: msg.timestamp,
                    hasImage: msg.thumbnailData != nil,
                    thumbnailData: msg.thumbnailData,
                    thinkingTime: msg.thinkingTime,
                    sequenceNumber: msg.sequenceNumber
                )
            }

            let payload = ConversationPayload(
                studentId: session?.studentAccountId ?? UUID(),
                studentName: "",
                deviceId: deviceId,
                classroomCode: "",
                conversationId: chatId,
                conversationTitle: session?.title ?? "Untitled",
                modelUsed: session?.modelUsed,
                messages: messagePayloads,
                totalMessageCount: session?.messageCount ?? chatMsgs.count,
                timestamp: Date()
            )
            payloads.append(payload)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(payloads)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"payload\"; filename=\"payload.json\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append(jsonData)
        body.append("\r\n".data(using: .utf8)!)

        // Attach thumbnail images
        for message in messages {
            if let imageData = message.thumbnailData {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"image_\(message.messageId.uuidString)\"; filename=\"\(message.messageId.uuidString).jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n".data(using: .utf8)!)
            }
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, httpResponse) = try await urlSession.data(for: request)

        guard let response = httpResponse as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0
            throw SyncError.serverError(statusCode: statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncResponse.self, from: data)
    }

    private func handleSyncResponse(_ response: SyncResponse, for messages: [SyncableMessage]) {
        let acknowledgedSet = Set(response.acknowledged)
        let failedSet = Set(response.failed.map { $0.messageId })

        for message in messages {
            let idString = message.messageId.uuidString
            if acknowledgedSet.contains(idString) {
                message.syncStatus = MessageSyncStatus.synced.rawValue
                message.lastSyncAttempt = Date()
            } else if failedSet.contains(idString) {
                let failureReason = response.failed.first { $0.messageId == idString }?.error ?? "Unknown"
                message.syncStatus = MessageSyncStatus.failed.rawValue
                message.syncAttempts += 1
                message.lastSyncAttempt = Date()
                message.syncError = failureReason
            }
        }

        // Apply config updates from server
        if let configUpdate = response.configuration {
            let configDescriptor = FetchDescriptor<SyncConfiguration>()
            if let config = try? sharedModelContext.fetch(configDescriptor).first {
                if let maxMessages = configUpdate.maxUnsyncedMessages {
                    config.maxUnsyncedMessages = maxMessages
                }
                if let maxDuration = configUpdate.maxUnsyncedDuration {
                    config.maxUnsyncedDuration = maxDuration
                }
                if let enabled = configUpdate.isEnabled {
                    config.isEnabled = enabled
                }
                config.lastUpdatedAt = Date()
            }
        }

        try? sharedModelContext.save()
    }
}

// MARK: - Sync Errors

enum SyncError: LocalizedError {
    case noEndpointConfigured
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .noEndpointConfigured:
            return "No sync endpoint configured. Connect to a teacher first."
        case .serverError(let code):
            return "Server returned error (HTTP \(code))"
        }
    }
}
