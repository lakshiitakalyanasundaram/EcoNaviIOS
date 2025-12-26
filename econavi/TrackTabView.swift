import SwiftUI

struct TrackTabView: View {

    // MARK: - State
    @State private var entries: [CommuteEntry] = []
    @State private var weeklyEmissions: Double = 0
    @State private var weeklySavings: Double = 0
    @State private var greenScore: Double = 0.72   // 72%

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                heroSection

                progressRing

                insightsRow

                recentTrips

                nextActionCard
            }
            .padding()
        }
        .onAppear(perform: loadMockData)
    }

    // MARK: - HERO
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This Week")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Carbon Impact")
                .font(.title2.bold())

            Text("You saved **\(EmissionsCalculatorIndia.formatEmissions(weeklySavings))**")
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - PROGRESS RING
    private var progressRing: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.2), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: greenScore)
                    .stroke(
                        AngularGradient(
                            colors: [.green, .mint],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text("\(Int(greenScore * 100))%")
                        .font(.system(size: 34, weight: .bold))
                    Text("Low-carbon score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 180, height: 180)

            Text("Above average compared to city commuters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

    // MARK: - INSIGHTS
    private var insightsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {

                insightCard(
                    title: "Best Mode",
                    value: "🚴 Bike",
                    subtitle: "Most used this week",
                    color: .green
                )

                insightCard(
                    title: "CO₂ Avoided",
                    value: EmissionsCalculatorIndia.formatEmissions(weeklySavings),
                    subtitle: "vs car travel",
                    color: .mint
                )

                insightCard(
                    title: "Trips Logged",
                    value: "\(entries.count)",
                    subtitle: "this week",
                    color: .blue
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - RECENT TRIPS
    private var recentTrips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Trips")
                .font(.headline)

            ForEach(entries) { e in
                HStack(spacing: 12) {
                    Text(icon(for: e.mode))
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text(e.mode.capitalized)
                            .bold()
                        Text(e.date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(EmissionsCalculatorIndia.formatEmissions(e.emissions))
                            .font(.caption.bold())
                            .foregroundStyle(e.emissions == 0 ? .green : .orange)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - NEXT ACTION (SMART NUDGE)
    private var nextActionCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Next best action")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Take public transport tomorrow to save ~250g CO₂")
                    .font(.subheadline)
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - HELPERS
    private func insightCard(
        title: String,
        value: String,
        subtitle: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .padding()
        .frame(width: 160)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func icon(for mode: String) -> String {
        switch mode {
        case "walk": return "🚶"
        case "bike": return "🚴"
        case "bus": return "🚌"
        case "metro": return "🚇"
        case "car": return "🚗"
        default: return "📍"
        }
    }

    // MARK: - MOCK DATA (replace with real later)
    private func loadMockData() {
        entries = [
            CommuteEntry(date: "Mon", mode: "bike", distance: 6, emissions: 0),
            CommuteEntry(date: "Tue", mode: "bus", distance: 8, emissions: 120),
            CommuteEntry(date: "Wed", mode: "walk", distance: 3, emissions: 0),
            CommuteEntry(date: "Thu", mode: "metro", distance: 10, emissions: 90)
        ]

        weeklyEmissions = entries.reduce(0) { $0 + $1.emissions }
        weeklySavings = 620   // vs car baseline
        greenScore = 0.72
    }
}

