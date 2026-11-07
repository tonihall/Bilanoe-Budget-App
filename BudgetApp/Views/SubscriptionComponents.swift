import SwiftUI
import SwiftData

// Supporting views for the Bills feature.

// MARK: - Subscription Card

struct SubscriptionCard: View {
    var sub: Subscription
    var urgent: Bool
    var isOverdue: Bool
    var onEdit: (() -> Void)? = nil
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
        .contentShape(Rectangle())
        .onTapGesture { onEdit?() }
    }
}

// MARK: - Edit Subscription

struct EditSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let subscription: Subscription
    var onSaved: () -> Void

    @State private var name: String
    @State private var amount: String
    @State private var dueDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var validationMessage = ""
    @State private var error: AppError? = nil

    init(subscription: Subscription, onSaved: @escaping () -> Void) {
        self.subscription = subscription
        self.onSaved = onSaved
        _name = State(initialValue: subscription.name)
        _amount = State(initialValue: String(format: "%.2f", subscription.amount))
        _dueDate = State(initialValue: subscription.dueDate)
        _hasEndDate = State(initialValue: subscription.endDate != nil)
        _endDate = State(initialValue: subscription.endDate ?? subscription.dueDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bill name", text: $name)
                        .textContentType(.organizationName)
                    TextField("Amount due each month", text: $amount)
                        .keyboardType(.decimalPad)
                    if !validationMessage.isEmpty {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(.wineRed)
                    }
                } header: {
                    Text("Details")
                }

                Section {
                    DatePicker("Next due date", selection: $dueDate, displayedComponents: .date)
                    Toggle("Has end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End date", selection: $endDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Dates")
                } footer: {
                    Text("Changing the next due date updates the bill reminder.")
                }
            }
            .navigationTitle("Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert(error: $error)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.isEmpty)
                        .foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }

    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Enter a bill name."
            return
        }
        guard let newAmount = Double(amount), newAmount > 0 else {
            validationMessage = "Enter a monthly amount greater than zero."
            return
        }
        guard !hasEndDate || endDate >= dueDate else {
            validationMessage = "The end date must be on or after the next due date."
            return
        }

        subscription.name = trimmedName
        subscription.amount = newAmount
        subscription.dueDate = dueDate
        subscription.endDate = hasEndDate ? endDate : nil

        do {
            try modelContext.safeSave()
            onSaved()
            HapticManager.medium()
            dismiss()
        } catch {
            self.error = .saveFailed
            HapticManager.error()
        }
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
