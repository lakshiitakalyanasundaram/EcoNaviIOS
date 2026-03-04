import Foundation
import MapKit
import Combine
import CoreLocation

@MainActor
final class SearchService: NSObject, ObservableObject {

    @Published var results: [SearchResult] = []
    @Published var isSearching = false

    private let searchCompleter = MKLocalSearchCompleter()
    private var currentSearch: MKLocalSearch?
    private var cancellables = Set<AnyCancellable>()
    
    // Search radius in meters (default 20km)
    var searchRadius: CLLocationDistance = 20_000
    
    // User location for distance calculations
    var userLocation: CLLocation?

    override init() {
        super.init()
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        searchCompleter.delegate = self
    }
    
    func updateUserLocation(_ location: CLLocation) {
        self.userLocation = location
        
        // Bias search results to nearby area
        searchCompleter.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    }

    func updateQuery(_ query: String) {
        // Cancel any ongoing search
        currentSearch?.cancel()
        currentSearch = nil
        
        guard !query.isEmpty else {
            results = []
            return
        }
        
        searchCompleter.queryFragment = query
    }

    func clear() {
        currentSearch?.cancel()
        currentSearch = nil
        results = []
        isSearching = false
    }
}

extension SearchService: MKLocalSearchCompleterDelegate {

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !completer.results.isEmpty else {
            results = []
            return
        }
        
        isSearching = true
        
        // Get top 20 completions to search
        let completions = Array(completer.results.prefix(20))
        
        // Perform actual location searches for each completion
        let searchPublishers = completions.map { completion -> AnyPublisher<SearchResult?, Never> in
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            
            // Set region if we have user location
            if let userLocation = userLocation {
                request.region = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
                )
            }
            
            return Future { [weak self] promise in
                search.start { response, error in
                    guard let self = self,
                          let mapItem = response?.mapItems.first,
                          let location = mapItem.placemark.location else {
                        promise(.success(nil))
                        return
                    }
                    
                    // Calculate distance from user location
                    var distance: CLLocationDistance = 0
                    if let userLocation = self.userLocation {
                        distance = userLocation.distance(from: location)
                        
                        // Filter out results beyond search radius
                        if distance > self.searchRadius {
                            promise(.success(nil))
                            return
                        }
                    }
                    
                    let result = SearchResult(
                        title: mapItem.name ?? completion.title,
                        subtitle: mapItem.placemark.title ?? completion.subtitle,
                        coordinate: location.coordinate,
                        distance: distance,
                        score: 0 // Will be sorted by distance
                    )
                    
                    promise(.success(result))
                }
            }
            .eraseToAnyPublisher()
        }
        
        // Merge all searches and collect results
        Publishers.MergeMany(searchPublishers)
            .compactMap { $0 }
            .collect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] allResults in
                guard let self = self else { return }
                
                // Remove duplicates based on title and coordinate
                var uniqueResults: [SearchResult] = []
                var seenCoordinates: Set<String> = []
                
                for result in allResults {
                    let coordKey = "\(result.coordinate.latitude),\(result.coordinate.longitude)"
                    if !seenCoordinates.contains(coordKey) {
                        seenCoordinates.insert(coordKey)
                        uniqueResults.append(result)
                    }
                }
                
                // Sort by distance (nearest first) and take top 10
                let sortedResults = uniqueResults
                    .sorted { $0.distance < $1.distance }
                    .prefix(10)
                
                self.results = Array(sortedResults)
                self.isSearching = false
            }
            .store(in: &cancellables)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search error:", error.localizedDescription)
        results = []
        isSearching = false
    }
}

