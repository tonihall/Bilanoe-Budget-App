import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showSignup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    BilanoeLogo(style: .lightBg, iconSize: 44, showWordmark: false)
                    Text("Bilanoe")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Your money, in balance.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 48)

                // Fields
                VStack(spacing: 14) {
                    BilanoeTextField(icon: "person", placeholder: "Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    BilanoeTextField(icon: "lock", placeholder: "Password", text: $password, isSecure: true)
                }
                .padding(.horizontal, 28)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption).foregroundColor(.red)
                        .padding(.top, 10).padding(.horizontal, 28)
                }

                // Sign in button
                Button {
                    do {
                        try auth.logIn(username: username, password: password)
                    } catch let e as AuthError {
                        errorMessage = e.errorDescription ?? "Login failed."
                    } catch {
                        errorMessage = "Login failed. Please try again."
                    }
                } label: {
                    Text("Sign In")
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

                // Sign up link
                Button { showSignup = true } label: {
                    HStack(spacing: 4) {
                        Text("Don't have an account?").foregroundColor(.secondary)
                        Text("Sign Up").foregroundColor(.pistachio).fontWeight(.medium)
                    }
                    .font(.subheadline)
                }
                .padding(.top, 16)

                Spacer()
            }
            .sheet(isPresented: $showSignup) { SignupView() }
        }
    }
}

// MARK: - Reusable Text Field

struct BilanoeTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.secondary).frame(width: 20)
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }
}
