import SwiftUI

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
