import Foundation
import SwiftUI

struct OpenRouterModel: Identifiable, Codable {
    var id: String
    var name: String
    var contextLength: Int?
    var pricing: Pricing?

    struct Pricing: Codable {
        var prompt: String?
        var completion: String?
    }
}

@Observable
class CustomBackendStore {
    var backends: [CustomBackend] = []
    var openRouterAPIKey: String = ""
    var isOpenRouterLoggedIn: Bool = false
    var openRouterModels: [OpenRouterModel] = []
    var isLoadingModels: Bool = false

    init() {
        load()
    }

    func addBackend(_ backend: CustomBackend = CustomBackend()) {
        backends.append(backend)
        save()
    }

    func updateBackend(_ backend: CustomBackend) {
        if let index = backends.firstIndex(where: { $0.id == backend.id }) {
            backends[index] = backend
            save()
        }
    }

    func deleteBackend(_ backend: CustomBackend) {
        backends.removeAll { $0.id == backend.id }
        save()
    }

    func saveOpenRouterKey(_ key: String) {
        openRouterAPIKey = key
        isOpenRouterLoggedIn = !key.isEmpty
        UserDefaults.standard.set(key, forKey: "openRouterAPIKey")
    }

    // MARK: - Model Loading

    func loadModels(for backend: CustomBackend) async -> [String] {
        guard !backend.baseURL.isEmpty,
              let url = URL(string: backend.baseURL + backend.modelsPath) else {
            return []
        }

        var request = URLRequest(url: url)
        switch backend.authType {
        case .bearerToken:
            request.setValue("Bearer \(backend.authToken)", forHTTPHeaderField: "Authorization")
        case .apiKey:
            request.setValue(backend.authToken, forHTTPHeaderField: "X-API-Key")
        case .none:
            break
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["data"] as? [[String: Any]] {
                return models.compactMap { $0["id"] as? String }
            }
        } catch {
            print("[Backend] Error loading models: \(error)")
        }
        return []
    }

    func loadOpenRouterModels() async {
        guard !openRouterAPIKey.isEmpty else { return }

        isLoadingModels = true
        defer { isLoadingModels = false }

        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(openRouterAPIKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("[OpenRouter] HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return
            }

            struct ModelsResponse: Codable {
                let data: [OpenRouterModel]
            }

            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            await MainActor.run {
                openRouterModels = decoded.data.sorted { $0.name < $1.name }
                print("[OpenRouter] Loaded \(openRouterModels.count) models")
            }
        } catch {
            print("[OpenRouter] Error: \(error)")
        }
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(backends) {
            UserDefaults.standard.set(data, forKey: "customBackends")
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: "customBackends"),
           let decoded = try? JSONDecoder().decode([CustomBackend].self, from: data) {
            backends = decoded
        }
        openRouterAPIKey = UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? ""
        isOpenRouterLoggedIn = !openRouterAPIKey.isEmpty
    }
}
