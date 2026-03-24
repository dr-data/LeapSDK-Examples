import SwiftUI
import SwiftData

struct StudentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allStudents: [UserAccount]
    @Query private var allMessages: [SyncableMessage]
    @Query private var allSessions: [ChatSessionRecord]

    @State private var searchText = ""
    @State private var sortOption: SortOption = .name

    let classroomId: String

    private let bgColor = Color(red: 0.067, green: 0.09, blue: 0.137)
    private let cardBg = Color(red: 0.098, green: 0.125, blue: 0.184)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case lastActivity = "Last Activity"
        case syncStatus = "Sync Status"
    }

    private var students: [UserAccount] {
        let filtered = allStudents.filter {
            $0.role == UserRole.student.rawValue && $0.classroomId == classroomId && $0.isActive
        }

        let searched: [UserAccount]
        if searchText.isEmpty {
            searched = filtered
        } else {
            searched = filtered.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.classcode.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .name:
            return searched.sorted { $0.displayName < $1.displayName }
        case .lastActivity:
            return searched.sorted { lastActivity(for: $0) > lastActivity(for: $1) }
        case .syncStatus:
            return searched.sorted { unsyncedCount(for: $0) > unsyncedCount(for: $1) }
        }
    }

    var body: some View {
        Group {
            if students.isEmpty && searchText.isEmpty {
                emptyState
            } else {
                List(students, id: \.accountId) { student in
                    NavigationLink {
                        StudentConversationsView(student: student)
                    } label: {
                        StudentRow(
                            student: student,
                            lastSync: lastActivity(for: student),
                            unsyncedMessages: unsyncedCount(for: student),
                            totalConversations: conversationCount(for: student)
                        )
                    }
                    .listRowBackground(cardBg)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle("Students")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search by name or classcode")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(secondaryText)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.slash")
                .font(.system(size: 48))
                .foregroundColor(secondaryText)
            Text("No students registered yet")
                .font(.title3)
                .foregroundColor(.white)
            Text("Students will appear here once they join your classroom.")
                .font(.subheadline)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Data Helpers

    private func lastActivity(for student: UserAccount) -> Date {
        let sessions = allSessions.filter { $0.studentAccountId == student.accountId }
        return sessions.map(\.updatedAt).max() ?? student.createdAt
    }

    private func unsyncedCount(for student: UserAccount) -> Int {
        let sessionIds = Set(allSessions.filter { $0.studentAccountId == student.accountId }.map(\.chatId))
        return allMessages.filter { sessionIds.contains($0.chatId) && $0.syncStatus == MessageSyncStatus.unsynced.rawValue }.count
    }

    private func conversationCount(for student: UserAccount) -> Int {
        allSessions.filter { $0.studentAccountId == student.accountId }.count
    }
}

// MARK: - Student Row

struct StudentRow: View {
    let student: UserAccount
    let lastSync: Date
    let unsyncedMessages: Int
    let totalConversations: Int

    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    private var isOnline: Bool {
        guard let lastActive = student.lastActiveAt else { return false }
        return Date().timeIntervalSince(lastActive) < 300 // 5 minutes
    }

    private var syncStatusColor: Color {
        if unsyncedMessages == 0 { return .green }
        if unsyncedMessages < 5 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(syncStatusColor)
                    .frame(width: 10, height: 10)
                if isOnline {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .offset(x: 6, y: -6)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(student.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    if isOnline {
                        Text("ONLINE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Text(student.classcode)
                        .font(.caption)
                        .foregroundColor(secondaryText)
                    Text("·")
                        .foregroundColor(secondaryText)
                    Text(lastSync, style: .relative)
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if unsyncedMessages > 0 {
                    Text("\(unsyncedMessages)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(syncStatusColor)
                        .clipShape(Capsule())
                }
                Text("\(totalConversations) chats")
                    .font(.caption2)
                    .foregroundColor(secondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}
