import SwiftData
import Foundation

@Model
class Account {
    var userID: String
    var name: String
    var balance: Double
    var type: String

    init(userID: String = "", name: String, balance: Double, type: String) {
        self.userID = userID
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

    init(userID: String = "", name: String, amount: Double, date: Date, category: String, accountName: String) {
        self.userID = userID
        self.name = name
        self.amount = amount
        self.date = date
        self.category = category
        self.accountName = accountName
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
    var emoji: String
    var createdAt: Date

    init(userID: String = "", name: String, targetAmount: Double, currentAmount: Double = 0,
         deadline: Date? = nil, accountName: String = "", emoji: String = "🎯") {
        self.userID = userID
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.accountName = accountName
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
