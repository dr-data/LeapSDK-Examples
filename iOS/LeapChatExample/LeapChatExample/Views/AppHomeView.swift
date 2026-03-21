import SwiftUI

struct AppHomeView: View {
    @Environment(ModelStore.self) private var modelStore
    @Environment(PromptStore.self) private var promptStore
    @State private var searchText = ""
    @State private var path = NavigationPath()

    private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
    private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
    private let accentCyan = Color(red: 0.024, green: 0.714, blue: 0.831)

    struct AppItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let category: ModelCategory?
        let isHighlighted: Bool
    }

    private let apps: [AppItem] = [
        AppItem(name: "Chat", icon: "message.fill", category: .chat, isHighlighted: true),
        AppItem(name: "Extract", icon: "doc.text", category: .extract, isHighlighted: false),
        AppItem(name: "EN-JP Translator", icon: "character.book.closed", category: .translate, isHighlighted: false),
        AppItem(name: "Audio", icon: "mic", category: .audio, isHighlighted: false),
        AppItem(name: "Vision", icon: "eye", category: .vision, isHighlighted: false),
        AppItem(name: "OCR", icon: "doc.text.viewfinder", category: .ocr, isHighlighted: false),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                bgColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        brandRow
                        searchBar
                        appsSection
                        recentsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .appHome:
                    ContentView()
                case .aiProviders:
                    AIProvidersView(path: $path)
                case .openRouterConfig:
                    OpenRouterConfigView()
                case .localModelsBrowser:
                    LocalModelsBrowserView(path: $path)
                case .customBackends:
                    CustomBackendsView()
                case .customBackendEdit(let backend):
                    CustomBackendEditView(existingBackend: backend)
                case .modelDetail(let model):
                    ModelDetailView(model: model, path: $path)
                case .modelDetailPopup(let model):
                    ModelDetailPopupView(model: model)
                }
            }
        }
    }

    private var brandRow: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(accentCyan)
                    .frame(width: 10, height: 10)

                Text("APOLLO")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button {
                path.append(AppDestination.aiProviders)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(secondaryText)
            }
        }
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(secondaryText)
                .font(.system(size: 15))

            TextField("Search", text: $searchText)
                .foregroundColor(.white)
                .font(.system(size: 15))
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPS")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryText)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(apps) { app in
                    Button {
                        // All apps navigate to the chat screen for now
                        path.append(AppDestination.appHome)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: app.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)

                            Text(app.name)
                                .font(.system(size: 16))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(app.isHighlighted ? cardColor : Color.clear)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENTS")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryText)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(sampleRecents, id: \.self) { title in
                    Button {
                        // Navigate to chat with this recent conversation
                        path.append(AppDestination.appHome)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "circle")
                                .font(.system(size: 14))
                                .foregroundColor(secondaryText)

                            Text(title)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var sampleRecents: [String] {
        ["What's quantum computing?", "Where's it", "Derive the quantum computer si..."]
    }
}
