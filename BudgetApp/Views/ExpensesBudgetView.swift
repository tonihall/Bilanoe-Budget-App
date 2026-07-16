import SwiftUI
import SwiftData
import Charts

struct ExpensesBudgetView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query var allExpenses: [Expense]
    @Query var allBudgets: [MonthlyBudget]
    @Query var allAccounts: [Account]

    var expenses: [Expense]      { allExpenses.filter  { $0.userID == auth.userID } }
    var budgets: [MonthlyBudget] { allBudgets.filter   { $0.userID == auth.userID } }
    var accounts: [Account]      { allAccounts.filter  { $0.userID == auth.userID } }

    @AppStorage("budgetMode")     var budgetMode: String = "weekly"
    @AppStorage("defaultAccount") var defaultAccount: String = ""

    @State private var showAddExpense = false
    @State private var showAddBudget = false
    @State private var expenseFilter: FilterMode = .month
    @State private var searchText: String = ""
    @State private var error: AppError? = nil
    @State private var showCharts = true

    enum FilterMode: String, CaseIterable {
        case week = "Week"; case month = "Month"; case all = "All Time"
    }

    var weeklyBudgets: [MonthlyBudget]  { budgets.filter { $0.period == "weekly" } }
    var monthlyBudgets: [MonthlyBudget] { budgets.filter { $0.period == "monthly" } }

    var filteredExpenses: [Expense] {
        let now = Date()
        var result: [Expense]
        switch expenseFilter {
        case .week:  result = expenses.filter { Calendar.current.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
        case .month: result = expenses.filter { Calendar.current.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .all:   result = expenses
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                $0.accountName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var sortedExpenses: [Expense] { filteredExpenses.sorted { $0.date > $1.date } }
    var totalSpent: Double { filteredExpenses.reduce(0) { $0 + $1.amount } }

    var categoryTotals: [(category: String, total: Double)] {
        var dict: [String: Double] = [:]
        for exp in filteredExpenses { dict[exp.category, default: 0] += exp.amount }
        return dict.map { (category: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
    }

    var dailySpending: [(date: Date, total: Double)] {
        var dict: [Date: Double] = [:]
        for exp in filteredExpenses {
            let day = Calendar.current.startOfDay(for: exp.date)
            dict[day, default: 0] += exp.amount
        }
        return dict.map { (date: $0.key, total: $0.value) }.sorted { $0.date < $1.date }
    }

    let chartColors: [Color] = [.forestGreen, .wineRed, .burntOrange, .steelBlue, .purple, .pink, .teal, .yellow, .indigo, .mint]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Total + Filter
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Spent").font(.subheadline).foregroundColor(.secondary)
                            Text(totalSpent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(totalSpent == 0 ? .secondary : .wineRed)
                        }
                        Spacer()
                        if !filteredExpenses.isEmpty {
                            Button {
                                withAnimation { showCharts.toggle() }
                            } label: {
                                Image(systemName: showCharts ? "chart.pie.fill" : "chart.pie")
                                    .font(.title3)
                                    .foregroundColor(showCharts ? .pistachio : .secondary)
                            }
                        }
                    }
                    Picker("Filter", selection: $expenseFilter) {
                        ForEach(FilterMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)

                // Charts
                if showCharts && !filteredExpenses.isEmpty {
                    if !categoryTotals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Spending by Category").font(.headline)
                            HStack(alignment: .top, spacing: 16) {
                        let topCategories = categoryTotals.prefix(10)
                        let colorMap = Dictionary(uniqueKeysWithValues:
                            topCategories.enumerated().map { ($1.category, chartColors[$0 % chartColors.count]) }
                        )

                        Chart(Array(topCategories), id: \.category) { item in
                                    SectorMark(
                                        angle: .value("Amount", item.total),
                                        innerRadius: .ratio(0.55),
                                        angularInset: 2
                                    )
                                    .foregroundStyle(colorMap[item.category] ?? .gray)
                                    .cornerRadius(4)
                                }
                                .frame(width: 130, height: 130)

                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(Array(categoryTotals.prefix(6).enumerated()), id: \.element.category) { index, item in
                                        HStack(spacing: 6) {
                                            Circle().fill(chartColors[index % chartColors.count]).frame(width: 7, height: 7)
                                            Text(item.category).font(.caption).foregroundColor(.primary).lineLimit(1)
                                            Spacer()
                                            Text(item.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    if categoryTotals.count > 6 {
                                        Text("+ \(categoryTotals.count - 6) more").font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                    }

                    if dailySpending.count > 1 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Spending Trend").font(.headline)
                            Text(expenseFilter == .week ? "This week" : expenseFilter == .month ? "This month" : "All time")
                                .font(.caption).foregroundColor(.secondary)
                            Chart(dailySpending, id: \.date) { item in
                                BarMark(x: .value("Date", item.date, unit: .day), y: .value("Spent", item.total))
                                    .foregroundStyle(Color.forestGreen.opacity(0.8))
                                    .cornerRadius(4)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisValueLabel(format: .dateTime.day()).font(.caption2)
                                }
                            }
                            .frame(height: 130)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                }

                // Budgets
                if budgetMode == "weekly" || budgetMode == "both" {
                    budgetSection(title: "Weekly Budgets", period: "weekly", periodBudgets: weeklyBudgets, granularity: .weekOfYear)
                }
                if budgetMode == "monthly" || budgetMode == "both" {
                    budgetSection(title: "Monthly Budgets", period: "monthly", periodBudgets: monthlyBudgets, granularity: .month)
                }

                // Expenses
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Expenses").font(.headline)
                        Spacer()
                        Button("+ Add") { showAddExpense = true }
                            .font(.subheadline).fontWeight(.medium).foregroundColor(.pistachio)
                    }
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search by name, category or account", text: $searchText)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(10)

                    if expenses.isEmpty {
                        EmptyStateView(icon: "receipt", title: "No Expenses Yet",
                            message: "Tap + Add to log your first transaction.",
                            buttonLabel: "Add Expense", onButton: { showAddExpense = true })
                    } else if filteredExpenses.isEmpty {
                        EmptyStateView(
                            icon: searchText.isEmpty ? "calendar.badge.exclamationmark" : "magnifyingglass",
                            title: searchText.isEmpty ? "Nothing This Period" : "No Results",
                            message: searchText.isEmpty ? "No expenses recorded for this time period." : "No expenses match \"\(searchText)\".")
                    } else {
                        List {
                            ForEach(sortedExpenses) { expense in
                                ExpenseRow(expense: expense)
                                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).padding(.vertical, 4)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            if let idx = sortedExpenses.firstIndex(where: { $0.id == expense.id }) {
                                                deleteExpense(at: IndexSet([idx]))
                                            }
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                            }
                        }
                        .listStyle(.plain).scrollDisabled(true)
                        .frame(minHeight: CGFloat(sortedExpenses.count) * 80)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Expenses & Budget")
        .errorAlert(error: $error)
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(accounts: accounts, defaultAccount: defaultAccount) { name, amount, category, date, accountName in
                guard amount > 0 else { error = .invalidAmount; return }
                if let account = accounts.first(where: { $0.name == accountName }) {
                    account.type == "Credit Card" ? (account.balance += amount) : (account.balance -= amount)
                }
                let newExpense = Expense(userID: auth.userID, name: name, amount: amount, date: date, category: category, accountName: accountName)
                modelContext.insert(newExpense)
                do { try modelContext.safeSave(); HapticManager.medium() }
                catch { self.error = .saveFailed; HapticManager.error() }
            }
        }
        .sheet(isPresented: $showAddBudget) {
            AddBudgetView(budgetMode: budgetMode, existingBudgets: budgets) { category, amount, period in
                guard amount > 0 else { error = .invalidAmount; return }
                // Check for duplicate
                if budgets.contains(where: { $0.category == category && $0.period == period }) {
                    error = .custom("\(category) budget already exists for that period. Swipe to delete it first.")
                    return
                }
                let newBudget = MonthlyBudget(userID: auth.userID, category: category, budgetAmount: amount, period: period)
                modelContext.insert(newBudget)
                do { try modelContext.safeSave(); HapticManager.medium() }
                catch { self.error = .saveFailed; HapticManager.error() }
            }
        }
    }

    private func budgetSection(title: String, period: String, periodBudgets: [MonthlyBudget], granularity: Calendar.Component) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("+ Add") { showAddBudget = true }
                    .font(.subheadline).fontWeight(.medium).foregroundColor(.pistachio)
            }
            if periodBudgets.isEmpty {
                EmptyStateView(icon: "chart.bar", title: "No \(title) Yet",
                    message: "Set a budget for categories like groceries, gas, or entertainment.",
                    buttonLabel: "Add Budget", onButton: { showAddBudget = true })
            } else {
                List {
                    ForEach(periodBudgets) { budget in
                        BudgetCategoryRow(budget: budget, expenses: expenses, granularity: granularity)
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(budget)
                                    do { try modelContext.safeSave(); HapticManager.heavy() }
                                    catch { self.error = .saveFailed }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
                .listStyle(.plain).scrollDisabled(true)
                .frame(minHeight: CGFloat(periodBudgets.count) * 95)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func deleteExpense(at offsets: IndexSet) {
        for index in offsets {
            let expense = sortedExpenses[index]
            if let account = accounts.first(where: { $0.name == expense.accountName }) {
                account.type == "Credit Card" ? (account.balance -= expense.amount) : (account.balance += expense.amount)
            }
            modelContext.delete(expense)
        }
        do { try modelContext.safeSave(); HapticManager.heavy() }
        catch { self.error = .saveFailed }
    }
}

// MARK: - Budget Category Row

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
    var remaining: Double  { budget.budgetAmount - spentInCategory }
    var isOverBudget: Bool { spentInCategory > budget.budgetAmount }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(budget.category).font(.subheadline).fontWeight(.medium)
                Spacer()
                Text(isOverBudget ? "\(abs(remaining), specifier: "%.2f") over" : "\(remaining, specifier: "%.2f") left")
                    .font(.subheadline).foregroundColor(isOverBudget ? .wineRed : .pistachio)
            }
            ProgressView(value: min(spentInCategory, budget.budgetAmount), total: budget.budgetAmount)
                .tint(isOverBudget ? .wineRed : .pistachio)
            HStack {
                Text("\(spentInCategory, specifier: "%.2f") spent").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("of \(budget.budgetAmount, specifier: "%.2f")").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(12).background(Color(UIColor.tertiarySystemBackground)).cornerRadius(10)
    }
}

// MARK: - Expense Row

struct ExpenseRow: View {
    var expense: Expense
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(UIColor.tertiarySystemBackground)).frame(width: 40, height: 40)
                Text(categoryEmoji(expense.category)).font(.system(size: 18))
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
                Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.wineRed)
                Text(expense.date, style: .date).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(12).background(Color(UIColor.tertiarySystemBackground)).cornerRadius(12)
    }

    func categoryEmoji(_ c: String) -> String {
        switch c {
        case "Food & Dining": return "🍣"; case "Transport": return "🏎️"
        case "Shopping": return "🛍️"; case "Entertainment": return "🎬"
        case "Health": return "🏥"; case "Bills & Utilities": return "💡"
        case "Travel": return "✈️"; case "Education": return "📚"
        case "Subscriptions": return "🔄"; default: return "💸"
        }
    }
}

// MARK: - Add Expense

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    var accounts: [Account]
    var defaultAccount: String
    var onSave: (String, Double, String, Date, String) -> Void
    @State private var name = ""
    @State private var amount = ""
    @State private var category = "Food & Dining"
    @State private var date = Date()
    @State private var selectedAccount = ""
    @State private var error: AppError? = nil

    let categories = ["Food & Dining","Transport","Shopping","Entertainment","Health","Bills & Utilities","Travel","Education","Subscriptions","Other"]

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
                Section("Account") {
                    if accounts.isEmpty {
                        EmptyStateView(icon: "creditcard.trianglebadge.exclamationmark", title: "No Accounts", message: "Add an account on the Dashboard first.")
                    } else {
                        Picker("Pay from", selection: $selectedAccount) {
                            ForEach(accounts) { Text("\($0.name) (\($0.type))").tag($0.name) }
                        }
                    }
                }
            }
            .navigationTitle("New Expense")
            .errorAlert(error: $error)
            .onAppear { selectedAccount = !defaultAccount.isEmpty ? defaultAccount : accounts.first?.name ?? "" }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !name.isEmpty else { error = .custom("Please enter a name."); return }
                        guard let amt = Double(amount), amt > 0 else { error = .invalidAmount; return }
                        guard !selectedAccount.isEmpty else { error = .noAccountSelected; return }
                        onSave(name, amt, category, date, selectedAccount); dismiss()
                    }.foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.pistachio) }
            }
        }
    }
}

// MARK: - Add Budget

struct AddBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    var budgetMode: String
    var existingBudgets: [MonthlyBudget]
    var onSave: (String, Double, String) -> Void
    let categories = ["Food & Dining","Transport","Shopping","Entertainment","Health","Bills & Utilities","Travel","Education","Subscriptions","Other"]
    @State private var category = "Food & Dining"
    @State private var amount = ""
    @State private var period = "monthly"
    @State private var error: AppError? = nil

    func isAlreadyUsed(_ cat: String) -> Bool {
        existingBudgets.contains { $0.category == cat && $0.period == period }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        HStack {
                            Text(cat)
                            if isAlreadyUsed(cat) { Text("(exists)").foregroundColor(.secondary).font(.caption) }
                        }.tag(cat)
                    }
                }
                TextField("Budget Amount", text: $amount).keyboardType(.decimalPad)
                if budgetMode == "both" {
                    Picker("Period", selection: $period) {
                        Text("Weekly").tag("weekly"); Text("Monthly").tag("monthly")
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
                        guard let amt = Double(amount), amt > 0 else { error = .invalidAmount; return }
                        onSave(category, amt, period); dismiss()
                    }
                    .disabled(isAlreadyUsed(category))
                    .foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.pistachio) }
            }
        }
    }
}
