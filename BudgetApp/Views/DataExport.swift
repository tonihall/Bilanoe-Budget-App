import Foundation
import SwiftUI
import UIKit

enum DataExportService {
    static func createCSV(expenses: [Expense], budgets: [MonthlyBudget]) throws -> URL {
        guard !expenses.isEmpty || !budgets.isEmpty else {
            throw DataExportError.noData
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let header = [
            "Record Type", "Date", "Description", "Category", "Account", "Expense Amount",
            "Budget Period", "Budget Limit", "Current Period Spending", "Budget Remaining"
        ]
        var rows = [header]

        for expense in expenses.sorted(by: { $0.date > $1.date }) {
            rows.append([
                "Expense",
                dateFormatter.string(from: expense.date),
                expense.name,
                expense.category,
                expense.accountName,
                decimalString(expense.amount),
                "", "", "", ""
            ])
        }

        let calendar = Calendar.current
        for budget in budgets.sorted(by: { $0.category < $1.category }) {
            let granularity: Calendar.Component = budget.period == "weekly" ? .weekOfYear : .month
            let spent = expenses
                .filter {
                    $0.category == budget.category &&
                    calendar.isDate($0.date, equalTo: Date(), toGranularity: granularity)
                }
                .reduce(0) { $0 + $1.amount }

            rows.append([
                "Budget",
                dateFormatter.string(from: Date()),
                "",
                budget.category,
                "",
                "",
                budget.period.capitalized,
                decimalString(budget.budgetAmount),
                decimalString(spent),
                decimalString(budget.budgetAmount - spent)
            ])
        }

        let csv = rows
            .map { $0.map(csvValue).joined(separator: ",") }
            .joined(separator: "\n")

        guard let data = csv.data(using: .utf8) else {
            throw DataExportError.creationFailed
        }

        let filename = "Bilanoe-Export-\(dateFormatter.string(from: Date())).csv"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func csvValue(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func decimalString(_ amount: Double) -> String {
        String(format: "%.2f", amount)
    }
}

enum DataExportError: LocalizedError {
    case noData
    case creationFailed

    var errorDescription: String? {
        switch self {
        case .noData:
            return "Add an expense or budget before exporting your data."
        case .creationFailed:
            return "Your export could not be created. Please try again."
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                onComplete()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
