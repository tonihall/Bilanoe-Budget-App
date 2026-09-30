import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(userID: auth.userID)
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                ExpensesBudgetView()
            }
            .tabItem { Label("Spending", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                SubscriptionsView()
            }
            .tabItem { Label("Bills", systemImage: "repeat") }

            NavigationStack {
                PlanView()
            }
            .tabItem { Label("Plan", systemImage: "target") }
        }
        .tint(.pistachio)
    }
}
