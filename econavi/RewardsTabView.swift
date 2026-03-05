//
//  RewardsTabView.swift
//  econavi
//
//  Reads rewards and credits from UserDataManager (Supabase). No static data.
//

import SwiftUI

/// Carbon Budget rewards: 100 kg CO₂ monthly budget, dynamically computed from Supabase trip_emissions for current month.
struct RewardsTabView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @State private var showEditBudgetSheet = false
    private var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL"
        return f.string(from: Date())
    }

    private var totalKgThisMonth: Double {
        userDataManager.monthlyCarbonEmissionKg
    }

    private var remainingKg: Double {
        limitKg - totalKgThisMonth
    }

    private var ringProgress: Double {
        if remainingKg < 0 { return 1 }
        return min(max(remainingKg / limitKg, 0), 1)
    }

    private var ringColor: Color {
        remainingKg < 0 ? .red : .green
    }

    private var lastMonthBadge: UserBadge? {
        let cal = Calendar.current
        guard let prev = cal.date(byAdding: .month, value: -1, to: Date()) else { return nil }
        let m = cal.component(.month, from: prev)
        let y = cal.component(.year, from: prev)
        return userDataManager.userBadges.first(where: { $0.month == m && $0.year == y })
    }

    private var limitKg: Double {
        max(userDataManager.monthlyBudgetKg, 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                carbonBudgetRingCard
                if let badge = lastMonthBadge {
                    badgeCard(badge)
                }
                if let err = userDataManager.lastError, !err.isEmpty {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .task {
            await userDataManager.fetchTripEmissionsThisMonth()
            await userDataManager.fetchUserBadges()
            await userDataManager.fetchCarbonBudget()
            await userDataManager.awardBadgeForPreviousMonthIfNeeded(monthlyLimitKg: limitKg)
        }
        .refreshable {
            await userDataManager.fetchTripEmissionsThisMonth()
            await userDataManager.fetchUserBadges()
            await userDataManager.fetchCarbonBudget()
        }
        .sheet(isPresented: $showEditBudgetSheet) {
            EditBudgetSheet(isPresented: $showEditBudgetSheet)
                .environmentObject(userDataManager)
        }
    }

    private var carbonBudgetRingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Carbon Budget")
                        .font(.headline.weight(.semibold))
                    Text("\(monthName) • Resets on the 1st")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Edit") {
                    showEditBudgetSheet = true
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.18), lineWidth: 16)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: ringProgress)

                VStack(spacing: 4) {
                    Text(String(format: "%.0f / %.0f kg", remainingKg, limitKg))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(remainingKg < 0 ? .red : .primary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 240, height: 240)
            .frame(maxWidth: .infinity)

            HStack(spacing: 20) {
                metric("Emitted", String(format: "%.1f kg", totalKgThisMonth))
                metric("Trips", "\(userDataManager.tripEmissionsThisMonth.count)")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badgeCard(_ badge: UserBadge) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "rosette")
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ultraThinMaterial))
            VStack(alignment: .leading, spacing: 2) {
                Text("Last month’s badge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(badge.badgeName)
                    .font(.headline.weight(.semibold))
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Edit budget sheet

private struct EditBudgetSheet: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @Binding var isPresented: Bool

    @State private var budgetText: String = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Carbon Budget") {
                    HStack {
                        TextField("100", text: $budgetText)
                            .keyboardType(.decimalPad)
                        Text("kg")
                    }
                }
                if let error {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Monthly Carbon Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(isSaving || Double(budgetText) == nil)
                }
            }
        }
        .onAppear {
            budgetText = String(format: "%.0f", max(userDataManager.monthlyBudgetKg, 1))
        }
    }

    private func save() async {
        error = nil
        guard let value = Double(budgetText), value > 0 else {
            error = "Please enter a positive number."
            return
        }
        isSaving = true
        defer { isSaving = false }
        await userDataManager.upsertCarbonBudget(budgetKg: value)
        if let err = userDataManager.lastError, !err.isEmpty {
            error = err
            return
        }
        isPresented = false
    }
}
