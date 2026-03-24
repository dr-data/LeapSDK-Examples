import Foundation

@Observable
class RecentChatStore {
    var recentChats: [RecentChat] = []

    init() {
        load()
    }

    // MARK: - Active chats (non-archived)

    var activeChats: [RecentChat] {
        recentChats.filter { !$0.isArchived }
    }

    func activeChats(for category: String) -> [RecentChat] {
        recentChats.filter { $0.category == category && !$0.isArchived }
    }

    // MARK: - Student-specific queries (for teacher dashboard)

    func chatsForStudent(accountId: UUID) -> [RecentChat] {
        recentChats.filter { $0.studentAccountId == accountId }
    }

    func activeChatsForStudent(accountId: UUID) -> [RecentChat] {
        recentChats.filter { $0.studentAccountId == accountId && !$0.isArchived }
    }

    func totalMessageCount(forStudent accountId: UUID) -> Int {
        chatsForStudent(accountId: accountId).reduce(0) { $0 + $1.messages.count }
    }

    // MARK: - CRUD

    func addChat(id: UUID? = nil, title: String, category: String? = nil, studentAccountId: UUID? = nil, messages: [MessageBubble] = []) {
        let chat = RecentChat(
            id: id ?? UUID(),
            title: title,
            timestamp: Date(),
            category: category,
            studentAccountId: studentAccountId,
            messages: messages
        )
        recentChats.insert(chat, at: 0)
        if recentChats.count > 200 {
            recentChats = Array(recentChats.prefix(200))
        }
        save()
        print("[RecentChatStore] Added chat '\(title)' studentId=\(studentAccountId?.uuidString ?? "NIL") category=\(category ?? "nil") total=\(recentChats.count)")
    }

    func updateMessages(for chatId: UUID, messages: [MessageBubble]) {
        guard let index = recentChats.firstIndex(where: { $0.id == chatId }) else { return }
        recentChats[index].messages = messages
        save()
    }

    func archiveChat(id: UUID) {
        guard let index = recentChats.firstIndex(where: { $0.id == id }) else { return }
        recentChats[index].isArchived = true
        save()
    }

    func unarchiveChat(id: UUID) {
        guard let index = recentChats.firstIndex(where: { $0.id == id }) else { return }
        recentChats[index].isArchived = false
        save()
    }

    func deleteChat(id: UUID) {
        recentChats.removeAll { $0.id == id }
        save()
    }

    func chat(for id: UUID) -> RecentChat? {
        recentChats.first(where: { $0.id == id })
    }

    // MARK: - Persistence

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
