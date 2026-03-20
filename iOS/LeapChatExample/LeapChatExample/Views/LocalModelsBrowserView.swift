import SwiftUI

struct LocalModelsBrowserView: View {
  @Environment(ModelStore.self) private var modelStore
  @Binding var path: NavigationPath

  var body: some View {
    List {
      Section {
        Text("Always verify information. Smaller models may produce more inaccuracies.")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .multilineTextAlignment(.center)
          .listRowBackground(Color.clear)
      }

      ForEach(ModelCategory.allCases) { category in
        let models = ModelCatalog.models(for: category)
        if !models.isEmpty {
          Section {
            ForEach(models) { model in
              Button {
                path.append(AppDestination.modelDetail(model))
              } label: {
                ModelRowView(model: model, isDownloaded: modelStore.isModelDownloaded(model))
              }
            }
          } header: {
            Text(category.rawValue)
              .textCase(nil)
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Local Models")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct ModelRowView: View {
  let model: ModelDefinition
  let isDownloaded: Bool

  var body: some View {
    HStack(spacing: 12) {
      ProviderIconView(provider: model.provider)

      VStack(alignment: .leading, spacing: 2) {
        Text(model.name)
          .font(.body)
          .foregroundColor(.white)
        HStack(spacing: 4) {
          Text("\(model.parameterCount) parameters")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("·")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(model.provider)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        if isDownloaded {
          Text("Downloaded")
            .font(.caption)
            .foregroundColor(.green)
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundColor(.secondary)
    }
    .padding(.vertical, 4)
  }
}

struct ProviderIconView: View {
  let provider: String

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(provider == "Qwen" ? Color.purple.opacity(0.3) : Color(.systemGray5))
        .frame(width: 36, height: 36)

      Image(systemName: provider == "Qwen" ? "diamond.fill" : "flame.fill")
        .font(.system(size: 16))
        .foregroundColor(provider == "Qwen" ? .purple : .white)
    }
  }
}
