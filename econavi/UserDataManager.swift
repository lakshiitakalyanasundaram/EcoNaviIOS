//
//  UserDataManager.swift
//  econavi
//
//  Fetches and writes user-specific data from Supabase. Uses auth session for user_id.
//  MainActor-safe and drives SwiftUI via @Published properties.
//

import Foundation
import Supabase
import SwiftUI
import Combine

@MainActor
final class UserDataManager: ObservableObject {

    static let shared = UserDataManager()

    // MARK: - Published state (SwiftUI binds to these)

    @Published private(set) var rewards: [Reward] = []
    @Published private(set) var savedPlaces: [SavedPlace] = []
    @Published private(set) var collections: [Collection] = []
    @Published private(set) var offlineMaps: [OfflineMap] = []
    @Published private(set) var reports: [Report] = []
    @Published private(set) var tripEmissions: [TripEmission] = []
    @Published private(set) var tripEmissionsThisMonth: [TripEmission] = []
    @Published private(set) var userBadges: [UserBadge] = []

    @Published private(set) var isLoadingRewards = false
    @Published private(set) var isLoadingSavedPlaces = false
    @Published private(set) var isLoadingCollections = false
    @Published private(set) var isLoadingOfflineMaps = false
    @Published private(set) var isLoadingReports = false
    @Published private(set) var isLoadingTripEmissions = false
    @Published private(set) var isLoadingTripEmissionsThisMonth = false
    @Published private(set) var isLoadingUserBadges = false

    @Published private(set) var lastError: String?

    private let client = SupabaseManager.shared.client

    /// Current user id from AuthManager (synced from Supabase Auth). Avoids async session access.
    var currentUserId: UUID? {
        AuthManager.shared.user?.id
    }

    private init() {}

    // MARK: - Rewards

    func fetchRewards() async {
        guard let uid = currentUserId else {
            rewards = []
            return
        }
        isLoadingRewards = true
        lastError = nil
        defer { isLoadingRewards = false }

        do {
            let response: [Reward] = try await client
                .from("rewards")
                .select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            rewards = response
        } catch {
            lastError = error.localizedDescription
            rewards = []
        }
    }

    func addReward(name: String, cost: Int, description: String?) async {
        guard let uid = currentUserId else {
            lastError = "Not signed in"
            return
        }
        lastError = nil
        let payload = RewardInsert(user_id: uid, name: name, cost: cost, description: description)
        do {
            try await client
                .from("rewards")
                .insert(payload)
                .execute()
            await fetchRewards()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Call after report, saved place, or offline map to grant points and refetch.
    func addRewardPoints(_ points: Int, reason: String) async {
        await addReward(name: reason, cost: points, description: nil)
    }

    // MARK: - Saved places

    /// Shared save entrypoint (used by map long-press and Places page).
    /// - Ensures non-empty name (falls back to `"Saved Place"`).
    /// - Inserts into Supabase and refreshes `savedPlaces`.
    func savePlace(name: String, latitude: Double, longitude: Double, category: PlaceCategory) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Saved Place" : trimmed
        await addSavedPlace(name: finalName, address: nil, latitude: latitude, longitude: longitude, category: category)
    }

    func fetchSavedPlaces() async {
        guard let uid = currentUserId else {
            savedPlaces = []
            return
        }
        isLoadingSavedPlaces = true
        lastError = nil
        defer { isLoadingSavedPlaces = false }

        do {
            let response: [SavedPlace] = try await client
                .from("saved_places")
                .select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            savedPlaces = response
        } catch {
            lastError = error.localizedDescription
            savedPlaces = []
        }
    }

    func addSavedPlace(name: String, address: String?, latitude: Double, longitude: Double, category: PlaceCategory, collectionId: UUID? = nil) async {
        guard let uid = currentUserId else {
            lastError = "Not signed in"
            return
        }
        lastError = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Saved Place" : trimmed
        let payload = SavedPlaceInsert(user_id: uid, name: finalName, display_name: finalName, address: address, latitude: latitude, longitude: longitude, category: category.rawValue, collection_id: collectionId)
        do {
            try await client
                .from("saved_places")
                .insert(payload)
                .execute()
            await fetchSavedPlaces()
            await addRewardPoints(5, reason: "Saved a place")
        } catch {
            // Back-compat: if the DB still has only (display_name, latitude, longitude), retry with legacy payload.
            let message = error.localizedDescription
            print("SavedPlaces insert failed:", message)

            // Only attempt legacy insert if this is a missing-column style error (not NOT NULL violations).
            let looksLikeMissingColumnError =
                message.contains("does not exist") ||
                message.contains("42703") ||
                message.contains("PGRST204")

            if looksLikeMissingColumnError {
                do {
                    let legacy = SavedPlaceLegacyInsert(user_id: uid, display_name: finalName, latitude: latitude, longitude: longitude)
                    try await client
                        .from("saved_places")
                        .insert(legacy)
                        .execute()
                    await fetchSavedPlaces()
                    await addRewardPoints(5, reason: "Saved a place")
                } catch {
                    print("SavedPlaces legacy insert failed:", error.localizedDescription)
                    lastError = error.localizedDescription
                }
            } else {
                lastError = message
            }
        }
    }

    func savePlace(displayName: String, latitude: Double, longitude: Double) async {
        await addSavedPlace(name: displayName, address: nil, latitude: latitude, longitude: longitude, category: .favorites)
    }

    func updateSavedPlace(id: UUID, name: String?, address: String?, category: PlaceCategory?, collectionId: UUID?) async {
        guard currentUserId != nil else {
            lastError = "Not signed in"
            return
        }
        lastError = nil
        var payload = SavedPlaceUpdate(name: name, address: address, category: category?.rawValue, collection_id: collectionId)
        do {
            try await client
                .from("saved_places")
                .update(payload)
                .eq("id", value: id)
                .execute()
            await fetchSavedPlaces()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func removeSavedPlace(id: UUID) async {
        guard currentUserId != nil else {
            lastError = "Not signed in"
            return
        }
        lastError = nil
        do {
            try await client
                .from("saved_places")
                .delete()
                .eq("id", value: id)
                .execute()
            await fetchSavedPlaces()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteSavedPlace(id: UUID) async {
        await removeSavedPlace(id: id)
    }

    // MARK: - Collections

    func fetchCollections() async {
        guard let uid = currentUserId else {
            collections = []
            return
        }
        isLoadingCollections = true
        lastError = nil
        defer { isLoadingCollections = false }

        do {
            let response: [Collection] = try await client
                .from("collections")
                .select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            collections = response
        } catch {
            lastError = error.localizedDescription
            collections = []
        }
    }

    func createCollection(name: String) async {
        guard let uid = currentUserId else {
            lastError = "Not signed in"
            return
        }
        lastError = nil
        let payload = CollectionInsert(user_id: uid, name: name)
        do {
            try await client
                .from("collections")
                .insert(payload)
                .execute()
            await fetchCollections()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Offline maps

    func fetchOfflineMaps() async {
        guard let uid = currentUserId else {
            offlineMaps = []
            return
        }
        isLoadingOfflineMaps = true
        lastError = nil
        defer { isLoadingOfflineMaps = false }

        do {
            let response: [OfflineMap] = try await client
                .from("offline_maps")
                .select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            offlineMaps = response
        } catch {
            lastError = error.localizedDescription
            offlineMaps = []
        }
    }

    func downloadMap(name: String, totalMB: Double, downloadedMB: Double = 0, lastUpdated: String = "Downloading…") async {
        guard let uid = currentUserId else {
            lastError = "Not signed in"
            return
        }
        lastError = nil
        let payload = OfflineMapInsert(user_id: uid, name: name, downloaded_mb: downloadedMB, total_mb: totalMB, last_updated: lastUpdated)
        do {
            try await client
                .from("offline_maps")
                .insert(payload)
                .execute()
            await fetchOfflineMaps()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Inserts an offline map and returns the created row (for simulation progress updates).
    func addOfflineMapAndReturn(name: String, totalMB: Double) async -> OfflineMap? {
        guard let uid = currentUserId else {
            lastError = "Not signed in"
            return nil
        }
        lastError = nil
        let payload = OfflineMapInsert(user_id: uid, name: name, downloaded_mb: 0, total_mb: totalMB, last_updated: "Downloading…")
        do {
            let inserted: OfflineMap = try await client
                .from("offline_maps")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            await fetchOfflineMaps()
            return inserted
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func updateOfflineMap(id: UUID, downloadedMB: Double, lastUpdated: String) async {
        guard currentUserId != nil else {
            lastError = "Not signed in"
            return
        }
        lastError = nil
        let payload = OfflineMapUpdate(downloaded_mb: downloadedMB, last_updated: lastUpdated)
        do {
            try await client
                .from("offline_maps")
                .update(payload)
                .eq("id", value: id)
                .execute()
            await fetchOfflineMaps()
            if lastUpdated == "Just now" {
                await addRewardPoints(15, reason: "Downloaded map")
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteOfflineMap(id: UUID) async {
        guard currentUserId != nil else {
            lastError = "Not signed in"
            return
        }
        lastError = nil
        do {
            try await client
                .from("offline_maps")
                .delete()
                .eq("id", value: id)
                .execute()
            await fetchOfflineMaps()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Reports

    func fetchReports() async {
        guard let uid = currentUserId else {
            reports = []
            return
        }
        isLoadingReports = true
        lastError = nil
        defer { isLoadingReports = false }

        do {
            let response: [Report] = try await client
                .from("reports")
                .select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            reports = response
        } catch {
            lastError = error.localizedDescription
            reports = []
        }
    }

    func raiseReport(issueType: String, placeTitle: String? = nil, description: String? = nil, latitude: Double? = nil, longitude: Double? = nil) async {
        guard let uid = currentUserId else {
            lastError = "Not signed in"
            return
        }
        lastError = nil
        let payload = ReportInsert(user_id: uid, issue_type: issueType, place_title: placeTitle, description: description, latitude: latitude, longitude: longitude)
        do {
            try await client
                .from("reports")
                .insert(payload)
                .execute()
            await fetchReports()
            await addRewardPoints(10, reason: "Report submitted")
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Trip emissions (carbon tracking)

    func fetchTripEmissions() async {
        guard let uid = currentUserId else {
            tripEmissions = []
            return
        }
        isLoadingTripEmissions = true
        lastError = nil
        defer { isLoadingTripEmissions = false }

        do {
            let response: [TripEmission] = try await client
                .from("trip_emissions")
                .select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            tripEmissions = response
        } catch {
            lastError = error.localizedDescription
            tripEmissions = []
        }
    }

    func insertTripEmission(distanceKm: Double, timeTakenSeconds: Double, carbonEmissionGrams: Double, transportMode: String?) async {
        guard let uid = currentUserId else {
            lastError = "Not signed in"
            return
        }
        lastError = nil
        let payload = TripEmissionInsert(
            user_id: uid,
            distance: distanceKm,
            time_taken: timeTakenSeconds,
            carbon_emission: carbonEmissionGrams,
            transport_mode: transportMode
        )
        do {
            try await client
                .from("trip_emissions")
                .insert(payload)
                .execute()
            await fetchTripEmissions()
            await fetchTripEmissionsThisMonth()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Total carbon (grams) from all trip emissions for the logged-in user (from in-memory list after fetch).
    var totalCarbonEmissionGrams: Double {
        tripEmissions.reduce(0) { $0 + $1.carbonEmission }
    }

    /// Total distance (km) from all trip emissions.
    var totalTripDistanceKm: Double {
        tripEmissions.reduce(0) { $0 + $1.distance }
    }

    // MARK: - Monthly emissions (Carbon budget)

    func fetchTripEmissionsThisMonth() async {
        guard let uid = currentUserId else {
            tripEmissionsThisMonth = []
            return
        }
        isLoadingTripEmissionsThisMonth = true
        lastError = nil
        defer { isLoadingTripEmissionsThisMonth = false }

        let cal = Calendar.current
        let now = Date()
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let startOfNextMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth) ?? now

        do {
            let response: [TripEmission] = try await client
                .from("trip_emissions")
                .select()
                .eq("user_id", value: uid)
                .gte("created_at", value: startOfMonth)
                .lt("created_at", value: startOfNextMonth)
                .order("created_at", ascending: false)
                .execute()
                .value
            tripEmissionsThisMonth = response
        } catch {
            lastError = error.localizedDescription
            tripEmissionsThisMonth = []
        }
    }

    var monthlyCarbonEmissionKg: Double {
        (tripEmissionsThisMonth.reduce(0) { $0 + $1.carbonEmission }) / 1000.0
    }

    // MARK: - User badges (monthly award)

    func fetchUserBadges() async {
        guard let uid = currentUserId else {
            userBadges = []
            return
        }
        isLoadingUserBadges = true
        lastError = nil
        defer { isLoadingUserBadges = false }

        do {
            let response: [UserBadge] = try await client
                .from("user_badges")
                .select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            userBadges = response
        } catch {
            lastError = error.localizedDescription
            userBadges = []
        }
    }

    /// Award a badge for the previous month if eligible and not already awarded.
    func awardBadgeForPreviousMonthIfNeeded(monthlyLimitKg: Double = 100) async {
        guard let uid = currentUserId else { return }
        let cal = Calendar.current
        let now = Date()
        guard let prevMonthDate = cal.date(byAdding: .month, value: -1, to: now) else { return }
        let prevMonth = cal.component(.month, from: prevMonthDate)
        let prevYear = cal.component(.year, from: prevMonthDate)

        // Already awarded?
        if userBadges.contains(where: { $0.month == prevMonth && $0.year == prevYear }) {
            return
        }

        let startPrevMonth = cal.date(from: cal.dateComponents([.year, .month], from: prevMonthDate)) ?? prevMonthDate
        let startThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now

        do {
            let prevTrips: [TripEmission] = try await client
                .from("trip_emissions")
                .select()
                .eq("user_id", value: uid)
                .gte("created_at", value: startPrevMonth)
                .lt("created_at", value: startThisMonth)
                .execute()
                .value

            let totalKg = (prevTrips.reduce(0) { $0 + $1.carbonEmission }) / 1000.0
            guard totalKg < monthlyLimitKg else { return }

            let badgeName: String
            switch totalKg {
            case ..<25: badgeName = "Climate Champion"
            case ..<50: badgeName = "Low Carbon Hero"
            case ..<75: badgeName = "Eco Guardian"
            default: badgeName = "Green Commuter"
            }

            let payload = UserBadgeInsert(user_id: uid, badge_name: badgeName, month: prevMonth, year: prevYear)
            try await client
                .from("user_badges")
                .insert(payload)
                .execute()

            await fetchUserBadges()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Refresh all (e.g. on login or pull-to-refresh)

    func refreshAll() async {
        await fetchRewards()
        await fetchSavedPlaces()
        await fetchCollections()
        await fetchOfflineMaps()
        await fetchReports()
        await fetchTripEmissions()
        await fetchTripEmissionsThisMonth()
        await fetchUserBadges()
    }

    func clearError() {
        lastError = nil
    }
}
