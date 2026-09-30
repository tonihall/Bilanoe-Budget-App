import SwiftData
import Foundation

enum AccountType: String, CaseIterable, Identifiable, Codable {
    case checking = "Checking"
    case savings = "Savings"
    case investment = "Investment"
    case creditCard = "Credit Card"

    var id: String { rawValue }
}

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case foodDining = "Food & Dining"
    case transport = "Transport"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case health = "Health"
    case billsUtilities = "Bills & Utilities"
    case travel = "Travel"
    case education = "Education"
    case subscriptions = "Subscriptions"
    case other = "Other"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .foodDining: return "🍣"
        case .transport: return "🏎️"
        case .shopping: return "🛍️"
        case .entertainment: return "🎬"
        case .health: return "🏥"
        case .billsUtilities: return "💡"
        case .travel: return "✈️"
        case .education: return "📚"
        case .subscriptions: return "🔄"
        case .other: return "💸"
        }
    }
}

enum ExpenseFilter: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case all = "All Time"

    var id: String { rawValue }

    func includes(_ date: Date, relativeTo referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .week:
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .month)
        case .all:
            return true
        }
    }
}

enum IncomeFrequency: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case biWeekly = "Bi-Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }

    var monthlyMultiplier: Double {
        switch self {
        case .weekly: return 52 / 12
        case .biWeekly: return 26 / 12
        case .monthly: return 1
        }
    }
}

/// A draft income source used while assembling an income distribution.
struct IncomeSource: Identifiable {
    var id = UUID()
    var name = ""
    var amount = ""
    var frequency: IncomeFrequency = .monthly

    var amountDouble: Double { Double(amount) ?? 0 }
    var monthlyEquivalent: Double { amountDouble * frequency.monthlyMultiplier }
}

struct ExpenseAnalytics {
    let expenses: [Expense]
    private let calendar: Calendar

    init(expenses: [Expense], calendar: Calendar = .current) {
        self.expenses = expenses
        self.calendar = calendar
    }

    var totalSpent: Double { expenses.reduce(0) { $0 + $1.amount } }
    var sortedByNewest: [Expense] { expenses.sorted { $0.date > $1.date } }

    var categoryTotals: [(category: String, total: Double)] {
        Dictionary(grouping: expenses, by: \.category)
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    var dailyTotals: [(date: Date, total: Double)] {
        Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
            .map { (date: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.date < $1.date }
    }
}

@Model
class Account {
    var userID: String
    var uuid: String
    var name: String
    var balance: Double
    var type: String

    init(userID: String = "", name: String, balance: Double, type: String) {
        self.userID = userID
        self.uuid = UUID().uuidString
        self.name = name
        self.balance = balance
        self.type = type
    }
}

@Model
class Expense {
    var userID: String
    var name: String
    var amount: Double
    var date: Date
    var category: String
    var accountName: String
    /// Stable account reference. `accountName` remains as the display snapshot for older data.
    var accountID: String

    init(userID: String = "", name: String, amount: Double, date: Date, category: String, accountName: String, accountID: String = "") {
        self.userID = userID
        self.name = name
        self.amount = amount
        self.date = date
        self.category = category
        self.accountName = accountName
        self.accountID = accountID
    }
}

@Model
class MonthlyBudget {
    var userID: String
    var category: String
    var budgetAmount: Double
    var period: String

    init(userID: String = "", category: String, budgetAmount: Double, period: String = "monthly") {
        self.userID = userID
        self.category = category
        self.budgetAmount = budgetAmount
        self.period = period
    }
}

@Model
class Subscription {
    var userID: String
    var uuid: String
    var name: String
    var amount: Double
    var dueDate: Date
    var endDate: Date?

    init(userID: String = "", name: String, amount: Double, dueDate: Date, endDate: Date? = nil) {
        self.userID = userID
        self.uuid = UUID().uuidString
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.endDate = endDate
    }
}

@Model
class Income {
    var userID: String
    var amount: Double
    var frequency: String
    var date: Date
    var savingsPct: Double
    var investPct: Double
    var debtPct: Double
    var checkingPct: Double

    init(userID: String = "", amount: Double, frequency: String, date: Date = Date(),
         savingsPct: Double, investPct: Double, debtPct: Double, checkingPct: Double) {
        self.userID = userID
        self.amount = amount
        self.frequency = frequency
        self.date = date
        self.savingsPct = savingsPct
        self.investPct = investPct
        self.debtPct = debtPct
        self.checkingPct = checkingPct
    }
}

@Model
class NetWorthSnapshot {
    var userID: String
    var date: Date
    var netWorth: Double

    init(userID: String = "", date: Date = Date(), netWorth: Double) {
        self.userID = userID
        self.date = date
        self.netWorth = netWorth
    }
}

@Model
class SavingsGoal {
    var userID: String
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var deadline: Date?
    var accountName: String
    /// Stable account reference. `accountName` is kept for display and migration fallback.
    var accountID: String
    var emoji: String
    var createdAt: Date

    init(userID: String = "", name: String, targetAmount: Double, currentAmount: Double = 0,
         deadline: Date? = nil, accountName: String = "", accountID: String = "", emoji: String = "🎯") {
        self.userID = userID
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.accountName = accountName
        self.accountID = accountID
        self.emoji = emoji
        self.createdAt = Date()
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }

    var isComplete: Bool { currentAmount >= targetAmount }

    var monthsRemaining: Int? {
        guard let deadline = deadline else { return nil }
        let months = Calendar.current.dateComponents([.month], from: Date(), to: deadline).month ?? 0
        return max(0, months)
    }

    var monthlyContributionNeeded: Double? {
        guard let months = monthsRemaining, months > 0 else { return nil }
        let remaining = targetAmount - currentAmount
        return max(0, remaining / Double(months))
    }
}

// MARK: - Account Balance Rules

/// Keeps account-balance rules in one place so each feature applies the same financial behavior.
enum AccountLedger {
    static func account(id: String, fallbackName: String = "", in accounts: [Account]) -> Account? {
        accounts.first { $0.uuid == id }
            ?? accounts.first { !$0.name.isEmpty && $0.name == fallbackName }
    }

    /// Records money leaving an account. Credit-card balances represent debt, so they rise when charged.
    static func debit(_ account: Account, amount: Double) {
        account.balance += account.type == "Credit Card" ? amount : -amount
    }

    /// Reverses a debit. This is used when deleting an expense or refunding a goal contribution.
    static func credit(_ account: Account, amount: Double) {
        account.balance += account.type == "Credit Card" ? -amount : amount
    }

    static func applyExpense(_ expense: Expense, accounts: [Account]) {
        guard let account = account(id: expense.accountID, fallbackName: expense.accountName, in: accounts) else { return }
        debit(account, amount: expense.amount)
    }

    static func reverseExpense(_ expense: Expense, accounts: [Account]) {
        guard let account = account(id: expense.accountID, fallbackName: expense.accountName, in: accounts) else { return }
        credit(account, amount: expense.amount)
    }

    /// Applies an income allocation to the first account of each matching type.
    /// A negative amount reverses a previous allocation.
    static func applyIncome(amount: Double, savingsPct: Double, investmentPct: Double,
                            debtPct: Double, checkingPct: Double, accounts: [Account]) {
        if let savings = accounts.first(where: { $0.type == AccountType.savings.rawValue }) {
            savings.balance += amount * savingsPct / 100
        }
        if let investment = accounts.first(where: { $0.type == AccountType.investment.rawValue }) {
            investment.balance += amount * investmentPct / 100
        }
        if let creditCard = accounts.first(where: { $0.type == AccountType.creditCard.rawValue }) {
            creditCard.balance -= amount * debtPct / 100
        }
        if let checking = accounts.first(where: { $0.type == AccountType.checking.rawValue }) {
            checking.balance += amount * checkingPct / 100
        }
    }
}
