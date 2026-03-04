import MapKit
import Combine
import CoreLocation

final class LocationSearchService: NSObject, ObservableObject {

    @Published var results: [SearchResult] = []

    private let completer = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()

    private var userLocation: CLLocation?

    override init() {
        super.init()
        completer.delegate = self

        // VERY IMPORTANT — limit noise
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func updateUserLocation(_ location: CLLocation) {
        self.userLocation = location

        // 🔥 Bias results to nearby area
        completer.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    }

    func updateQuery(_ query: String) {
        completer.queryFragment = query
    }

    func clear() {
        results = []
    }
}
extension LocationSearchService: MKLocalSearchCompleterDelegate {

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {

        guard let userLocation else { return }

        let items = completer.results.prefix(20)

        let searches = items.map { completion -> AnyPublisher<SearchResult?, Never> in
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)

            return Future { promise in
                search.start { response, _ in
                    guard
                        let mapItem = response?.mapItems.first,
                        let location = mapItem.placemark.location
                    else {
                        promise(.success(nil))
                        return
                    }

                    let distance = userLocation.distance(from: location)

                    // 🚫 Filter VERY FAR results (like Venezuela)
                    if distance > 50_000 { // 50 km
                        promise(.success(nil))
                        return
                    }

                    let score = self.scoreResult(
                        title: completion.title,
                        distance: distance
                    )

                    promise(.success(
                        SearchResult(
                            title: completion.title,
                            subtitle: completion.subtitle,
                            coordinate: location.coordinate,
                            distance: distance,
                            score: score
                        )
                    ))
                }
            }
            .eraseToAnyPublisher()
        }

        Publishers.MergeMany(searches)
            .compactMap { $0 }
            .collect()
            .map { results in
                results
                    .sorted { $0.score > $1.score }
                    .prefix(10)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ranked in
                self?.results = Array(ranked)
            }
            .store(in: &cancellables)
    }

    // 🔥 GOOGLE-LIKE SCORING
    private func scoreResult(title: String, distance: CLLocationDistance) -> Double {

        var score = 0.0

        // 1️⃣ Distance weight (most important)
        score += max(0, 1_000 - distance / 10)

        // 2️⃣ POI boost
        if title.lowercased().contains("mall")
            || title.lowercased().contains("temple")
            || title.lowercased().contains("hospital")
            || title.lowercased().contains("college") {
            score += 300
        }

        // 3️⃣ City-level penalty
        if title.contains(",") == false {
            score -= 200
        }

        return score
    }
}


