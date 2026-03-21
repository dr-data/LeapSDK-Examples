import SwiftUI

struct ModelDetailPopupView: View {
  @Environment(ModelStore.self) private var modelStore
  @Environment(\.dismiss) private var dismiss
  let model: ModelDefinition

  // MARK: - Colors

  private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
  private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
  private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
  private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
  private let accentCyan = Color(red: 0.024, green: 0.714, blue: 0.831)
  private let greenColor = Color(red: 0.133, green: 0.773, blue: 0.369)

  var body: some View {
    ZStack {
      bgColor.ignoresSafeArea()

      VStack(spacing: 0) {
        headerBar
        scrollContent
      }
    }
  }

  // MARK: - Header Bar

  private var headerBar: some View {
    HStack {
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.body.weight(.medium))
          .foregroundColor(secondaryText)
      }

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 8)
  }

  // MARK: - Scroll Content

  private var scrollContent: some View {
    ScrollView {
      VStack(spacing: 24) {
        brandSection
        modelInfoSection
        leapLinkSection
        optionsSection
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 40)
    }
  }

  // MARK: - Brand Section

  private var brandSection: some View {
    VStack(spacing: 8) {
      Image(systemName: "drop.fill")
        .font(.system(size: 40))
        .foregroundColor(accentCyan)

      Text(model.provider)
        .font(.subheadline)
        .foregroundColor(secondaryText)
    }
  }

  // MARK: - Model Info

  private var modelInfoSection: some View {
    VStack(spacing: 12) {
      Text(model.name)
        .font(.system(size: 24, weight: .bold))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)

      Text(model.description)
        .font(.system(size: 13))
        .foregroundColor(secondaryText)
        .lineSpacing(13 * 0.5)
        .multilineTextAlignment(.center)
    }
  }

  // MARK: - LEAP Link

  private var leapLinkSection: some View {
    Link(destination: URL(string: "https://leap.liquid.ai")!) {
      HStack(spacing: 4) {
        Text("View on LEAP")
          .font(.subheadline.weight(.medium))
        Image(systemName: "arrow.up.right")
          .font(.caption)
      }
      .foregroundColor(accentBlue)
    }
  }

  // MARK: - Options Section

  private var optionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("OPTIONS")
        .font(.system(size: 12, weight: .medium))
        .textCase(.uppercase)
        .foregroundColor(secondaryText)
        .tracking(0.5)

      ForEach(model.quantizations) { quantization in
        quantizationRow(quantization)
      }
    }
  }

  // MARK: - Quantization Row

  private func quantizationRow(_ quantization: QuantizationOption) -> some View {
    let status = modelStore.status(for: model, quantization: quantization)
    let isActive = modelStore.activeModel == model
      && modelStore.activeQuantization?.name == quantization.name

    return HStack {
      VStack(alignment: .leading, spacing: 6) {
        Text(quantization.name)
          .font(.body.weight(.semibold))
          .foregroundColor(.white)

        HStack(spacing: 8) {
          Text("Compatible")
            .font(.caption)
            .foregroundColor(greenColor)

          Text(quantization.fileSize)
            .font(.caption)
            .foregroundColor(secondaryText)
        }
      }

      Spacer()

      quantizationStatusView(status: status, isActive: isActive, quantization: quantization)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(cardColor)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Status View

  @ViewBuilder
  private func quantizationStatusView(
    status: DownloadStatus,
    isActive: Bool,
    quantization: QuantizationOption
  ) -> some View {
    switch status {
    case .notDownloaded:
      Button {
        Task {
          await modelStore.downloadAndLoad(model: model, quantization: quantization)
        }
      } label: {
        Image(systemName: "arrow.down.circle")
          .font(.title2)
          .foregroundColor(accentCyan)
      }

    case .downloading(let progress):
      ZStack {
        Circle()
          .stroke(cardColor, lineWidth: 3)
          .frame(width: 30, height: 30)
        Circle()
          .trim(from: 0, to: progress)
          .stroke(accentBlue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
          .frame(width: 30, height: 30)
          .rotationEffect(.degrees(-90))
        Text("\(Int(progress * 100))")
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(secondaryText)
      }

    case .downloaded:
      if isActive {
        Image(systemName: "checkmark.circle.fill")
          .font(.title2)
          .foregroundColor(greenColor)
      } else {
        Button {
          Task {
            await modelStore.downloadAndLoad(model: model, quantization: quantization)
          }
        } label: {
          Text("Use")
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(accentBlue)
            .clipShape(Capsule())
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

#Preview {
  ModelDetailPopupView(
    model: ModelCatalog.allModels.first(where: { $0.id == "LFM2-1.2B-Extract" })
      ?? ModelCatalog.allModels[0]
  )
  .environment(ModelStore())
  .preferredColorScheme(.dark)
}
