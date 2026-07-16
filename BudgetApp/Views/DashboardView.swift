import SwiftUI
import SwiftData
import Charts

enum AccountType: String, CaseIterable, Identifiable, Codable {
    case checking   = "Checking"
    case savings    = "Savings"
    case investment = "Investment"
    case creditCard = "Credit Card"
    var id: String { self.rawValue }
}

struct DashboardView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var allAccounts: [Account]
    @Query private var allExpenses: [Expense]
    @Query private var allSubscriptions: [Subscription]
    @Query private var allBudgets: [MonthlyBudget]
    @Query private var allSnapshots: [NetWorthSnapshot]
    @Query private var allIncomes: [Income]

    var accounts: [Account]           { allAccounts.filter      { $0.userID == auth.userID } }
    var expenses: [Expense]           { allExpenses.filter      { $0.userID == auth.userID } }
    var subscriptions: [Subscription] { allSubscriptions.filter { $0.userID == auth.userID } }
    var budgets: [MonthlyBudget]      { allBudgets.filter       { $0.userID == auth.userID } }
    var snapshots: [NetWorthSnapshot] { allSnapshots.filter     { $0.userID == auth.userID }.sorted { $0.date < $1.date } }
    var incomes: [Income]             { allIncomes.filter       { $0.userID == auth.userID } }

    @AppStorage("budgetMode") var budgetMode: String = "weekly"

    var notesKey: String { "notes_\(auth.userID)" }
    @State private var notes: String = ""
    @State private var isEditingNotes = false
    @State private var showingAddAccount = false
    @State private var accountToEdit: Account? = nil
    @State private var isEditing = false
    @State private var showSettings = false
    @State private var error: AppError? = nil
    @State private var showNetWorthChart = false

    var currentNetWorth: Double {
        accounts.reduce(0.0) { $0 + ($1.type == "Credit Card" ? -$1.balance : $1.balance) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                netWorthView
                accountsListView

                Button { showingAddAccount = true } label: {
                    Label("Add Account", systemImage: "plus.circle")
                        .font(.subheadline).fontWeight(.medium)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.pistachioSubtle)
                        .foregroundColor(.pistachioText)
                        .cornerRadius(12)
                }

                incomeVsExpensesChart
                streakView
                budgetView
                alertsView
                notesView
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            notes = UserDefaults.standard.string(forKey: notesKey) ?? ""
            saveNetWorthSnapshot()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").foregroundColor(.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") { isEditing.toggle() }
                    .foregroundColor(.pistachio)
            }
        }
        .errorAlert(error: $error)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView { name, balance, type in
                let newAccount = Account(userID: auth.userID, name: name, balance: balance, type: type)
                modelContext.insert(newAccount)
                do { try modelContext.safeSave(); HapticManager.medium() }
                catch { self.error = .saveFailed; HapticManager.error() }
            }
        }
        .sheet(item: $accountToEdit) { account in EditAccountView(account: account) }
    }

    // MARK: Snapshot

    private func saveNetWorthSnapshot() {
        guard !accounts.isEmpty else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let alreadySaved = snapshots.contains { Calendar.current.startOfDay(for: $0.date) == today }
        guard !alreadySaved else { return }
        modelContext.insert(NetWorthSnapshot(userID: auth.userID, date: Date(), netWorth: currentNetWorth))
        try? modelContext.save()
    }

    // MARK: Net Worth

    private var netWorthView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Worth")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(currentNetWorth, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(currentNetWorth >= 0 ? .primary : .wineRed)
                }
                Spacer()
                if snapshots.count > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showNetWorthChart.toggle() }
                    } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundColor(showNetWorthChart ? .pistachio : .secondary)
                    }
                }
            }

            if accounts.isEmpty {
                Text("Add your first account to get started")
                    .font(.caption).foregroundColor(.secondary)
            }

            if showNetWorthChart && snapshots.count > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Net Worth History")
                        .font(.caption).foregroundColor(.secondary)

                    // Deduplicate — keep only the latest snapshot per day
                    let dedupedSnapshots: [NetWorthSnapshot] = {
                        var seen: [Date: NetWorthSnapshot] = [:]
                        for s in snapshots {
                            let day = Calendar.current.startOfDay(for: s.date)
                            if seen[day] == nil || s.date > seen[day]!.date {
                                seen[day] = s
                            }
                        }
                        return seen.values.sorted { $0.date < $1.date }
                    }()

                    Chart(dedupedSnapshots) { snapshot in
                        LineMark(
                            x: .value("Date", snapshot.date),
                            y: .value("Net Worth", snapshot.netWorth)
                        )
                        .foregroundStyle(Color.pistachio)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", snapshot.date),
                            y: .value("Net Worth", snapshot.netWorth)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [Color.pistachio.opacity(0.25), Color.pistachio.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", snapshot.date),
                            y: .value("Net Worth", snapshot.netWorth)
                        )
                        .foregroundStyle(Color.pistachio)
                        .symbolSize(25)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .weekOfYear)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.month(.abbreviated).day())
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                            AxisValueLabel {
                                if let val = value.as(Double.self) {
                                    Text(val, format: .currency(code: Locale.current.currency?.identifier ?? "USD").precision(.fractionLength(0)))
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                        }
                    }
                    .frame(height: 180)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: Income vs Expenses

    private var incomeVsExpensesChart: some View {
        let months = last6Months()
        guard !months.isEmpty else { return AnyView(EmptyView()) }
        let hasData = months.contains { $0.income > 0 || $0.expenses > 0 }
        guard hasData else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("Income vs Expenses")
                    .font(.headline)
                Text("Last 6 months")
                    .font(.caption).foregroundColor(.secondary)

                Chart {
                    ForEach(months, id: \.month) { item in
                        BarMark(x: .value("Month", item.month), y: .value("Amount", item.income))
                            .foregroundStyle(Color.pistachio.opacity(0.85))
                            .cornerRadius(4)
                        BarMark(x: .value("Month", item.month), y: .value("Amount", item.expenses))
                            .foregroundStyle(Color.wineRed.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
                .frame(height: 160)

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.pistachio).frame(width: 8, height: 8)
                        Text("Income").font(.caption).foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.wineRed.opacity(0.8)).frame(width: 8, height: 8)
                        Text("Expenses").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        )
    }

    private struct MonthData { var month: String; var income: Double; var expenses: Double }

    private func last6Months() -> [MonthData] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return (0..<6).reversed().compactMap { i -> MonthData? in
            guard let d = Calendar.current.date(byAdding: .month, value: -i, to: Date()) else { return nil }
            let inc = incomes.filter  { Calendar.current.isDate($0.date, equalTo: d, toGranularity: .month) }.reduce(0) { $0 + $1.amount }
            let exp = expenses.filter { Calendar.current.isDate($0.date, equalTo: d, toGranularity: .month) }.reduce(0) { $0 + $1.amount }
            return MonthData(month: formatter.string(from: d), income: inc, expenses: exp)
        }
    }

    // MARK: Accounts

    private var accountsListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accounts").font(.headline)
            if accounts.isEmpty {
                EmptyStateView(icon: "creditcard", title: "No Accounts Yet",
                    message: "Add a checking, savings, or investment account to start tracking your net worth.",
                    buttonLabel: "Add Account", onButton: { showingAddAccount = true })
            } else {
                ForEach(accounts) { account in
                    CleanAccountCard(account: account, isEditing: isEditing) { accountToEdit = account }
                }
                if isEditing {
                    Text("Tap an account to edit it").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: Streak

    var spendingStreak: Int {
        guard !budgets.isEmpty else { return 0 }
        let monthlyTotal = budgets.filter { $0.period == "monthly" }.reduce(0) { $0 + $1.budgetAmount }
        let weeklyTotal  = budgets.filter { $0.period == "weekly"  }.reduce(0) { $0 + $1.budgetAmount }
        var dailyBudget: Double = 0
        if monthlyTotal > 0 { dailyBudget += monthlyTotal / 30 }
        if weeklyTotal  > 0 { dailyBudget += weeklyTotal  / 7  }
        guard dailyBudget > 0 else { return 0 }

        // Only count back as far as the first expense ever logged
        guard let firstExpenseDate = expenses.map({ $0.date }).min() else { return 0 }
        let appStartDay = Calendar.current.startOfDay(for: firstExpenseDate)

        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())

        for _ in 0..<365 {
            // Don't go further back than when the app was first used
            if checkDate < appStartDay { break }

            let dayExpenses = expenses.filter {
                Calendar.current.startOfDay(for: $0.date) == checkDate
            }

            // Only count this day if there was at least one expense logged OR it's today
            // (today with no expenses is still valid — you haven't broken the streak yet)
            let isToday = checkDate == Calendar.current.startOfDay(for: Date())
            let hasActivity = !dayExpenses.isEmpty

            if isToday || hasActivity {
                let dayTotal = dayExpenses.reduce(0) { $0 + $1.amount }
                if dayTotal <= dailyBudget {
                    streak += 1
                } else {
                    break
                }
            } else {
                // No expenses and not today — don't count silent past days
                break
            }

            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    private var streakView: some View {
        let streak = spendingStreak
        let emoji: String
        let message: String
        switch streak {
        case 0:       emoji = "😇"; message = "Stay under budget today to start a streak"
        case 1:       emoji = "🥳"; message = "Day 1 — great start!"
        case 2:       emoji = "🌱"; message = "2 days strong!"
        case 3...6:   emoji = "🔥"; message = "\(streak) days — you're on a roll!"
        case 7...13:  emoji = "⚡"; message = "\(streak) days — one full week!"
        case 14...29: emoji = "🚀"; message = "\(streak) days — incredible!"
        default:      emoji = "👑"; message = "\(streak) days — absolute legend!"
        }

        return HStack(spacing: 14) {
            Text(emoji).font(.system(size: 32))
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(streak == 0 ? .secondary : .primary)
                    Text("day streak")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Text(message).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(streak >= 7
            ? AnyView(Color.pistachio.opacity(0.08))
            : AnyView(Color(UIColor.secondarySystemBackground))
        )
        .cornerRadius(16)
        .overlay(streak >= 7
            ? AnyView(RoundedRectangle(cornerRadius: 16).stroke(Color.pistachio.opacity(0.3), lineWidth: 1))
            : AnyView(EmptyView())
        )
    }

    // MARK: Budget

    private var budgetView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Budget").font(.headline)
            if budgetMode == "weekly" || budgetMode == "both" {
                budgetSummaryRow(label: "This Week", period: "weekly", granularity: .weekOfYear)
            }
            if budgetMode == "monthly" || budgetMode == "both" {
                budgetSummaryRow(label: "This Month", period: "monthly", granularity: .month)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func budgetSummaryRow(label: String, period: String, granularity: Calendar.Component) -> some View {
        let periodBudgets = budgets.filter { $0.period == period }
        let totalBudget = periodBudgets.reduce(0) { $0 + $1.budgetAmount }
        let spent = expenses.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: granularity) }.reduce(0.0) { $0 + $1.amount }
        let remaining = totalBudget - spent
        let isOver = spent > totalBudget && totalBudget > 0

        return VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            if totalBudget == 0 {
                Text("No budgets set — add them in Expenses & Budget").font(.caption).foregroundColor(.secondary)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(.title2).bold().foregroundColor(isOver ? .wineRed : .primary)
                        Text("of \(totalBudget, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(remaining, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(.headline).foregroundColor(isOver ? .wineRed : .pistachio)
                        Text(isOver ? "over budget" : "remaining").font(.caption).foregroundColor(.secondary)
                    }
                }
                ProgressView(value: min(spent, totalBudget), total: max(totalBudget, 1))
                    .tint(isOver ? .wineRed : .pistachio)
            }
        }
    }

    // MARK: Alerts

    private var alertsView: some View {
        let dueSoon = subscriptions.filter {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: $0.dueDate).day ?? 999
            return days >= 0 && days <= 7
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Alerts").font(.headline)
            if subscriptions.isEmpty {
                EmptyStateView(icon: "bell.slash", title: "No Subscriptions", message: "Add subscriptions to get due date alerts here.")
            } else if dueSoon.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.pistachio)
                    Text("No upcoming bills this week — you're all good!").font(.subheadline).foregroundColor(.secondary)
                }
            } else {
                ForEach(dueSoon) { sub in
                    HStack {
                        Image(systemName: "bell.fill").foregroundColor(.orange)
                        Text("\(sub.name) due \(sub.dueDate, style: .date)").font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: Notes

    private var notesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Notes").font(.headline)
                Spacer()
                Button {
                    if isEditingNotes { UserDefaults.standard.set(notes, forKey: notesKey) }
                    isEditingNotes.toggle()
                } label: {
                    Text(isEditingNotes ? "Done" : "Edit")
                        .font(.subheadline).foregroundColor(.pistachio)
                }
            }
            if isEditingNotes {
                TextEditor(text: $notes)
                    .frame(minHeight: 120).padding(8)
                    .background(Color(UIColor.tertiarySystemBackground)).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pistachio.opacity(0.4), lineWidth: 1))
            } else if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(icon: "note.text", title: "No Notes Yet",
                    message: "Tap Edit to jot down goals, reminders, or anything financial.",
                    buttonLabel: "Add Note", onButton: { isEditingNotes = true })
            } else {
                Text(notes).font(.subheadline).foregroundColor(.primary).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Account Card

struct CleanAccountCard: View {
    var account: Account
    var isEditing: Bool
    var onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(account.name).font(.subheadline).fontWeight(.medium)
                Text(account.type).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(account.balance, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(account.type == "Credit Card" ? .wineRed : .primary)
            if isEditing {
                Image(systemName: "pencil.circle.fill").foregroundColor(.pistachio).font(.title3).padding(.leading, 8)
            }
        }
        .padding(14)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture { if isEditing { onEdit() } }
    }
}

// MARK: - Edit Account

struct EditAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    var account: Account
    @State private var name: String
    @State private var balance: Double
    @State private var type: AccountType
    @State private var error: AppError? = nil
    @State private var showDeleteConfirm = false

    init(account: Account) {
        self.account = account
        _name    = State(initialValue: account.name)
        _balance = State(initialValue: account.balance)
        _type    = State(initialValue: AccountType(rawValue: account.type) ?? .checking)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Account Name", text: $name)
                    Picker("Account Type", selection: $type) {
                        ForEach(AccountType.allCases) { t in Text(t.rawValue).tag(t) }
                    }
                    TextField("Balance", value: $balance, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Account")
            .errorAlert(error: $error)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        account.name = name; account.balance = balance; account.type = type.rawValue
                        do { try modelContext.safeSave(); HapticManager.medium(); dismiss() }
                        catch { self.error = .saveFailed; HapticManager.error() }
                    }
                    .disabled(name.isEmpty)
                    .foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
            .alert("Delete \(account.name)?", isPresented: $showDeleteConfirm) {
                Button("Delete Account", role: .destructive) {
                    modelContext.delete(account)
                    do { try modelContext.safeSave(); HapticManager.heavy(); dismiss() }
                    catch { self.error = .saveFailed }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete the account and its balance. Your expenses and subscriptions linked to this account won't be deleted.")
            }
        }
    }
}

// MARK: - Add Account

struct AddAccountView: View {
    @Environment(\.dismiss) var dismiss
    var onSave: (String, Double, String) -> Void
    @State private var name: String = ""
    @State private var balance: Double = 0
    @State private var type: AccountType = .checking

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account Name", text: $name)
                Picker("Account Type", selection: $type) {
                    ForEach(AccountType.allCases) { t in Text(t.rawValue).tag(t) }
                }
                TextField("Starting Balance", value: $balance, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(name, balance, type.rawValue); dismiss() }
                        .disabled(name.isEmpty).foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }
}
