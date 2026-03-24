import Foundation

class CloudSyncService {
    private let baseURL: URL
    private let urlSession: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)
    }

    func syncMessages(_ payload: [ConversationPayload]) async throws -> SyncResponse {
        let url = baseURL.appendingPathComponent("api/sync")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        let (data, httpResponse) = try await urlSession.data(for: request)

        guard let response = httpResponse as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0
            throw CloudSyncError.serverError(statusCode: statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncResponse.self, from: data)
    }

    func checkStatus(studentId: UUID) async throws -> SyncStatusResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/sync/status"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "studentId", value: studentId.uuidString)]

        guard let url = components.url else {
            throw CloudSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, httpResponse) = try await urlSession.data(for: request)

        guard let response = httpResponse as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0
            throw CloudSyncError.serverError(statusCode: statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncStatusResponse.self, from: data)
    }

    func register(studentId: UUID, deviceId: String, classroomCode: String) async throws {
        let url = baseURL.appendingPathComponent("api/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "studentId": studentId.uuidString,
            "deviceId": deviceId,
            "classroomCode": classroomCode
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await urlSession.data(for: request)

        guard let response = httpResponse as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0
            throw CloudSyncError.serverError(statusCode: statusCode)
        }
    }

    func getConfig() async throws -> SyncConfigUpdate {
        let url = baseURL.appendingPathComponent("api/config")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, httpResponse) = try await urlSession.data(for: request)

        guard let response = httpResponse as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0
            throw CloudSyncError.serverError(statusCode: statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncConfigUpdate.self, from: data)
    }
}

enum CloudSyncError: LocalizedError {
    case invalidURL
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .serverError(let code):
            return "Cloud server returned error (HTTP \(code))"
        }
    }
}
