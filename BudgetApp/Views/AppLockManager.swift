import Combine
import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    @Published private(set) var isLocked: Bool
    @Published private(set) var isAuthenticating = false
    @Published var errorMessage: String?

    private let lockEnabledKey = "appLockEnabled"

    private init() {
        isLocked = UserDefaults.standard.bool(forKey: lockEnabledKey)
    }

    func lock() {
        guard isEnabled else {
            isLocked = false
            return
        }
        isLocked = true
        errorMessage = nil
    }

    func unlock() {
        isLocked = false
        errorMessage = nil
    }

    func authenticate() {
        guard isEnabled else {
            unlock()
            return
        }
        guard !isAuthenticating else { return }

        let context = LAContext()
        var evaluationError: NSError?
        let policy = LAPolicy.deviceOwnerAuthentication

        guard context.canEvaluatePolicy(policy, error: &evaluationError) else {
            errorMessage = "Set up a device passcode to use app lock."
            isLocked = true
            return
        }

        isAuthenticating = true
        errorMessage = nil
        context.evaluatePolicy(policy, localizedReason: "Unlock Bilanoe to view your financial information.") { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isAuthenticating = false
                if success {
                    self.unlock()
                } else {
                    self.isLocked = true
                    self.errorMessage = error?.localizedDescription ?? "Authentication was not completed."
                }
            }
        }
    }

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: lockEnabledKey)
    }
}

struct AppLockView: View {
    @EnvironmentObject private var appLock: AppLockManager

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.pistachioSubtle)
                    .frame(width: 72, height: 72)
                Image(systemName: "lock.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.pistachioText)
            }

            VStack(spacing: 6) {
                Text("Bilanoe is locked")
                    .font(.title3.weight(.semibold))
                Text("Use Face ID or your device passcode to continue.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = appLock.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.wineRed)
                    .multilineTextAlignment(.center)
            }

            Button { appLock.authenticate() } label: {
                Label(appLock.isAuthenticating ? "Unlocking…" : "Unlock Bilanoe", systemImage: "faceid")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .disabled(appLock.isAuthenticating)
            .foregroundColor(.white)
            .background(Color.pistachioText)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .onAppear { appLock.authenticate() }
        .accessibilityAddTraits(.isModal)
    }
}
