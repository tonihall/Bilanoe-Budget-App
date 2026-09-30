//
//  BudgetAppTests.swift
//  BudgetAppTests
//
//  Created by Toni Hall on 2/23/26.
//

import Foundation
import SwiftData
import Testing
@testable import Bilanoe

struct BudgetAppTests {

    @Test @MainActor func accountRoundTripsThroughSwiftData() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Account.self, configurations: configuration)
        let context = container.mainContext
        let account = Account(userID: "toni", name: "Checking", balance: 600, type: AccountType.checking.rawValue)

        context.insert(account)
        try context.save()

        let savedAccounts = try context.fetch(FetchDescriptor<Account>())
        #expect(savedAccounts.count == 1)
        #expect(savedAccounts[0].userID == "toni")
        #expect(savedAccounts[0].name == "Checking")
        #expect(savedAccounts[0].balance == 600)
        #expect(savedAccounts[0].uuid == account.uuid)
    }

    @Test func expenseLedgerUpdatesAndReversesCheckingBalance() {
        let account = Account(userID: "test", name: "Checking", balance: 100, type: AccountType.checking.rawValue)
        let expense = Expense(
            userID: "test", name: "Groceries", amount: 25, date: Date(),
            category: ExpenseCategory.foodDining.rawValue, accountName: account.name, accountID: account.uuid
        )

        AccountLedger.applyExpense(expense, accounts: [account])
        #expect(account.balance == 75)

        AccountLedger.reverseExpense(expense, accounts: [account])
        #expect(account.balance == 100)
    }

    @Test func creditCardExpenseRaisesBalance() {
        let account = Account(userID: "test", name: "Card", balance: 100, type: AccountType.creditCard.rawValue)
        let expense = Expense(
            userID: "test", name: "Fuel", amount: 20, date: Date(),
            category: ExpenseCategory.transport.rawValue, accountName: account.name, accountID: account.uuid
        )

        AccountLedger.applyExpense(expense, accounts: [account])
        #expect(account.balance == 120)
    }

    @Test func expenseAnalyticsGroupsCategoriesAndOrdersNewestFirst() {
        let older = Expense(userID: "test", name: "Coffee", amount: 5, date: .distantPast, category: ExpenseCategory.foodDining.rawValue, accountName: "Checking")
        let newer = Expense(userID: "test", name: "Bus", amount: 3, date: .now, category: ExpenseCategory.transport.rawValue, accountName: "Checking")
        let analytics = ExpenseAnalytics(expenses: [older, newer])

        #expect(analytics.totalSpent == 8)
        #expect(analytics.sortedByNewest.first?.name == "Bus")
        #expect(analytics.categoryTotals.count == 2)
    }

}
