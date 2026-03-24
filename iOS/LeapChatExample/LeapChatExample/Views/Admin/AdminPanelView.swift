import SwiftUI
import SwiftData

struct AdminPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Query private var allAccounts: [UserAccount]
    @Query private var allMessages: [SyncableMessage]

    @State private var showCreateTeacher = false

    private let bgColor = Color(red: 0.067, green: 0.09, blue: 0.137)
    private let cardBg = Color(red: 0.098, green: 0.125, blue: 0.184)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    private var teachers: [UserAccount] {
        allAccounts.filter { $0.role == UserRole.teacher.rawValue && $0.isActive }
    }

    private var totalStudents: Int {
        allAccounts.filter { $0.role == UserRole.student.rawValue && $0.isActive }.count
    }

    private var totalTeachers: Int {
        teachers.count
    }

    private var totalSyncedMessages: Int {
        allMessages.filter { $0.syncStatus == MessageSyncStatus.synced.rawValue }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    globalStatsSection
                    teachersSection
                }
                .padding()
            }
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        authManager.logout()
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $showCreateTeacher) {
                CreateTeacherSheet()
            }
        }
    }

    // MARK: - Global Stats

    private var globalStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Global Stats")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Students", value: "\(totalStudents)", icon: "person.fill", color: .blue)
                StatCard(title: "Teachers", value: "\(totalTeachers)", icon: "person.badge.key.fill", color: .purple)
                StatCard(title: "Synced", value: "\(totalSyncedMessages)", icon: "checkmark.circle.fill", color: .green)
            }
        }
    }

    // MARK: - Teachers Section

    private var teachersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Teachers")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showCreateTeacher = true
                } label: {
                    Label("Create Teacher", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if teachers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(secondaryText)
                    Text("No teachers yet")
                        .foregroundColor(secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(teachers, id: \.accountId) { teacher in
                    NavigationLink {
                        TeacherManagementView(teacher: teacher)
                    } label: {
                        TeacherCard(
                            teacher: teacher,
                            studentCount: studentCount(for: teacher),
                            messageCount: messageCount(for: teacher)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Data Helpers

    private func studentCount(for teacher: UserAccount) -> Int {
        guard let classroomId = teacher.classroomId else { return 0 }
        return allAccounts.filter { $0.role == UserRole.student.rawValue && $0.classroomId == classroomId && $0.isActive }.count
    }

    private func messageCount(for teacher: UserAccount) -> Int {
        guard let classroomId = teacher.classroomId else { return 0 }
        let studentIds = Set(
            allAccounts
                .filter { $0.role == UserRole.student.rawValue && $0.classroomId == classroomId }
                .map(\.accountId)
        )
        return allMessages.filter { msg in
            studentIds.contains(msg.chatId)
        }.count
    }
}

// MARK: - Teacher Card

struct TeacherCard: View {
    let teacher: UserAccount
    let studentCount: Int
    let messageCount: Int

    private let cardBg = Color(red: 0.098, green: 0.125, blue: 0.184)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.key.fill")
                .font(.title3)
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 4) {
                Text(teacher.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                HStack(spacing: 12) {
                    Label("\(studentCount) students", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                    Label("\(messageCount) messages", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(secondaryText)
        }
        .padding()
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Create Teacher Sheet

struct CreateTeacherSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var teacherName = ""
    @State private var generatedClasscode = ""
    @State private var generatedPassword = ""
    @State private var didCreate = false

    private let bgColor = Color(red: 0.067, green: 0.09, blue: 0.137)
    private let cardBg = Color(red: 0.098, green: 0.125, blue: 0.184)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if didCreate {
                    createdView
                } else {
                    createForm
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Create Teacher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var createForm: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Teacher Name")
                    .font(.subheadline)
                    .foregroundColor(secondaryText)
                TextField("Enter name", text: $teacherName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }

            Button {
                createTeacher()
            } label: {
                Text("Create")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(teacherName.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(teacherName.isEmpty)

            Spacer()
        }
    }

    private var createdView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Teacher Created")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                InfoRow(label: "Name", value: teacherName)
                InfoRow(label: "Classcode", value: generatedClasscode)
                InfoRow(label: "Password", value: generatedPassword)
            }
            .padding()
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                UIPasteboard.general.string = "Name: \(teacherName)\nClasscode: \(generatedClasscode)\nPassword: \(generatedPassword)"
            } label: {
                Label("Copy Credentials", systemImage: "doc.on.doc")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button("Done") { dismiss() }
                .foregroundColor(secondaryText)

            Spacer()
        }
    }

    private func createTeacher() {
        let classcode = "T\(String(format: "%05d", Int.random(in: 10000...99999)))"
        let password = String((0..<8).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })

        let teacher = UserAccount(
            classcode: classcode,
            displayName: teacherName,
            role: .teacher,
            passwordHash: password,
            classroomId: classcode
        )
        modelContext.insert(teacher)

        generatedClasscode = classcode
        generatedPassword = password
        didCreate = true
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(secondaryText)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .font(.system(.body, design: .monospaced))
        }
    }
}
