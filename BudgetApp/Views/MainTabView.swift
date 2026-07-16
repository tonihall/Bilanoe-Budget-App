import SwiftUI
import SwiftData

struct MainTabView: View {
    var account: Account

    var body: some View {
        TabView {
            // Dashboard tab
            DashboardView(account: account)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

            // Expenses & Budget tab
            ExpensesBudgetView(account: account)
                .tabItem {
                    Label("Expenses & Budget", systemImage: "list.bullet.rectangle")
                }

            // Income tab
            IncomeView(account: account)
                .tabItem {
                    Label("Income", systemImage: "dollarsign.circle.fill")
                }

            // Subscriptions tab
            SubscriptionsView(account: account)
                .tabItem {
                    Label("Subscriptions", systemImage: "calendar")
                }
        }
    }
}
