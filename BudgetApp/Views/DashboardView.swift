import SwiftUI

struct DashboardView: View {
    var account: Account

    var body: some View {
        VStack {
            Text("Welcome, \(account.name)!")
                .font(.largeTitle)
                .padding()
            Text("Balance: $\(account.balance, specifier: "%.2f")")
                .font(.title2)
            Spacer()
        }
    }
}
