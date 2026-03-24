import SwiftUI
import SwiftData

struct TeacherManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allStudents: [UserAccount]
    @Query private var allMessages: [SyncableMessage]
    @Query private var allSessions: [ChatSessionRecord]

    @State private var showBulkCreate = false
    @State private var showResetPassword = false
    @State private var newPassword = ""

    let teacher: UserAccount

    private let bgColor = Color(red: 0.067, green: 0.09, blue: 0.137)
    private let cardBg = Color(red: 0.098, green: 0.125, blue: 0.184)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    private var students: [UserAccount] {
        guard let classroomId = teacher.classroomId else { return [] }
        return allStudents
            .filter { $0.role == UserRole.student.rawValue && $0.classroomId == classroomId && $0.isActive }
            .sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                teacherInfoSection
                actionsSection
                studentsSection
            }
            .padding()
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle(teacher.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showBulkCreate) {
            StudentBulkCreateView(classroomId: teacher.classroomId ?? "", teacherAccountId: teacher.accountId)
        }
        .alert("New Password", isPresented: $showResetPassword) {
            Button("Copy") {
                UIPasteboard.general.string = newPassword
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("New password: \(newPassword)\n\nMake sure to share this with the teacher.")
        }
    }

    // MARK: - Teacher Info

    private var teacherInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Teacher Info")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                InfoRow(label: "Name", value: teacher.displayName)
                InfoRow(label: "Classcode", value: teacher.classcode)
                InfoRow(label: "Classroom ID", value: teacher.classroomId ?? "—")
                InfoRow(label: "Created", value: teacher.createdAt.formatted(date: .abbreviated, time: .omitted))
                HStack {
                    Text("Active")
                        .foregroundColor(secondaryText)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { teacher.isActive },
                        set: { teacher.isActive = $0 }
                    ))
                    .tint(.blue)
                }
            }
            .padding()
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                Button {
                    showBulkCreate = true
                } label: {
                    HStack {
                        Image(systemName: "person.3.fill")
                        Text("Add Students")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    resetPassword()
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Reset Password")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Students

    private var studentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Students (\(students.count))")
                .font(.headline)
                .foregroundColor(.white)

            if students.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 36))
                        .foregroundColor(secondaryText)
                    Text("No students in this classroom")
                        .foregroundColor(secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(students, id: \.accountId) { student in
                    StudentRow(
                        student: student,
                        lastSync: lastActivity(for: student),
                        unsyncedMessages: unsyncedCount(for: student),
                        totalConversations: conversationCount(for: student)
                    )
                    .padding()
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Helpers

    private func resetPassword() {
        let password = String((0..<8).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
        teacher.passwordHash = password
        newPassword = password
        showResetPassword = true
    }

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
