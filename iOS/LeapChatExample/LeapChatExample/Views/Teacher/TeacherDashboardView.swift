import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

struct TeacherDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(RecentChatStore.self) private var recentChatStore
    @Query private var allStudents: [UserAccount]
    @Query private var syncConfigs: [SyncConfiguration]

    let classroomId: String
    let teacherAccountId: UUID

    @State private var showForceSyncAlert = false

    private var bgColor: Color { AppColors.background }
    private var cardBg: Color { AppColors.secondaryBackground }
    private var secondaryText: Color { AppColors.secondaryText }

    private var students: [UserAccount] {
        allStudents.filter { $0.role == UserRole.student.rawValue && $0.classroomId == classroomId && $0.isActive }
    }

    private var syncConfig: SyncConfiguration {
        syncConfigs.first ?? SyncConfiguration.defaultConfiguration()
    }

    // Read directly from RecentChatStore — the SAME data students write to
    // Include chats with matching studentAccountId OR chats with nil studentAccountId
    // (legacy chats created before the field was added)
    private var studentChats: [RecentChat] {
        let studentIds = Set(students.map { $0.accountId })
        return recentChatStore.recentChats.filter { chat in
            if let sid = chat.studentAccountId {
                return studentIds.contains(sid)
            }
            // Include chats without studentAccountId (legacy) — they're from students on this device
            return true
        }
    }

    private var todayMessageCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return studentChats
            .filter { $0.timestamp >= startOfDay }
            .reduce(0) { $0 + $1.messages.count }
    }

    private var onlineStudentCount: Int {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        return students.filter { $0.lastActiveAt != nil && $0.lastActiveAt! >= fiveMinutesAgo }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsSection
                    classroomInfoSection
                    forceSyncSection
                    settingsSection
                    navigationSection
                }
                .padding()
            }
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { authManager.logout() } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                print("[Teacher] ===== DASHBOARD DEBUG =====")
                print("[Teacher] classroomId=\(classroomId)")
                print("[Teacher] SwiftData students: \(allStudents.count) total, \(students.count) in classroom")
                for s in allStudents {
                    print("[Teacher]   \(s.displayName) role=\(s.role) classcode=\(s.classcode) classroomId=\(s.classroomId ?? "nil") active=\(s.lastActiveAt?.description ?? "never")")
                }
                print("[Teacher] RecentChatStore: \(recentChatStore.recentChats.count) total chats")
                for c in recentChatStore.recentChats {
                    print("[Teacher]   chat '\(c.title)' studentId=\(c.studentAccountId?.uuidString ?? "NIL") msgs=\(c.messages.count)")
                }
                print("[Teacher] Matched studentChats: \(studentChats.count)")
                print("[Teacher] ============================")
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Students", value: "\(students.count)", icon: "person.2.fill", color: .blue)
                StatCard(title: "Online Now", value: "\(onlineStudentCount)", icon: "circle.fill", color: .green)
                StatCard(title: "Messages Today", value: "\(todayMessageCount)", icon: "bubble.left.fill", color: .cyan)
                StatCard(title: "Total Chats", value: "\(studentChats.count)", icon: "text.bubble.fill", color: .purple)
            }
        }
    }

    // MARK: - Classroom Info

    private var classroomInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Classroom")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Classroom Code")
                            .font(.subheadline)
                            .foregroundColor(secondaryText)
                        Text(classroomId)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    if let qrImage = generateQRCode(from: classroomId) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Force Sync

    private var forceSyncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Control")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                if syncConfig.forceSyncRequested {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Force-sync active")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    Button {
                        syncConfig.forceSyncRequested = false
                        try? modelContext.save()
                    } label: {
                        Text("Cancel Force-Sync")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    Button { showForceSyncAlert = true } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            Text("Force All Students to Sync")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding()
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .alert("Force Sync", isPresented: $showForceSyncAlert) {
            Button("Force Sync", role: .destructive) {
                syncConfig.forceSyncRequested = true
                syncConfig.forceSyncRequestedAt = Date()
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All students will be blocked from chatting until they sync.")
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Settings")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 16) {
                Toggle("Force-Sync Enabled", isOn: Binding(
                    get: { syncConfig.isEnabled },
                    set: { syncConfig.isEnabled = $0; syncConfig.lastUpdatedAt = Date() }
                ))
                .tint(.blue)
                .foregroundColor(.white)

                Divider().overlay(Color(red: 0.2, green: 0.23, blue: 0.3))

                Stepper(value: Binding(
                    get: { syncConfig.maxUnsyncedMessages },
                    set: { syncConfig.maxUnsyncedMessages = $0; syncConfig.lastUpdatedAt = Date() }
                ), in: 5...50) {
                    HStack {
                        Text("Max Unsynced").foregroundColor(.white)
                        Spacer()
                        Text("\(syncConfig.maxUnsyncedMessages)").foregroundColor(secondaryText).monospacedDigit()
                    }
                }
            }
            .padding()
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        NavigationLink {
            TeacherStudentListView(classroomId: classroomId, students: students)
        } label: {
            HStack {
                Image(systemName: "person.3.fill")
                Text("View Students")
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - QR Code

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Teacher Student List (reads from RecentChatStore)

struct TeacherStudentListView: View {
    let classroomId: String
    let students: [UserAccount]
    @Environment(RecentChatStore.self) private var recentChatStore
    @State private var searchText = ""

    private var bgColor: Color { AppColors.background }
    private var cardBg: Color { AppColors.secondaryBackground }
    private var secondaryText: Color { AppColors.secondaryText }

    private var filteredStudents: [UserAccount] {
        if searchText.isEmpty { return students }
        return students.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.classcode.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filteredStudents, id: \.accountId) { student in
            NavigationLink {
                TeacherStudentChatsView(student: student)
            } label: {
                studentRow(student)
            }
            .listRowBackground(cardBg)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(bgColor.ignoresSafeArea())
        .navigationTitle("Students")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search by name or classcode")
    }

    private func chatsForStudentIncludingLegacy(_ student: UserAccount) -> [RecentChat] {
        let matched = recentChatStore.chatsForStudent(accountId: student.accountId)
        if !matched.isEmpty { return matched }
        return recentChatStore.recentChats.filter { $0.studentAccountId == nil }
    }

    private func studentRow(_ student: UserAccount) -> some View {
        let chats = chatsForStudentIncludingLegacy(student)
        let messageCount = chats.reduce(0) { $0 + $1.messages.count }
        let isOnline = student.lastActiveAt.map { Date().timeIntervalSince($0) < 300 } ?? false

        return HStack(spacing: 12) {
            Circle()
                .fill(isOnline ? .green : .gray)
                .frame(width: 10, height: 10)

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
                Text(student.classcode)
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(chats.count) chats")
                    .font(.caption2)
                    .foregroundColor(secondaryText)
                Text("\(messageCount) msgs")
                    .font(.caption2)
                    .foregroundColor(secondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Teacher Student Chats View (reads from RecentChatStore)

struct TeacherStudentChatsView: View {
    let student: UserAccount
    @Environment(RecentChatStore.self) private var recentChatStore

    private var bgColor: Color { AppColors.background }
    private var cardBg: Color { AppColors.secondaryBackground }
    private var secondaryText: Color { AppColors.secondaryText }

    private var chats: [RecentChat] {
        let matched = recentChatStore.chatsForStudent(accountId: student.accountId)
        if !matched.isEmpty { return matched }
        // Fallback: show chats without studentAccountId (legacy)
        return recentChatStore.recentChats.filter { $0.studentAccountId == nil }
    }

    var body: some View {
        Group {
            if chats.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(secondaryText)
                    Text("No conversations yet")
                        .font(.title3)
                        .foregroundColor(.white)
                    Text("\(student.displayName) hasn't started any chats.")
                        .font(.subheadline)
                        .foregroundColor(secondaryText)
                    Spacer()
                }
            } else {
                List(chats) { chat in
                    NavigationLink {
                        TeacherConvoDetailView(chat: chat, studentName: student.displayName)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconForCategory(chat.category))
                                .font(.system(size: 14))
                                .foregroundColor(.cyan)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(chat.title)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    if let cat = chat.category {
                                        Text(cat)
                                            .font(.system(size: 10))
                                            .foregroundColor(.cyan)
                                    }
                                    Text(chat.timeAgo)
                                        .font(.caption)
                                        .foregroundColor(secondaryText)
                                }
                            }

                            Spacer()

                            Text("\(chat.messages.count) msgs")
                                .font(.caption2)
                                .foregroundColor(secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(cardBg)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle(student.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func iconForCategory(_ category: String?) -> String {
        guard let c = category else { return "message" }
        switch c {
        case ModelCategory.math.rawValue: return "function"
        case ModelCategory.rag.rawValue: return "doc.text.magnifyingglass"
        case ModelCategory.vision.rawValue: return "eye"
        default: return "message"
        }
    }
}

// MARK: - Teacher Conversation Detail (reads messages from RecentChat)

struct TeacherConvoDetailView: View {
    let chat: RecentChat
    let studentName: String

    private var bgColor: Color { AppColors.background }
    private var secondaryText: Color { AppColors.secondaryText }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(chat.messages.enumerated()), id: \.offset) { _, message in
                    MessageRow(message: message)
                }
            }
            .padding()
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(chat.messages.count) messages")
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    private var cardBg: Color { AppColors.secondaryBackground }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
