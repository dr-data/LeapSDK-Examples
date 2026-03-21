import SwiftUI

struct ChatSidebarView: View {
    @Binding var isPresented: Bool
    @Environment(RecentChatStore.self) private var recentChatStore

    var onNewChat: () -> Void = {}
    var onSelectChat: (RecentChat) -> Void = { _ in }
    var onSelectCategory: (ModelCategory) -> Void = { _ in }
    var onSelectModel: () -> Void = {}
    var onSelectPrompt: () -> Void = {}
    var onSettings: () -> Void = {}

    // MARK: - Design tokens

    private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
    private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
    private let accentCyan = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
    private let deleteRed = Color(red: 0.937, green: 0.267, blue: 0.267)

    private var sidebarWidth: CGFloat {
        min(UIScreen.main.bounds.width * 0.8, 320)
    }

    // MARK: - Category display helpers

    private struct CategoryItem: Identifiable {
        let id: ModelCategory
        let label: String
        let icon: String
    }

    private let categoryItems: [CategoryItem] = [
        CategoryItem(id: .chat, label: "Chat", icon: "message.fill"),
        CategoryItem(id: .extract, label: "Extract", icon: "doc.text"),
        CategoryItem(id: .translate, label: "Translator", icon: "character.book.closed"),
        CategoryItem(id: .audio, label: "Audio", icon: "mic"),
        CategoryItem(id: .vision, label: "Vision", icon: "eye"),
        CategoryItem(id: .ocr, label: "OCR", icon: "doc.text.viewfinder"),
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { close() }

            HStack(spacing: 0) {
                sidebarContent
                    .frame(width: sidebarWidth)
                    .background(bgColor)

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Sidebar content

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            header
            scrollableContent
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(accentCyan)
                    .frame(width: 10, height: 10)

                Text("APOLLO")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button(action: {
                close()
                onNewChat()
            }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18))
                    .foregroundStyle(accentCyan)
            }
        }
        .padding(20)
    }

    // MARK: - Scrollable content

    private var scrollableContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                appsSection
                recentChatsSection
            }
        }
    }

    // MARK: - APPS section

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("APPS")

            VStack(spacing: 0) {
                ForEach(categoryItems) { item in
                    Button {
                        close()
                        onSelectCategory(item.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .frame(width: 20, alignment: .center)

                            Text(item.label)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(secondaryText)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - RECENT CHATS section

    private var recentChatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("RECENT CHATS")

            if recentChatStore.recentChats.isEmpty {
                Text("No recent chats")
                    .font(.system(size: 14))
                    .foregroundStyle(secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentChatStore.recentChats) { chat in
                        Button {
                            close()
                            onSelectChat(chat)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(secondaryText)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.title)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    Text(chat.timeAgo)
                                        .font(.system(size: 12))
                                        .foregroundStyle(secondaryText)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(cardColor)

            footerButton(icon: "cube", title: "Model") {
                close()
                onSelectModel()
            }

            footerButton(icon: "text.alignleft", title: "Prompt") {
                close()
                onSelectPrompt()
            }

            footerButton(icon: "gearshape", title: "Settings") {
                close()
                onSettings()
            }
        }
    }

    // MARK: - Reusable components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(secondaryText)
            .tracking(0.5)
            .padding(.horizontal, 16)
    }

    private func footerButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))

                Text(title)
                    .font(.system(size: 15))
            }
            .foregroundStyle(secondaryText)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func close() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    ChatSidebarView(isPresented: $isPresented)
        .environment(RecentChatStore())
}
