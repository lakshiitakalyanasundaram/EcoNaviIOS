import Foundation
import MapKit
import Combine
import CoreLocation

// MARK: - Identifiable wrapper for SwiftUI ForEach (MKLocalSearchCompletion has no stable id)
struct SearchSuggestionItem: Identifiable {
    let id = UUID()
    let completion: MKLocalSearchCompletion
}

/// Apple Maps–style search: MKLocalSearchCompleter with debounced query, region bias, and one-shot resolve.
@MainActor
final class SearchManager: NSObject, ObservableObject {

    // MARK: - Published (STEP 7, 11)

    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isResolving = false

    // MARK: - Completer & region (STEP 2, 3, 4, 10)

    private let searchCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    private let querySubject = PassthroughSubject<String, Never>()

    override init() {
        super.init()
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        searchCompleter.delegate = self

        // STEP 6: Throttle input with Combine debounce (250ms)
        querySubject
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] fragment in
                self?.applyQueryFragment(fragment)
            }
            .store(in: &cancellables)
    }

    /// STEP 4, 10: Bias search to visible map region.
    func updateRegion(_ region: MKCoordinateRegion) {
        searchCompleter.region = region
    }

    /// STEP 5: Call on each keystroke; debounced internally.
    func updateQuery(_ query: String) {
        querySubject.send(query)
    }

    /// Clear suggestions and current query.
    func clear() {
        querySubject.send("")
        searchCompleter.queryFragment = ""
        suggestions = []
        isSearching = false
    }

    private func applyQueryFragment(_ fragment: String) {
        searchCompleter.queryFragment = fragment
        if fragment.isEmpty {
            suggestions = []
            isSearching = false
        } else {
            isSearching = true
        }
    }

    // MARK: - Resolve suggestion to map item (STEP 8, 12)

    /// Fetches full MKMapItem for a completion. Run from UI on tap.
    func resolve(completion: MKLocalSearchCompletion) async -> (name: String, coordinate: CLLocationCoordinate2D)? {
        isResolving = true
        defer { isResolving = false }

        return await withCheckedContinuation { continuation in
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, error in
                Task { @MainActor in
                    guard let mapItem = response?.mapItems.first,
                          let location = mapItem.placemark.location else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let name = mapItem.name ?? completion.title
                    continuation.resume(returning: (name, location.coordinate))
                }
            }
        }
    }

    // MARK: - Category search (STEP 9): MKLocalPointsOfInterestRequest

    /// Categories supported for POI search.
    static let categoryPOIFilter: [MKPointOfInterestCategory] = [
        .hospital,
        .restaurant,
        .parking,
        .cafe,
        .evCharger,
        .gasStation
    ]

    /// Search points of interest by category. Region is defined by center + radius (MKLocalPointsOfInterestRequest has no settable region).
    func searchPointsOfInterest(
        region: MKCoordinateRegion,
        categories: [MKPointOfInterestCategory],
        radius: CLLocationDistance = 5000
    ) async -> [MKMapItem] {
        let request = MKLocalPointsOfInterestRequest(center: region.center, radius: radius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)

        return await withCheckedContinuation { continuation in
            let search = MKLocalSearch(request: request)
            search.start { response, _ in
                Task { @MainActor in
                    let items = response?.mapItems ?? []
                    continuation.resume(returning: items)
                }
            }
        }
    }

    /// Single-category POI search (convenience for UI).
    func searchCategory(
        _ category: MKPointOfInterestCategory,
        region: MKCoordinateRegion,
        radius: CLLocationDistance = 5000
    ) async -> [MKMapItem] {
        await searchPointsOfInterest(region: region, categories: [category], radius: radius)
    }
}

// MARK: - MKLocalSearchCompleterDelegate (STEP 7)

extension SearchManager: MKLocalSearchCompleterDelegate {

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // STEP 11: Update UI instantly when suggestions arrive (on main; delegate is main)
        suggestions = completer.results
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
        isSearching = false
    }
}
