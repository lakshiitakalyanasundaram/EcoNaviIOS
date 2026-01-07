import Foundation
import MapKit
import CoreLocation
import SwiftUI
import Combine

/// Service for calculating routes between locations
@MainActor
class RouteService: ObservableObject {
    @Published var route: MKRoute?
    @Published var isCalculating = false
    @Published var error: String?
    
    /// Calculate route from origin to destination with specified transport type
    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType
    ) {
        isCalculating = true
        error = nil
        route = nil
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isCalculating = false
                
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                
                guard let route = response?.routes.first else {
                    self.error = "No route found"
                    return
                }
                
                self.route = route
            }
        }
    }
    
    func clearRoute() {
        route = nil
        error = nil
    }
}

/// Transport mode enum
enum TransportMode: String, CaseIterable, Identifiable {
    case walk = "walk"
    case bike = "bike"
    case car = "car"
    case publicTransport = "publicTransport"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .walk:
            return "Walk"
        case .bike:
            return "Bike"
        case .car:
            return "Car"
        case .publicTransport:
            return "Public Transport"
        }
    }
    
    var icon: String {
        switch self {
        case .walk:
            return "figure.walk"
        case .bike:
            return "bicycle"
        case .car:
            return "car.fill"
        case .publicTransport:
            return "bus.fill"
        }
    }
    
    var mapKitTransportType: MKDirectionsTransportType {
        switch self {
        case .walk:
            return .walking
        case .bike:
            return .walking // MapKit doesn't have bike, use walking
        case .car:
            return .automobile
        case .publicTransport:
            return .transit
        }
    }
    
    var color: Color {
        switch self {
        case .walk:
            return .blue
        case .bike:
            return .green
        case .car:
            return .orange
        case .publicTransport:
            return .purple
        }
    }
}

