import SwiftUI
import SwiftData

// Supporting views for the Expenses & Budget screen live here so the feature's
// coordinator stays focused on loading data and handling feature actions.

struct BudgetCategoryRow: View {
    var budget: MonthlyBudget
    var expenses: [Expense]
    var granularity: Calendar.Component

    var spentInCategory: Double {
        expenses.filter {
            $0.category == budget.category &&
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: granularity)
        }.reduce(0) { $0 + $1.amount }
    }
    var remaining: Double { budget.budgetAmount - spentInCategory }
    var isOverBudget: Bool { spentInCategory > budget.budgetAmount }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(budget.category).font(.subheadline).fontWeight(.medium)
                Spacer()
                Text(isOverBudget
                    ? "\(abs(remaining), format: .currency(code: CurrencyFormat.code)) over"
                    : "\(remaining, format: .currency(code: CurrencyFormat.code)) left")
                    .font(.subheadline).foregroundColor(isOverBudget ? .wineRed : .pistachio)
            }
            ProgressView(value: min(spentInCategory, budget.budgetAmount), total: budget.budgetAmount)
                .tint(isOverBudget ? .wineRed : .pistachio)
            HStack {
                Text("\(spentInCategory, format: .currency(code: CurrencyFormat.code)) spent")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("of \(budget.budgetAmount, format: .currency(code: CurrencyFormat.code))")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(12).background(Color.appSurfaceElevated).cornerRadius(10)
    }
}

struct ExpenseRow: View {
    var expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.appSurfaceElevated).frame(width: 40, height: 40)
                Text(ExpenseCategory(rawValue: expense.category)?.emoji ?? ExpenseCategory.other.emoji)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name).font(.subheadline).fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(expense.category).font(.caption).foregroundColor(.secondary)
                    Text("·").font(.caption).foregroundColor(.secondary)
                    Text(expense.accountName).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount, format: .currency(code: CurrencyFormat.code))
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.wineRed)
                Text(expense.date, style: .date).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(12).background(Color.appSurfaceElevated).cornerRadius(12)
    }
}

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    var accounts: [Account]
    var defaultAccountID: String
    var onSave: (String, Double, String, Date, String) -> Void
    @State private var name = ""
    @State private var amount = ""
    @State private var category = "Food & Dining"
    @State private var date = Date()
    @State private var selectedAccount = ""
    @State private var error: AppError? = nil

    let categories = ExpenseCategory.allCases.map(\.rawValue)

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Expense Name", text: $name)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    if accounts.isEmpty {
                        EmptyStateView(icon: "creditcard.trianglebadge.exclamationmark", title: "No Accounts", message: "Add an account on the Dashboard first.")
                    } else {
                        Picker("Pay from", selection: $selectedAccount) {
                            ForEach(accounts) { Text("\($0.name) (\($0.type))").tag($0.uuid) }
                        }
                    }
                }
            }
            .navigationTitle("New Expense")
            .errorAlert(error: $error)
            .onAppear {
                selectedAccount = accounts.contains { $0.uuid == defaultAccountID }
                    ? defaultAccountID : accounts.first?.uuid ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !name.isEmpty else { error = .custom("Please enter a name."); return }
                        guard let amount = Double(amount), amount > 0 else { error = .invalidAmount; return }
                        guard !selectedAccount.isEmpty else { error = .noAccountSelected; return }
                        onSave(name, amount, category, date, selectedAccount)
                        dismiss()
                    }.foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }
}

struct EditExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let expense: Expense
    let accounts: [Account]
    @State private var name: String
    @State private var amount: String
    @State private var category: String
    @State private var date: Date
    @State private var selectedAccountID: String
    @State private var error: AppError? = nil
    private let categories = ExpenseCategory.allCases.map(\.rawValue)

    init(expense: Expense, accounts: [Account]) {
        self.expense = expense
        self.accounts = accounts
        _name = State(initialValue: expense.name)
        _amount = State(initialValue: String(format: "%.2f", expense.amount))
        _category = State(initialValue: expense.category)
        _date = State(initialValue: expense.date)
        _selectedAccountID = State(initialValue: AccountLedger.account(id: expense.accountID, fallbackName: expense.accountName, in: accounts)?.uuid ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Expense Name", text: $name)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    if accounts.isEmpty {
                        Text("No accounts available. Add an account on the Dashboard first.")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        Picker("Paid from", selection: $selectedAccountID) {
                            ForEach(accounts) { account in
                                Text("\(account.name) (\(account.type))").tag(account.uuid)
                            }
                        }
                    }
                } header: { Text("Account") } footer: {
                    Text("Saving reverses the original account impact before applying these updated details.")
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert(error: $error)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .foregroundColor(.pistachio)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.isEmpty || selectedAccountID.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }

    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { error = .custom("Please enter a name."); return }
        guard let newAmount = Double(amount), newAmount > 0 else { error = .invalidAmount; return }
        guard let newAccount = AccountLedger.account(id: selectedAccountID, in: accounts) else {
            error = .noAccountSelected
            return
        }
        AccountLedger.reverseExpense(expense, accounts: accounts)
        expense.name = trimmedName
        expense.amount = newAmount
        expense.category = category
        expense.date = date
        expense.accountID = newAccount.uuid
        expense.accountName = newAccount.name
        AccountLedger.applyExpense(expense, accounts: accounts)
        do {
            try modelContext.safeSave()
            HapticManager.medium()
            dismiss()
        } catch {
            self.error = .saveFailed
            HapticManager.error()
        }
    }
}

struct AddBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    var budgetMode: String
    var existingBudgets: [MonthlyBudget]
    var onSave: (String, Double, String) -> Void
    let categories = ExpenseCategory.allCases.map(\.rawValue)
    @State private var category = "Food & Dining"
    @State private var amount = ""
    @State private var period = "monthly"
    @State private var error: AppError? = nil

    func isAlreadyUsed(_ category: String) -> Bool {
        existingBudgets.contains { $0.category == category && $0.period == period }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { category in
                        HStack {
                            Text(category)
                            if isAlreadyUsed(category) { Text("(exists)").foregroundColor(.secondary).font(.caption) }
                        }.tag(category)
                    }
                }
                TextField("Budget Amount", text: $amount).keyboardType(.decimalPad)
                if budgetMode == "both" {
                    Picker("Period", selection: $period) {
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }.pickerStyle(.segmented)
                }
                if isAlreadyUsed(category) {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            Text("A \(period) budget for \(category) already exists. Delete it first to replace it.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Budget")
            .errorAlert(error: $error)
            .onAppear { period = budgetMode == "weekly" ? "weekly" : "monthly" }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = Double(amount), amount > 0 else { error = .invalidAmount; return }
                        onSave(category, amount, period)
                        dismiss()
                    }
                    .disabled(isAlreadyUsed(category))
                    .foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }
}
