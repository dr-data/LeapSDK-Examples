import Foundation

@Observable
class RecentChatStore {
    var recentChats: [RecentChat] = []

    init() {
        load()
    }

    func addChat(id: UUID? = nil, title: String, category: String? = nil, messages: [MessageBubble] = []) {
        let chat = RecentChat(id: id ?? UUID(), title: title, timestamp: Date(), category: category, messages: messages)
        recentChats.insert(chat, at: 0)
        if recentChats.count > 20 {
            recentChats = Array(recentChats.prefix(20))
        }
        save()
    }

    func updateMessages(for chatId: UUID, messages: [MessageBubble]) {
        guard let index = recentChats.firstIndex(where: { $0.id == chatId }) else { return }
        recentChats[index].messages = messages
        save()
    }

    func chat(for id: UUID) -> RecentChat? {
        recentChats.first(where: { $0.id == id })
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: "recentChats"),
              let chats = try? JSONDecoder().decode([RecentChat].self, from: data) else { return }
        recentChats = chats
    }

    func save() {
        guard let data = try? JSONEncoder().encode(recentChats) else { return }
        UserDefaults.standard.set(data, forKey: "recentChats")
    }
}
