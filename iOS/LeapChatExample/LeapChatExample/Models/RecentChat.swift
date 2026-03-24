import Foundation

struct RecentChat: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let timestamp: Date
    var category: String?
    var studentAccountId: UUID?
    var isArchived: Bool
    var messages: [MessageBubble] = []

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    init(id: UUID = UUID(), title: String, timestamp: Date = Date(), category: String? = nil, studentAccountId: UUID? = nil, isArchived: Bool = false, messages: [MessageBubble] = []) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
        self.category = category
        self.studentAccountId = studentAccountId
        self.isArchived = isArchived
        self.messages = messages
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RecentChat, rhs: RecentChat) -> Bool {
        lhs.id == rhs.id
    }
}
