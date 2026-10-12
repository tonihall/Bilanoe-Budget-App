import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @Query private var allAccounts: [Account]
    @Query private var allExpenses: [Expense]
    @Query private var allBudgets: [MonthlyBudget]
    @Query private var allSubscriptions: [Subscription]
    @Query private var allIncomes: [Income]
    @Query private var allGoals: [SavingsGoal]
    @Query private var allSnapshots: [NetWorthSnapshot]

    var accounts: [Account]           { allAccounts.filter      { $0.userID == auth.userID } }
    var expenses: [Expense]           { allExpenses.filter      { $0.userID == auth.userID } }
    var budgets: [MonthlyBudget]      { allBudgets.filter       { $0.userID == auth.userID } }
    var subscriptions: [Subscription] { allSubscriptions.filter { $0.userID == auth.userID } }
    var incomes: [Income]             { allIncomes.filter       { $0.userID == auth.userID } }
    var goals: [SavingsGoal]          { allGoals.filter         { $0.userID == auth.userID } }
    var snapshots: [NetWorthSnapshot] { allSnapshots.filter     { $0.userID == auth.userID } }

    @AppStorage("budgetMode")     var budgetMode: String = "weekly"
    @AppStorage("defaultAccount") var defaultAccount: String = ""
    @AppStorage("notificationsOn") var notificationsOn: Bool = true
    @AppStorage("hapticsOn")       var hapticsOn: Bool = true

    @State private var selectedBudgetMode: String = "weekly"
    @State private var selectedDefaultAccount: String = ""

    @State private var notifPermissionDenied = false
    @State private var showClearConfirm = false
    @State private var error: AppError? = nil

    var body: some View {
        NavigationStack {
            Form {

                Section {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.10, green: 0.13, blue: 0.10))
                                .frame(width: 44, height: 44)
                            BilanoeMark(color: .white, size: 28)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.username).font(.subheadline).fontWeight(.medium)
                            Text("Bilanoe account").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Your profile")
                }

                Section {
                    Picker("Budget Mode", selection: $selectedBudgetMode) {
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                        Text("Both").tag("both")
                    }
                    .onChange(of: selectedBudgetMode) { _, val in budgetMode = val }

                    if !accounts.isEmpty {
                        Picker("Everyday account", selection: $selectedDefaultAccount) {
                            Text("None").tag("")
                            ForEach(accounts) { Text($0.name).tag($0.uuid) }
                        }
                        .onChange(of: selectedDefaultAccount) { _, val in defaultAccount = val }
                    }
                } header: {
                    Text("Preferences")
                }

                Section {
                    Toggle("Bill reminders", isOn: $notificationsOn)
                        .tint(.pistachio)
                        .onChange(of: notificationsOn) { _, enabled in
                            if enabled {
                                NotificationManager.shared.requestPermission { granted in
                                    if granted {
                                        NotificationManager.shared.scheduleAll(subscriptions: subscriptions)
                                        notifPermissionDenied = false
                                    } else {
                                        notificationsOn = false
                                        notifPermissionDenied = true
                                    }
                                }
                            } else {
                                NotificationManager.shared.cancelAll()
                            }
                        }
                    if notifPermissionDenied {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            Text("Notifications are disabled. Go to Settings → Notifications → Bilanoe to enable.")
                            .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Toggle("Haptic feedback", isOn: $hapticsOn)
                        .tint(.pistachio)
                } header: {
                    Text("Alerts & feedback")
                } footer: {
                    Text("Get a reminder the day before each bill is due.")
                }

                Section {
                    Button {
                        NotificationManager.shared.cancelAll()
                        auth.logOut()
                        dismiss()
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account")
                }

                Section {
                    Button(role: .destructive) { showClearConfirm = true } label: {
                        Label("Delete all app data", systemImage: "trash")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("This permanently deletes all saved financial data from this device.")
                }

                // MARK: App Info
                Section {
                    HStack {
                        Text("App").foregroundColor(.secondary)
                        Spacer()
                        Text("Bilanoe")
                    }
                    HStack {
                        Text("Version").foregroundColor(.secondary)
                        Spacer()
                        Text("1.0.0")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert(error: $error)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.pistachio)
                }
            }
            .onAppear {
                selectedBudgetMode = budgetMode
                let resolvedDefaultAccount = accounts.first { $0.uuid == defaultAccount }
                    ?? accounts.first { $0.name == defaultAccount }
                selectedDefaultAccount = resolvedDefaultAccount?.uuid ?? ""
                // Older app versions stored the account name. Persist the stable ID once found.
                if let resolvedDefaultAccount {
                    defaultAccount = resolvedDefaultAccount.uuid
                }
                NotificationManager.shared.checkPermission { granted in
                    if !granted && notificationsOn {
                        notificationsOn = false
                        notifPermissionDenied = true
                    }
                }
            }
            .alert("Clear All Data?", isPresented: $showClearConfirm) {
                Button("Clear Everything", role: .destructive) {
                    clearUserData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all your accounts, expenses, budgets, subscriptions, income history, and goals. This cannot be undone.")
            }
       }
   }

    private func clearUserData() {
        NotificationManager.shared.cancelAll()
        accounts.forEach { modelContext.delete($0) }
        expenses.forEach { modelContext.delete($0) }
        budgets.forEach { modelContext.delete($0) }
        subscriptions.forEach { modelContext.delete($0) }
        incomes.forEach { modelContext.delete($0) }
        goals.forEach { modelContext.delete($0) }
        snapshots.forEach { modelContext.delete($0) }

        do {
            try modelContext.safeSave()
            defaultAccount = ""
            selectedDefaultAccount = ""
            HapticManager.heavy()
        } catch {
            self.error = .saveFailed
            HapticManager.error()
        }
    }
}
