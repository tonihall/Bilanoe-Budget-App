import Foundation
import SwiftData

@Model
class Account {
    var name: String
    var balance: Double
    
    init(name: String, balance: Double) {
        self.name = name
        self.balance = balance
    }
}

@Model
class Expense {
    var name: String
    var amount: Double
    var date: Date
    var category: String
    var accountName: String
    
    init(name: String, amount: Double, date: Date, category: String, accountName: String) {
        self.name = name
        self.amount = amount
        self.date = date
        self.category = category
        self.accountName = accountName
    }
}

@Model
class MonthlyBudget {
    var category: String
    var budgetAmount: Double
    var spentAmount: Double
    
    init(category: String, budgetAmount: Double, spentAmount: Double = 0) {
        self.category = category
        self.budgetAmount = budgetAmount
        self.spentAmount = spentAmount
    }
}

@Model
class Subscription {
    var name: String
    var amount: Double
    var dueDate: Date
    var endDate: Date?
    
    init(name: String, amount: Double, dueDate: Date, endDate: Date? = nil) {
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.endDate = endDate
    }
}
