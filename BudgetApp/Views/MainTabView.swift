import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Dashboard", systemImage: "house.fill") }

            NavigationStack {
                ExpensesBudgetView()
            }
            .tabItem { Label("Expenses", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                SubscriptionsView()
            }
            .tabItem { Label("Subscriptions", systemImage: "repeat") }

            NavigationStack {
                IncomeView()
            }
            .tabItem { Label("Income", systemImage: "dollarsign.circle") }

            NavigationStack {
                SavingsGoalsView()
            }
            .tabItem { Label("Goals", systemImage: "target") }
        }
        .tint(.pistachio)
    }
}
