import SwiftUI

struct CustomBackendsView: View {
  @Environment(CustomBackendStore.self) private var backendStore
  @Environment(\.dismiss) private var dismiss
  @State private var path = NavigationPath()

  // MARK: - Colors

  private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
  private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
  private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
  private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
  private let dividerColor = Color(red: 0.059, green: 0.090, blue: 0.165)

  var body: some View {
    NavigationStack(path: $path) {
      ZStack {
        bgColor.ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            descriptionSection
            actionsSection
            backendsSection
          }
          .padding(.horizontal, 20)
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
              Text("Custom Backends")
                .font(.body.weight(.bold))
            }
            .foregroundColor(accentBlue)
          }
        }
      }
      .navigationDestination(for: CustomBackendNavDestination.self) { destination in
        switch destination {
        case .edit(let backend):
          CustomBackendEditView(existingBackend: backend)
        case .new:
          CustomBackendEditView(existingBackend: nil)
        }
      }
    }
  }

  // MARK: - Description

  private var descriptionSection: some View {
    Text("Field requirements will depend on your specific backend deployment.")
      .font(.system(size: 13))
      .foregroundColor(secondaryText)
  }

  // MARK: - Actions Section

  private var actionsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("ACTIONS")

      VStack(spacing: 0) {
        Button {
          path.append(CustomBackendNavDestination.new)
        } label: {
          HStack {
            Text("New Backend")
              .font(.body)
              .foregroundColor(.white)
            Spacer()
            Image(systemName: "plus")
              .foregroundColor(secondaryText)
          }
          .padding(.horizontal, 16)
          .frame(height: 48)
        }

        dividerColor.frame(height: 1).padding(.leading, 16)

        Button {
          // QR code scanning
        } label: {
          HStack {
            Text("Scan QR code")
              .font(.body)
              .foregroundColor(.white)
            Spacer()
            Image(systemName: "qrcode")
              .foregroundColor(secondaryText)
          }
          .padding(.horizontal, 16)
          .frame(height: 48)
        }
      }
      .background(cardColor)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }

  // MARK: - Backends Section

  @ViewBuilder
  private var backendsSection: some View {
    if !backendStore.backends.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        sectionHeader("BACKENDS")

        VStack(spacing: 0) {
          ForEach(Array(backendStore.backends.enumerated()), id: \.element.id) { index, backend in
            Button {
              path.append(CustomBackendNavDestination.edit(backend))
            } label: {
              HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                  .fill(accentBlue.opacity(index == 0 ? 1.0 : 0.0))
                  .frame(width: 3, height: 36)
                  .padding(.trailing, 12)

                VStack(alignment: .leading, spacing: 2) {
                  Text(backend.name.isEmpty ? "Custom Backend" : backend.name)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                  Text(backend.baseURL.isEmpty ? "No URL configured" : backend.baseURL)
                    .font(.caption)
                    .foregroundColor(secondaryText)
                    .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                  .font(.caption)
                  .foregroundColor(secondaryText)
              }
              .padding(.horizontal, 16)
              .frame(height: 56)
            }

            if index < backendStore.backends.count - 1 {
              dividerColor.frame(height: 1).padding(.leading, 31)
            }
          }
        }
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
}

// MARK: - Navigation Destination

enum CustomBackendNavDestination: Hashable {
  case new
  case edit(CustomBackend)
}

#Preview {
  CustomBackendsView()
    .environment(CustomBackendStore())
    .preferredColorScheme(.dark)
}
