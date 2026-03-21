import SwiftUI

struct CustomBackendEditView: View {
    @Environment(CustomBackendStore.self) private var backendStore
    @Environment(\.dismiss) private var dismiss
    let existingBackend: CustomBackend?

    @State private var name = "Custom Backend"
    @State private var baseURL = ""
    @State private var chatPath = "/v1/chat/completions"
    @State private var modelsPath = "/v1/models"
    @State private var authType: AuthType = .bearerToken
    @State private var authToken = ""
    @State private var customModelId = ""
    @State private var showDeleteConfirmation = false
    @State private var isLoadingModels = false

    // MARK: - Colors

    private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
    private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
    private let accentCyan = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let deleteRed = Color(red: 0.937, green: 0.267, blue: 0.267)
    private let dividerColor = Color(red: 0.059, green: 0.090, blue: 0.165)

    private var isEditing: Bool { existingBackend != nil }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    descriptionSection
                    endpointSection
                    customModelSection
                    modelsSection
                    if isEditing {
                        dangerSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(accentCyan)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Custom Backend")
                    .font(.body.weight(.bold))
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveBackend()
                } label: {
                    Text("Save")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(accentCyan)
                        .clipShape(Capsule())
                }
            }
        }
        .onAppear {
            if let backend = existingBackend {
                name = backend.name
                baseURL = backend.baseURL
                chatPath = backend.chatPath
                modelsPath = backend.modelsPath
                authType = backend.authType
                authToken = backend.authToken
                customModelId = backend.customModelId
            }
        }
        .alert("Delete Backend", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let backend = existingBackend {
                    backendStore.deleteBackend(backend)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this backend? This action cannot be undone.")
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        Text("Field requirements will depend on your specific backend deployment.")
            .font(.system(size: 13))
            .foregroundColor(secondaryText)
    }

    // MARK: - Chat Completion Endpoint

    private var endpointSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CHAT COMPLETION ENDPOINT")

            VStack(spacing: 0) {
                formRow(label: "Name", value: $name, placeholder: "Custom Backend")
                formDivider
                formRow(label: "Base URL", value: $baseURL, placeholder: "http://192.168.1.100:123")
                formDivider
                formRow(label: "Chat Path", value: $chatPath, placeholder: "/v1/chat/completions")
                formDivider
                formRow(label: "Models Path", value: $modelsPath, placeholder: "/v1/models")
                formDivider
                authPickerRow
            }
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func formRow(label: String, value: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 90, alignment: .leading)

            TextField(placeholder, text: value)
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }

    private var authPickerRow: some View {
        HStack {
            Text("Auth")
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 90, alignment: .leading)

            Spacer()

            Picker("Auth", selection: $authType) {
                ForEach(AuthType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .tint(.white)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }

    private var formDivider: some View {
        dividerColor.frame(height: 1).padding(.leading, 16)
    }

    // MARK: - Custom Model Section

    private var customModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CUSTOM MODEL")

            TextField("model-id", text: $customModelId)
                .font(.body)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Specify your model identifier, or reload your custom models.")
                .font(.system(size: 13))
                .foregroundColor(secondaryText)
        }
    }

    // MARK: - Models Section

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("MODELS")

            Button {
                isLoadingModels = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isLoadingModels = false
                }
            } label: {
                HStack {
                    if isLoadingModels {
                        ProgressView()
                            .tint(secondaryText)
                        Text("Loading models...")
                            .font(.body)
                            .foregroundColor(secondaryText)
                    } else {
                        Text("Tap to load models")
                            .font(.body)
                            .foregroundColor(secondaryText)
                    }

                    Spacer()

                    if !isLoadingModels {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(secondaryText)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isLoadingModels)
        }
    }

    // MARK: - Danger Section

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("DANGER")

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Text("Delete")
                        .font(.body)
                        .foregroundColor(deleteRed)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .textCase(.uppercase)
            .foregroundColor(secondaryText)
            .tracking(0.5)
    }

    private func saveBackend() {
        var backend = existingBackend ?? CustomBackend()
        backend.name = name
        backend.baseURL = baseURL
        backend.chatPath = chatPath
        backend.modelsPath = modelsPath
        backend.authType = authType
        backend.authToken = authToken
        backend.customModelId = customModelId

        if isEditing {
            backendStore.updateBackend(backend)
        } else {
            backendStore.addBackend(backend)
        }

        dismiss()
    }
}

#Preview("New") {
    NavigationStack {
        CustomBackendEditView(existingBackend: nil)
            .environment(CustomBackendStore())
    }
    .preferredColorScheme(.dark)
}

#Preview("Edit") {
    NavigationStack {
        CustomBackendEditView(
            existingBackend: CustomBackend(
                name: "My Server",
                baseURL: "http://192.168.1.100:8080",
                chatPath: "/v1/chat/completions",
                modelsPath: "/v1/models",
                authType: .bearerToken,
                authToken: "sk-abc123",
                customModelId: "llama-3.1-8b"
            )
        )
        .environment(CustomBackendStore())
    }
    .preferredColorScheme(.dark)
}
