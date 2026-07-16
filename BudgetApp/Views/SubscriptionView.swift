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
    var monthlyTotal: Double     { activeSubscriptions.reduce(0) { $0 + $1.amount } }
    var yearlyTotal: Double {
        let now = Date(); let yearEnd = Calendar.current.date(byAdding: .year, value: 1, to: now)!
        return activeSubscriptions.reduce(0) { total, sub in
            let effectiveEnd = min(sub.endDate ?? yearEnd, yearEnd)
            let months = max(0, Calendar.current.dateComponents([.month], from: now, to: effectiveEnd).month ?? 0)
            return total + (sub.amount * Double(months))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthlyTotalView

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

                sectionHeader("All Subscriptions")
                if activeSubscriptions.isEmpty {
                    EmptyStateView(icon: "calendar.badge.plus", title: "No Subscriptions Yet",
                        message: "Track Netflix, Spotify, rent — anything that bills you regularly.")
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                } else {
                    List {
                        ForEach(activeSubscriptions) { sub in
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
                    .frame(minHeight: CGFloat(activeSubscriptions.count) * 88)
                }
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Subscriptions")
        .errorAlert(error: $error)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { showAddSubscription = true } label: { Image(systemName: "plus") }
                    .foregroundColor(.pistachio)
            }
        }
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
                    Section("Subscription") {
                        HStack {
                            Text(sub.name).font(.headline)
                            Spacer()
                            Text(sub.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
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
                            Text("No accounts — add one on the Dashboard first").font(.caption).foregroundColor(.secondary)
                        } else {
                            Picker("Account", selection: $selectedPayAccount) {
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
                    Section {
                        HStack {
                            Text("New due date").foregroundColor(.secondary)
                            Spacer()
                            Text(nextDueDate(from: sub.dueDate), style: .date).foregroundColor(.pistachio)
                        }
                    } footer: {
                        Text("Paying will deduct \(sub.amount, specifier: "%.2f") from your account, log it as an expense, and roll the due date forward 1 month.")
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

    private var monthlyTotalView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Monthly Total").font(.subheadline).foregroundColor(.secondary)
                Text(monthlyTotal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.system(size: 32, weight: .bold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Yearly").font(.subheadline).foregroundColor(.secondary)
                Text(yearlyTotal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
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

    private func initiatePay(_ sub: Subscription) {
        selectedPayAccount = accounts.first?.name ?? ""
        subToPay = sub
    }

    private func nextDueDate(from date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
    }

    private func markAsPaid(_ sub: Subscription) {
        if let account = accounts.first(where: { $0.name == selectedPayAccount }) {
            account.type == "Credit Card" ? (account.balance += sub.amount) : (account.balance -= sub.amount)
        }
        modelContext.insert(Expense(userID: auth.userID, name: sub.name, amount: sub.amount, date: Date(), category: "Subscriptions", accountName: selectedPayAccount))
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

// MARK: - Subscription Card

struct SubscriptionCard: View {
    var sub: Subscription
    var urgent: Bool
    var isOverdue: Bool
    var onMarkPaid: () -> Void

    var daysUntilDue: Int { Calendar.current.dateComponents([.day], from: Date(), to: sub.dueDate).day ?? 0 }
    var statusColor: Color { isOverdue ? .wineRed : urgent ? .orange : .secondary }
    var statusText: String {
        if isOverdue { return "Overdue by \(abs(daysUntilDue)) day\(abs(daysUntilDue) == 1 ? "" : "s")" }
        if urgent    { return "Due in \(daysUntilDue) day\(daysUntilDue == 1 ? "" : "s")" }
        return sub.dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 42, height: 42)
                Image(systemName: isOverdue ? "exclamationmark.circle.fill" : urgent ? "bell.fill" : "repeat")
                    .foregroundColor(statusColor).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(sub.name).font(.subheadline).fontWeight(.medium)
                Text(statusText).font(.caption).foregroundColor(statusColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(sub.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(isOverdue ? .wineRed : .primary)
                Button { onMarkPaid() } label: {
                    Text("Pay")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.pistachioSubtle)
                        .foregroundColor(.pistachioText)
                        .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
    }
}

// MARK: - Add Subscription

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (String, Double, Date, Date?) -> Void
    @State private var name = ""
    @State private var amount = ""
    @State private var dueDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Subscription Name", text: $name)
                    TextField("Monthly Amount", text: $amount).keyboardType(.decimalPad)
                }
                Section("Dates") {
                    DatePicker("Next Due Date", selection: $dueDate, displayedComponents: .date)
                    Toggle("Has End Date", isOn: $hasEndDate)
                    if hasEndDate { DatePicker("End Date", selection: $endDate, displayedComponents: .date) }
                }
            }
            .navigationTitle("Add Subscription")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amt = Double(amount), amt > 0 else { return }
                        onSave(name, amt, dueDate, hasEndDate ? endDate : nil); dismiss()
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                    .foregroundColor(.pistachio)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.pistachio)
                }
            }
        }
    }
}
