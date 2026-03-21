import Foundation

struct AIProvider: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let isAvailable: Bool

    static let allProviders: [AIProvider] = [
        AIProvider(id: "openrouter", name: "OpenRouter", icon: "arrow.triangle.branch", isAvailable: true),
        AIProvider(id: "local", name: "Local Model", icon: "lock.shield", isAvailable: true),
        AIProvider(id: "custom", name: "Custom Backends", icon: "server.rack", isAvailable: true),
    ]
}
