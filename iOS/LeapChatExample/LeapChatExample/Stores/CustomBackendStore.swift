import Foundation
import SwiftUI

@Observable
class CustomBackendStore {
    var backends: [CustomBackend] = []
    var openRouterAPIKey: String = ""
    var isOpenRouterLoggedIn: Bool = false

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

    func loadModels(for backend: CustomBackend) async -> [String] {
        return []
    }

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
