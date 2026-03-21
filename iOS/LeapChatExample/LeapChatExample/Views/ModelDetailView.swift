import SwiftUI

struct ModelDetailView: View {
    let model: ModelDefinition
    @Binding var path: NavigationPath
    @Environment(ModelStore.self) private var modelStore

    private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
    private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
    private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
    private let greenColor = Color(red: 0.133, green: 0.773, blue: 0.369)
    private let dividerColor = Color(red: 0.059, green: 0.090, blue: 0.165)

    init(model: ModelDefinition, path: Binding<NavigationPath>) {
        self.model = model
        self._path = path
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    descriptionSection
                    leapLinkSection
                    optionsSection
                    infoSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !path.isEmpty {
                        path.removeLast()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(accentBlue)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(model.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        Text(model.description)
            .font(.system(size: 14))
            .foregroundColor(secondaryText)
            .lineSpacing(14 * 0.4)
    }

    // MARK: - LEAP Link

    private var leapLinkSection: some View {
        Link(destination: URL(string: "https://leap.liquid.ai")!) {
            HStack(spacing: 4) {
                Text("View on LEAP")
                    .font(.system(size: 15, weight: .medium))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
            }
            .foregroundColor(accentBlue)
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OPTIONS")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryText)
                .tracking(0.5)

            ForEach(model.quantizations) { quantization in
                quantizationRow(quantization)
            }
        }
    }

    private func quantizationRow(_ quantization: QuantizationOption) -> some View {
        let status = modelStore.status(for: model, quantization: quantization)
        let isActive = modelStore.activeModel == model
            && modelStore.activeQuantization?.name == quantization.name

        return HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(quantization.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Text(quantization.fileSize)
                        .font(.system(size: 13))
                        .foregroundColor(secondaryText)

                    Text("Compatible")
                        .font(.system(size: 13))
                        .foregroundColor(greenColor)
                }
            }

            Spacer()

            quantizationStatusView(status: status, isActive: isActive, quantization: quantization)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

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
                    .foregroundColor(accentBlue)
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
                        .font(.system(size: 13, weight: .semibold))
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

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INFO")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryText)
                .tracking(0.5)

            VStack(spacing: 0) {
                infoRow(label: "Size", value: "\(model.parameterCount) parameters")
                dividerColor.frame(height: 1).padding(.leading, 16)
                infoRow(label: "Context Length", value: "4096")
                dividerColor.frame(height: 1).padding(.leading, 16)
                infoRow(label: "License", value: licenseText, showChevron: true)
            }
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func infoRow(label: String, value: String, showChevron: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.white)

            Spacer()

            Text(value)
                .font(.system(size: 15))
                .foregroundColor(secondaryText)
                .lineLimit(1)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var licenseText: String {
        if model.provider == "LiquidAI" {
            return "LFM Open License v1.0"
        } else if model.provider == "Qwen" {
            return "Apache 2.0"
        }
        return "See provider"
    }
}
