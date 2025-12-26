import SwiftUI

struct RewardsTabView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {

                headerSection

                impactRingSection

                achievementsSection
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Text("Environmental Impact")
                .font(.title2.weight(.semibold))

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Main Impact Card (Health-style)
    private var impactRingSection: some View {
        VStack(spacing: 20) {

            VStack(spacing: 6) {
                Text("Total CO₂ Reduced")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("24.7 kg")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.green)

                Text("This month")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 24) {
                metric("Eco Credits", "247")
                metric("Trips", "18")
                metric("Days Active", "9")
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Achievements (Apple Health style)
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Achievements")
                .font(.headline)

            achievementCard(
                title: "Green Commuter",
                subtitle: "Used low-emission transport 10 times",
                systemIcon: "shield.lefthalf.filled",
                color: .green
            )

            achievementCard(
                title: "Carbon Saver",
                subtitle: "Saved over 20 kg CO₂",
                systemIcon: "leaf.circle.fill",
                color: .mint
            )

            achievementCard(
                title: "Consistency Badge",
                subtitle: "Eco-friendly travel for 5 days straight",
                systemIcon: "checkmark.shield.fill",
                color: .blue
            )
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private func achievementCard(
        title: String,
        subtitle: String,
        systemIcon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 16) {

            Image(systemName: systemIcon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

