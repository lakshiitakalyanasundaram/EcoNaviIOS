import Foundation
import CoreLocation

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


