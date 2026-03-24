import PhotosUI
import SwiftUI

struct ChatInputView: View {
    @Bindable var store: ChatStore
    @State private var selectedImage: PhotosPickerItem?
    @Environment(ModelStore.self) private var modelStore
    var syncGate: SyncGate?
    var syncManager: SyncManager?

    private var bgColor: Color { AppColors.background }
    private var cardColor: Color { AppColors.cardBackground }
    private var secondaryText: Color { AppColors.secondaryText }
    private let accentBlue = AppColors.accentBlue

    private var canSend: Bool {
        (!store.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || store.attachedImage != nil)
            && !store.isImageLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            // Show sync barrier when blocked
            if let gate = syncGate, gate.isBlocked {
                SyncBarrierView()
            }

            if modelStore.isGLMOCRActive || modelStore.isPaddleOCRActive {
                ocrTaskPicker
            }

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

                HStack(alignment: .bottom, spacing: 8) {
                    ExpandableTextInput(
                        text: $store.input,
                        isDisabled: store.isLoading,
                        onSubmit: {
                            if canSend && !store.isLoading {
                                Task { await store.send() }
                            }
                        }
                    )
                    .accessibilityIdentifier("messageTextField")

                    if store.isLoading {
                        // Stop button during generation
                        Button {
                            store.stopGenerating()
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                        }
                        .accessibilityIdentifier("stopButton")
                        .padding(.bottom, 2)
                    } else if canSend {
                        Button {
                            Task { await store.send() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(accentBlue)
                        }
                        .accessibilityIdentifier("sendButton")
                        .padding(.bottom, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
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

    private var ocrTaskOptions: [(OCRTask, String)] {
        var options: [(OCRTask, String)] = [
            (.text, "Text"), (.table, "Table"), (.formula, "Formula"),
        ]
        if modelStore.isPaddleOCRActive {
            options.append((.handwriting, "Handwriting"))
            options.append((.documentLayout, "Layout"))
        }
        return options
    }

    @ViewBuilder
    private var ocrTaskPicker: some View {
        HStack(spacing: 8) {
            Text("OCR Mode:")
                .font(.system(size: 13))
                .foregroundColor(secondaryText)

            ForEach(ocrTaskOptions, id: \.1) { task, label in
                Button {
                    store.ocrTask = task
                } label: {
                    Text(label)
                        .font(.system(size: 13, weight: store.ocrTask == task ? .semibold : .regular))
                        .foregroundColor(store.ocrTask == task ? .white : secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(store.ocrTask == task ? accentBlue : cardColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Expandable Text Input

struct ExpandableTextInput: View {
    @Binding var text: String
    var isDisabled: Bool = false
    var onSubmit: () -> Void = {}

    @State private var textHeight: CGFloat = 36

    private let minHeight: CGFloat = 36
    private let maxHeight: CGFloat = 120

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text("Message")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }

            // Hidden text for height calculation
            Text(text.isEmpty ? " " : text)
                .font(.system(size: 16))
                .foregroundColor(.clear)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: TextHeightKey.self, value: geo.size.height)
                    }
                )

            // Actual TextEditor
            TextEditor(text: $text)
                .font(.system(size: 16))
                .foregroundColor(AppColors.primaryText)
                .scrollContentBackground(.hidden)
                .disabled(isDisabled)
                .frame(height: min(max(textHeight, minHeight), maxHeight))
                .padding(.horizontal, -1)
        }
        .onPreferenceChange(TextHeightKey.self) { height in
            textHeight = height
        }
    }
}

private struct TextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 36
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
