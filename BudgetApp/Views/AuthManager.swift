import SwiftUI
import Combine
import CryptoKit

class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published var userID: String {
        didSet { UserDefaults.standard.set(userID, forKey: "userID") }
    }

    @Published var username: String {
        didSet { UserDefaults.standard.set(username, forKey: "username") }
    }

    var isLoggedIn: Bool { !userID.isEmpty }

    private init() {
        self.userID   = UserDefaults.standard.string(forKey: "userID")   ?? ""
        self.username = UserDefaults.standard.string(forKey: "username") ?? ""
    }

    // MARK: - Sign Up

    func signUp(username: String, password: String) throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { throw AuthError.usernameTooShort }
        guard password.count >= 6 else { throw AuthError.passwordTooShort }

        let key = "user_\(trimmed.lowercased())"
        if KeychainHelper.shared.read(for: key) != nil {
            throw AuthError.usernameTaken
        }

        let hashed = hashPassword(password)
        KeychainHelper.shared.save(hashed, for: key)

        self.userID   = trimmed.lowercased()
        self.username = trimmed
    }

    // MARK: - Log In

    func logIn(username: String, password: String) throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "user_\(trimmed.lowercased())"

        guard let storedHash = KeychainHelper.shared.read(for: key) else {
            throw AuthError.userNotFound
        }

        let hashed = hashPassword(password)
        guard hashed == storedHash else {
            throw AuthError.wrongPassword
        }

        self.userID   = trimmed.lowercased()
        self.username = trimmed
    }

    // MARK: - Log Out

    func logOut() {
        userID   = ""
        username = ""
    }

    // MARK: - Password Hashing

    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case usernameTooShort
    case passwordTooShort
    case usernameTaken
    case userNotFound
    case wrongPassword

    var errorDescription: String? {
        switch self {
        case .usernameTooShort: return "Username must be at least 3 characters."
        case .passwordTooShort: return "Password must be at least 6 characters."
        case .usernameTaken:    return "That username is already taken."
        case .userNotFound:     return "No account found with that username."
        case .wrongPassword:    return "Incorrect password."
        }
    }
}
