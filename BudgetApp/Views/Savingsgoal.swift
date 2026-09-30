import SwiftUI
import SwiftData

struct SavingsGoalsView: View {
    var showsNavigationTitle = true
    @EnvironmentObject var auth: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var allGoals: [SavingsGoal]
    @Query private var allAccounts: [Account]

    var goals: [SavingsGoal] { allGoals.filter    { $0.userID == auth.userID } }
    var accounts: [Account]  { allAccounts.filter { $0.userID == auth.userID } }

    @State private var showAddGoal = false
    @State private var goalToContribute: SavingsGoal? = nil
    @State private var goalToWithdraw: SavingsGoal? = nil
    @State private var goalToDelete: SavingsGoal? = nil
    @State private var showDeleteAlert = false
    @State private var error: AppError? = nil
    @State private var showSuccessBanner = false
    @State private var showCompletedGoals = false
    @State private var successMessage = ""

    var activeGoals: [SavingsGoal]    { goals.filter { !$0.isComplete }.sorted { $0.createdAt < $1.createdAt } }
    var completedGoals: [SavingsGoal] { goals.filter {  $0.isComplete }.sorted { $0.createdAt < $1.createdAt } }
    var totalSaved: Double  { goals.reduce(0) { $0 + $1.currentAmount } }
    var totalTarget: Double { goals.reduce(0) { $0 + $1.targetAmount  } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button { showAddGoal = true } label: {
                    Label("Add goal", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundColor(.white)
                .background(Color.pistachioText)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if !goals.isEmpty {
                    summaryCard
                }

                if showSuccessBanner {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.pistachio)
                        Text(successMessage).font(.subheadline).foregroundColor(.pistachioText)
                    }
                    .padding().frame(maxWidth: .infinity)
                    .background(Color.pistachioSubtle).cornerRadius(12)
                    .transition(.opacity)
                }

                if activeGoals.isEmpty && completedGoals.isEmpty {
                    EmptyStateView(
                        icon: "target",
                        title: "What are you saving for?",
                        message: "Start with something that matters to you, like an emergency fund, trip, or new car."
                    )
                    .padding()
                    .bilanoeCard()
                } else {
                    if !activeGoals.isEmpty {
                        sectionHeader("In Progress")
                        ForEach(activeGoals) { goal in
                            GoalCard(
                                goal: goal,
                                onContribute: { goalToContribute = goal },
                                onWithdraw: goal.currentAmount > 0 ? { goalToWithdraw = goal } : nil
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    goalToDelete = goal
                                    showDeleteAlert = true
                                } label: { Label("Delete", systemImage: "trash") }

                                Button { goalToContribute = goal } label: {
                                    Label("Add", systemImage: "plus.circle")
                                }
                                .tint(.pistachio)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if goal.currentAmount > 0 {
                                    Button { goalToWithdraw = goal } label: {
                                        Label("Remove", systemImage: "minus.circle")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }

                    if !completedGoals.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showCompletedGoals.toggle() }
                        } label: {
                            HStack {
                                Text("Completed (\(completedGoals.count))")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: showCompletedGoals ? "chevron.up" : "chevron.down")
                            }
                            .foregroundColor(.secondary)
                        }
                        if showCompletedGoals {
                            ForEach(completedGoals) { goal in
                                GoalCard(
                                    goal: goal,
                                    onContribute: nil,
                                    onWithdraw: goal.currentAmount > 0 ? { goalToWithdraw = goal } : nil
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        goalToDelete = goal
                                        showDeleteAlert = true
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle(showsNavigationTitle ? "Savings Goals" : "Plan")
        .errorAlert(error: $error)
        .sheet(isPresented: $showAddGoal) {
            AddGoalView(accounts: accounts) { name, target, deadline, accountID, emoji in
                let account = AccountLedger.account(id: accountID, in: accounts)
                let goal = SavingsGoal(
                    userID: auth.userID, name: name, targetAmount: target,
                    deadline: deadline, accountName: account?.name ?? "", accountID: accountID, emoji: emoji
                )
                modelContext.insert(goal)
                do { try modelContext.safeSave(); HapticManager.medium() }
                catch { self.error = .saveFailed; HapticManager.error() }
            }
        }
        .sheet(item: $goalToContribute) { goal in
            ContributeView(goal: goal, accounts: accounts) { amount, accountID, deductFromAccount in
                if deductFromAccount, let account = AccountLedger.account(id: accountID, in: accounts) {
                    AccountLedger.debit(account, amount: amount)
                }
                goal.currentAmount += amount
                do {
                    try modelContext.safeSave()
                    HapticManager.success()
                    successMessage = goal.isComplete
                        ? "\(goal.emoji) \(goal.name) goal reached! 🎉"
                        : "Added \(amount.formatted(.currency(code: CurrencyFormat.code))) to \(goal.name)"
                    withAnimation { showSuccessBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showSuccessBanner = false } }
                } catch { self.error = .saveFailed; HapticManager.error() }
            }
        }
        .sheet(item: $goalToWithdraw) { goal in
            WithdrawView(goal: goal, accounts: accounts) { amount, refundToAccount, accountID in
                goal.currentAmount = max(0, goal.currentAmount - amount)
                if refundToAccount, let account = AccountLedger.account(id: accountID, in: accounts) {
                    AccountLedger.credit(account, amount: amount)
                }
                do {
                    try modelContext.safeSave()
                    HapticManager.medium()
                    successMessage = "Removed \(amount.formatted(.currency(code: CurrencyFormat.code))) from \(goal.name)"
                    withAnimation { showSuccessBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showSuccessBanner = false } }
                } catch { self.error = .saveFailed; HapticManager.error() }
            }
        }
        .alert("Delete \(goalToDelete?.name ?? "Goal")?", isPresented: $showDeleteAlert) {
            if let goal = goalToDelete, goal.currentAmount > 0, !goal.accountName.isEmpty {
                Button("Delete & Refund \(goal.currentAmount.formatted(.currency(code: CurrencyFormat.code)))", role: .destructive) {
                    deleteGoal(goal, refund: true)
                }
            }
            Button("Delete Without Refund", role: .destructive) {
                if let goal = goalToDelete { deleteGoal(goal, refund: false) }
            }
            Button("Cancel", role: .cancel) { goalToDelete = nil }
        } message: {
            if let goal = goalToDelete, goal.currentAmount > 0 {
                Text("You have \(goal.currentAmount.formatted(.currency(code: CurrencyFormat.code))) saved. Refund it to \(goal.accountName.isEmpty ? "your account" : goal.accountName)?")
            } else {
                Text("This will permanently delete the goal.")
            }
        }
    }

    // MARK: Helpers

    private func deleteGoal(_ goal: SavingsGoal, refund: Bool) {
        if refund, goal.currentAmount > 0 {
            if let account = AccountLedger.account(id: goal.accountID, fallbackName: goal.accountName, in: accounts) {
                AccountLedger.credit(account, amount: goal.currentAmount)
            }
        }
        modelContext.delete(goal)
        do { try modelContext.safeSave(); HapticManager.heavy() }
        catch { self.error = .saveFailed }
        goalToDelete = nil
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saved toward your goals").font(.subheadline).foregroundColor(.secondary)
                Text(totalSaved, format: .currency(code: CurrencyFormat.code))
                    .font(.title2.weight(.bold)).foregroundColor(.pistachio)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("of \(totalTarget, format: .currency(code: CurrencyFormat.code))")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack { Text(title).font(.headline); Spacer() }.padding(.top, 4)
    }
}
