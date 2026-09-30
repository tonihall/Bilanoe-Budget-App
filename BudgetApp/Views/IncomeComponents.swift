import SwiftUI

/// Edits one income source while the parent IncomeView owns the draft collection.
struct IncomeSourceCard: View {
    @Binding var source: IncomeSource
    let showsSourceName: Bool
    let showsRemoveAction: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(showsSourceName ? "Income source" : "Paycheck")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                if showsRemoveAction {
                    Button(action: onRemove) {
                        Label("Remove", systemImage: "minus.circle.fill")
                            .font(.caption).foregroundColor(.wineRed)
                    }
                }
            }
            if showsSourceName {
                TextField("Source name (e.g. Main Job)", text: $source.name)
                    .textFieldStyle(.roundedBorder)
            }
            TextField("Paycheck amount", text: $source.amount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            Picker("Frequency", selection: $source.frequency) {
                ForEach(IncomeFrequency.allCases) { frequency in
                    Text(frequency.rawValue).tag(frequency)
                }
            }
            .pickerStyle(.segmented)

            if source.amountDouble > 0 {
                HStack {
                    Text("Monthly equivalent:").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(source.monthlyEquivalent, format: .currency(code: CurrencyFormat.code))
                            .font(.caption).fontWeight(.semibold).foregroundColor(.pistachioText)
                        if source.frequency == .biWeekly {
                            Text("(26 pay periods ÷ 12 months)").font(.caption2).foregroundColor(.secondary)
                        } else if source.frequency == .weekly {
                            Text("(52 weeks ÷ 12 months)").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .bilanoeCard(radius: 12, elevated: true)
    }
}

struct AllocationSliderRow: View {
    let label: String
    let icon: String
    let color: Color
    let totalIncome: Double
    @Binding var percentage: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundColor(color).frame(width: 20)
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(percentage))%").font(.subheadline).fontWeight(.semibold).foregroundColor(color)
                if totalIncome > 0 {
                    Text(totalIncome * percentage / 100, format: .currency(code: CurrencyFormat.code))
                        .font(.caption).foregroundColor(.secondary).frame(width: 72, alignment: .trailing)
                }
            }
            Slider(value: $percentage, in: 0...100, step: 1).tint(color)
        }
    }
}

struct DistributionPreviewRow: View {
    let label: String
    let amount: Double
    let color: Color

    var body: some View {
        HStack {
            Circle().fill(color.opacity(0.3)).frame(width: 8, height: 8)
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(amount, format: .currency(code: CurrencyFormat.code))
                .font(.subheadline).fontWeight(.semibold).foregroundColor(color)
        }
    }
}
