import SwiftUI

struct ModelSelectorView: View {
    @Environment(ModelStore.self) private var modelStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    var onManage: () -> Void = {}

    private let bgColor = Color(red: 0.039, green: 0.059, blue: 0.110)
    private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)
    private let secondaryText = Color(red: 0.580, green: 0.639, blue: 0.722)
    private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
    private let accentCyan = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let greenColor = Color(red: 0.133, green: 0.773, blue: 0.369)

    private var allModelsWithDefaultQuant: [(ModelDefinition, QuantizationOption)] {
        ModelCatalog.allModels.compactMap { model in
            guard let firstQuant = model.quantizations.first else { return nil }
            // Use the downloaded quantization if available, otherwise the first one
            for quant in model.quantizations {
                if case .downloaded = modelStore.status(for: model, quantization: quant) {
                    return (model, quant)
                }
            }
            return (model, firstQuant)
        }
    }

    private var filteredModels: [(ModelDefinition, QuantizationOption)] {
        if searchText.isEmpty { return allModelsWithDefaultQuant }
        return allModelsWithDefaultQuant.filter {
            $0.0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                searchBar
                modelList
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
                onManage()
            } label: {
                Text("Manage")
                    .font(.system(size: 15))
                    .foregroundColor(accentBlue)
            }

            Spacer()

            Text("Model")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accentBlue)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
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
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var modelList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("LOCAL")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryText)
                    .tracking(0.5)
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(filteredModels, id: \.0.id) { model, quant in
                        modelRow(model: model, quantization: quant)

                        if model.id != filteredModels.last?.0.id {
                            Color(red: 0.059, green: 0.090, blue: 0.165)
                                .frame(height: 1)
                                .padding(.leading, 64)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func modelRow(model: ModelDefinition, quantization: QuantizationOption) -> some View {
        let status = modelStore.status(for: model, quantization: quantization)
        let isActive = modelStore.activeModel == model
            && modelStore.activeQuantization?.name == quantization.name
        let isDownloaded = status == .downloaded

        return Button {
            Task {
                await modelStore.downloadAndLoad(model: model, quantization: quantization)
            }
            if isDownloaded {
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                ProviderIconView(provider: model.provider)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.system(size: 15))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Text(model.parameterCount)
                            .font(.system(size: 12))
                            .foregroundColor(secondaryText)
                        Text("\u{00B7}")
                            .font(.system(size: 12))
                            .foregroundColor(secondaryText)
                        Text(model.provider)
                            .font(.system(size: 12))
                            .foregroundColor(secondaryText)
                    }
                }

                Spacer()

                statusIndicator(status: status, isActive: isActive)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func statusIndicator(status: DownloadStatus, isActive: Bool) -> some View {
        switch status {
        case .downloaded:
            if isActive {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentBlue)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(greenColor)
            }

        case .downloading(let progress):
            ZStack {
                Circle()
                    .stroke(cardColor, lineWidth: 2)
                    .frame(width: 22, height: 22)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(accentBlue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(-90))
            }

        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 18))
                .foregroundColor(accentCyan)

        case .failed:
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: 18))
                .foregroundColor(.red)
        }
    }
}
