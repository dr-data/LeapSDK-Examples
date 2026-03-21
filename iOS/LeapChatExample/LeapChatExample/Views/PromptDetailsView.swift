import SwiftUI

struct PromptDetailsView: View {
  @Environment(PromptStore.self) private var promptStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    @Bindable var store = promptStore

    NavigationStack {
      List {
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("Title")
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(.secondary)
            TextField("Title", text: $store.title)
              .textFieldStyle(.roundedBorder)
          }
          .listRowBackground(Color.clear)
        }

        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("General instruction")
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(.secondary)
            TextEditor(text: $store.systemPrompt)
              .frame(minHeight: 120)
              .scrollContentBackground(.hidden)
              .padding(8)
              .background(Color(.systemGray5))
              .clipShape(RoundedRectangle(cornerRadius: 10))
          }
          .listRowBackground(Color.clear)
        }

        Section {
          Toggle(isOn: $store.fileInstructionEnabled) {
            Label("File instruction", systemImage: "doc")
          }
          Toggle(isOn: $store.imageInstructionEnabled) {
            Label("Image instruction", systemImage: "photo")
          }
          Toggle(isOn: $store.audioInstructionEnabled) {
            Label("Audio instruction", systemImage: "waveform")
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Prompt Details")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .foregroundColor(.white)
          }
        }
      }
    }
  }
}
