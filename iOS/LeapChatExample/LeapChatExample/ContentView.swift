import SwiftUI

struct ContentView: View {
  @State private var store = ChatStore()
  @State private var path = NavigationPath()
  @State private var showingPromptDetails = false
  @Environment(ModelStore.self) private var modelStore
  @Environment(PromptStore.self) private var promptStore

  var body: some View {
    NavigationStack(path: $path) {
      VStack(spacing: 0) {
        if modelStore.activeModelRunner == nil {
          noModelSelectedView
        } else {
          MessagesListView(store: store)
          ChatInputView(store: store)
        }
      }
      .navigationTitle("Leap Chat")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            showingPromptDetails = true
          } label: {
            Image(systemName: "doc.text")
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            path.append(AppDestination.aiProviders)
          } label: {
            Image(systemName: "gearshape")
          }
        }
      }
      .navigationDestination(for: AppDestination.self) { destination in
        switch destination {
        case .aiProviders:
          AIProvidersView(path: $path)
        case .localModelsBrowser:
          LocalModelsBrowserView(path: $path)
        case .modelDetail(let model):
          ModelDetailView(model: model)
        }
      }
      .sheet(isPresented: $showingPromptDetails) {
        PromptDetailsView()
      }
      .onChange(of: modelStore.activeModelRunner != nil) { _, hasRunner in
        if hasRunner {
          store.configureWithModel(
            runner: modelStore.activeModelRunner!,
            systemPrompt: promptStore.systemPrompt
          )
        }
      }
    }
  }

  private var noModelSelectedView: some View {
    VStack(spacing: 20) {
      Spacer()

      Image(systemName: "cpu")
        .font(.system(size: 48))
        .foregroundColor(.secondary)

      Text("No Model Selected")
        .font(.title2)
        .fontWeight(.semibold)

      Text("Select a model to start chatting")
        .foregroundColor(.secondary)

      Button {
        path.append(AppDestination.aiProviders)
      } label: {
        Label("Browse Models", systemImage: "arrow.right.circle.fill")
          .font(.headline)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(Color.blue)
          .foregroundColor(.white)
          .clipShape(RoundedRectangle(cornerRadius: 25))
      }

      if modelStore.isLoading {
        VStack(spacing: 8) {
          ProgressView()
          Text(modelStore.loadingMessage)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.top, 8)
      }

      Spacer()
    }
    .frame(maxWidth: .infinity)
  }
}

#Preview {
  ContentView()
    .environment(ModelStore())
    .environment(PromptStore())
}
