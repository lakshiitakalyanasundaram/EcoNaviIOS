import Foundation
import MapKit
import CoreLocation
import SwiftUI
import Combine

/// Service for calculating routes between locations
@MainActor
class RouteService: ObservableObject {
    @Published var route: MKRoute?
    /// When non-empty, map should draw all legs; navigation uses combined steps.
    @Published var routeLegs: [MKRoute] = []
    @Published var isCalculating = false
    @Published var error: String?
    
    /// Calculate route from origin to destination with specified transport type
    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType
    ) {
        routeLegs = []
        calculateRouteWithWaypoints(origin: origin, waypoints: [], destination: destination, transportType: transportType)
    }
    
    /// Calculate route with optional waypoints: origin → waypoint[0] → … → destination
    func calculateRouteWithWaypoints(
        origin: CLLocationCoordinate2D,
        waypoints: [MKMapItem],
        destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType
    ) {
        isCalculating = true
        error = nil
        route = nil
        routeLegs = []
        
        let allStops: [MKMapItem] = [MKMapItem(placemark: MKPlacemark(coordinate: origin))]
            + waypoints
            + [MKMapItem(placemark: MKPlacemark(coordinate: destination))]
        
        guard allStops.count >= 2 else {
            isCalculating = false
            return
        }
        
        var legs: [MKRoute] = []
        var currentIndex = 0
        
        func requestNext() {
            guard currentIndex < allStops.count - 1 else {
                Task { @MainActor in
                    self.isCalculating = false
                    self.routeLegs = legs
                    self.route = legs.first
                }
                return
            }
            
            let request = MKDirections.Request()
            request.source = allStops[currentIndex]
            request.destination = allStops[currentIndex + 1]
            request.transportType = transportType
            request.requestsAlternateRoutes = false
            
            let directions = MKDirections(request: request)
            directions.calculate { response, err in
                Task { @MainActor in
                    if let err = err {
                        self.isCalculating = false
                        self.error = err.localizedDescription
                        return
                    }
                    guard let r = response?.routes.first else {
                        self.isCalculating = false
                        self.error = "No route found"
                        return
                    }
                    legs.append(r)
                    currentIndex += 1
                    if currentIndex < allStops.count - 1 {
                        requestNext()
                    } else {
                        self.isCalculating = false
                        self.routeLegs = legs
                        self.route = legs.first
                    }
                }
            }
        }
        
        requestNext()
    }
    
    func clearRoute() {
        route = nil
        routeLegs = []
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

