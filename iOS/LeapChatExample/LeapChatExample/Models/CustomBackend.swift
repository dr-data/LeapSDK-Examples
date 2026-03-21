import Foundation

enum AuthType: String, Codable, CaseIterable, Hashable {
    case bearerToken = "Bearer Token"
    case apiKey = "API Key"
    case none = "None"
}

struct CustomBackend: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String = "Custom Backend"
    var baseURL: String = ""
    var chatPath: String = "/v1/chat/completions"
    var modelsPath: String = "/v1/models"
    var authType: AuthType = .bearerToken
    var authToken: String = ""
    var customModelId: String = ""
}
