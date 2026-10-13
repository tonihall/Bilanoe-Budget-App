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
    @State private var expenseToEdit: Expense? = nil
    @State private var expenseFilter: ExpenseFilter = .month
    @State private var searchText: String = ""
    @State private var error: AppError? = nil
    @State private var showCharts = false

    var weeklyBudgets: [MonthlyBudget]  { budgets.filter { $0.period == "weekly" } }
    var monthlyBudgets: [MonthlyBudget] { budgets.filter { $0.period == "monthly" } }

    var filteredExpenses: [Expense] {
        var result = expenses.filter { expenseFilter.includes($0.date) }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                $0.accountName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    private var analytics: ExpenseAnalytics { ExpenseAnalytics(expenses: filteredExpenses) }
    var sortedExpenses: [Expense] { analytics.sortedByNewest }
    var categoryTotals: [(category: String, total: Double)] { analytics.categoryTotals }
    var dailySpending: [(date: Date, total: Double)] { analytics.dailyTotals }
    private var summaryIsWeekly: Bool { budgetMode == "weekly" }
    private var summaryLabel: String { summaryIsWeekly ? "This week" : "This month" }
    private var summarySpent: Double {
        expenses
            .filter {
                Calendar.current.isDate(
                    $0.date,
                    equalTo: Date(),
                    toGranularity: summaryIsWeekly ? .weekOfYear : .month
                )
            }
            .reduce(0) { $0 + $1.amount }
    }
    private var summaryBudget: Double {
        (summaryIsWeekly ? weeklyBudgets : monthlyBudgets).reduce(0) { $0 + $1.budgetAmount }
    }
    private var summaryRemaining: Double { summaryBudget - summarySpent }

    let chartColors: [Color] = [.forestGreen, .wineRed, .burntOrange, .steelBlue, .purple, .pink, .teal, .yellow, .indigo, .mint]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // This month's snapshot
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summaryLabel).font(.subheadline).foregroundColor(.secondary)
                            Text(summarySpent, format: .currency(code: CurrencyFormat.code))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(summarySpent == 0 ? .secondary : .wineRed)
                            Text("spent so far")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if summaryBudget > 0 {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(summaryRemaining, format: .currency(code: CurrencyFormat.code))
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(summaryRemaining < 0 ? .wineRed : .pistachioText)
                                Text(summaryRemaining < 0 ? "over budget" : "left to spend")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }

                    if summaryBudget > 0 {
                        ProgressView(value: min(summarySpent, summaryBudget), total: max(summaryBudget, 1))
                            .tint(summaryRemaining < 0 ? .wineRed : .pistachio)
                    } else {
                        Button {
                            showAddBudget = true
                        } label: {
                            Label("Set a budget to see what is left", systemImage: "plus.circle")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.pistachioText)
                        }
                    }
                }
                .padding()
                .bilanoeCard()

                Button { showAddExpense = true } label: {
                    Label("Add expense", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundColor(.white)
                .background(Color.pistachioText)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Optional breakdown
                if !filteredExpenses.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showCharts.toggle() }
                    } label: {
                        Label(showCharts ? "Hide spending breakdown" : "See spending breakdown",
                              systemImage: showCharts ? "chevron.up" : "chart.pie")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

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
                                            Text(item.total, format: .currency(code: CurrencyFormat.code))
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
                    budgetSection(title: "Weekly plan", period: "weekly", periodBudgets: weeklyBudgets, granularity: .weekOfYear)
                }
                if budgetMode == "monthly" || budgetMode == "both" {
                    budgetSection(title: "Monthly plan", period: "monthly", periodBudgets: monthlyBudgets, granularity: .month)
                }

                // Expenses
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent expenses").font(.headline)
                        Spacer()
                    }
                    Text("Tap an expense to edit it")
                        .font(.caption).foregroundColor(.secondary)
                    Picker("Filter", selection: $expenseFilter) {
                        ForEach(ExpenseFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
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
                            message: accounts.isEmpty
                                ? "Add an account on Home first, then log your first transaction here."
                                : "Start with one purchase. Bilanoe will update the account you choose.",
                            buttonLabel: accounts.isEmpty ? nil : "Add Expense",
                            onButton: accounts.isEmpty ? nil : { showAddExpense = true })
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
                                    .contentShape(Rectangle())
                                    .onTapGesture { expenseToEdit = expense }
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
        .navigationTitle("Spending")
        .errorAlert(error: $error)
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(accounts: accounts, defaultAccountID: defaultAccount) { name, amount, category, date, accountID in
                guard amount > 0 else { error = .invalidAmount; return }
                guard let account = AccountLedger.account(id: accountID, in: accounts) else {
                    error = .noAccountSelected
                    return
                }
                let newExpense = Expense(userID: auth.userID, name: name, amount: amount, date: date,
                                         category: category, accountName: account.name, accountID: account.uuid)
                AccountLedger.applyExpense(newExpense, accounts: accounts)
                modelContext.insert(newExpense)
                do { try modelContext.safeSave(); HapticManager.medium() }
                catch { self.error = .saveFailed; HapticManager.error() }
            }
        }
        .sheet(item: $expenseToEdit) { expense in
            EditExpenseView(expense: expense, accounts: accounts)
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
            AccountLedger.reverseExpense(expense, accounts: accounts)
            modelContext.delete(expense)
        }
        do { try modelContext.safeSave(); HapticManager.heavy() }
        catch { self.error = .saveFailed }
    }
}
