import Foundation
import MapKit
import CoreLocation
import Combine

/// Service for searching places using MKLocalPointsOfInterestRequest (Step 11). Results are rendered on the map (Step 12).
@MainActor
class PlaceSearchService: ObservableObject {
    @Published var places: [MapPlace] = []
    @Published var isSearching = false
    @Published var currentRadius: CLLocationDistance = MapConstants.initialSearchRadius

    private var currentSearch: MKLocalSearch?

    /// Search for places of a specific type using POI request (Step 11)
    func searchPlaces(
        type: PlaceType,
        location: CLLocation,
        initialRadius: CLLocationDistance = MapConstants.initialSearchRadius
    ) {
        currentSearch?.cancel()
        currentSearch = nil
        places = []
        isSearching = true
        currentRadius = initialRadius

        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: initialRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [type.mapKitCategory])

        let search = MKLocalSearch(request: request)
        currentSearch = search

        search.start { [weak self] response, error in
            guard let self = self else { return }
            Task { @MainActor in
                self.isSearching = false
                if let error = error {
                    print("POI search error: \(error.localizedDescription)")
                    return
                }
                guard let response = response else { return }
                let locationCLL = location
                let foundPlaces = response.mapItems.compactMap { mapItem -> MapPlace? in
                    guard let placeLocation = mapItem.placemark.location else { return nil }
                    let distance = locationCLL.distance(from: placeLocation)
                    guard distance <= self.currentRadius else { return nil }
                    return MapPlace(
                        name: mapItem.name ?? "Unknown",
                        coordinate: placeLocation.coordinate,
                        placeType: type,
                        distance: distance,
                        address: mapItem.placemark.title
                    )
                }
                self.places = foundPlaces.sorted { $0.distance < $1.distance }
            }
        }
    }

    /// Clear all places
    func clearPlaces() {
        currentSearch?.cancel()
        currentSearch = nil
        places = []
        isSearching = false
        currentRadius = MapConstants.initialSearchRadius
    }
}
