//
//  TripPlan.swift
//  econavi
//
//  Created by lakshiita kalyanasundaram on 3/4/26.
//

import Foundation
import MapKit

struct TripPlan: Identifiable {
    let id = UUID()
    
    let destination: String
    let destinationCoordinate: CLLocationCoordinate2D?
    let departureDate: Date
    let departureTime: Date
    let transportMode: TravelMode
    let distanceKm: Double
    let estimatedDurationMinutes: Int
    let congestionFactor: Double
    let trafficLevel: TrafficLevel
    
    // Transit-specific fields
    let routeName: String?  // e.g., "Bus 356A", "Metro Green Line"
    let arrivalTime: Date?  // Actual arrival time from MapKit transit
    
    var departureDateTime: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: departureDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: departureTime)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        return calendar.date(from: components) ?? Date()
    }
    
    var timeOfDay: Int {
        Calendar.current.component(.hour, from: departureDateTime)
    }
    
    var dayOfWeek: Int {
        // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        Calendar.current.component(.weekday, from: departureDateTime)
    }
}

struct TravelSummary: Identifiable {
    let id = UUID()
    
    let destination: String
    let transportMode: TravelMode
    let distanceKm: Double
    let estimatedDurationMinutes: Int
    let estimatedArrivalTime: Date
    let trafficLevel: TrafficLevel
    let predictedEmissionKg: Double
    let exceedsLimit: Bool
    let routeName: String?  // Transit route info
    let dailyUrbanCarbonLimit: Double = 2.0
    
    var emissionStatus: EmissionStatus {
        if predictedEmissionKg > dailyUrbanCarbonLimit {
            return .high
        } else if predictedEmissionKg > dailyUrbanCarbonLimit * 0.75 {
            return .moderate
        } else {
            return .low
        }
    }
    
    enum EmissionStatus {
        case low, moderate, high
        
        var description: String {
            switch self {
            case .low:
                return "Low Emissions"
            case .moderate:
                return "Moderate Emissions"
            case .high:
                return "High Emissions"
            }
        }
        
        var icon: String {
            switch self {
            case .low:
                return "checkmark.circle.fill"
            case .moderate:
                return "exclamationmark.circle.fill"
            case .high:
                return "xmark.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .low:
                return "green"
            case .moderate:
                return "orange"
            case .high:
                return "red"
            }
        }
    }
}

struct AlternativeTravelOption: Identifiable {
    let id = UUID()
    
    let transportMode: TravelMode
    let departureTime: Date
    let estimatedDurationMinutes: Int
    let estimatedArrivalTime: Date
    let predictedEmissionKg: Double
    let emissionSavingsKg: Double
    
    var emissionSavingsPercentage: Double {
        // Will be calculated relative to original trip
        0.0
    }
}
