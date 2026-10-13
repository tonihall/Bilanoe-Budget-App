import SwiftUI

struct DashboardGettingStartedCard: View {
    let onAddAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Welcome to Bilanoe")
                    .font(.title3.weight(.semibold))
                Text("Start with the money you have today. You can add the rest as you go.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                DashboardGettingStartedStep(number: 1, title: "Add your first account", detail: "Checking, savings, investment, or credit card", isActive: true)
                DashboardGettingStartedStep(number: 2, title: "Add bills or expenses", detail: "See where your money is going", isActive: false)
                DashboardGettingStartedStep(number: 3, title: "Make a plan", detail: "Set a budget or savings goal when you're ready", isActive: false)
            }

            Button(action: onAddAccount) {
                Label("Add your first account", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .foregroundColor(.white)
            .background(Color.pistachioText)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
        .bilanoeCard()
    }
}

private struct DashboardGettingStartedStep: View {
    let number: Int
    let title: String
    let detail: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundColor(isActive ? .white : .secondary)
                .frame(width: 24, height: 24)
                .background(isActive ? Color.pistachioText : Color.appSurfaceElevated)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isActive ? .primary : .secondary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct DashboardSafeToSpendCard: View {
    let safeToSpend: Double
    let checkingBalance: Double
    let upcomingBillsTotal: Double
    let hasCheckingAccount: Bool

    private var amountColor: Color { safeToSpend >= 0 ? .primary : .wineRed }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Safe to spend", systemImage: "wallet.pass.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.pistachioText)

            if hasCheckingAccount {
                Text(safeToSpend, format: .currency(code: CurrencyFormat.code))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(amountColor)

                Text(upcomingBillsTotal > 0
                    ? "After \(upcomingBillsTotal, format: .currency(code: CurrencyFormat.code)) in bills due this week."
                    : "No bills are due this week.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Based on \(checkingBalance, format: .currency(code: CurrencyFormat.code)) in checking")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Add a checking account to see what is available for everyday spending.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.pistachioSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

struct DashboardMetricCard: View {
    let title: String
    let amount: Double
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text(amount, format: .currency(code: CurrencyFormat.code))
                .font(.headline.weight(.semibold))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .bilanoeCard()
    }
}
