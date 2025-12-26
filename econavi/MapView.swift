import SwiftUI
import MapKit
import CoreLocation

struct MapView: UIViewRepresentable {

    @Binding var region: MKCoordinateRegion
    let origin: String
    let destination: String
    let selectedMode: String?
    let showRoutes: Bool
    let userLocation: CLLocation?
    let isTracking: Bool

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()

        map.showsUserLocation = true
        map.userTrackingMode = .none

        // ❌ REMOVE APPLE MAPS UI
        map.showsCompass = false
        map.showsScale = false
        map.showsTraffic = false
        map.showsBuildings = true
        map.pointOfInterestFilter = .excludingAll

        // ❌ IMPORTANT — removes Apple Maps overlays
        map.layoutMargins = .zero
        map.insetsLayoutMarginsFromSafeArea = false

        map.delegate = context.coordinator
        return map
    }
  

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
    }

    // 🔹 THIS IS WHERE Coordinator LIVES
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // 🔹 INNER CLASS
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        // later:
        // - draw routes
        // - calculate distance
        // - update emissions
    }
}

        
    


