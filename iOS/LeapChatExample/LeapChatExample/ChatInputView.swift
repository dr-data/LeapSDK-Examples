import PhotosUI
import SwiftUI

struct ChatInputView: View {
    @Bindable var store: ChatStore
    @State private var selectedImage: PhotosPickerItem?

    private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
    private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
    private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)

    private var canSend: Bool {
        (!store.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || store.attachedImage != nil)
            && !store.isImageLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.isImageLoading {
                HStack {
                    ProgressView()
                        .tint(.white)
                    Text("Loading image...")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
            } else if let attachedImage = store.attachedImage {
                HStack {
                    Image(uiImage: attachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 120, maxHeight: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    Button(action: { store.removeAttachedImage() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(secondaryText)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 22))
                        .foregroundColor(secondaryText)
                }
                .disabled(store.isLoading || store.isImageLoading)
                .onChange(of: selectedImage) { _, newItem in
                    Task {
                        if let newItem {
                            await store.loadImageFrom(item: newItem)
                            selectedImage = nil
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Message", text: $store.input)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .disabled(store.isLoading)
                        .accessibilityIdentifier("messageTextField")
                        .submitLabel(.send)
                        .onSubmit {
                            if canSend && !store.isLoading {
                                Task { await store.send() }
                            }
                        }

                    if canSend && !store.isLoading {
                        Button {
                            Task { await store.send() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(accentBlue)
                        }
                        .accessibilityIdentifier("sendButton")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryText)
                    Text("Search")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 14)
                .background(cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Button(action: {}) {
                    Image(systemName: "mic")
                        .font(.system(size: 22))
                        .foregroundColor(secondaryText)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
        }
        .background(bgColor)
    }
}
