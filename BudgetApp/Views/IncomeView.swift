import SwiftUI
import SwiftData

enum IncomeFrequency: String, CaseIterable, Identifiable {
    case weekly   = "Weekly"
    case biWeekly = "Bi-Weekly"
    case monthly  = "Monthly"
    var id: String { self.rawValue }
    var monthlyMultiplier: Double {
        switch self { case .weekly: return 52/12; case .biWeekly: return 26/12; case .monthly: return 1 }
    }
}

struct IncomeSource: Identifiable {
    var id = UUID()
    var name: String = ""
    var amount: String = ""
    var frequency: IncomeFrequency = .monthly
    var amountDouble: Double { Double(amount) ?? 0 }
    var monthlyEquivalent: Double { amountDouble * frequency.monthlyMultiplier }
}

struct IncomeView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var allAccounts: [Account]
    @Query private var allIncomes: [Income]

    var accounts: [Account] { allAccounts.filter { $0.userID == auth.userID } }
    var incomes: [Income]   { allIncomes.filter   { $0.userID == auth.userID } }

    @State private var sources: [IncomeSource] = [IncomeSource()]
    @State private var savingsPct:  Double = 20
    @State private var investPct:   Double = 20
    @State private var debtPct:     Double = 10
    @State private var checkingPct: Double = 50
    @State private var minChecking: String = ""
    @State private var showConfirmation = false
    @State private var lastDistributed: Double = 0
    @State private var incomeToDelete: Income? = nil
    @State private var showDeleteConfirm = false
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
                        message: "Add at least one account on the Dashboard before distributing income.")
                        .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(16)
                } else {
                    incomeSourcesSection
                    allocationSection
                    minimumCheckingSection
                    if totalIncome > 0 { distributionPreview }
                    distributeButton
                    if showConfirmation { confirmationBanner }
                }

                if incomes.isEmpty && !accounts.isEmpty {
                    EmptyStateView(icon: "dollarsign.circle", title: "No Income Logged Yet",
                        message: "Enter your paycheck above and tap Distribute to log your first entry.")
                        .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(16)
                } else if !incomes.isEmpty {
                    historySection
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Income")
        .errorAlert(error: $error)
        .confirmationDialog("Undo this income?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Reverse & Delete", role: .destructive) {
                if let income = incomeToDelete { undistributeAndDelete(income) }
            }
            Button("Cancel", role: .cancel) { incomeToDelete = nil }
        } message: {
            if let income = incomeToDelete {
                Text("This will subtract \(income.amount, specifier: "%.2f") from your accounts and delete this record.")
            }
        }
    }

    // MARK: Income Sources

    private var incomeSourcesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Income Sources").font(.headline)
                Spacer()
                Button {
                    sources.append(IncomeSource())
                } label: {
                    Label("Add Job", systemImage: "plus.circle")
                        .font(.subheadline).fontWeight(.medium).foregroundColor(.pistachio)
                }
            }

            ForEach($sources) { $source in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(sources.count > 1 ? "Job / Source" : "Income Source")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        if sources.count > 1 {
                            Button {
                                sources.removeAll { $0.id == source.id }
                            } label: {
                                Label("Remove", systemImage: "minus.circle.fill")
                                    .font(.caption).foregroundColor(.wineRed)
                            }
                        }
                    }
                    TextField("Source name (e.g. Main Job)", text: $source.name).textFieldStyle(.roundedBorder)
                    TextField("Amount per paycheck", text: $source.amount).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    Picker("Frequency", selection: $source.frequency) {
                        ForEach(IncomeFrequency.allCases) { f in Text(f.rawValue).tag(f) }
                    }.pickerStyle(.segmented)
                    if source.amountDouble > 0 {
                        HStack {
                            Text("Monthly equivalent:").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(source.monthlyEquivalent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    .font(.caption).fontWeight(.semibold).foregroundColor(.pistachioText)
                                if source.frequency == .biWeekly {
                                    Text("(26 pay periods ÷ 12 months)").font(.caption2).foregroundColor(.secondary)
                                } else if source.frequency == .weekly {
                                    Text("(52 weeks ÷ 12 months)").font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(12)
            }

            if sources.count > 1 && totalIncome > 0 {
                HStack {
                    Text("Combined total:").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                    Text(totalIncome, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.subheadline).fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
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
            allocationRow(label: "Savings",     icon: "banknote",                  color: .pistachio,                              pct: $savingsPct)
            allocationRow(label: "Investments", icon: "chart.line.uptrend.xyaxis", color: Color.steelBlue, pct: $investPct)
            allocationRow(label: "Debt",        icon: "creditcard",                color: .wineRed,                                     pct: $debtPct)
            allocationRow(label: "Checking",    icon: "building.columns",          color: Color.burntOrange, pct: $checkingPct)
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
            Text("Distribution Preview").font(.headline)
            previewRow(label: "Savings",     amount: totalIncome * savingsPct  / 100, color: .pistachio)
            previewRow(label: "Investments", amount: totalIncome * investPct   / 100, color: Color.steelBlue)
            previewRow(label: "Debt",        amount: totalIncome * debtPct     / 100, color: .red)
            previewRow(label: "Checking",    amount: totalIncome * checkingPct / 100, color: Color.burntOrange)

            let minBal = Double(minChecking) ?? 0
            if minBal > 0 {
                let projected = (accounts.first { $0.type == "Checking" }?.balance ?? 0) + (totalIncome * checkingPct / 100)
                if projected < minBal {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text("Checking will be \(projected, specifier: "%.2f"), below your \(minBal, specifier: "%.0f") minimum")
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
            Label("Add Income & Distribute", systemImage: "arrow.triangle.branch")
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
            Text("\(lastDistributed, specifier: "%.2f") distributed successfully!")
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
                Text("Income History").font(.headline)
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
                        Text(income.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
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

    private func allocationRow(label: String, icon: String, color: Color, pct: Binding<Double>) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundColor(color).frame(width: 20)
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(pct.wrappedValue))%").font(.subheadline).fontWeight(.semibold).foregroundColor(color)
                if totalIncome > 0 {
                    Text(totalIncome * pct.wrappedValue / 100, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.caption).foregroundColor(.secondary).frame(width: 72, alignment: .trailing)
                }
            }
            Slider(value: pct, in: 0...100, step: 1).tint(color)
        }
    }

    private func previewRow(label: String, amount: Double, color: Color) -> some View {
        HStack {
            Circle().fill(color.opacity(0.3)).frame(width: 8, height: 8)
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.subheadline).fontWeight(.semibold).foregroundColor(color)
        }
    }

    private func balanceSliders() {
        let diff = 100 - (savingsPct + investPct + debtPct + checkingPct)
        checkingPct = max(0, checkingPct + diff)
    }

    private func distributeIncome() {
        for source in sources where source.amountDouble > 0 {
            modelContext.insert(Income(userID: auth.userID, amount: source.amountDouble,
                frequency: source.frequency.rawValue,
                savingsPct: savingsPct, investPct: investPct, debtPct: debtPct, checkingPct: checkingPct))
        }
        // Distribute to the FIRST account of each type only
        if let savings = accounts.first(where: { $0.type == "Savings" }) {
            savings.balance += totalIncome * savingsPct / 100
        }
        if let investment = accounts.first(where: { $0.type == "Investment" }) {
            investment.balance += totalIncome * investPct / 100
        }
        if let creditCard = accounts.first(where: { $0.type == "Credit Card" }) {
            creditCard.balance -= totalIncome * debtPct / 100
        }
        if let checking = accounts.first(where: { $0.type == "Checking" }) {
            checking.balance += totalIncome * checkingPct / 100
        }
        do {
            try modelContext.safeSave(); HapticManager.success()
            lastDistributed = totalIncome
            withAnimation { sources = [IncomeSource()]; showConfirmation = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showConfirmation = false } }
        } catch let e as AppError { error = e; HapticManager.error()
        } catch { self.error = .saveFailed; HapticManager.error() }
    }

    private func undistributeAndDelete(_ income: Income) {
        if let savings = accounts.first(where: { $0.type == "Savings" }) {
            savings.balance -= income.amount * income.savingsPct / 100
        }
        if let investment = accounts.first(where: { $0.type == "Investment" }) {
            investment.balance -= income.amount * income.investPct / 100
        }
        if let creditCard = accounts.first(where: { $0.type == "Credit Card" }) {
            creditCard.balance += income.amount * income.debtPct / 100
        }
        if let checking = accounts.first(where: { $0.type == "Checking" }) {
            checking.balance -= income.amount * income.checkingPct / 100
        }
        modelContext.delete(income)
        do { try modelContext.safeSave(); HapticManager.heavy() }
        catch { self.error = .saveFailed }
        incomeToDelete = nil
    }
}
