import SwiftUI
import Combine
import CryptoKit

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var userID: String {
        didSet { UserDefaults.standard.set(userID, forKey: StorageKey.userID) }
    }

    @Published var username: String {
        didSet { UserDefaults.standard.set(username, forKey: StorageKey.username) }
    }

    var isLoggedIn: Bool { !userID.isEmpty }

    private init() {
        self.userID = UserDefaults.standard.string(forKey: StorageKey.userID) ?? ""
        self.username = UserDefaults.standard.string(forKey: StorageKey.username) ?? ""
    }

    // MARK: - Sign Up

    func signUp(username: String, password: String) throws {
        let normalizedUsername = try validatedUsername(username)
        guard password.count >= 6 else { throw AuthError.passwordTooShort }

        let key = credentialKey(for: normalizedUsername)
        if KeychainHelper.shared.read(for: key) != nil {
            throw AuthError.usernameTaken
        }

        KeychainHelper.shared.save(hashPassword(password), for: key)
        setCurrentUser(normalizedUsername)
    }

    // MARK: - Log In

    func logIn(username: String, password: String) throws {
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = credentialKey(for: normalizedUsername)

        guard let storedHash = KeychainHelper.shared.read(for: key) else {
            throw AuthError.userNotFound
        }

        let hashed = hashPassword(password)
        guard hashed == storedHash else {
            throw AuthError.wrongPassword
        }

        setCurrentUser(normalizedUsername)
    }

    // MARK: - Log Out

    func logOut() {
        userID   = ""
        username = ""
    }

    private func validatedUsername(_ username: String) throws -> String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { throw AuthError.usernameTooShort }
        return trimmed
    }

    private func credentialKey(for username: String) -> String {
        "user_\(username.lowercased())"
    }

    private func setCurrentUser(_ username: String) {
        userID = username.lowercased()
        self.username = username
    }

    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private enum StorageKey {
        static let userID = "userID"
        static let username = "username"
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
