import SwiftUI

struct LocalModelsBrowserView: View {
    @Environment(ModelStore.self) private var modelStore
    @Binding var path: NavigationPath

    private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
    private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
    private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
    private let greenColor = Color(red: 0.133, green: 0.773, blue: 0.369)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    descriptionText
                    chatModelsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !path.isEmpty {
                        path.removeLast()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(accentBlue)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Local Models")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Description

    private var descriptionText: some View {
        Text("Smaller models that run directly on your device. Download once, use offline.")
            .font(.system(size: 14))
            .foregroundColor(secondaryText)
            .lineSpacing(14 * 0.4)
    }

    // MARK: - Chat Models Section

    private var chatModelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHAT MODELS")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryText)
                .tracking(0.5)

            VStack(spacing: 10) {
                ForEach(ModelCatalog.allModels) { model in
                    Button {
                        path.append(AppDestination.modelDetail(model))
                    } label: {
                        modelRow(model)
                    }
                }
            }
        }
    }

    private func modelRow(_ model: ModelDefinition) -> some View {
        let isDownloaded = modelStore.isModelDownloaded(model)

        return HStack(spacing: 12) {
            ProviderIconView(provider: model.provider)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    if model.isMLX {
                        Text("MLX")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                HStack(spacing: 4) {
                    Text(model.parameterCount)
                        .font(.system(size: 13))
                        .foregroundColor(secondaryText)
                    Text("\u{00B7}")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryText)
                    Text(model.provider)
                        .font(.system(size: 13))
                        .foregroundColor(secondaryText)
                }
            }

            Spacer()

            if isDownloaded {
                Text("Downloaded")
                    .font(.system(size: 13))
                    .foregroundColor(greenColor)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

}

struct ProviderIconView: View {
    let provider: String

    private var iconColor: Color {
        switch provider {
        case "Qwen": return .purple
        case "ZAI": return .orange
        default: return Color(red: 0.024, green: 0.714, blue: 0.831)
        }
    }

    private var iconName: String {
        switch provider {
        case "Qwen": return "diamond.fill"
        case "ZAI": return "doc.text.viewfinder"
        default: return "drop.fill"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconColor.opacity(provider == "Qwen" ? 0.3 : 0.2))
                .frame(width: 36, height: 36)

            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
        }
    }
}
