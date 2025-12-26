import Foundation

struct EmissionsCalculatorIndia {

    // 🇮🇳 Emission factors (grams CO₂ per passenger-km)
    static let emissionFactors: [String: Double] = [
        "walk": 0,
        "bike": 0,
        "bus": 82,          // Indian city buses (high occupancy)
        "train": 35,        // Indian Railways (mostly electric)
        "metro": 28,        // Urban metro systems
        "car": 210,         // Petrol/diesel mix, congestion
        "rideshare": 210,
        "auto": 120,        // Auto-rickshaw
        "freightTruck": 70,
        "freightRail": 18,
        "freightShip": 9,
        "freightAir": 540
    ]

    // 🇮🇳 Average speeds (km/h)
    static let averageSpeeds: [String: Double] = [
        "walk": 4.5,
        "bike": 14,
        "bus": 18,
        "train": 65,
        "metro": 35,
        "car": 30,
        "rideshare": 30,
        "auto": 25
    ]

    // 🇮🇳 Cost factors (INR per km + base fare)
    static let costFactors: [String: (perKm: Double, baseFare: Double)] = [
        "walk": (0, 0),
        "bike": (2.0, 0),          // Bicycle rentals
        "bus": (1.5, 15),          // City buses
        "train": (1.0, 30),        // Local + express average
        "metro": (2.0, 25),
        "auto": (12, 30),
        "car": (8.5, 0),           // Fuel + maintenance
        "rideshare": (14, 40)      // Ola / Uber
    ]

    // MARK: - Passenger Emissions
    static func calculateEmissions(mode: String, distanceKm: Double) -> Double {
        let factor = emissionFactors[mode] ?? 0
        return factor * distanceKm
    }

    // MARK: - Travel Time (minutes)
    static func calculateTravelTime(mode: String, distanceKm: Double) -> Double {
        let speed = averageSpeeds[mode] ?? 30
        return (distanceKm / speed) * 60
    }

    // MARK: - Travel Cost (₹)
    static func calculateCost(
        mode: String,
        distanceKm: Double,
        peakHour: Bool = false
    ) -> Double {
        guard let factors = costFactors[mode] else { return 0 }
        var cost = factors.baseFare + factors.perKm * distanceKm

        // Surge pricing (rideshare only)
        if peakHour && mode == "rideshare" {
            cost *= 1.4
        }

        return cost
    }

    // MARK: - Freight Emissions (India)
    static func calculateFreightEmissions(
        method: String,
        weightKg: Double,
        distanceKm: Double
    ) -> Double {
        let weightTons = weightKg / 1000
        let factor = emissionFactors[method] ?? 0
        return factor * weightTons * distanceKm
    }

    // MARK: - Carbon Credits (India logic)
    // 1 credit = 100g CO₂ saved
    static func calculateCarbonCredits(savedEmissionsGrams: Double) -> Int {
        return Int(savedEmissionsGrams / 100)
    }

    // MARK: - Formatter
    static func formatEmissions(_ gramsCO2: Double) -> String {
        if gramsCO2 >= 1000 {
            return String(format: "%.2f kg CO₂", gramsCO2 / 1000)
        }
        return String(format: "%.0f g CO₂", gramsCO2)
    }

    static func formatCostINR(_ amount: Double) -> String {
        return String(format: "₹%.0f", amount)
    }
}

