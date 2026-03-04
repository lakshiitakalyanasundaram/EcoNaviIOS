import Foundation
import CoreLocation

struct SearchResult: Identifiable, Hashable {

    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let distance: CLLocationDistance
    let score: Double

    // ✅ Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // ✅ Equatable
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

