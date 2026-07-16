import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var accounts: [Account]

    @Binding var loggedInAccount: Account?

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showingSignup = false
    @State private var loginError: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("BudgetApp")
                    .font(.largeTitle)
                    .bold()

                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if let loginError = loginError {
                    Text(loginError)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button("Login") {
                    login()
                }
                .buttonStyle(.borderedProminent)

                Button("Sign Up") {
                    showingSignup = true
                }
                .sheet(isPresented: $showingSignup) {
                    SignupView()
                }
            }
            .padding()
        }
    }

    private func login() {
        if let account = accounts.first(where: { $0.name.lowercased() == username.lowercased() }) {
            loginError = nil
            loggedInAccount = account
        } else {
            loginError = "Account not found. Please sign up."
        }
    }
}
