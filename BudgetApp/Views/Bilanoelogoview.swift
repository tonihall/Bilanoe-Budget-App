import SwiftUI

// MARK: - Bilanoe Logo Mark
// Recreates the chart line + upward arrow icon from the app logo

struct BilanoeMark: View {
    var color: Color = .white
    var size: CGFloat = 60

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Matches the actual logo: zigzag down-up-down-up then arrow shooting up-right
            let points: [CGPoint] = [
                CGPoint(x: 0.10, y: 0.55),  // start
                CGPoint(x: 0.25, y: 0.72),  // down
                CGPoint(x: 0.38, y: 0.48),  // up
                CGPoint(x: 0.52, y: 0.68),  // down
                CGPoint(x: 0.65, y: 0.45),  // up
                CGPoint(x: 0.88, y: 0.22),  // arrow tip
            ].map { CGPoint(x: $0.x * w, y: $0.y * h) }

            // Main line
            var path = Path()
            path.move(to: points[0])
            for pt in points.dropFirst() { path.addLine(to: pt) }
            context.stroke(path, with: .color(color),
                style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round, lineJoin: .round))

            // Arrowhead
            let tip = points.last!
            let prev = points[points.count - 2]
            let angle = atan2(tip.y - prev.y, tip.x - prev.x)
            let arrowLen = size * 0.22
            let arrowAngle: CGFloat = .pi / 5.0

            let left  = CGPoint(x: tip.x - arrowLen * cos(angle - arrowAngle),
                                y: tip.y - arrowLen * sin(angle - arrowAngle))
            let right = CGPoint(x: tip.x - arrowLen * cos(angle + arrowAngle),
                                y: tip.y - arrowLen * sin(angle + arrowAngle))

            var arrow = Path()
            arrow.move(to: left)
            arrow.addLine(to: tip)
            arrow.addLine(to: right)
            context.stroke(arrow, with: .color(color),
                style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Full Logo (icon + wordmark)

struct BilanoeLogo: View {
    var style: Style = .darkBg   // dark bg = white icon, light bg = dark icon
    var iconSize: CGFloat = 52
    var showWordmark: Bool = true

    enum Style {
        case darkBg   // white mark on dark
        case lightBg  // dark mark on light
        case iconOnly
    }

    var markColor: Color {
        switch style {
        case .darkBg:   return .white
        case .lightBg:  return Color(red: 0.10, green: 0.13, blue: 0.10)
        case .iconOnly: return .white
        }
    }

    var wordmarkColor: Color {
        switch style {
        case .darkBg:   return .white
        case .lightBg:  return .primary
        case .iconOnly: return .clear
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: iconSize * 0.22)
                    .fill(style == .lightBg
                        ? Color(red: 0.10, green: 0.13, blue: 0.10)
                        : Color.clear)
                    .frame(width: iconSize * 1.3, height: iconSize * 1.3)

                BilanoeMark(color: style == .lightBg ? .white : markColor, size: iconSize)
            }

            if showWordmark && style != .iconOnly {
                Text("Bilanoe")
                    .font(.system(size: iconSize * 0.5, weight: .semibold))
                    .foregroundColor(wordmarkColor)
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        ZStack {
            Color(red: 0.10, green: 0.13, blue: 0.10)
            BilanoeLogo(style: .darkBg, iconSize: 60)
        }
        .frame(height: 200)

        ZStack {
            Color(UIColor.systemBackground)
            BilanoeLogo(style: .lightBg, iconSize: 60)
        }
        .frame(height: 200)
    }
    .ignoresSafeArea()
}
