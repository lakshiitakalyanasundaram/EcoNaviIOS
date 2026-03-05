//
//  TravelMode.swift
//  econavi
//
//  Created by lakshiita kalyanasundaram on 3/4/26.
//

import Foundation

enum TravelMode: String, CaseIterable, Identifiable {
    case car = "car"
    case bus = "bus"
    case metro = "metro"
    case twoWheeler = "two_wheeler"
    case walk = "walk"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .car:
            return "Car"
        case .bus:
            return "Bus"
        case .metro:
            return "Metro"
        case .twoWheeler:
            return "Two Wheeler"
        case .walk:
            return "Walk"
        }
    }
    
    var icon: String {
        switch self {
        case .car:
            return "car.fill"
        case .bus:
            return "bus.fill"
        case .metro:
            return "train.side.front.car"
        case .twoWheeler:
            return "scooter"
        case .walk:
            return "figure.walk"
        }
    }
    
    var estimatedEmissionFactor: Double {
        // Baseline emissions (kg CO2 per km) - rough estimates for India
        switch self {
        case .car:
            return 0.2
        case .bus:
            return 0.02
        case .metro:
            return 0.01
        case .twoWheeler:
            return 0.05
        case .walk:
            return 0.0
        }
    }
}

enum TrafficLevel: String, CaseIterable, Identifiable {
    case low = "low"
    case moderate = "moderate"
    case heavy = "heavy"
    case severe = "severe"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .moderate:
            return "Moderate"
        case .heavy:
            return "Heavy"
        case .severe:
            return "Severe"
        }
    }
    
    var congestionFactor: Double {
        switch self {
        case .low:
            return 1.0
        case .moderate:
            return 1.2
        case .heavy:
            return 1.4
        case .severe:
            return 1.6
        }
    }
    
    var color: String {
        switch self {
        case .low:
            return "green"
        case .moderate:
            return "yellow"
        case .heavy:
            return "orange"
        case .severe:
            return "red"
        }
    }
}
