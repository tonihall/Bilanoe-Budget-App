import SwiftUI
import SwiftData

struct ExpensesBudgetView: View {
    var account: Account

    @Environment(\.modelContext) private var modelContext
    @Query var expenses: [Expense]
    @Query var budgets: [MonthlyBudget]

    @State private var showAddExpense = false
    @State private var showAddBudget = false

    var body: some View {
        NavigationView {
            VStack {
                // Budgets Section
                HStack {
                    Text("Monthly Budgets")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("+ Budget") {
                        showAddBudget = true
                    }
                }
                .padding([.top, .horizontal])

                List {
                    ForEach(budgets) { budget in
                        HStack {
                            Text(budget.category)
                            Spacer()
                            Text("$\(budget.spentAmount, specifier: "%.2f") / $\(budget.budgetAmount, specifier: "%.2f")")
                        }
                    }
                }
                .frame(height: 200)

                Divider()

                // Expenses Section
                HStack {
                    Text("Expenses")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("+ Expense") {
                        showAddExpense = true
                    }
                }
                .padding([.top, .horizontal])

                List {
                    ForEach(expenses.filter { $0.accountName == account.name }) { expense in
                        VStack(alignment: .leading) {
                            Text(expense.name)
                                .font(.headline)
                            HStack {
                                Text("$\(expense.amount, specifier: "%.2f")")
                                Spacer()
                                Text(expense.category)
                                Text(expense.date, style: .date)
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Expenses & Budget")
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView(account: account)
            }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetView()
            }
        }
    }
}
