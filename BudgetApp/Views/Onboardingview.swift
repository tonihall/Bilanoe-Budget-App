import SwiftUI

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
}

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var currentPage = 0

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Know Your\nNet Worth",
            subtitle: "Always in the picture",
            description: "Connect all your accounts in one place. Bilanoe calculates your real net worth in real time — checking, savings, investments, and debt."
        ),
        OnboardingPage(
            icon: "arrow.triangle.branch",
            title: "Pay Yourself\nFirst",
            subtitle: "Every paycheck, on purpose",
            description: "Tell Bilanoe how much you earned and it splits your money exactly how you want — savings, investments, debt, and spending — automatically."
        ),
        OnboardingPage(
            icon: "repeat",
            title: "Never Miss\na Bill",
            subtitle: "Subscriptions, handled",
            description: "Track every subscription and recurring bill. Bilanoe alerts you the day before anything is due and lets you mark it paid with one tap."
        )
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(pages[index]).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                VStack(spacing: 28) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? Color.pistachio : Color.white.opacity(0.25))
                                .frame(width: currentPage == index ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }

                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                        } else {
                            onComplete()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(currentPage == pages.count - 1 ? .black : .black)
                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(currentPage == pages.count - 1 ? Color.pistachio : Color.white)
                        .cornerRadius(16)
                    }

                    if currentPage < pages.count - 1 {
                        Button("Skip") { onComplete() }
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.35))
                    } else {
                        Color.clear.frame(height: 20)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // Same logo mark on every page
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.10, green: 0.13, blue: 0.10))
                    .frame(width: 72, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                BilanoeMark(color: .white, size: 44)
            }
            .padding(.bottom, 36)

            if currentPage == 0 {
                Text("Bilanoe")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.pistachio.opacity(0.7))
                    .kerning(3)
                    .textCase(.uppercase)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }

            Text(page.title)
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.white)
                .lineSpacing(2)
                .padding(.bottom, 12)

            Text(page.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.pistachio.opacity(0.8))
                .kerning(1.5)
                .textCase(.uppercase)
                .padding(.bottom, 18)

            Text(page.description)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
