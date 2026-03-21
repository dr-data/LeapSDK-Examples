import SwiftUI

struct OpenRouterConfigView: View {
  @Environment(CustomBackendStore.self) private var backendStore
  @Environment(\.dismiss) private var dismiss
  @State private var apiKey = ""
  @State private var isLoadingModels = false

  // MARK: - Colors

  private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
  private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
  private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
  private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)

  var body: some View {
    ZStack {
      bgColor.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          descriptionSection
          accountSection
          apiKeySection
          modelsSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
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
            Text("OpenRouter")
              .font(.body.weight(.bold))
          }
          .foregroundColor(accentBlue)
        }
      }
    }
    .onAppear {
      apiKey = backendStore.openRouterAPIKey
    }
  }

  // MARK: - Description

  private var descriptionSection: some View {
    Text("OpenRouter routes your requests to the best available LLM providers. Connect your account or paste an API key to get started.")
      .font(.system(size: 14))
      .foregroundColor(secondaryText)
      .lineSpacing(14 * 0.4)
  }

  // MARK: - Account Section

  private var accountSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("OPENROUTER ACCOUNT")

      Button {
        // Open OpenRouter login flow
      } label: {
        Text("Log In")
          .font(.body)
          .foregroundColor(accentBlue)
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(cardColor)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  // MARK: - API Key Section

  private var apiKeySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("OPENROUTER API KEY")

      SecureField("Paste your key", text: $apiKey)
        .font(.body)
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onChange(of: apiKey) { _, newValue in
          backendStore.saveOpenRouterKey(newValue)
        }
    }
  }

  // MARK: - Models Section

  private var modelsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("MODELS")

      Button {
        isLoadingModels = true
        // Trigger model loading from OpenRouter
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

  // MARK: - Helpers

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 12, weight: .medium))
      .textCase(.uppercase)
      .foregroundColor(secondaryText)
      .tracking(0.5)
  }
}

#Preview {
  NavigationStack {
    OpenRouterConfigView()
      .environment(CustomBackendStore())
  }
  .preferredColorScheme(.dark)
}
