import SwiftUI
import SwiftData

// Account-specific display and form views are kept separate from the Dashboard
// so it can focus on assembling financial data and navigation.

struct CleanAccountCard: View {
    var account: Account
    var onEdit: () -> Void

    private var accountType: AccountType {
        AccountType(rawValue: account.type) ?? .checking
    }

    private var icon: String {
        switch accountType {
        case .checking: return "building.columns.fill"
        case .savings: return "leaf.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .creditCard: return "creditcard.fill"
        }
    }

    private var accent: Color {
        switch accountType {
        case .checking: return .burntOrange
        case .savings: return .pistachioText
        case .investment: return .steelBlue
        case .creditCard: return .wineRed
        }
    }

    private var balanceLabel: String {
        accountType == .creditCard ? "Current debt" : account.type
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name).font(.subheadline).fontWeight(.medium)
                Text(balanceLabel).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(account.balance, format: .currency(code: CurrencyFormat.code))
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(accent)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .padding(14)
        .background(Color.appSurfaceElevated)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(account.name), \(account.type), \(account.balance, format: .currency(code: CurrencyFormat.code))")
        .accessibilityHint("Double tap to edit this account")
    }
}

struct EditAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultAccount") private var defaultAccount = ""
    @Query private var allExpenses: [Expense]
    @Query private var allGoals: [SavingsGoal]
    var account: Account
    @State private var name: String
    @State private var balance: Double
    @State private var type: AccountType
    @State private var error: AppError? = nil
    @State private var showDeleteConfirm = false

    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _balance = State(initialValue: account.balance)
        _type = State(initialValue: AccountType(rawValue: account.type) ?? .checking)
    }

    private var linkedExpenseCount: Int {
        allExpenses.filter {
            $0.userID == account.userID &&
            ($0.accountID == account.uuid || ($0.accountID.isEmpty && $0.accountName == account.name))
        }.count
    }

    private var linkedGoalCount: Int {
        allGoals.filter {
            $0.userID == account.userID &&
            ($0.accountID == account.uuid || ($0.accountID.isEmpty && $0.accountName == account.name))
        }.count
    }

    private var deletionMessage: String {
        var linkedItems: [String] = []
        if linkedExpenseCount > 0 {
            linkedItems.append("\(linkedExpenseCount) expense\(linkedExpenseCount == 1 ? "" : "s")")
        }
        if linkedGoalCount > 0 {
            linkedItems.append("\(linkedGoalCount) goal\(linkedGoalCount == 1 ? "" : "s")")
        }
        guard !linkedItems.isEmpty else {
            return "This permanently deletes the account and its balance. This cannot be undone."
        }
        return "This permanently deletes the account and its balance. \(linkedItems.joined(separator: " and ")) will remain, but they will no longer be linked to an active account."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Account Name", text: $name)
                    Picker("Account Type", selection: $type) {
                        ForEach(AccountType.allCases) { type in Text(type.rawValue).tag(type) }
                    }
                    TextField("Balance", value: $balance, format: .currency(code: CurrencyFormat.code))
                        .keyboardType(.decimalPad)
                }
                Section {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Account")
            .errorAlert(error: $error)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAccount() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
            .alert("Delete \(account.name)?", isPresented: $showDeleteConfirm) {
                Button("Delete Account", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(deletionMessage)
            }
        }
    }

    private func saveAccount() {
        account.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        account.balance = balance
        account.type = type.rawValue
        do {
            try modelContext.safeSave()
            HapticManager.medium()
            dismiss()
        } catch {
            self.error = .saveFailed
            HapticManager.error()
        }
    }

    private func deleteAccount() {
        modelContext.delete(account)
        do {
            try modelContext.safeSave()
            if defaultAccount == account.uuid || defaultAccount == account.name {
                defaultAccount = ""
            }
            HapticManager.heavy()
            dismiss()
        } catch {
            self.error = .saveFailed
            HapticManager.error()
        }
    }
}

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (String, Double, String) -> Void
    @State private var name = ""
    @State private var balance = 0.0
    @State private var type: AccountType = .checking

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account Name", text: $name)
                Picker("Account Type", selection: $type) {
                    ForEach(AccountType.allCases) { type in Text(type.rawValue).tag(type) }
                }
                TextField("Starting Balance", value: $balance, format: .currency(code: CurrencyFormat.code))
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), balance, type.rawValue)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }
}
