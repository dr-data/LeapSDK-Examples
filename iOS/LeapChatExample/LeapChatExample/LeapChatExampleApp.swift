import SwiftData
import SwiftUI

@main
struct LeapChatExampleApp: App {
    @State private var modelStore = ModelStore()
    @State private var promptStore = PromptStore()
    @State private var customBackendStore = CustomBackendStore()
    @State private var recentChatStore = RecentChatStore()
    @State private var authManager: AuthManager
    @State private var syncManager: SyncManager
    @State private var syncGate: SyncGate
    @State private var appSettings = AppSettings()

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            UserAccount.self,
            SyncableMessage.self,
            ChatSessionRecord.self,
            SyncConfiguration.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema migration failed — delete old store and retry
            print("[App] SwiftData migration failed: \(error). Deleting old store.")
            let storeURL = URL.applicationSupportDirectory.appendingPathComponent("default.store")
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            container = try! ModelContainer(for: schema, configurations: [config])
        }
        self.modelContainer = container

        // CRITICAL: Use the container's mainContext everywhere so all components
        // share the same ModelContext and see each other's changes
        let context = container.mainContext
        let manager = SyncManager(modelContext: context)
        let auth = AuthManager(modelContext: context)
        let gate = SyncGate(syncManager: manager, modelContext: context)

        self._authManager = State(initialValue: auth)
        self._syncManager = State(initialValue: manager)
        self._syncGate = State(initialValue: gate)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(modelStore)
                .environment(promptStore)
                .environment(customBackendStore)
                .environment(recentChatStore)
                .environment(authManager)
                .environment(syncManager)
                .environment(syncGate)
                .environment(appSettings)
                .modelContainer(modelContainer)
                .preferredColorScheme(appSettings.themeMode.colorScheme)
                .task {
                    authManager.restoreSession()
                    if authManager.isFirstLaunch {
                        authManager.seedAdminAccounts()
                    }
                    // Ensure SyncConfiguration exists
                    let context = modelContainer.mainContext
                    let configDescriptor = FetchDescriptor<SyncConfiguration>()
                    if (try? context.fetchCount(configDescriptor)) == 0 {
                        let config = SyncConfiguration.defaultConfiguration()
                        context.insert(config)
                        try? context.save()
                    }
                }
        }
    }
}

/// Root view that shows login or role-based home screen
struct RootView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isFirstLaunch, let passwords = authManager.generatedAdminPasswords {
                FirstLaunchView(passwords: passwords) {
                    authManager.generatedAdminPasswords = nil
                }
            } else if authManager.currentUser == nil {
                LoginView()
            } else if let user = authManager.currentUser {
                switch user.userRole {
                case .admin:
                    NavigationStack {
                        AdminPanelView()
                    }
                case .teacher:
                    NavigationStack {
                        TeacherDashboardView(
                            classroomId: user.classroomId ?? user.classcode,
                            teacherAccountId: user.accountId
                        )
                    }
                case .student:
                    AppHomeView()
                }
            }
        }
    }
}
