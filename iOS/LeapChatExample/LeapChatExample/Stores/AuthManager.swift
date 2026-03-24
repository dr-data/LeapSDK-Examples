import CryptoKit
import Foundation
import Security
import SwiftData

enum AuthError: LocalizedError {
    case invalidCredentials
    case accountDeactivated
    case accountNotFound

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid classcode or password."
        case .accountDeactivated:
            return "This account has been deactivated."
        case .accountNotFound:
            return "Account not found."
        }
    }
}

@Observable
class AuthManager {
    var currentUser: UserAccount?
    var generatedAdminPasswords: [String: String]?

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var isFirstLaunch: Bool {
        let descriptor = FetchDescriptor<UserAccount>(
            predicate: #Predicate { $0.role == "admin" }
        )
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count == 0
    }

    private let modelContext: ModelContext
    private static let keychainKey = "com.leap.chat.session"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Authentication

    func login(classcode: String, password: String) throws -> UserAccount {
        let descriptor = FetchDescriptor<UserAccount>(
            predicate: #Predicate { $0.classcode == classcode }
        )
        guard let account = try? modelContext.fetch(descriptor).first else {
            throw AuthError.invalidCredentials
        }
        guard account.isActive else {
            throw AuthError.accountDeactivated
        }
        let hashed = Self.hashPassword(password)
        guard account.passwordHash == hashed else {
            throw AuthError.invalidCredentials
        }
        currentUser = account
        saveSessionToKeychain(accountId: account.accountId.uuidString)
        return account
    }

    func logout() {
        currentUser = nil
        removeSessionFromKeychain()
    }

    func restoreSession() {
        guard let accountIdString = loadSessionFromKeychain(),
              let accountId = UUID(uuidString: accountIdString) else {
            return
        }
        let descriptor = FetchDescriptor<UserAccount>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let accounts = try? modelContext.fetch(descriptor),
              let account = accounts.first(where: { $0.accountId == accountId }) else {
            removeSessionFromKeychain()
            return
        }
        currentUser = account
    }

    // MARK: - Account Creation

    func seedAdminAccounts() {
        // Fixed test passwords for development
        let password1 = "Pass1234"
        let password2 = "Pass5678"

        let admin1 = UserAccount(
            classcode: "admin01",
            displayName: "Administrator 1",
            role: .admin,
            passwordHash: Self.hashPassword(password1)
        )
        let admin2 = UserAccount(
            classcode: "admin02",
            displayName: "Administrator 2",
            role: .admin,
            passwordHash: Self.hashPassword(password2)
        )

        modelContext.insert(admin1)
        modelContext.insert(admin2)

        // Pre-seed a test teacher and student for development
        let teacherPassword = "Teacher1"
        let teacherClassroom = "teacher01"
        let teacher = UserAccount(
            classcode: teacherClassroom,
            displayName: "Test Teacher",
            role: .teacher,
            passwordHash: Self.hashPassword(teacherPassword),
            classroomId: teacherClassroom,  // Teacher's classroomId = their own classcode
            createdBy: admin1.accountId
        )
        modelContext.insert(teacher)

        let studentPassword = "Student1"
        let student = UserAccount(
            classcode: "26f327",
            displayName: "Test Student",
            role: .student,
            passwordHash: Self.hashPassword(studentPassword),
            classroomId: teacherClassroom,  // Links to teacher's classroom
            createdBy: teacher.accountId
        )
        modelContext.insert(student)

        try? modelContext.save()

        generatedAdminPasswords = [
            "admin01": password1,
            "admin02": password2,
            "teacher01": teacherPassword,
            "26f327": studentPassword,
        ]
    }

    func createTeacherAccount(name: String, classcode: String) -> (account: UserAccount, password: String) {
        let password = Self.generateRandomPassword()
        let account = UserAccount(
            classcode: classcode,
            displayName: name,
            role: .teacher,
            passwordHash: Self.hashPassword(password),
            classroomId: classcode,  // Teacher's classroomId = their classcode
            createdBy: currentUser?.accountId
        )
        modelContext.insert(account)
        try? modelContext.save()
        return (account, password)
    }

    func createStudentAccount(
        displayName: String,
        year: Int,
        form: Int,
        number: Int,
        classroomId: String
    ) -> (account: UserAccount, password: String) {
        let classcode = String(format: "%02df%d%02d", year % 100, form, number)
        let password = Self.generateRandomPassword()
        let account = UserAccount(
            classcode: classcode,
            displayName: displayName,
            role: .student,
            passwordHash: Self.hashPassword(password),
            classroomId: classroomId,
            createdBy: currentUser?.accountId
        )
        modelContext.insert(account)
        try? modelContext.save()
        return (account, password)
    }

    func createStudentAccounts(
        year: Int,
        form: Int,
        numberRange: ClosedRange<Int>,
        classroomId: String
    ) -> [(account: UserAccount, password: String)] {
        var results: [(account: UserAccount, password: String)] = []
        for number in numberRange {
            let classcode = String(format: "%02df%d%02d", year % 100, form, number)
            let password = Self.generateRandomPassword()
            let account = UserAccount(
                classcode: classcode,
                displayName: "Student \(number)",
                role: .student,
                passwordHash: Self.hashPassword(password),
                classroomId: classroomId,
                createdBy: currentUser?.accountId
            )
            modelContext.insert(account)
            results.append((account, password))
        }
        try? modelContext.save()
        return results
    }

    // MARK: - Password Utilities

    static func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func generateRandomPassword(length: Int = 8) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    // MARK: - Keychain

    private func saveSessionToKeychain(accountId: String) {
        removeSessionFromKeychain()
        let data = Data(accountId.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadSessionFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func removeSessionFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.keychainKey,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
