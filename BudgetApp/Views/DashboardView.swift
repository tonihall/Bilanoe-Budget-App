import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var allAccounts: [Account]
    @Query private var allSubscriptions: [Subscription]

    init(userID: String) {
        _allAccounts = Query(filter: #Predicate<Account> { $0.userID == userID })
        _allSubscriptions = Query(filter: #Predicate<Subscription> { $0.userID == userID })
    }

    var accounts: [Account]           { allAccounts }
    var subscriptions: [Subscription] { allSubscriptions }
    @State private var showingAddAccount = false
    @State private var accountToEdit: Account? = nil
    @State private var showSettings = false
    @State private var error: AppError? = nil

    var currentNetWorth: Double {
        accounts.reduce(0.0) { $0 + ($1.type == "Credit Card" ? -$1.balance : $1.balance) }
    }

    private var checkingBalance: Double {
        accounts
            .filter { $0.type == AccountType.checking.rawValue }
            .reduce(0) { $0 + $1.balance }
    }

    private var cashAndAssetsTotal: Double {
        accounts
            .filter { $0.type != AccountType.creditCard.rawValue }
            .reduce(0) { $0 + $1.balance }
    }

    private var creditCardDebt: Double {
        accounts
            .filter { $0.type == AccountType.creditCard.rawValue }
            .reduce(0) { $0 + $1.balance }
    }

    private var billsDueThisWeek: [Subscription] {
        subscriptions.filter { subscription in
            guard subscription.endDate.map({ $0 >= Date() }) ?? true else { return false }
            let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: subscription.dueDate).day ?? .max
            return (0...7).contains(daysUntilDue)
        }
    }

    private var safeToSpend: Double {
        checkingBalance - billsDueThisWeek.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if accounts.isEmpty {
                    DashboardGettingStartedCard {
                        showingAddAccount = true
                    }
                } else {
                    safeToSpendView
                    overviewRow
                    accountsListView
                }
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").foregroundColor(.primary)
                }
            }
        }
        .errorAlert(error: $error)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView { name, balance, type in
                let newAccount = Account(userID: auth.userID, name: name, balance: balance, type: type)
                modelContext.insert(newAccount)
                do {
                    try modelContext.safeSave()
                    HapticManager.medium()
                } catch {
                    self.error = .saveFailed
                    HapticManager.error()
                }
            }
        }
        .sheet(item: $accountToEdit) { account in EditAccountView(account: account) }
    }

    private var safeToSpendView: some View {
        DashboardSafeToSpendCard(
            safeToSpend: safeToSpend,
            checkingBalance: checkingBalance,
            upcomingBillsTotal: billsDueThisWeek.reduce(0) { $0 + $1.amount },
            hasCheckingAccount: accounts.contains { $0.type == AccountType.checking.rawValue }
        )
    }

    private var overviewRow: some View {
        HStack(alignment: .top, spacing: 12) {
            DashboardMetricCard(
                title: "Net worth",
                amount: currentNetWorth,
                detail: accounts.isEmpty ? "Add an account" : "Across all accounts",
                icon: "chart.line.uptrend.xyaxis",
                tint: currentNetWorth < 0 ? .wineRed : .pistachioText
            )

            DashboardMetricCard(
                title: "Bills this week",
                amount: billsDueThisWeek.reduce(0) { $0 + $1.amount },
                detail: billsDueThisWeek.isEmpty ? "Nothing due" : "\(billsDueThisWeek.count) due soon",
                icon: "calendar",
                tint: billsDueThisWeek.isEmpty ? .pistachioText : .orange
            )
        }
    }

    // MARK: Accounts

    private var accountsListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accounts").font(.headline)
                    if !accounts.isEmpty {
                        Text("Cash & assets \(cashAndAssetsTotal, format: .currency(code: CurrencyFormat.code))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button {
                    showingAddAccount = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(.pistachioText)
            }
            if accounts.isEmpty {
                EmptyStateView(icon: "creditcard", title: "No Accounts Yet",
                    message: "Add a checking, savings, or investment account to start tracking your net worth.",
                    buttonLabel: "Add Account", onButton: { showingAddAccount = true })
            } else {
                if creditCardDebt > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "creditcard.fill")
                        Text(creditCardDebt, format: .currency(code: CurrencyFormat.code))
                        Text("in credit-card debt")
                    }
                    .font(.caption)
                    .foregroundColor(.wineRed)
                    .padding(.horizontal, 2)
                }
                ForEach(accounts) { account in
                    CleanAccountCard(account: account) { accountToEdit = account }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .accessibilityElement(children: .contain)
    }

}
