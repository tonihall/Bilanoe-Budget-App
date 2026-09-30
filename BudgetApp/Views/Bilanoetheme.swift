import SwiftUI

// MARK: - Bilanoe Design System

extension Color {
    /// Pistachio green — primary accent
    static let pistachio = Color(red: 0.55, green: 0.76, blue: 0.49)
    static let pistachioSubtle = Color(red: 0.55, green: 0.76, blue: 0.49).opacity(0.12)
    static let pistachioText = Color(red: 0.30, green: 0.55, blue: 0.25)

    /// Wine red — expenses, debt, negative values
    static let wineRed = Color(red: 0.56, green: 0.07, blue: 0.13)
    static let wineRedSubtle = Color(red: 0.56, green: 0.07, blue: 0.13).opacity(0.12)

    /// Forest green — spending trend chart
    static let forestGreen = Color(red: 0.13, green: 0.37, blue: 0.13)

    /// Steel blue — investments
    static let steelBlue = Color(red: 0.27, green: 0.51, blue: 0.71)

    /// Burnt orange — checking
    static let burntOrange = Color(red: 0.80, green: 0.33, blue: 0.00)

    static let appSurface = Color(UIColor.secondarySystemBackground)
    static let appSurfaceElevated = Color(UIColor.tertiarySystemBackground)
}

enum CurrencyFormat {
    static let code = Locale.current.currency?.identifier ?? "USD"
}

struct BilanoeCardModifier: ViewModifier {
    var radius: CGFloat = 16
    var elevated = false

    func body(content: Content) -> some View {
        content
            .background(elevated ? Color.appSurfaceElevated : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func bilanoeCard(radius: CGFloat = 16, elevated: Bool = false) -> some View {
        modifier(BilanoeCardModifier(radius: radius, elevated: elevated))
    }
}
