import SwiftUI

struct FirstLaunchView: View {
    @Environment(AuthManager.self) private var authManager
    let passwords: [String: String]
    var onDismiss: () -> Void

    private var bgColor: Color { AppColors.background }
    private var cardColor: Color { AppColors.cardBackground }
    private var secondaryText: Color { AppColors.secondaryText }
    private let accentBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
    private let warningColor = Color(red: 0.95, green: 0.6, blue: 0.1)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(warningColor)

                Text("Admin Credentials")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Save these credentials! They will not be shown again.")
                    .font(.subheadline)
                    .foregroundColor(warningColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 16) {
                    ForEach(passwords.sorted(by: { $0.key < $1.key }), id: \.key) { classcode, password in
                        credentialCard(classcode: classcode, password: password)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("I've saved these credentials")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accentBlue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
                .accessibilityIdentifier("dismissFirstLaunchButton")
            }
        }
    }

    private func credentialCard(classcode: String, password: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Classcode")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                    Text(classcode)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = classcode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryText)
                }
                .accessibilityLabel("Copy classcode \(classcode)")
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                    Text(password)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = password
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryText)
                }
                .accessibilityLabel("Copy password for \(classcode)")
            }
        }
        .padding(16)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
