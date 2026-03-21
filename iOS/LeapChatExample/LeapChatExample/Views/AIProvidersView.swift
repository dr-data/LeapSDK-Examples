import SwiftUI

struct AIProvidersView: View {
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss

    private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
    private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
    private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    descriptionText
                    providersSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("AI Providers")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentBlue)
                }
            }
        }
    }

    // MARK: - Description

    private var descriptionText: some View {
        Text("Configure AI providers to access different language models and services.")
            .font(.system(size: 14))
            .foregroundColor(secondaryText)
            .lineSpacing(14 * 0.4)
    }

    // MARK: - Providers Section

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROVIDERS")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryText)
                .tracking(0.5)

            VStack(spacing: 8) {
                ForEach(AIProvider.allProviders) { provider in
                    providerRow(provider)
                }
            }
        }
    }

    private func providerRow(_ provider: AIProvider) -> some View {
        Button {
            navigateToProvider(provider)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: provider.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)

                Text(provider.name)
                    .font(.system(size: 16))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(secondaryText)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func navigateToProvider(_ provider: AIProvider) {
        switch provider.id {
        case "openrouter":
            path.append(AppDestination.openRouterConfig)
        case "local":
            path.append(AppDestination.localModelsBrowser)
        case "custom":
            path.append(AppDestination.customBackends)
        default:
            break
        }
    }
}
