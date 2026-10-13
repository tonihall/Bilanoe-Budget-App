import SwiftUI
import SwiftData

// Supporting views for the Savings Goals feature.

// MARK: - Goal Card

struct GoalCard: View {
    var goal: SavingsGoal
    var onContribute: (() -> Void)?
    var onWithdraw: (() -> Void)?

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
                    let remaining = max(0, goal.targetAmount - goal.currentAmount)
                    Text(goal.isComplete ? "Goal reached" : "\(remaining, format: .currency(code: CurrencyFormat.code))")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(goal.isComplete ? .pistachio : .primary)
                    Text(goal.isComplete ? "Nice work" : "left to save")
                        .font(.caption).foregroundColor(.secondary)
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
                         : "\(diff, format: .currency(code: CurrencyFormat.code)) to go")
                        .font(.caption)
                        .foregroundColor(diff <= 0 ? .pistachio : .secondary)
                }
            }

            // Monthly suggestion
            if !goal.isComplete, let monthly = goal.monthlyContributionNeeded {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").foregroundColor(.secondary).font(.caption)
                    Text("Save \(monthly, format: .currency(code: CurrencyFormat.code))/mo to hit your deadline")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // Action buttons
            if !goal.isComplete {
                HStack(spacing: 10) {
                    if let onContribute {
                        Button(action: onContribute) {
                            Label("Add money", systemImage: "plus.circle.fill")
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
                            Label("Take money out", systemImage: "minus.circle")
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
                Section("What are you saving for?") {
                    TextField("Goal name, e.g. Emergency Fund", text: $name)
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
                Section("Optional details") {
                    Toggle("Set a deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Target Date", selection: $deadline, in: Date()..., displayedComponents: .date)
                    }
                    if accounts.isEmpty {
                        Text("No accounts yet — add one on Home first")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        Picker("Link an account", selection: $selectedAccount) {
                            Text("No linked account").tag("")
                            ForEach(accounts) { Text("\($0.name) (\($0.type))").tag($0.uuid) }
                        }
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert(error: $error)
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
                        Text(remaining, format: .currency(code: CurrencyFormat.code))
                            .fontWeight(.semibold).foregroundColor(.pistachio)
                    }
                }

                Section("Add money") {
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
                    Toggle("Take money from an account", isOn: $deductFromAccount)
                        .tint(.pistachio)
                } footer: {
                    Text(deductFromAccount
                        ? "The amount will be subtracted from your selected account."
                        : "Balance won't change — use this if the money is already set aside.")
                }

                if deductFromAccount {
                    Section("Pay From") {
                        if accounts.isEmpty {
                            Text("No accounts — add one on Home first")
                                .font(.caption).foregroundColor(.secondary)
                        } else {
                            Picker("Account", selection: $selectedAccount) {
                                ForEach(accounts) { account in
                                    HStack {
                                        Text(account.name)
                                        Spacer()
                                        Text(account.balance, format: .currency(code: CurrencyFormat.code))
                                    }.tag(account.uuid)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                    }
                }
            }
            .navigationTitle("Add money")
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert(error: $error)
            .onAppear { selectedAccount = accounts.first?.uuid ?? "" }
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
                        Text("Saved: \(goal.currentAmount, format: .currency(code: CurrencyFormat.code))")
                            .font(.caption).foregroundColor(.pistachio)
                    }
                }

                Section("Take money out") {
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
                    Toggle("Put money back into an account", isOn: $refundToAccount)
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
                                    Text(account.balance, format: .currency(code: CurrencyFormat.code))
                                }.tag(account.uuid)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }
            }
            .navigationTitle("Take money out")
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert(error: $error)
            .onAppear { selectedAccount = accounts.first?.uuid ?? "" }
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
