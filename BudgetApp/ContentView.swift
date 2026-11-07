import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject private var appLock: AppLockManager
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false

    var body: some View {
        ZStack {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            hasSeenOnboarding = true
                        }
                    }
                    .transition(.opacity)
                } else if auth.isLoggedIn {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }

            if auth.isLoggedIn && appLock.isLocked {
                AppLockView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasSeenOnboarding)
        .animation(.easeInOut(duration: 0.4), value: auth.isLoggedIn)
    }
}
