import SwiftUI
import SwiftData

struct SubscriptionsView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var allSubscriptions: [Subscription]
    @Query private var allAccounts: [Account]

    var subscriptions: [Subscription] { allSubscriptions.filter { $0.userID == auth.userID } }
    var accounts: [Account]           { allAccounts.filter      { $0.userID == auth.userID } }

    @AppStorage("notificationsOn") var notificationsOn: Bool = true

    @State private var showAddSubscription = false
    @State private var subToPay: Subscription? = nil
    @State private var selectedPayAccount: String = ""
    @State private var paidConfirmName: String = ""
    @State private var showPaidBanner = false
    @State private var error: AppError? = nil

    var activeSubscriptions: [Subscription] {
        subscriptions.filter { guard let end = $0.endDate else { return true }; return end >= Date() }
            .sorted { $0.dueDate < $1.dueDate }
    }
    var dueThisWeek: [Subscription] {
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        return activeSubscriptions.filter { $0.dueDate >= Date() && $0.dueDate <= weekEnd }
    }
    var overdue: [Subscription]  { activeSubscriptions.filter { $0.dueDate < Date() } }
    var laterBills: [Subscription] {
        let urgentIDs = Set(overdue.map(\.id) + dueThisWeek.map(\.id))
        return activeSubscriptions.filter { !urgentIDs.contains($0.id) }
    }
    var monthlyTotal: Double     { activeSubscriptions.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                billSummaryView

                Button { showAddSubscription = true } label: {
                    Label("Add bill", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundColor(.white)
                .background(Color.pistachioText)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if showPaidBanner {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.pistachio)
                        Text("\(paidConfirmName) marked as paid!").font(.subheadline).foregroundColor(.pistachioText)
                    }
                    .padding().frame(maxWidth: .infinity)
                    .background(Color.pistachioSubtle).cornerRadius(12)
                    .transition(.opacity)
                }

                if !overdue.isEmpty {
                    sectionHeader("⚠️ Overdue")
                    ForEach(overdue) { sub in
                        SubscriptionCard(sub: sub, urgent: true, isOverdue: true) { initiatePay(sub) }
                    }
                }
                if !dueThisWeek.isEmpty {
                    sectionHeader("Due This Week")
                    ForEach(dueThisWeek) { sub in
                        SubscriptionCard(sub: sub, urgent: true, isOverdue: false) { initiatePay(sub) }
                    }
                }

                if activeSubscriptions.isEmpty {
                    EmptyStateView(icon: "calendar.badge.plus", title: "No Bills Yet",
                        message: "Add rent, utilities, subscriptions, or anything that repeats every month.")
                        .padding()
                        .bilanoeCard()
                } else if !laterBills.isEmpty {
                    sectionHeader(overdue.isEmpty && dueThisWeek.isEmpty ? "Next up" : "Later")
                    List {
                        ForEach(laterBills) { sub in
                            SubscriptionCard(sub: sub, urgent: false, isOverdue: false) { initiatePay(sub) }
                                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).padding(.vertical, 4)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        NotificationManager.shared.cancelReminder(for: sub)
                                        modelContext.delete(sub)
                                        do { try modelContext.safeSave(); HapticManager.heavy() }
                                        catch { self.error = .saveFailed }
                                    } label: { Label("Delete", systemImage: "trash") }
                                    Button { initiatePay(sub) } label: { Label("Pay", systemImage: "checkmark.circle") }.tint(.pistachio)
                                }
                        }
                    }
                    .listStyle(.plain).scrollDisabled(true)
                    .frame(minHeight: CGFloat(laterBills.count) * 88)
                }
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Bills")
        .errorAlert(error: $error)
        .onAppear { if notificationsOn { NotificationManager.shared.scheduleAll(subscriptions: activeSubscriptions) } }
        .sheet(isPresented: $showAddSubscription) {
            AddSubscriptionView { name, amount, dueDate, endDate in
                guard amount > 0 else { error = .invalidAmount; return }
                let newSub = Subscription(userID: auth.userID, name: name, amount: amount, dueDate: dueDate, endDate: endDate)
                modelContext.insert(newSub)
                do {
                    try modelContext.safeSave(); HapticManager.medium()
                    if notificationsOn {
                        NotificationManager.shared.requestPermission { granted in
                            if granted { NotificationManager.shared.scheduleReminder(for: newSub) }
                        }
                    }
                } catch { self.error = .saveFailed }
            }
        }
        .sheet(item: $subToPay) { sub in
            NavigationStack {
                Form {
                    Section("Bill") {
                        HStack {
                            Text(sub.name).font(.headline)
                            Spacer()
                            Text(sub.amount, format: .currency(code: CurrencyFormat.code))
                                .bold().foregroundColor(.wineRed)
                        }
                        HStack {
                            Text("Due date").foregroundColor(.secondary)
                            Spacer()
                            Text(sub.dueDate, style: .date)
                        }
                    }
                    Section("Pay From") {
                        if accounts.isEmpty {
                            Text("No accounts — add one on Home first").font(.caption).foregroundColor(.secondary)
                        } else {
                            Picker("Account", selection: $selectedPayAccount) {
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
                    Section {
                        HStack {
                            Text("New due date").foregroundColor(.secondary)
                            Spacer()
                            Text(nextDueDate(from: sub.dueDate), style: .date).foregroundColor(.pistachio)
                        }
                    } footer: {
                        Text("Paying will deduct \(sub.amount, format: .currency(code: CurrencyFormat.code)) from your account, log it as an expense, and roll the due date forward 1 month.")
                    }
                }
                .navigationTitle("Mark as Paid")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") { markAsPaid(sub) }
                            .disabled(selectedPayAccount.isEmpty || accounts.isEmpty)
                            .bold().foregroundColor(.pistachio)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { subToPay = nil }.foregroundColor(.pistachio)
                    }
                }
            }
        }
    }

    private var billSummaryView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bills each month").font(.subheadline).foregroundColor(.secondary)
                Text(monthlyTotal, format: .currency(code: CurrencyFormat.code))
                    .font(.title2.weight(.bold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(!overdue.isEmpty
                    ? "\(overdue.count) overdue"
                    : dueThisWeek.isEmpty ? "No bills due this week" : "\(dueThisWeek.count) due this week")
                    .font(.caption)
                    .foregroundColor(!overdue.isEmpty ? .wineRed : dueThisWeek.isEmpty ? .secondary : .orange)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding()
        .bilanoeCard()
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack { Text(title).font(.headline); Spacer() }.padding(.top, 4)
    }

    private func initiatePay(_ sub: Subscription) {
        selectedPayAccount = accounts.first?.uuid ?? ""
        subToPay = sub
    }

    private func nextDueDate(from date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
    }

    private func markAsPaid(_ sub: Subscription) {
        guard let account = AccountLedger.account(id: selectedPayAccount, in: accounts) else {
            error = .noAccountSelected
            return
        }
        let expense = Expense(userID: auth.userID, name: sub.name, amount: sub.amount, date: Date(),
                              category: "Subscriptions", accountName: account.name, accountID: account.uuid)
        AccountLedger.applyExpense(expense, accounts: accounts)
        modelContext.insert(expense)
        sub.dueDate = nextDueDate(from: sub.dueDate)
        if notificationsOn { NotificationManager.shared.scheduleReminder(for: sub) }
        do {
            try modelContext.safeSave(); HapticManager.success()
            paidConfirmName = sub.name; subToPay = nil
            withAnimation { showPaidBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showPaidBanner = false } }
        } catch { self.error = .saveFailed }
    }
}
