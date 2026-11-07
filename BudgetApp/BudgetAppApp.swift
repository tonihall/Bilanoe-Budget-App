import SwiftUI
import SwiftData

@main
struct BudgetAppApp: App {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var appLock = AppLockManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(appLock)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .inactive, .background:
                        appLock.lock()
                    case .active:
                        NotificationManager.shared.clearBadge()
                        if appLock.isLocked {
                            appLock.authenticate()
                        }
                    @unknown default:
                        break
                    }
                }
        }
        .modelContainer(for: [
            Account.self,
            Expense.self,
            MonthlyBudget.self,
            Subscription.self,
            Income.self,
            SavingsGoal.self,
            NetWorthSnapshot.self
        ])
    }
}
