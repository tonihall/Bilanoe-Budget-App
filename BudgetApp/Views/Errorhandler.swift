import SwiftUI
import SwiftData

// MARK: - App Error

enum AppError: LocalizedError {
    case saveFailed
    case invalidAmount
    case noAccountSelected
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save. Please try again."
        case .invalidAmount:
            return "Please enter a valid amount greater than zero."
        case .noAccountSelected:
            return "Please select an account first."
        case .custom(let message):
            return message
        }
    }
}

// MARK: - Error Alert ViewModifier

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?

    func body(content: Content) -> some View {
        content
            .alert("Something Went Wrong", isPresented: .constant(error != nil), presenting: error) { _ in
                Button("OK", role: .cancel) { error = nil }
            } message: { err in
                Text(err.errorDescription ?? "An unknown error occurred.")
            }
    }
}

extension View {
    func errorAlert(error: Binding<AppError?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}

// MARK: - Safe Save Helper

extension ModelContext {
    func safeSave() throws {
        do {
            try save()
        } catch {
            throw AppError.saveFailed
        }
    }
}
