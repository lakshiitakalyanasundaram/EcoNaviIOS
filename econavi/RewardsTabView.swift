//
//  RewardsTabView.swift
//  econavi
//
//  Reads rewards and credits from UserDataManager (Supabase). No static data.
//

import SwiftUI

struct RewardsTabView: View {
    @EnvironmentObject var userDataManager: UserDataManager

    private var totalCredits: Int {
        userDataManager.rewards.reduce(0) { $0 + $1.cost }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                impactRingSection
                rewardsListSection
                achievementsSection
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .task {
            await userDataManager.fetchRewards()
        }
    }

    private var headerSection: some View {
        HStack {
            Text("Environmental Impact")
                .font(.title2.weight(.semibold))
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var impactRingSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Eco Credits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(totalCredits)")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.green)
                Text("Earned from reports, saved places & offline maps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Divider()
            HStack(spacing: 24) {
                metric("Rewards", "\(userDataManager.rewards.count)")
                metric("Reports", "\(userDataManager.reports.count)")
                metric("Places", "\(userDataManager.savedPlaces.count)")
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

    private var rewardsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Rewards")
                .font(.headline)
            if userDataManager.rewards.isEmpty {
                Text("Complete reports, save places, and download maps to earn credits.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(userDataManager.rewards) { reward in
                    HStack(spacing: 16) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reward.name)
                                .font(.subheadline.weight(.semibold))
                            if let desc = reward.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("+\(reward.cost)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.headline)
            achievementCard(
                title: "Green Commuter",
                subtitle: "Use low-emission transport to earn more",
                systemIcon: "shield.lefthalf.filled",
                color: .green
            )
            achievementCard(
                title: "Carbon Saver",
                subtitle: "Save places and download maps to earn credits",
                systemIcon: "leaf.circle.fill",
                color: .mint
            )
            achievementCard(
                title: "Reporter",
                subtitle: "Submit reports to help improve the map",
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
                .background(Circle().fill(.ultraThinMaterial))
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
