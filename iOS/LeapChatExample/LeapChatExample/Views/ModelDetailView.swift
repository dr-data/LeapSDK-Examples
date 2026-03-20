import SwiftUI

struct ModelDetailView: View {
  let model: ModelDefinition
  @Environment(ModelStore.self) private var modelStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    List {
      // Header section
      Section {
        VStack(spacing: 12) {
          ProviderIconView(provider: model.provider)
            .scaleEffect(1.5)

          Text(model.provider)
            .font(.caption)
            .foregroundColor(.secondary)

          Text(model.name)
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.white)

          Text(model.description)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

          Link(destination: URL(string: "https://leap.liquid.ai")!) {
            Text("View on LEAP")
              .font(.subheadline)
              .fontWeight(.medium)
              .padding(.horizontal, 20)
              .padding(.vertical, 8)
              .background(Color(.systemGray4))
              .foregroundColor(.white)
              .clipShape(RoundedRectangle(cornerRadius: 20))
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
      }

      // Quantization options
      Section {
        ForEach(model.quantizations) { quant in
          QuantizationRowView(
            model: model,
            quantization: quant,
            status: modelStore.status(for: model, quantization: quant),
            isActive: modelStore.activeModel == model
              && modelStore.activeQuantization?.name == quant.name
          )
        }
      } header: {
        Text("Options")
          .textCase(nil)
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle(model.name)
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct QuantizationRowView: View {
  let model: ModelDefinition
  let quantization: QuantizationOption
  let status: DownloadStatus
  let isActive: Bool
  @Environment(ModelStore.self) private var modelStore

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(quantization.name)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(Color(.systemGray4))
          .clipShape(RoundedRectangle(cornerRadius: 6))

        Text("Compatible · \(quantization.fileSize)")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      statusView
    }
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private var statusView: some View {
    switch status {
    case .notDownloaded:
      Button {
        Task {
          await modelStore.downloadAndLoad(model: model, quantization: quantization)
        }
      } label: {
        Image(systemName: "arrow.down.circle")
          .font(.title2)
          .foregroundColor(.white)
      }

    case .downloading(let progress):
      ZStack {
        Circle()
          .stroke(Color(.systemGray4), lineWidth: 3)
          .frame(width: 28, height: 28)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(Color.blue, lineWidth: 3)
          .frame(width: 28, height: 28)
          .rotationEffect(.degrees(-90))
        Text("\(Int(progress * 100))")
          .font(.system(size: 8))
          .foregroundColor(.secondary)
      }

    case .downloaded:
      if isActive {
        Image(systemName: "checkmark.circle.fill")
          .font(.title2)
          .foregroundColor(.green)
      } else {
        Button {
          Task {
            await modelStore.downloadAndLoad(model: model, quantization: quantization)
          }
        } label: {
          Text("Use")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
      }

    case .failed:
      Button {
        Task {
          await modelStore.downloadAndLoad(model: model, quantization: quantization)
        }
      } label: {
        Image(systemName: "arrow.clockwise.circle")
          .font(.title2)
          .foregroundColor(.red)
      }
    }
  }
}
