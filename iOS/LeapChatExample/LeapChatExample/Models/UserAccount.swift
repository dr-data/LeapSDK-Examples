import Foundation
import SwiftData

enum UserRole: String, Codable, CaseIterable {
    case student
    case teacher
    case admin
}

@Model
final class UserAccount {
    @Attribute(.unique) var accountId: UUID
    @Attribute(.unique) var classcode: String
    var displayName: String
    var role: String
    var passwordHash: String
    var classroomId: String?
    var createdBy: UUID?
    var createdAt: Date
    var isActive: Bool
    var lastActiveAt: Date?

    var userRole: UserRole {
        UserRole(rawValue: role) ?? .student
    }

    init(
        accountId: UUID = UUID(),
        classcode: String,
        displayName: String,
        role: UserRole = .student,
        passwordHash: String = "",
        classroomId: String? = nil,
        createdBy: UUID? = nil,
        createdAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.accountId = accountId
        self.classcode = classcode
        self.displayName = displayName
        self.role = role.rawValue
        self.passwordHash = passwordHash
        self.classroomId = classroomId
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.isActive = isActive
    }
}
