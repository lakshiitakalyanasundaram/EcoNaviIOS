//
//  EmissionCalculator.swift
//  econavi
//
//  Created by lakshiita kalyanasundaram on 3/4/26.
//

import Foundation
import MapKit

class EmissionCalculator {
    
    static let shared = EmissionCalculator()
    
    private let emissionPredictor = EmissionPredictor.shared
    private let dailyUrbanCarbonLimit: Double = 2.0 // kg CO2
    
    // MARK: - Prediction
    
    /// Predict emissions for a trip using the ML model
    func predictEmission(
        distance: Double,
        speed: Double,
        congestion: Double,
        mode: TravelMode,
        departureTime: Date
    ) -> Double {
        let hour = Calendar.current.component(.hour, from: departureTime)
        let weekday = Calendar.current.component(.weekday, from: departureTime)
        
        return emissionPredictor.predictEmission(
            distance: distance,
            speed: speed,
            congestion: congestion,
            mode: mode.rawValue,
            hour: hour,
            day: weekday
        )
    }
    
    // MARK: - Traffic Level Detection
    
    /// Estimate traffic level based on route ETA and actual distance
    func estimateTrafficLevel(
        distance: Double,
        expectedTravelTime: TimeInterval
    ) -> TrafficLevel {
        // Calculate average speed from distance and time
        let averageSpeedKmh = (distance / 1000) / (expectedTravelTime / 3600)
        
        // Typical urban speeds:
        // Low traffic: 40+ km/h
        // Moderate traffic: 25-40 km/h
        // Heavy traffic: 15-25 km/h
        // Severe traffic: < 15 km/h
        
        if averageSpeedKmh >= 40 {
            return .low
        } else if averageSpeedKmh >= 25 {
            return .moderate
        } else if averageSpeedKmh >= 15 {
            return .heavy
        } else {
            return .severe
        }
    }
    
    // MARK: - Alternative Suggestions
    
    /// Generate alternative travel options to minimize emissions
    func suggestAlternatives(
        originalTrip: TripPlan,
        originalEmission: Double
    ) async -> [AlternativeTravelOption] {
        var alternatives: [AlternativeTravelOption] = []
        
        // Test different transport modes
        let modesToTest: [TravelMode] = [.metro, .bus, .twoWheeler]
        
        for mode in modesToTest {
            guard mode != originalTrip.transportMode else { continue }
            
            // Predict emission for this mode (assume similar distance/time)
            let emission = predictEmission(
                distance: originalTrip.distanceKm,
                speed: estimatedSpeedForMode(mode),
                congestion: originalTrip.congestionFactor,
                mode: mode,
                departureTime: originalTrip.departureDateTime
            )
            
            let estimatedDuration = estimatedDurationForMode(mode, distance: originalTrip.distanceKm)
            let arrivalTime = originalTrip.departureDateTime.addingTimeInterval(TimeInterval(estimatedDuration * 60))
            
            let alternative = AlternativeTravelOption(
                transportMode: mode,
                departureTime: originalTrip.departureDateTime,
                estimatedDurationMinutes: estimatedDuration,
                estimatedArrivalTime: arrivalTime,
                predictedEmissionKg: emission,
                emissionSavingsKg: max(0, originalEmission - emission)
            )
            
            alternatives.append(alternative)
        }
        
        // Test different departure times if original emission is high
        if originalEmission > dailyUrbanCarbonLimit {
            let timeOffsets = [-30, -15, 15, 30] // minutes
            
            for offset in timeOffsets {
                let alternativeTime = originalTrip.departureDateTime.addingTimeInterval(TimeInterval(offset * 60))
                
                let emission = predictEmission(
                    distance: originalTrip.distanceKm,
                    speed: estimatedSpeedForMode(originalTrip.transportMode),
                    congestion: originalTrip.congestionFactor,
                    mode: originalTrip.transportMode,
                    departureTime: alternativeTime
                )
                
                let estimatedDuration = originalTrip.estimatedDurationMinutes
                let arrivalTime = alternativeTime.addingTimeInterval(TimeInterval(estimatedDuration * 60))
                
                let alternative = AlternativeTravelOption(
                    transportMode: originalTrip.transportMode,
                    departureTime: alternativeTime,
                    estimatedDurationMinutes: estimatedDuration,
                    estimatedArrivalTime: arrivalTime,
                    predictedEmissionKg: emission,
                    emissionSavingsKg: max(0, originalEmission - emission)
                )
                
                if emission < originalEmission {
                    alternatives.append(alternative)
                }
            }
        }
        
        // Sort by emission (lowest first)
        return alternatives.sorted { $0.predictedEmissionKg < $1.predictedEmissionKg }
    }
    
    // MARK: - Helper Methods
    
    private func estimatedSpeedForMode(_ mode: TravelMode) -> Double {
        switch mode {
        case .car:
            return 40.0 // typical urban speed
        case .bus:
            return 25.0
        case .metro:
            return 45.0
        case .twoWheeler:
            return 30.0
        case .walk:
            return 5.0
        }
    }
    
    private func estimatedDurationForMode(_ mode: TravelMode, distance: Double) -> Int {
        let speed = estimatedSpeedForMode(mode)
        let durationHours = distance / speed
        return Int(durationHours * 60)
    }
    
    // MARK: - Carbon Tracking
    
    func checkExceedsLimit(_ emissionKg: Double) -> Bool {
        return emissionKg > dailyUrbanCarbonLimit
    }
    
    func getWarningMessage(emission: Double) -> String {
        let exceeds = emission - dailyUrbanCarbonLimit
        return "This trip exceeds recommended Indian urban transport carbon levels by \(String(format: "%.2f", exceeds)) kg CO₂"
    }
    
    func formatEmission(_ emission: Double) -> String {
        return String(format: "%.2f", emission) + " kg CO₂"
    }
}
