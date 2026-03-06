//
//  EmissionCalculator.swift
//  econavi
//
//  Created by lakshiita kalyanasundaram on 3/4/26.
//

import Foundation

class EmissionCalculator {
    
    static let shared = EmissionCalculator()
    
    private let dailyUrbanCarbonLimitGrams: Double = 2000.0 // 2.0 kg CO₂, stored as grams for standardization
    
    // MARK: - Prediction
    
    /// Predict emissions for a trip using the standardized rule-based model (grams CO₂).
    /// Signature kept for compatibility; `speed`, `congestion`, and `departureTime` are currently unused.
    func predictEmission(
        distance: Double,
        speed: Double,
        congestion: Double,
        mode: TravelMode,
        departureTime: Date
    ) -> Double {
        EmissionsCalculatorIndia.calculateEmissions(mode: mode.rawValue, distanceKm: distance)
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
            
            // Predict emission for this mode (grams CO₂; assume same distance)
            let emissionG = EmissionsCalculatorIndia.calculateEmissions(
                mode: mode.rawValue,
                distanceKm: originalTrip.distanceKm
            )
            
            let estimatedDuration = estimatedDurationForMode(mode, distance: originalTrip.distanceKm)
            let arrivalTime = originalTrip.departureDateTime.addingTimeInterval(TimeInterval(estimatedDuration * 60))
            
            let alternative = AlternativeTravelOption(
                transportMode: mode,
                departureTime: originalTrip.departureDateTime,
                estimatedDurationMinutes: estimatedDuration,
                estimatedArrivalTime: arrivalTime,
                // AlternativeTravelOption stores kg; convert from standardized grams.
                predictedEmissionKg: emissionG / 1000.0,
                emissionSavingsKg: max(0, originalEmission - emissionG) / 1000.0
            )
            
            alternatives.append(alternative)
        }
        
        // Test different departure times if original emission is high
        if originalEmission > dailyUrbanCarbonLimitGrams {
            let timeOffsets = [-30, -15, 15, 30] // minutes
            
            for offset in timeOffsets {
                let alternativeTime = originalTrip.departureDateTime.addingTimeInterval(TimeInterval(offset * 60))
                
                let emissionG = EmissionsCalculatorIndia.calculateEmissions(
                    mode: originalTrip.transportMode.rawValue,
                    distanceKm: originalTrip.distanceKm
                )
                
                let estimatedDuration = originalTrip.estimatedDurationMinutes
                let arrivalTime = alternativeTime.addingTimeInterval(TimeInterval(estimatedDuration * 60))
                
                let alternative = AlternativeTravelOption(
                    transportMode: originalTrip.transportMode,
                    departureTime: alternativeTime,
                    estimatedDurationMinutes: estimatedDuration,
                    estimatedArrivalTime: arrivalTime,
                    predictedEmissionKg: emissionG / 1000.0,
                    emissionSavingsKg: max(0, originalEmission - emissionG) / 1000.0
                )
                
                if emissionG < originalEmission {
                    alternatives.append(alternative)
                }
            }
        }
        
        // Sort by emission (lowest first) using standardized grams.
        return alternatives.sorted { $0.predictedEmissionG < $1.predictedEmissionG }
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
        // Signature kept for compatibility; parameter is interpreted as grams under the standardized system.
        return emissionKg > dailyUrbanCarbonLimitGrams
    }
    
    func getWarningMessage(emission: Double) -> String {
        let exceedsGrams = emission - dailyUrbanCarbonLimitGrams
        return "This trip exceeds recommended Indian urban transport carbon levels by \(EmissionsCalculatorIndia.formatEmission(max(0, exceedsGrams)))"
    }
    
    func formatEmission(_ emission: Double) -> String {
        EmissionsCalculatorIndia.formatEmission(emission)
    }
}

extension AlternativeTravelOption {
    /// Standardized grams CO₂ (derived from stored kg field to avoid model changes).
    var predictedEmissionG: Double { predictedEmissionKg * 1000.0 }
    var emissionSavingsG: Double { emissionSavingsKg * 1000.0 }
}
