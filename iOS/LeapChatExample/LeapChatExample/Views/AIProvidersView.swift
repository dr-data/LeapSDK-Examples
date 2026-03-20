import SwiftUI

struct AIProvidersView: View {
  @Binding var path: NavigationPath

  var body: some View {
    List {
      Section {
        ForEach(AIProvider.allProviders) { provider in
          Button {
            if provider.isAvailable {
              path.append(AppDestination.localModelsBrowser)
            }
          } label: {
            HStack(spacing: 16) {
              Image(systemName: provider.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 10))

              Text(provider.name)
                .foregroundColor(.white)

              Spacer()

              if provider.isAvailable {
                Image(systemName: "chevron.right")
                  .foregroundColor(.secondary)
              } else {
                Text("Coming Soon")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
            .padding(.vertical, 4)
          }
          .disabled(!provider.isAvailable)
        }
      } header: {
        Text("Providers")
          .textCase(nil)
      } footer: {
        Text("Your model provider determines the AIs you have access to.")
          .foregroundColor(.secondary)
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("AI Providers")
    .navigationBarTitleDisplayMode(.inline)
  }
}
