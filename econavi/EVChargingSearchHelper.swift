import Foundation
import MapKit
import CoreLocation

/// EV Charging POI search with region expansion and fallbacks to avoid MKErrorDomain error 4 in sparse regions.
enum EVChargingSearchHelper {

    private static let initialRadius: CLLocationDistance = 5_000   // 5 km (STEP 1–2: region-based)
    private static let expandedRadius: CLLocationDistance = 25_000 // 25 km (STEP 3–4: 5x expansion)
    private static let fallbackCategories: [MKPointOfInterestCategory] = [.gasStation, .parking] // STEP 5
    private static let naturalLanguageQueries: [String] = [ // STEP 6
        "EV charging station",
        "charging point",
        "Tata Power EV",
        "ChargeZone",
        "Ather Grid"
    ]

    /// Run EV Charging search with full fallback chain. Returns combined, deduplicated MKMapItems.
    static func searchEVCharging(center: CLLocationCoordinate2D) async -> [MKMapItem] {
        var allItems: [MKMapItem] = []

        // STEP 1–2: MKLocalPointsOfInterestRequest with .evCharger
        let poiItems = await runPOIRequest(center: center, radius: initialRadius, categories: [.evCharger])
        allItems.append(contentsOf: poiItems)

        // STEP 3–4: If no results, expand region (5x) and retry .evCharger
        if allItems.isEmpty {
            let expandedItems = await runPOIRequest(center: center, radius: expandedRadius, categories: [.evCharger])
            allItems.append(contentsOf: expandedItems)
        }

        // STEP 5: If still no results, fallback to .gasStation and .parking
        if allItems.isEmpty {
            let fallbackItems = await runPOIRequest(center: center, radius: expandedRadius, categories: fallbackCategories)
            allItems.append(contentsOf: fallbackItems)
        }

        // STEP 6–7: If still no results, natural language search and combine
        if allItems.isEmpty {
            for query in naturalLanguageQueries {
                let nlItems = await runNaturalLanguageSearch(center: center, query: query)
                allItems.append(contentsOf: nlItems)
            }
        }

        // STEP 7: Deduplicate by coordinate (and optionally name)
        return deduplicateMapItems(allItems)
    }

    private static func runPOIRequest(center: CLLocationCoordinate2D, radius: CLLocationDistance, categories: [MKPointOfInterestCategory]) async -> [MKMapItem] {
        await withCheckedContinuation { continuation in
            let request = MKLocalPointsOfInterestRequest(center: center, radius: radius)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                if error != nil {
                    continuation.resume(returning: [])
                    return
                }
                let items = response?.mapItems ?? []
                continuation.resume(returning: items)
            }
        }
    }

    private static func runNaturalLanguageSearch(center: CLLocationCoordinate2D, query: String) async -> [MKMapItem] {
        await withCheckedContinuation { continuation in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
            request.resultTypes = [.pointOfInterest, .address]
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                if error != nil {
                    continuation.resume(returning: [])
                    return
                }
                let items = response?.mapItems ?? []
                continuation.resume(returning: items)
            }
        }
    }

    private static func deduplicateMapItems(_ items: [MKMapItem]) -> [MKMapItem] {
        var seen: Set<String> = []
        return items.compactMap { item in
            guard let loc = item.placemark.location else { return nil }
            let key = String(format: "%.5f,%.5f", loc.coordinate.latitude, loc.coordinate.longitude)
            if seen.contains(key) { return nil }
            seen.insert(key)
            return item
        }
    }
}
