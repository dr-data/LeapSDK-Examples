import SwiftUI

/// Shows chat history for a specific category (Math, RAG, etc.)
/// Entry point before entering a specialized chat session.
struct SpecializedChatHistoryView: View {
    let title: String
    let icon: String
    let category: ModelCategory
    let suggestedModelId: String
    let defaultQuant: String
    let systemPrompt: String
    let examples: [ExamplePrompt]

    @Environment(\.dismiss) private var dismiss
    @Environment(RecentChatStore.self) private var recentChatStore
    @State private var navigateToNewChat = false
    @State private var selectedChat: RecentChat?

    private var bgColor: Color { AppColors.background }
    private var cardColor: Color { AppColors.cardBackground }
    private var secondaryText: Color { AppColors.secondaryText }
    private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)

    private var categoryChats: [RecentChat] {
        recentChatStore.recentChats.filter { $0.category == category.rawValue }
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if categoryChats.isEmpty {
                    emptyState
                } else {
                    chatList
                }
            }

            // Navigation to chat
            NavigationLink(
                destination: SpecializedChatView(
                    title: title,
                    suggestedModelId: suggestedModelId,
                    defaultQuant: defaultQuant,
                    systemPrompt: systemPrompt,
                    examples: examples,
                    restoreChat: selectedChat
                ),
                isActive: Binding(
                    get: { navigateToNewChat || selectedChat != nil },
                    set: { if !$0 { navigateToNewChat = false; selectedChat = nil } }
                )
            ) { EmptyView() }
            .hidden()
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Home")
                        .font(.system(size: 16))
                }
                .foregroundColor(accentBlue)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(accentBlue)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button {
                selectedChat = nil
                navigateToNewChat = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20))
                    .foregroundColor(accentBlue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(bgColor)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(secondaryText.opacity(0.5))

            Text("No \(title) Chats Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Start a new conversation to get help with \(title.lowercased()) tasks.")
                .font(.subheadline)
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                navigateToNewChat = true
            } label: {
                Label("New \(title) Chat", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(accentBlue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chat List

    private var chatList: some View {
        VStack(spacing: 0) {
            // New chat button
            Button {
                navigateToNewChat = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(accentBlue)
                    Text("New \(title) Chat")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(accentBlue)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            Divider().overlay(Color(red: 0.15, green: 0.18, blue: 0.25))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(categoryChats) { chat in
                        Button {
                            selectedChat = chat
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 14))
                                    .foregroundColor(secondaryText)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chat.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(chat.timestamp, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(secondaryText)
                                }

                                Spacer()

                                Text("\(chat.messages.count) msgs")
                                    .font(.caption2)
                                    .foregroundColor(secondaryText)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(cardColor)
                                    .clipShape(Capsule())

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(secondaryText)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }

                        Divider()
                            .overlay(Color(red: 0.15, green: 0.18, blue: 0.25))
                            .padding(.leading, 46)
                    }
                }
            }
        }
    }
}
