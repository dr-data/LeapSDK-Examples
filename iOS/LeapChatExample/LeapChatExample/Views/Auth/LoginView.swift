import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var classcode = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var bgColor: Color { AppColors.background }
    private var cardColor: Color { AppColors.cardBackground }
    private var secondaryText: Color { AppColors.secondaryText }
    private let accentBlue = AppColors.accentBlue

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 48))
                        .foregroundColor(accentBlue)

                    Text("Apollo")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Sign in to continue")
                        .font(.subheadline)
                        .foregroundColor(secondaryText)
                }

                VStack(spacing: 16) {
                    TextField("Classcode", text: $classcode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
                        .background(cardColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("classcodeField")

                    SecureField("Password", text: $password)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding()
                        .background(cardColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("passwordField")
                }
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    performLogin()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Login")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentBlue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(classcode.isEmpty || password.isEmpty || isLoading)
                .opacity(classcode.isEmpty || password.isEmpty ? 0.5 : 1.0)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("loginButton")

                #if DEBUG
                quickLoginSection
                #endif

                Spacer()
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }

    // MARK: - Quick Login (Debug)

    #if DEBUG
    private var quickLoginSection: some View {
        VStack(spacing: 8) {
            Text("QUICK LOGIN")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(secondaryText)
                .tracking(0.5)

            HStack(spacing: 10) {
                QuickLoginButton(label: "Admin", icon: "shield.fill", color: .purple) {
                    classcode = "admin01"
                    password = "Pass1234"
                }
                QuickLoginButton(label: "Teacher", icon: "person.badge.key.fill", color: .blue) {
                    classcode = "teacher01"
                    password = "Teacher1"
                }
                QuickLoginButton(label: "Student", icon: "graduationcap.fill", color: .green) {
                    classcode = "26f327"
                    password = "Student1"
                }
            }
            .padding(.horizontal, 32)
        }
    }
    #endif

    private func performLogin() {
        errorMessage = nil
        isLoading = true
        let trimmedClasscode = classcode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            _ = try authManager.login(classcode: trimmedClasscode, password: trimmedPassword)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#if DEBUG
struct QuickLoginButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    private let cardColor = Color(red: 0.118, green: 0.161, blue: 0.231)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
#endif
