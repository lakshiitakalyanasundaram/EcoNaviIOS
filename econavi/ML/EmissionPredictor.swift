//
//  EmissionPredictor.swift
//  econavi
//
//  Created by lakshiita kalyanasundaram on 3/4/26.
//


import CoreML

class EmissionPredictor {

    static let shared = EmissionPredictor()

    private let model: TravelEmissionPredicton

    init() {
        do {
            model = try TravelEmissionPredicton(configuration: MLModelConfiguration())
        } catch {
            fatalError("Failed to load ML model: \(error)")
        }
    }

    func predictEmission(
        distance: Double,
        speed: Double,
        congestion: Double,
        mode: String,
        hour: Int,
        day: Int
    ) -> Double {

        do {
            let prediction = try model.prediction(
                distance_km: distance,
                avg_speed_kmh: speed,
                congestion_factor: congestion,
                mode: mode,
                time_of_day: Int64(Double(hour)),
                day_of_week: Int64(Double(day))
            )

            return prediction.emission_kg

        } catch {
            print("Prediction failed:", error)
            return 0
        }
    }
}
