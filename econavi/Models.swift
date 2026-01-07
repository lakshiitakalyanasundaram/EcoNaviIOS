import Foundation
import CoreLocation
import SwiftUI
import MapKit

struct RoutePreferences {
    var time: Double
    var cost: Double
    var emissions: Double
    
    init(time: Double = 50, cost: Double = 30, emissions: Double = 20) {
        self.time = time
        self.cost = cost
        self.emissions = emissions
    }
}

struct RouteOption: Identifiable {
    let id = UUID()
    let mode: String
    let label: String
    let icon: String
    let durationMinutes: Int
    let cost: Double
    let emissionsGrams: Double
    let distanceKm: Double
}

struct CommuteEntry: Identifiable, Codable {
    var id = UUID()
    let date: String
    let mode: String
    let distance: Double
    let emissions: Double
    
    init(date: String, mode: String, distance: Double, emissions: Double) {
        self.date = date
        self.mode = mode
        self.distance = distance
        self.emissions = emissions
    }
}

struct EmissionTip: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let impact: ImpactLevel
    let icon: String
    let savings: String
    
    enum ImpactLevel {
        case high, medium, low
    }
}

struct Achievement: Identifiable {
    let id = UUID()
    let name: String
    let credits: Int
    let unlocked: Bool
    let icon: String
}

struct Reward: Identifiable {
    let id = UUID()
    let name: String
    let cost: Int
    let description: String
}

struct PlaceSuggestion: Identifiable {
    let id = UUID()
    let displayName: String
    let latitude: Double
    let longitude: Double
}

enum SidebarTab: CaseIterable {
    case navigate, shipment, track, rewards
}

struct Contact: Identifiable, Codable {
    var id: UUID
    var name: String
    var phoneNumber: String
    var isFavorite: Bool
    var isLiveLocationEnabled: Bool
    
    init(name: String, phoneNumber: String, isFavorite: Bool = false, isLiveLocationEnabled: Bool = false) {
        self.id = UUID()
        self.name = name
        self.phoneNumber = phoneNumber
        self.isFavorite = isFavorite
        self.isLiveLocationEnabled = isLiveLocationEnabled
    }
}

// MARK: - Color-Coded Map Models

enum PlaceType: String, CaseIterable, Identifiable {
    case hospital = "Hospital"
    case restaurant = "Restaurant"
    case police = "Police"
    case metro = "Metro"
    case publicTransport = "Public Transport"
    
    var id: String { rawValue }
    
    // Apple-style colors
    var color: Color {
        switch self {
        case .hospital:
            return Color(red: 1.0, green: 0.231, blue: 0.188) // #FF3B30
        case .restaurant:
            return Color(red: 1.0, green: 0.584, blue: 0.0) // #FF9500
        case .police:
            return Color(red: 0.0, green: 0.478, blue: 1.0) // #007AFF
        case .metro:
            return Color(red: 0.686, green: 0.322, blue: 0.871) // #AF52DE
        case .publicTransport:
            return Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
        }
    }
    
    var icon: String {
        switch self {
        case .hospital:
            return "cross.case.fill"
        case .restaurant:
            return "fork.knife"
        case .police:
            return "shield.fill"
        case .metro:
            return "tram.fill"
        case .publicTransport:
            return "bus.fill"
        }
    }
    
    
    
    // MapKit search category
    var mapKitCategory: MKPointOfInterestCategory {
        switch self {
        case .hospital:
            return .hospital
        case .restaurant:
            return .restaurant
        case .police:
            return .police
        case .metro:
            return .publicTransport
        case .publicTransport:
            return .publicTransport
        }
    }
}

struct MapPlace: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let placeType: PlaceType
    let distance: CLLocationDistance
    let address: String?
    
    init(name: String, coordinate: CLLocationCoordinate2D, placeType: PlaceType, distance: CLLocationDistance, address: String? = nil) {
        self.name = name
        self.coordinate = coordinate
        self.placeType = placeType
        self.distance = distance
        self.address = address
    }
}

// MARK: - Constants
struct MapConstants {
    static let initialSearchRadius: CLLocationDistance = 2000 // 2 km
    static let maxSearchRadius: CLLocationDistance = 5000 // 5 km max
    static let radiusExpansionStep: CLLocationDistance = 1000 // +1 km per expansion
    static let buttonSize: CGFloat = 55 // Reduced size
    static let buttonSpacing: CGFloat = 10
}


