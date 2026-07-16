import SwiftUI
import SwiftData

struct SignupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var signupError: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Sign Up")
                .font(.title)
                .bold()

            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let signupError = signupError {
                Text(signupError)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button("Create Account") {
                signup()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func signup() {
        guard !username.isEmpty else {
            signupError = "Username cannot be empty"
            return
        }

        let newAccount = Account(name: username, balance: 0)
        modelContext.insert(newAccount)
        try? modelContext.save()
        dismiss()
    }
}
