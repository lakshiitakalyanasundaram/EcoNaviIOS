import SwiftUI

struct TrackTabView: View {
    @EnvironmentObject var userDataManager: UserDataManager

    private static var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    // MARK: - Emission metrics (from Supabase trip_emissions)

    private var totalEmissionsGrams: Double {
        userDataManager.totalCarbonEmissionGrams
    }

    private var tripCount: Int {
        userDataManager.tripEmissions.count
    }

    private var lastTripEmissionGrams: Double {
        userDataManager.tripEmissions.first?.carbonEmission ?? 0
    }

    private var averageEmissionPerTripGrams: Double {
        guard tripCount > 0 else { return 0 }
        return totalEmissionsGrams / Double(tripCount)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                carbonImpactCard
                recentTrips
                nextActionCard
            }
            .padding()
        }
        .task {
            await userDataManager.fetchTripEmissions()
        }
        .refreshable {
            await userDataManager.fetchTripEmissions()
        }
    }

    // MARK: - Carbon impact card (Apple-style metrics)

    private var carbonImpactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Carbon Impact")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 4) {
                Text("Total Emissions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(EmissionsCalculatorIndia.formatEmissions(totalEmissionsGrams))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trips")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(tripCount)")
                        .font(.subheadline.weight(.semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Trip")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(EmissionsCalculatorIndia.formatEmissions(lastTripEmissionGrams))
                        .font(.subheadline.weight(.semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avg / Trip")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(EmissionsCalculatorIndia.formatEmissions(averageEmissionPerTripGrams))
                        .font(.subheadline.weight(.semibold))
                }
            }

            // Optional sparkline (emissions trend)
            if !userDataManager.tripEmissions.isEmpty {
                let lastEmissions = Array(userDataManager.tripEmissions.prefix(12).map { $0.carbonEmission }.reversed())
                let maxEmission = lastEmissions.max() ?? 1

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent trips")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(lastEmissions.enumerated()), id: \.offset) { _, value in
                            let height = maxEmission > 0 ? max(4, (value / maxEmission) * 32) : 4
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.green.opacity(0.8))
                                .frame(width: 6, height: CGFloat(height))
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - RECENT TRIPS
    private var recentTrips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Trips")
                .font(.headline)

            if userDataManager.isLoadingTripEmissions {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if userDataManager.tripEmissions.isEmpty {
                Text("Complete trips to see your carbon impact here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(userDataManager.tripEmissions.prefix(50)) { t in
                    HStack(spacing: 12) {
                        Text(icon(for: t.transportMode ?? "trip"))
                            .font(.title2)

                        VStack(alignment: .leading) {
                            Text((t.transportMode ?? "trip").capitalized)
                                .bold()
                            Text(Self.dateFormatter.string(from: t.createdAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(EmissionsCalculatorIndia.formatEmissions(t.carbonEmission))
                                .font(.caption.bold())
                                .foregroundStyle(t.carbonEmission == 0 ? .green : .orange)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
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
}
