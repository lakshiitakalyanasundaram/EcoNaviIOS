//
//  UserDataModels.swift
//  econavi
//
//  Supabase-backed models for user-specific data. Field names match DB columns (snake_case) via CodingKeys.
//  Decodes Postgres timestamptz (ISO8601 string) for created_at.
//

import Foundation
import CoreLocation

// MARK: - ISO8601 date decoding (Postgres timestamptz returns as string)

private func parseISODate(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}

// MARK: - Reward

struct Reward: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var createdAt: Date
    var name: String
    var cost: Int
    var description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case name
        case cost
        case description
    }

    init(id: UUID, userId: UUID, createdAt: Date, name: String, cost: Int, description: String?) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.name = name
        self.cost = cost
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        let dateStr = try c.decode(String.self, forKey: .createdAt)
        createdAt = parseISODate(dateStr) ?? Date()
        name = try c.decode(String.self, forKey: .name)
        cost = try c.decode(Int.self, forKey: .cost)
        description = try c.decodeIfPresent(String.self, forKey: .description)
    }
}

// MARK: - OfflineMap

struct OfflineMap: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var createdAt: Date
    var name: String
    var downloadedMB: Double
    var totalMB: Double
    var lastUpdated: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case name
        case downloadedMB = "downloaded_mb"
        case totalMB = "total_mb"
        case lastUpdated = "last_updated"
    }

    init(id: UUID, userId: UUID, createdAt: Date, name: String, downloadedMB: Double, totalMB: Double, lastUpdated: String) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.name = name
        self.downloadedMB = downloadedMB
        self.totalMB = totalMB
        self.lastUpdated = lastUpdated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        let dateStr = try c.decode(String.self, forKey: .createdAt)
        createdAt = parseISODate(dateStr) ?? Date()
        name = try c.decode(String.self, forKey: .name)
        downloadedMB = try c.decode(Double.self, forKey: .downloadedMB)
        totalMB = try c.decode(Double.self, forKey: .totalMB)
        lastUpdated = try c.decode(String.self, forKey: .lastUpdated)
    }
}

// MARK: - Report

struct Report: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var createdAt: Date
    var issueType: String
    var placeTitle: String?
    var description: String?
    var latitude: Double?
    var longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case issueType = "issue_type"
        case placeTitle = "place_title"
        case description
        case latitude
        case longitude
    }

    init(id: UUID, userId: UUID, createdAt: Date, issueType: String, placeTitle: String?, description: String?, latitude: Double?, longitude: Double?) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.issueType = issueType
        self.placeTitle = placeTitle
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        let dateStr = try c.decode(String.self, forKey: .createdAt)
        createdAt = parseISODate(dateStr) ?? Date()
        issueType = try c.decode(String.self, forKey: .issueType)
        placeTitle = try c.decodeIfPresent(String.self, forKey: .placeTitle)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
    }
}

// MARK: - PlaceCategory (Apple Maps style)

enum PlaceCategory: String, CaseIterable, Identifiable, Codable {
    case favorites
    case wantToGo = "want_to_go"
    case visited
    case collection
    case home
    case work

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .favorites: return "Favorites"
        case .wantToGo: return "Want to Go"
        case .visited: return "Visited"
        case .collection: return "Collection"
        case .home: return "Home"
        case .work: return "Work"
        }
    }

    var icon: String {
        switch self {
        case .favorites: return "heart.fill"
        case .wantToGo: return "star.fill"
        case .visited: return "checkmark.circle.fill"
        case .collection: return "folder.fill"
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        }
    }
}

// MARK: - SavedPlace

struct SavedPlace: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var createdAt: Date
    var name: String
    var displayName: String { name }
    var address: String?
    var latitude: Double
    var longitude: Double
    var category: PlaceCategory
    var collectionId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case name
        case address
        case latitude
        case longitude
        case category
        case collectionId = "collection_id"
    }

    init(id: UUID, userId: UUID, createdAt: Date, name: String, address: String?, latitude: Double, longitude: Double, category: PlaceCategory, collectionId: UUID?) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.collectionId = collectionId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        let dateStr = try c.decode(String.self, forKey: .createdAt)
        createdAt = parseISODate(dateStr) ?? Date()
        let nameFromDisplayName = (try? decoder.container(keyedBy: DisplayNameDecodeKey.self).decode(String.self, forKey: .display_name))
        name = (try? c.decode(String.self, forKey: .name)) ?? nameFromDisplayName ?? "Saved Place"
        address = try c.decodeIfPresent(String.self, forKey: .address)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        category = (try? c.decode(PlaceCategory.self, forKey: .category)) ?? .favorites
        collectionId = try c.decodeIfPresent(UUID.self, forKey: .collectionId)
    }

    private enum DisplayNameDecodeKey: String, CodingKey {
        case display_name
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Collection

struct Collection: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID
    var name: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case createdAt = "created_at"
    }

    init(id: UUID, userId: UUID, name: String, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.name = name
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        name = try c.decode(String.self, forKey: .name)
        let dateStr = try c.decode(String.self, forKey: .createdAt)
        createdAt = parseISODate(dateStr) ?? Date()
    }
}

// MARK: - Insert payloads (no id/created_at; user_id set by client)

struct RewardInsert: Encodable {
    var user_id: UUID
    var name: String
    var cost: Int
    var description: String?

    enum CodingKeys: String, CodingKey {
        case user_id
        case name
        case cost
        case description
    }
}

struct OfflineMapInsert: Encodable {
    var user_id: UUID
    var name: String
    var downloaded_mb: Double
    var total_mb: Double
    var last_updated: String

    enum CodingKeys: String, CodingKey {
        case user_id
        case name
        case downloaded_mb
        case total_mb
        case last_updated
    }
}

struct OfflineMapUpdate: Encodable {
    var downloaded_mb: Double
    var last_updated: String

    enum CodingKeys: String, CodingKey {
        case downloaded_mb
        case last_updated
    }
}

struct ReportInsert: Encodable {
    var user_id: UUID
    var issue_type: String
    var place_title: String?
    var description: String?
    var latitude: Double?
    var longitude: Double?

    enum CodingKeys: String, CodingKey {
        case user_id
        case issue_type
        case place_title
        case description
        case latitude
        case longitude
    }
}

struct SavedPlaceInsert: Encodable {
    var user_id: UUID
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    var category: String
    var collection_id: UUID?

    enum CodingKeys: String, CodingKey {
        case user_id
        case name
        case address
        case latitude
        case longitude
        case category
        case collection_id
    }
}

struct SavedPlaceUpdate: Encodable {
    var name: String?
    var address: String?
    var category: String?
    var collection_id: UUID?

    enum CodingKeys: String, CodingKey {
        case name
        case address
        case category
        case collection_id
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let name { try c.encode(name, forKey: .name) }
        if let address { try c.encode(address, forKey: .address) }
        if let category { try c.encode(category, forKey: .category) }
        if let collection_id { try c.encode(collection_id, forKey: .collection_id) }
    }
}

struct CollectionInsert: Encodable {
    var user_id: UUID
    var name: String

    enum CodingKeys: String, CodingKey {
        case user_id
        case name
    }
}
