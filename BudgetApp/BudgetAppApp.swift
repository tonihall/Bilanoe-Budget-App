import SwiftUI
import SwiftData

@main
struct BudgetAppApp: App {
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
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
