import SwiftUI

struct SyncBarrierView: View {
    @Environment(SyncGate.self) private var syncGate
    @Environment(SyncManager.self) private var syncManager

    @State private var syncResult: SyncResult?

    private enum SyncResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Sync Required")
                .font(.title2.bold())
                .foregroundStyle(.white)

            if let reason = syncGate.blockReason {
                Text(reason.userMessage)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Network status
            HStack(spacing: 8) {
                Circle()
                    .fill(syncManager.isNetworkAvailable ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(syncManager.isNetworkAvailable ? "Network Available" : "No Network")
                    .font(.caption)
                    .foregroundStyle(syncManager.isNetworkAvailable ? .green : .red)
            }

            // Progress or action
            if syncGate.isForceSyncing || syncManager.isSyncing {
                VStack(spacing: 12) {
                    ProgressView(value: syncManager.syncProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .padding(.horizontal, 32)

                    Text("Syncing...")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            } else if let result = syncResult {
                resultView(result)
            } else {
                Button {
                    Task {
                        syncResult = nil
                        let success = await syncGate.performForceSync()
                        syncResult = success ? .success : .failure(syncManager.syncError ?? "Sync failed")
                    }
                } label: {
                    Text("Sync Now")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue)
                        )
                }
                .padding(.horizontal, 32)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.12))
                .shadow(color: .black.opacity(0.3), radius: 10)
        )
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func resultView(_ result: SyncResult) -> some View {
        switch result {
        case .success:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Sync complete")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        case .failure(let message):
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Sync failed")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    Task {
                        syncResult = nil
                        let success = await syncGate.performForceSync()
                        syncResult = success ? .success : .failure(syncManager.syncError ?? "Sync failed")
                    }
                }
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.top, 4)
            }
        }
    }
}
