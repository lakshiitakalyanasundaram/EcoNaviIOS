import Foundation
import MapKit
import CoreLocation
import Combine

/// Service for searching places with automatic radius expansion
@MainActor
class PlaceSearchService: ObservableObject {
    @Published var places: [MapPlace] = []
    @Published var isSearching = false
    @Published var currentRadius: CLLocationDistance = MapConstants.initialSearchRadius
    
    private var cancellables = Set<AnyCancellable>()
    private var currentSearch: MKLocalSearch?
    
    /// Search for places of a specific type with automatic radius expansion
    func searchPlaces(
        type: PlaceType,
        location: CLLocation,
        initialRadius: CLLocationDistance = MapConstants.initialSearchRadius
    ) {
        // Cancel any ongoing search
        currentSearch?.cancel()
        currentSearch = nil
        places = []
        isSearching = true
        currentRadius = initialRadius
        
        searchWithRadius(type: type, location: location, radius: initialRadius)
    }
    
    /// Recursive search with radius expansion if no results found
    private func searchWithRadius(
        type: PlaceType,
        location: CLLocation,
        radius: CLLocationDistance
    ) {
        // Stop if we've exceeded max radius
        guard radius <= MapConstants.maxSearchRadius else {
            isSearching = false
            return
        }
        
        currentRadius = radius
        
        // Create search request
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = type.rawValue
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: radius / 111000, // Rough conversion: 1 degree ≈ 111 km
                longitudeDelta: radius / 111000
            )
        )
        
        // Filter by category if applicable
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [type.mapKitCategory])
        
        let search = MKLocalSearch(request: request)
        currentSearch = search
        
        search.start { [weak self] response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Search error: \(error.localizedDescription)")
                self.isSearching = false
                return
            }
            
            guard let response = response else {
                // No results, expand radius and try again
                self.expandAndSearch(type: type, location: location, currentRadius: radius)
                return
            }
            
            // Convert map items to MapPlace and filter by distance
            let foundPlaces = response.mapItems.compactMap { mapItem -> MapPlace? in
                guard let placeLocation = mapItem.placemark.location else { return nil }
                
                let distance = location.distance(from: placeLocation)
                
                // Only include places within the current search radius
                guard distance <= radius else { return nil }
                
                return MapPlace(
                    name: mapItem.name ?? "Unknown",
                    coordinate: placeLocation.coordinate,
                    placeType: type,
                    distance: distance,
                    address: mapItem.placemark.title
                )
            }
            
            // Sort by distance
            let sortedPlaces = foundPlaces.sorted { $0.distance < $1.distance }
            
            DispatchQueue.main.async {
                self.places = sortedPlaces
                self.isSearching = false
            }
        }
    }
    
    /// Expand radius and search again if no results found
    private func expandAndSearch(
        type: PlaceType,
        location: CLLocation,
        currentRadius: CLLocationDistance
    ) {
        let newRadius = currentRadius + MapConstants.radiusExpansionStep
        
        // Recursively search with expanded radius
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.searchWithRadius(type: type, location: location, radius: newRadius)
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

