import SwiftUI

struct SignupView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    BilanoeLogo(style: .lightBg, iconSize: 36, showWordmark: false)
                        .padding(.bottom, 4)
                    Text("Create Account")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Start your financial journey.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.bottom, 40)

                VStack(spacing: 14) {
                    BilanoeTextField(icon: "person", placeholder: "Username (min 3 characters)", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    BilanoeTextField(icon: "lock", placeholder: "Password (min 6 characters)", text: $password, isSecure: true)
                    BilanoeTextField(icon: "lock.fill", placeholder: "Confirm Password", text: $confirm, isSecure: true)
                }
                .padding(.horizontal, 28)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption).foregroundColor(.red)
                        .padding(.top, 10).padding(.horizontal, 28)
                }

                Button {
                    guard password == confirm else { errorMessage = "Passwords don't match."; return }
                    do {
                        try auth.signUp(username: username, password: password)
                        dismiss()
                    } catch let e as AuthError {
                        errorMessage = e.errorDescription ?? "Sign up failed."
                    } catch {
                        errorMessage = "Sign up failed. Please try again."
                    }
                } label: {
                    Text("Create Account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(username.isEmpty || password.isEmpty ? Color.secondary.opacity(0.3) : Color.pistachio)
                        .cornerRadius(14)
                }
                .disabled(username.isEmpty || password.isEmpty)
                .padding(.horizontal, 28)
                .padding(.top, 24)

                Spacer()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }
}
