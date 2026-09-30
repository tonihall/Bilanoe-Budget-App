import SwiftUI
import SwiftData

struct IncomeView: View {
    var showsNavigationTitle = true
    @EnvironmentObject var auth: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var allAccounts: [Account]
    @Query private var allIncomes: [Income]

    var accounts: [Account] { allAccounts.filter { $0.userID == auth.userID } }
    var incomes: [Income]   { allIncomes.filter   { $0.userID == auth.userID } }

    @State private var sources: [IncomeSource] = [IncomeSource(name: "Paycheck")]
    @State private var savingsPct:  Double = 20
    @State private var investPct:   Double = 20
    @State private var debtPct:     Double = 10
    @State private var checkingPct: Double = 50
    @State private var minChecking: String = ""
    @State private var showConfirmation = false
    @State private var lastDistributed: Double = 0
    @State private var incomeToDelete: Income? = nil
    @State private var showDeleteConfirm = false
    @State private var showCustomization = false
    @State private var error: AppError? = nil

    var totalIncome: Double  { sources.reduce(0) { $0 + $1.amountDouble } }
    var allocationTotal: Double { savingsPct + investPct + debtPct + checkingPct }
    var allocationValid: Bool { abs(allocationTotal - 100) < 0.5 }
    var canDistribute: Bool { totalIncome > 0 && allocationValid && sources.allSatisfy { !$0.name.isEmpty } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if accounts.isEmpty {
                    EmptyStateView(icon: "building.columns", title: "No Accounts Yet",
                        message: "Add at least one account on Home before planning a paycheck.")
                        .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(16)
                } else {
                    incomeSourcesSection
                    if totalIncome > 0 {
                        distributionPreview
                        customizationSection
                    }
                    distributeButton
                    if showConfirmation { confirmationBanner }
                }

                if incomes.isEmpty && !accounts.isEmpty {
                    EmptyStateView(icon: "dollarsign.circle", title: "No Income Logged Yet",
                        message: "Enter a paycheck amount above and apply your plan to log it.")
                        .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(16)
                } else if !incomes.isEmpty {
                    historySection
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle(showsNavigationTitle ? "Income" : "Plan")
        .errorAlert(error: $error)
        .confirmationDialog("Undo this income?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Reverse & Delete", role: .destructive) {
                if let income = incomeToDelete { undistributeAndDelete(income) }
            }
            Button("Cancel", role: .cancel) { incomeToDelete = nil }
        } message: {
            if let income = incomeToDelete {
                Text("This will subtract \(income.amount, format: .currency(code: CurrencyFormat.code)) from your accounts and delete this record.")
            }
        }
    }

    // MARK: Income Sources

    private var incomeSourcesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Plan a paycheck").font(.headline)
                Spacer()
                Button {
                    sources.append(IncomeSource())
                } label: {
                    Label("Add another income", systemImage: "plus.circle")
                        .font(.subheadline).fontWeight(.medium).foregroundColor(.pistachio)
                }
            }

            ForEach($sources) { $source in
                IncomeSourceCard(
                    source: $source,
                    showsSourceName: sources.count > 1,
                    showsRemoveAction: sources.count > 1,
                    onRemove: { sources.removeAll { $0.id == source.id } }
                )
            }

            if sources.count > 1 && totalIncome > 0 {
                HStack {
                    Text("Total paycheck:").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                    Text(totalIncome, format: .currency(code: CurrencyFormat.code))
                        .font(.subheadline).fontWeight(.semibold)
                }
            }
        }
        .padding()
        .bilanoeCard()
    }

    // MARK: Allocation

    private var allocationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Allocation").font(.headline)
                Spacer()
                Text("\(Int(allocationTotal))% / 100%")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(allocationValid ? .pistachio : .wineRed)
            }
            AllocationSliderRow(label: "Savings", icon: "banknote", color: .pistachio, totalIncome: totalIncome, percentage: $savingsPct)
            AllocationSliderRow(label: "Investments", icon: "chart.line.uptrend.xyaxis", color: .steelBlue, totalIncome: totalIncome, percentage: $investPct)
            AllocationSliderRow(label: "Debt", icon: "creditcard", color: .wineRed, totalIncome: totalIncome, percentage: $debtPct)
            AllocationSliderRow(label: "Checking", icon: "building.columns", color: .burntOrange, totalIncome: totalIncome, percentage: $checkingPct)
            if !allocationValid {
                Text("⚠ Total is \(Int(allocationTotal))% — adjust to reach exactly 100%")
                    .font(.caption).foregroundColor(.wineRed)
            }
            Button { balanceSliders() } label: {
                Text("Auto-balance to 100%")
                    .font(.caption).fontWeight(.medium)
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .background(Color.pistachioSubtle).foregroundColor(.pistachioText)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var customizationSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showCustomization.toggle() }
            } label: {
                HStack {
                    Label("Customize plan", systemImage: "slider.horizontal.3")
                    Spacer()
                    Image(systemName: showCustomization ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            }

            if showCustomization {
                allocationSection
                minimumCheckingSection
            }
        }
    }

    // MARK: Min Checking

    private var minimumCheckingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Minimum Checking Balance").font(.headline)
            Text("Warn me if checking drops below this after distribution.")
                .font(.caption).foregroundColor(.secondary)
            TextField("e.g. 500", text: $minChecking).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: Preview

    private var distributionPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your plan").font(.headline)
            DistributionPreviewRow(label: "Savings", amount: totalIncome * savingsPct / 100, color: .pistachio)
            DistributionPreviewRow(label: "Investments", amount: totalIncome * investPct / 100, color: .steelBlue)
            DistributionPreviewRow(label: "Debt", amount: totalIncome * debtPct / 100, color: .red)
            DistributionPreviewRow(label: "Checking", amount: totalIncome * checkingPct / 100, color: .burntOrange)

            let minBal = Double(minChecking) ?? 0
            if minBal > 0 {
                let projected = (accounts.first { $0.type == "Checking" }?.balance ?? 0) + (totalIncome * checkingPct / 100)
                if projected < minBal {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text("Checking will be \(projected, format: .currency(code: CurrencyFormat.code)), below your \(minBal, format: .currency(code: CurrencyFormat.code)) minimum")
                            .font(.caption).foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: Distribute Button

    private var distributeButton: some View {
        Button {
            guard canDistribute else {
                if !allocationValid { error = .custom("Allocation must total 100%.") }
                else if totalIncome <= 0 { error = .invalidAmount }
                return
            }
            distributeIncome()
        } label: {
            Label("Apply plan", systemImage: "arrow.triangle.branch")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canDistribute ? Color.pistachio : Color.secondary.opacity(0.2))
                .foregroundColor(canDistribute ? .white : .secondary)
                .cornerRadius(14)
        }
    }

    private var confirmationBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.pistachio)
            Text("\(lastDistributed, format: .currency(code: CurrencyFormat.code)) applied successfully!")
                .font(.subheadline).foregroundColor(.pistachioText)
        }
        .padding().frame(maxWidth: .infinity)
        .background(Color.pistachioSubtle).cornerRadius(12)
        .transition(.opacity)
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recent paychecks").font(.headline)
                Text("Swipe left to undo & delete").font(.caption).foregroundColor(.secondary)
            }

            List {
                ForEach(incomes.sorted { $0.date > $1.date }) { income in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(income.frequency).font(.subheadline).fontWeight(.medium)
                            Text(income.date, style: .date).font(.caption).foregroundColor(.secondary)
                            Text("Savings \(Int(income.savingsPct))% · Invest \(Int(income.investPct))% · Debt \(Int(income.debtPct))% · Checking \(Int(income.checkingPct))%")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(income.amount, format: .currency(code: CurrencyFormat.code))
                            .font(.headline).foregroundColor(.pistachio)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            incomeToDelete = income; showDeleteConfirm = true
                        } label: { Label("Undo & Delete", systemImage: "arrow.uturn.backward") }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .frame(minHeight: CGFloat(incomes.count) * 80)
            .scrollDisabled(true)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: Helpers

    private func balanceSliders() {
        let diff = 100 - (savingsPct + investPct + debtPct + checkingPct)
        checkingPct = max(0, checkingPct + diff)
    }

    private func distributeIncome() {
        for source in sources where source.amountDouble > 0 {
            modelContext.insert(Income(userID: auth.userID, amount: source.amountDouble,
                frequency: source.frequency.rawValue,
                savingsPct: savingsPct, investPct: investPct, debtPct: debtPct, checkingPct: checkingPct))
            AccountLedger.applyIncome(amount: source.amountDouble, savingsPct: savingsPct,
                                      investmentPct: investPct, debtPct: debtPct,
                                      checkingPct: checkingPct, accounts: accounts)
        }
        do {
            try modelContext.safeSave(); HapticManager.success()
            lastDistributed = totalIncome
            withAnimation { sources = [IncomeSource(name: "Paycheck")]; showConfirmation = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showConfirmation = false } }
        } catch let e as AppError { error = e; HapticManager.error()
        } catch { self.error = .saveFailed; HapticManager.error() }
    }

    private func undistributeAndDelete(_ income: Income) {
        AccountLedger.applyIncome(amount: -income.amount, savingsPct: income.savingsPct,
                                  investmentPct: income.investPct, debtPct: income.debtPct,
                                  checkingPct: income.checkingPct, accounts: accounts)
        modelContext.delete(income)
        do { try modelContext.safeSave(); HapticManager.heavy() }
        catch { self.error = .saveFailed }
        incomeToDelete = nil
    }
}
