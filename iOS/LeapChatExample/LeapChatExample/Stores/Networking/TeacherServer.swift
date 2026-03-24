import Foundation
import Network
import SwiftData

@Observable
class TeacherServer {
    var isRunning = false
    var port: UInt16?

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var advertiser: NWTXTRecord = NWTXTRecord()
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var activeConnections: [NWConnection] = []
    @ObservationIgnored private var classroomCode: String = ""

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    deinit {
        stop()
    }

    func start(classroomCode: String, teacherName: String) {
        guard !isRunning else { return }
        self.classroomCode = classroomCode

        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            let listener = try NWListener(using: parameters)

            // Configure Bonjour advertisement
            var txtRecord = NWTXTRecord()
            txtRecord["name"] = teacherName
            txtRecord["classroom"] = classroomCode
            listener.service = NWListener.Service(
                name: teacherName,
                type: "_leapchat._tcp",
                txtRecord: txtRecord
            )

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        if let port = self?.listener?.port?.rawValue {
                            self?.port = port
                        }
                    case .failed, .cancelled:
                        self?.isRunning = false
                        self?.port = nil
                    default:
                        break
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener.start(queue: .main)
            self.listener = listener
        } catch {
            isRunning = false
        }
    }

    func stop() {
        for connection in activeConnections {
            connection.cancel()
        }
        activeConnections.removeAll()
        listener?.cancel()
        listener = nil
        isRunning = false
        port = nil
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        activeConnections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                Task { @MainActor [weak self] in
                    self?.activeConnections.removeAll { $0 === connection }
                }
            default:
                break
            }
        }

        connection.start(queue: .main)
        receiveData(on: connection)
    }

    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self, let data else {
                if isComplete {
                    connection.cancel()
                }
                return
            }

            Task { @MainActor in
                self.processHTTPRequest(data: data, connection: connection)
            }

            if !isComplete && error == nil {
                self.receiveData(on: connection)
            }
        }
    }

    // MARK: - HTTP Processing

    @MainActor
    private func processHTTPRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: ["error": "Invalid request"])
            return
        }

        let parsed = parseHTTPRequest(requestString, rawData: data)

        switch (parsed.method, parsed.path) {
        case ("POST", "/api/sync"):
            handleSync(body: parsed.body, connection: connection)
        case ("GET", let path) where path.hasPrefix("/api/sync/status"):
            handleSyncStatus(query: parsed.query, connection: connection)
        case ("POST", "/api/register"):
            handleRegister(body: parsed.body, connection: connection)
        case ("GET", "/api/config"):
            handleGetConfig(connection: connection)
        default:
            sendResponse(connection: connection, statusCode: 404, body: ["error": "Not found"])
        }
    }

    // MARK: - Endpoint Handlers

    @MainActor
    private func handleSync(body: Data?, connection: NWConnection) {
        guard let body, let context = modelContext else {
            sendResponse(connection: connection, statusCode: 400, body: ["error": "Missing body"])
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let payloads = try? decoder.decode([ConversationPayload].self, from: body) else {
            sendResponse(connection: connection, statusCode: 400, body: ["error": "Invalid payload"])
            return
        }

        var acknowledged: [String] = []
        var failed: [SyncFailure] = []

        for payload in payloads {
            for messagePayload in payload.messages {
                let messageId = messagePayload.id
                let idString = messageId.uuidString

                // Deduplicate: check if already stored
                let existingDescriptor = FetchDescriptor<SyncableMessage>(
                    predicate: #Predicate<SyncableMessage> { msg in
                        msg.messageId == messageId
                    }
                )
                let existingCount = (try? context.fetchCount(existingDescriptor)) ?? 0

                if existingCount > 0 {
                    // Already have it — acknowledge without re-storing
                    acknowledged.append(idString)
                    continue
                }

                let syncMessage = SyncableMessage(
                    messageId: messageId,
                    chatId: payload.conversationId,
                    content: messagePayload.content,
                    isUser: messagePayload.isUser,
                    timestamp: messagePayload.timestamp,
                    thumbnailData: messagePayload.thumbnailData,
                    thinkingTime: messagePayload.thinkingTime,
                    syncStatus: .synced,
                    sequenceNumber: messagePayload.sequenceNumber
                )
                context.insert(syncMessage)
                acknowledged.append(idString)
            }

            // Update or create session record
            let convId = payload.conversationId
            let sessionDescriptor = FetchDescriptor<ChatSessionRecord>(
                predicate: #Predicate<ChatSessionRecord> { record in
                    record.chatId == convId
                }
            )
            if let existingSession = try? context.fetch(sessionDescriptor).first {
                existingSession.messageCount = payload.totalMessageCount
                existingSession.updatedAt = Date()
            } else {
                let record = ChatSessionRecord(
                    chatId: payload.conversationId,
                    studentAccountId: payload.studentId,
                    title: payload.conversationTitle,
                    modelUsed: payload.modelUsed,
                    messageCount: payload.totalMessageCount
                )
                context.insert(record)
            }
        }

        try? context.save()

        let response = SyncResponse(
            success: true,
            acknowledged: acknowledged,
            failed: failed,
            configuration: nil,
            serverTimestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let responseData = try? encoder.encode(response) {
            sendRawResponse(connection: connection, statusCode: 200, jsonData: responseData)
        } else {
            sendResponse(connection: connection, statusCode: 500, body: ["error": "Encoding failed"])
        }
    }

    @MainActor
    private func handleSyncStatus(query: [String: String], connection: NWConnection) {
        guard let studentIdString = query["studentId"],
              let studentId = UUID(uuidString: studentIdString),
              let context = modelContext else {
            sendResponse(connection: connection, statusCode: 400, body: ["error": "Missing studentId"])
            return
        }

        let descriptor = FetchDescriptor<SyncableMessage>(
            predicate: #Predicate<SyncableMessage> { message in
                message.syncStatus == "unsynced" || message.syncStatus == "failed"
            }
        )
        let unsyncedCount = (try? context.fetchCount(descriptor)) ?? 0

        let statusResponse = SyncStatusResponse(
            isSyncRequired: unsyncedCount > 0,
            unsyncedCount: unsyncedCount,
            lastSyncTimestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(statusResponse) {
            sendRawResponse(connection: connection, statusCode: 200, jsonData: data)
        } else {
            sendResponse(connection: connection, statusCode: 500, body: ["error": "Encoding failed"])
        }
    }

    @MainActor
    private func handleRegister(body: Data?, connection: NWConnection) {
        // Accept registration — in a full implementation, store student device info
        sendResponse(connection: connection, statusCode: 200, body: [
            "success": true,
            "message": "Registered successfully"
        ])
    }

    @MainActor
    private func handleGetConfig(connection: NWConnection) {
        guard let context = modelContext else {
            sendResponse(connection: connection, statusCode: 500, body: ["error": "No context"])
            return
        }

        let descriptor = FetchDescriptor<SyncConfiguration>()
        let config = (try? context.fetch(descriptor).first) ?? SyncConfiguration.defaultConfiguration()

        let configUpdate = SyncConfigUpdate(
            maxUnsyncedMessages: config.maxUnsyncedMessages,
            maxUnsyncedDuration: config.maxUnsyncedDuration,
            isEnabled: config.isEnabled
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(configUpdate) {
            sendRawResponse(connection: connection, statusCode: 200, jsonData: data)
        } else {
            sendResponse(connection: connection, statusCode: 500, body: ["error": "Encoding failed"])
        }
    }

    // MARK: - HTTP Parsing

    private struct HTTPRequest {
        let method: String
        let path: String
        let query: [String: String]
        let headers: [String: String]
        let body: Data?
    }

    private func parseHTTPRequest(_ request: String, rawData: Data) -> HTTPRequest {
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return HTTPRequest(method: "", path: "", query: [:], headers: [:], body: nil)
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        let method = parts.count > 0 ? String(parts[0]) : ""
        let fullPath = parts.count > 1 ? String(parts[1]) : ""

        // Parse path and query string
        var path = fullPath
        var queryParams: [String: String] = [:]
        if let queryIndex = fullPath.firstIndex(of: "?") {
            path = String(fullPath[fullPath.startIndex..<queryIndex])
            let queryString = String(fullPath[fullPath.index(after: queryIndex)...])
            for param in queryString.split(separator: "&") {
                let keyValue = param.split(separator: "=", maxSplits: 1)
                if keyValue.count == 2 {
                    let key = String(keyValue[0]).removingPercentEncoding ?? String(keyValue[0])
                    let value = String(keyValue[1]).removingPercentEncoding ?? String(keyValue[1])
                    queryParams[key] = value
                }
            }
        }

        // Parse headers
        var headers: [String: String] = [:]
        var bodyStartIndex: String.Index?
        for i in 1..<lines.count {
            let line = lines[i]
            if line.isEmpty {
                // Body starts after the blank line
                if i + 1 < lines.count {
                    let headerSection = lines[0...i].joined(separator: "\r\n") + "\r\n"
                    if let range = request.range(of: headerSection) {
                        bodyStartIndex = range.upperBound
                    }
                }
                break
            }
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                let key = String(headerParts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(headerParts[1]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        // Extract body
        var body: Data?
        if let bodyIndex = bodyStartIndex {
            let bodyString = String(request[bodyIndex...])
            body = bodyString.data(using: .utf8)
        }

        return HTTPRequest(method: method, path: path, query: queryParams, headers: headers, body: body)
    }

    // MARK: - HTTP Response

    private func sendResponse(connection: NWConnection, statusCode: Int, body: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }
        sendRawResponse(connection: connection, statusCode: statusCode, jsonData: jsonData)
    }

    private func sendRawResponse(connection: NWConnection, statusCode: Int, jsonData: Data) {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        response += "Content-Type: application/json\r\n"
        response += "Content-Length: \(jsonData.count)\r\n"
        response += "Connection: close\r\n"
        response += "\r\n"

        var responseData = response.data(using: .utf8)!
        responseData.append(jsonData)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
