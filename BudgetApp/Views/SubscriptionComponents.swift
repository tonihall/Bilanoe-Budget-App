import SwiftUI

// Supporting views for the Bills feature.

// MARK: - Subscription Card

struct SubscriptionCard: View {
    var sub: Subscription
    var urgent: Bool
    var isOverdue: Bool
    var onMarkPaid: () -> Void

    var daysUntilDue: Int { Calendar.current.dateComponents([.day], from: Date(), to: sub.dueDate).day ?? 0 }
    var statusColor: Color { isOverdue ? .wineRed : urgent ? .orange : .secondary }
    var statusText: String {
        if isOverdue { return "Overdue by \(abs(daysUntilDue)) day\(abs(daysUntilDue) == 1 ? "" : "s")" }
        if urgent    { return "Due in \(daysUntilDue) day\(daysUntilDue == 1 ? "" : "s")" }
        return sub.dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 42, height: 42)
                Image(systemName: isOverdue ? "exclamationmark.circle.fill" : urgent ? "bell.fill" : "repeat")
                    .foregroundColor(statusColor).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(sub.name).font(.subheadline).fontWeight(.medium)
                Text(statusText).font(.caption).foregroundColor(statusColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(sub.amount, format: .currency(code: CurrencyFormat.code))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(isOverdue ? .wineRed : .primary)
                Button { onMarkPaid() } label: {
                    Text("Pay")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.pistachioSubtle)
                        .foregroundColor(.pistachioText)
                        .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
}

// MARK: - Add Subscription

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (String, Double, Date, Date?) -> Void
    @State private var name = ""
    @State private var amount = ""
    @State private var dueDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var validationMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Bill name", text: $name)
                        .textContentType(.organizationName)
                    TextField("Amount due each month", text: $amount).keyboardType(.decimalPad)
                    if !validationMessage.isEmpty {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(.wineRed)
                    }
                }
                Section("Dates") {
                    DatePicker("Next Due Date", selection: $dueDate, displayedComponents: .date)
                    Toggle("Has End Date", isOn: $hasEndDate)
                    if hasEndDate { DatePicker("End Date", selection: $endDate, displayedComponents: .date) }
                }
            }
            .navigationTitle("Add Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else {
                            validationMessage = "Enter a bill name."
                            return
                        }
                        guard let amt = Double(amount), amt > 0 else {
                            validationMessage = "Enter a monthly amount greater than zero."
                            return
                        }
                        validationMessage = ""
                        onSave(trimmedName, amt, dueDate, hasEndDate ? endDate : nil); dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.isEmpty)
                    .foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }
}
