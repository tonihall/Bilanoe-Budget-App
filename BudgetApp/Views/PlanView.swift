import SwiftUI

struct PlanView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case income = "Paycheck"
        case goals = "Goals"

        var id: String { rawValue }
    }

    @State private var selectedSection: Section = .income

    var body: some View {
        VStack(spacing: 0) {
            Picker("Plan section", selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            switch selectedSection {
            case .income:
                IncomeView(showsNavigationTitle: false)
            case .goals:
                SavingsGoalsView(showsNavigationTitle: false)
            }
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.large)
    }
}
