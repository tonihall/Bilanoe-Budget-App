import SwiftUI
import SwiftData

struct SavingsGoalsView: View {
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
    @State private var successMessage = ""

    var activeGoals: [SavingsGoal]    { goals.filter { !$0.isComplete }.sorted { $0.createdAt < $1.createdAt } }
    var completedGoals: [SavingsGoal] { goals.filter {  $0.isComplete }.sorted { $0.createdAt < $1.createdAt } }
    var totalSaved: Double  { goals.reduce(0) { $0 + $1.currentAmount } }
    var totalTarget: Double { goals.reduce(0) { $0 + $1.targetAmount  } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

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
                        title: "No Savings Goals Yet",
                        message: "Set a goal for anything — an emergency fund, vacation, new car, or gadget.",
                        buttonLabel: "Create First Goal",
                        onButton: { showAddGoal = true }
                    )
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                } else {
                    if !activeGoals.isEmpty {
                        sectionHeader("In Progress")
                        ForEach(activeGoals) { goal in
                            GoalCard(
                                goal: goal,
                                onContribute: { goalToContribute = goal },
                                onWithdraw: goal.currentAmount > 0 ? { goalToWithdraw = goal } : nil,
                                onDelete: { goalToDelete = goal; showDeleteAlert = true }
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
                        sectionHeader("Completed 🎉")
                        ForEach(completedGoals) { goal in
                            GoalCard(
                                goal: goal,
                                onContribute: nil,
                                onWithdraw: goal.currentAmount > 0 ? { goalToWithdraw = goal } : nil,
                                onDelete: { goalToDelete = goal; showDeleteAlert = true }
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

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Savings Goals")
        .errorAlert(error: $error)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { showAddGoal = true } label: { Image(systemName: "plus") }
                    .foregroundColor(.pistachio)
            }
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalView(accounts: accounts) { name, target, deadline, accountName, emoji in
                let goal = SavingsGoal(
                    userID: auth.userID, name: name, targetAmount: target,
                    deadline: deadline, accountName: accountName, emoji: emoji
                )
                modelContext.insert(goal)
                do { try modelContext.safeSave(); HapticManager.medium() }
                catch { self.error = .saveFailed; HapticManager.error() }
            }
        }
        .sheet(item: $goalToContribute) { goal in
            ContributeView(goal: goal, accounts: accounts) { amount, accountName, deductFromAccount in
                if deductFromAccount, let account = accounts.first(where: { $0.name == accountName }) {
                    account.balance -= amount
                }
                goal.currentAmount += amount
                do {
                    try modelContext.safeSave()
                    HapticManager.success()
                    successMessage = goal.isComplete
                        ? "\(goal.emoji) \(goal.name) goal reached! 🎉"
                        : "Added \(amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) to \(goal.name)"
                    withAnimation { showSuccessBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showSuccessBanner = false } }
                } catch { self.error = .saveFailed; HapticManager.error() }
            }
        }
        .sheet(item: $goalToWithdraw) { goal in
            WithdrawView(goal: goal, accounts: accounts) { amount, refundToAccount, accountName in
                goal.currentAmount = max(0, goal.currentAmount - amount)
                if refundToAccount, let account = accounts.first(where: { $0.name == accountName }) {
                    account.balance += amount
                }
                do {
                    try modelContext.safeSave()
                    HapticManager.medium()
                    successMessage = "Removed \(amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) from \(goal.name)"
                    withAnimation { showSuccessBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showSuccessBanner = false } }
                } catch { self.error = .saveFailed; HapticManager.error() }
            }
        }
        .alert("Delete \(goalToDelete?.name ?? "Goal")?", isPresented: $showDeleteAlert) {
            if let goal = goalToDelete, goal.currentAmount > 0, !goal.accountName.isEmpty {
                Button("Delete & Refund \(goal.currentAmount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))", role: .destructive) {
                    deleteGoal(goal, refund: true)
                }
            }
            Button("Delete Without Refund", role: .destructive) {
                if let goal = goalToDelete { deleteGoal(goal, refund: false) }
            }
            Button("Cancel", role: .cancel) { goalToDelete = nil }
        } message: {
            if let goal = goalToDelete, goal.currentAmount > 0 {
                Text("You have \(goal.currentAmount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) saved. Refund it to \(goal.accountName.isEmpty ? "your account" : goal.accountName)?")
            } else {
                Text("This will permanently delete the goal.")
            }
        }
    }

    // MARK: Helpers

    private func deleteGoal(_ goal: SavingsGoal, refund: Bool) {
        if refund, goal.currentAmount > 0 {
            if let account = accounts.first(where: { $0.name == goal.accountName }) {
                account.balance += goal.currentAmount
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
                Text("Total Saved").font(.subheadline).foregroundColor(.secondary)
                Text(totalSaved, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.system(size: 32, weight: .bold)).foregroundColor(.pistachio)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Target").font(.subheadline).foregroundColor(.secondary)
                Text(totalTarget, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.title3).bold().foregroundColor(.secondary)
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

// MARK: - Goal Card

struct GoalCard: View {
    var goal: SavingsGoal
    var onContribute: (() -> Void)?
    var onWithdraw: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header row
            HStack(spacing: 12) {
                Text(goal.emoji).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name).font(.subheadline).fontWeight(.semibold)
                    if goal.isComplete {
                        Text("Goal reached!").font(.caption).foregroundColor(.pistachio)
                    } else if let months = goal.monthsRemaining {
                        Text(months == 0 ? "Due this month" : "\(months) month\(months == 1 ? "" : "s") to go")
                            .font(.caption).foregroundColor(months <= 1 ? .orange : .secondary)
                    } else {
                        Text("No deadline set").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(goal.currentAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(goal.isComplete ? .pistachio : .primary)
                    Text("of \(goal.targetAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                        .font(.caption).foregroundColor(.secondary)
                }
                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                }
            }

            // Progress bar
            VStack(spacing: 4) {
                ProgressView(value: goal.progress).tint(.pistachio)
                HStack {
                    Text("\(Int(goal.progress * 100))% complete")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    let diff = goal.targetAmount - goal.currentAmount
                    Text(diff <= 0
                         ? "Goal reached!"
                         : "\(diff, format: .currency(code: Locale.current.currency?.identifier ?? "USD")) to go")
                        .font(.caption)
                        .foregroundColor(diff <= 0 ? .pistachio : .secondary)
                }
            }

            // Monthly suggestion
            if !goal.isComplete, let monthly = goal.monthlyContributionNeeded {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").foregroundColor(.secondary).font(.caption)
                    Text("Save \(monthly, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))/mo to hit your deadline")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // Action buttons
            if !goal.isComplete {
                HStack(spacing: 10) {
                    if let onContribute {
                        Button(action: onContribute) {
                            Label("Add Funds", systemImage: "plus.circle.fill")
                                .font(.subheadline).fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.pistachioSubtle)
                                .foregroundColor(.pistachioText)
                                .cornerRadius(10)
                        }
                    }
                    if let onWithdraw, goal.currentAmount > 0 {
                        Button(action: onWithdraw) {
                            Label("Remove", systemImage: "minus.circle")
                                .font(.subheadline).fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(UIColor.tertiarySystemBackground))
                                .foregroundColor(.secondary)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
}

// MARK: - Add Goal View

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    var accounts: [Account]
    var onSave: (String, Double, Date?, String, String) -> Void

    @State private var name = ""
    @State private var targetAmount = ""
    @State private var hasDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var selectedAccount = ""
    @State private var selectedEmoji = "🎯"
    @State private var error: AppError? = nil

    let emojis = ["🎯","🏠","🚗","✈️","💍","🎓","💻","📱","🏋️","🐾","🛡️","🌴"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Goal Name (e.g. Emergency Fund)", text: $name)
                    TextField("Target Amount", text: $targetAmount).keyboardType(.decimalPad)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(emojis, id: \.self) { emoji in
                            Text(emoji).font(.title2)
                                .frame(width: 44, height: 44)
                                .background(selectedEmoji == emoji ? Color.pistachioSubtle : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture { selectedEmoji = emoji }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Deadline") {
                    Toggle("Set a deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Target Date", selection: $deadline, in: Date()..., displayedComponents: .date)
                    }
                }
                Section("Linked Account") {
                    if accounts.isEmpty {
                        Text("No accounts yet — add one on the Dashboard first")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        Picker("Account", selection: $selectedAccount) {
                            Text("None").tag("")
                            ForEach(accounts) { Text("\($0.name) (\($0.type))").tag($0.name) }
                        }
                    }
                }
            }
            .navigationTitle("New Goal")
            .errorAlert(error: $error)
            .onAppear { selectedAccount = accounts.first?.name ?? "" }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !name.isEmpty else { error = .custom("Please enter a goal name."); return }
                        guard let amt = Double(targetAmount), amt > 0 else { error = .invalidAmount; return }
                        onSave(name, amt, hasDeadline ? deadline : nil, selectedAccount, selectedEmoji)
                        dismiss()
                    }
                    .foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }
}

// MARK: - Contribute View

struct ContributeView: View {
    @Environment(\.dismiss) private var dismiss
    var goal: SavingsGoal
    var accounts: [Account]
    var onSave: (Double, String, Bool) -> Void

    @State private var amount = ""
    @State private var selectedAccount = ""
    @State private var deductFromAccount = true
    @State private var error: AppError? = nil

    var remaining: Double { goal.targetAmount - goal.currentAmount }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    HStack {
                        Text(goal.emoji + " " + goal.name).font(.headline)
                        Spacer()
                        Text("\(Int(goal.progress * 100))% complete")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Remaining").foregroundColor(.secondary)
                        Spacer()
                        Text(remaining, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .fontWeight(.semibold).foregroundColor(.pistachio)
                    }
                }

                Section("Contribution") {
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([25, 50, 100, 250], id: \.self) { preset in
                                Button {
                                    amount = "\(preset)"
                                } label: {
                                    Text("$\(preset)")
                                        .font(.caption).fontWeight(.medium)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Color.pistachioSubtle)
                                        .foregroundColor(.pistachioText)
                                        .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                amount = String(format: "%.2f", max(0, remaining))
                            } label: {
                                Text("Full")
                                    .font(.caption).fontWeight(.medium)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Color.pistachioSubtle)
                                    .foregroundColor(.pistachioText)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Toggle("Deduct from account balance", isOn: $deductFromAccount)
                        .tint(.pistachio)
                } footer: {
                    Text(deductFromAccount
                        ? "The amount will be subtracted from your selected account."
                        : "Balance won't change — use this if the money is already set aside.")
                }

                if deductFromAccount {
                    Section("Pay From") {
                        if accounts.isEmpty {
                            Text("No accounts — add one on the Dashboard first")
                                .font(.caption).foregroundColor(.secondary)
                        } else {
                            Picker("Account", selection: $selectedAccount) {
                                ForEach(accounts) { account in
                                    HStack {
                                        Text(account.name)
                                        Spacer()
                                        Text(account.balance, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    }.tag(account.name)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                    }
                }
            }
            .navigationTitle("Add Funds")
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert(error: $error)
            .onAppear { selectedAccount = accounts.first?.name ?? "" }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        guard let amt = Double(amount), amt > 0 else { error = .invalidAmount; return }
                        if deductFromAccount && selectedAccount.isEmpty { error = .noAccountSelected; return }
                        onSave(amt, selectedAccount, deductFromAccount)
                        dismiss()
                    }
                    .bold().foregroundColor(.pistachio)
                    .disabled(amount.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }
}

// MARK: - Withdraw View

struct WithdrawView: View {
    @Environment(\.dismiss) private var dismiss
    var goal: SavingsGoal
    var accounts: [Account]
    var onSave: (Double, Bool, String) -> Void

    @State private var amount = ""
    @State private var refundToAccount = true
    @State private var selectedAccount = ""
    @State private var error: AppError? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    HStack {
                        Text(goal.emoji + " " + goal.name).font(.headline)
                        Spacer()
                        Text("Saved: \(goal.currentAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                            .font(.caption).foregroundColor(.pistachio)
                    }
                }

                Section("Amount to Remove") {
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([10, 25, 50, 100], id: \.self) { preset in
                                Button {
                                    let capped = min(Double(preset), goal.currentAmount)
                                    amount = String(format: "%.2f", capped)
                                } label: {
                                    Text("$\(preset)")
                                        .font(.caption).fontWeight(.medium)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Color(UIColor.tertiarySystemBackground))
                                        .foregroundColor(.secondary)
                                        .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                amount = String(format: "%.2f", goal.currentAmount)
                            } label: {
                                Text("All")
                                    .font(.caption).fontWeight(.medium)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Color(UIColor.tertiarySystemBackground))
                                    .foregroundColor(.secondary)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Toggle("Refund to account balance", isOn: $refundToAccount)
                        .tint(.pistachio)
                } footer: {
                    Text(refundToAccount
                        ? "The amount will be added back to your selected account."
                        : "Balance won't change — just corrects the goal amount.")
                }

                if refundToAccount && !accounts.isEmpty {
                    Section("Refund To") {
                        Picker("Account", selection: $selectedAccount) {
                            ForEach(accounts) { account in
                                HStack {
                                    Text(account.name)
                                    Spacer()
                                    Text(account.balance, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                }.tag(account.name)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }
            }
            .navigationTitle("Remove Funds")
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert(error: $error)
            .onAppear { selectedAccount = accounts.first?.name ?? "" }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        guard let amt = Double(amount), amt > 0 else { error = .invalidAmount; return }
                        guard amt <= goal.currentAmount else {
                            error = .custom("Cannot remove more than the saved amount.")
                            return
                        }
                        onSave(amt, refundToAccount, selectedAccount)
                        dismiss()
                    }
                    .bold().foregroundColor(.pistachio)
                    .disabled(amount.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }
}
