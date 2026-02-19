import Foundation
import MapKit
import CoreLocation
import Combine
import SwiftUI

/// Central navigation state (route, ETA, instructions, emissions).
@MainActor
final class NavigationManager: ObservableObject {

    // MARK: Published state required by spec (STEP 10)

    @Published var route: MKRoute?
    @Published var eta: Date?
    @Published var remainingDistance: CLLocationDistance = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var nextInstruction: String?
    @Published var emissionEstimate: Double = 0
    @Published var navigationModeActive: Bool = false

    // Backwards‑compat fields (existing UI still uses these)
    @Published var isNavigating: Bool = false
    @Published var currentInstruction: String?
    @Published var distanceRemaining: CLLocationDistance = 0
    @Published var timeRemaining: TimeInterval = 0
    @Published var currentStep: MKRoute.Step?
    @Published var nextStep: MKRoute.Step?
    @Published var transportMode: TransportMode = .walk
    @Published var estimatedArrivalTime: Date?
    @Published var currentRoute: MKRoute?
    @Published var currentStepIndex: Int = 0
    @Published var userHeading: CLLocationDirection?
    @Published var waypoints: [MKMapItem] = []

    // Internals
    private var userLocation: CLLocation?
    private var routeSteps: [MKRoute.Step] = []
    private var routeLegs: [MKRoute] = []
    private var lastRecalcLocation: CLLocation?
    private let recalcThreshold: CLLocationDistance = 80 // meters
    private let stepAdvanceThreshold: CLLocationDistance = 35 // meters to advance to next step

    var remainingDistanceComputed: CLLocationDistance { remainingDistance }
    var remainingTimeComputed: TimeInterval { remainingTime }

    // MARK: Public API

    /// Prepare a route preview (used by DirectionsSheetView before GO).
    func prepareRoute(route: MKRoute, mode: TransportMode) {
        self.route = route
        self.currentRoute = route
        self.transportMode = mode
        self.routeSteps = route.steps.filter { !$0.instructions.isEmpty }
        self.currentStepIndex = 0
        self.currentStep = routeSteps.first
        self.nextStep = routeSteps.dropFirst().first
        updateMetrics()
    }

    /// Start navigation with a route and current user location.
    func startNavigation(route: MKRoute, userLocation: CLLocation, transportMode: TransportMode = .walk) {
        self.route = route
        self.currentRoute = route
        self.userLocation = userLocation
        self.transportMode = transportMode
        self.routeSteps = route.steps.filter { !$0.instructions.isEmpty }
        self.currentStepIndex = 0
        self.currentStep = routeSteps.first
        self.nextStep = routeSteps.dropFirst().first
        isNavigating = true
        navigationModeActive = true
        updateMetrics()
    }

    /// Start a live navigation session: start location/heading updates and initialize step tracking.
    func startNavigationSession(route: MKRoute, locationManager: LocationManager, transportMode: TransportMode = .walk) {
        startNavigationSession(routeLegs: [route], locationManager: locationManager, transportMode: transportMode)
    }

    /// Start a live navigation session with optional multi-leg route (waypoints).
    func startNavigationSession(routeLegs legs: [MKRoute], locationManager: LocationManager, transportMode: TransportMode = .walk) {
        let loc = locationManager.location
        self.routeLegs = legs
        self.route = legs.first
        self.currentRoute = legs.first
        self.userLocation = loc
        self.transportMode = transportMode
        self.routeSteps = legs.flatMap { $0.steps }.filter { !$0.instructions.isEmpty }
        self.currentStepIndex = 0
        self.currentStep = routeSteps.first
        self.nextStep = routeSteps.dropFirst().first
        self.userHeading = locationManager.heading?.trueHeading
        lastRecalcLocation = nil
        locationManager.startTracking()
        locationManager.startHeadingUpdates()
        isNavigating = true
        navigationModeActive = true
        updateMetrics()
    }

    /// Replace current route with new legs (e.g. after adding a waypoint). Keeps session active.
    func applyRouteLegs(_ legs: [MKRoute]) {
        guard isNavigating, !legs.isEmpty else { return }
        self.routeLegs = legs
        self.route = legs.first
        self.currentRoute = legs.first
        self.routeSteps = legs.flatMap { $0.steps }.filter { !$0.instructions.isEmpty }
        self.currentStepIndex = min(currentStepIndex, routeSteps.count)
        self.currentStep = routeSteps.indices.contains(currentStepIndex) ? routeSteps[currentStepIndex] : routeSteps.first
        self.nextStep = routeSteps.dropFirst(currentStepIndex + 1).first
        updateMetrics()
    }

    /// Destination coordinate (last point of route) for recalculating with waypoints.
    var destinationCoordinate: CLLocationCoordinate2D? {
        if let last = routeLegs.last?.polyline.coordinates.last { return last }
        return route?.polyline.coordinates.last
    }

    /// Update heading for map rotation (call from UI when LocationManager.heading changes).
    func updateHeading(_ heading: CLHeading?) {
        userHeading = heading?.trueHeading
    }

    /// Update navigation state based on user location.
    /// `recalcHandler` is called when we want to recalc the route via MKDirections.
    func updateLocation(_ location: CLLocation,
                        recalcHandler: ((_ from: CLLocationCoordinate2D, _ to: CLLocationCoordinate2D, _ type: MKDirectionsTransportType) -> Void)? = nil) {
        guard isNavigating else { return }
        let effectiveRoute = routeLegs.first ?? route
        guard effectiveRoute != nil else { return }

        userLocation = location

        if let r = effectiveRoute {
            updateCurrentStep(from: location, in: r)
        }
        updateMetrics()

        if let last = lastRecalcLocation, let dest = destinationCoordinate {
            if location.distance(from: last) > recalcThreshold {
                lastRecalcLocation = location
                recalcHandler?(location.coordinate, dest, transportMode.mapKitTransportType)
            }
        } else {
            lastRecalcLocation = location
        }
    }

    func stopNavigation() {
        isNavigating = false
        navigationModeActive = false
        route = nil
        currentRoute = nil
        currentInstruction = nil
        nextInstruction = nil
        distanceRemaining = 0
        timeRemaining = 0
        remainingDistance = 0
        remainingTime = 0
        emissionEstimate = 0
        currentStep = nil
        nextStep = nil
        routeSteps = []
        routeLegs = []
        waypoints = []
        currentStepIndex = 0
        userHeading = nil
        transportMode = .walk
        estimatedArrivalTime = nil
        eta = nil
        userLocation = nil
        lastRecalcLocation = nil
    }

    // MARK: Internal calculations

    private func updateCurrentStep(from location: CLLocation, in route: MKRoute) {
        guard !routeSteps.isEmpty else { return }

        // Advance to next step when user is within threshold of current step's end
        if currentStepIndex < routeSteps.count {
            let step = routeSteps[currentStepIndex]
            let coords = step.polyline.coordinates
            if let endCoord = coords.last {
                let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
                if location.distance(from: endLocation) <= stepAdvanceThreshold {
                    currentStepIndex = min(currentStepIndex + 1, routeSteps.count)
                    if currentStepIndex < routeSteps.count {
                        currentStep = routeSteps[currentStepIndex]
                        nextStep = routeSteps.dropFirst(currentStepIndex + 1).first
                    } else {
                        currentStep = nil
                        nextStep = nil
                    }
                    return
                }
            }
        }

        // Otherwise find closest step from current onward (avoid jumping backward)
        var closestStep: MKRoute.Step?
        var closestDistance: CLLocationDistance = .greatestFiniteMagnitude
        var closestIndex = currentStepIndex
        let startIndex = max(0, currentStepIndex)

        for (index, step) in routeSteps.enumerated() where index >= startIndex {
            let coordinates = step.polyline.coordinates
            guard !coordinates.isEmpty else { continue }
            for coordinate in coordinates {
                let stepLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let d = location.distance(from: stepLocation)
                if d < closestDistance {
                    closestDistance = d
                    closestStep = step
                    closestIndex = index
                }
            }
        }

        if let step = closestStep {
            currentStepIndex = closestIndex
            currentStep = step
            nextStep = routeSteps.dropFirst(closestIndex + 1).first
        }
    }

    private func updateMetrics() {
        let totalDistance: CLLocationDistance
        let totalTime: TimeInterval
        if !routeLegs.isEmpty {
            totalDistance = routeLegs.reduce(0) { $0 + $1.distance }
            totalTime = routeLegs.reduce(0) { $0 + $1.expectedTravelTime }
        } else if let route = route {
            totalDistance = route.distance
            totalTime = route.expectedTravelTime
        } else {
            return
        }

        var remaining: CLLocationDistance = 0
        if let currentStep = currentStep,
           currentStepIndex < routeSteps.count,
           let loc = userLocation {
            let coords = currentStep.polyline.coordinates
            if let last = coords.last {
                let end = CLLocation(latitude: last.latitude, longitude: last.longitude)
                remaining += loc.distance(from: end)
            }
        }
        for i in (currentStepIndex + 1)..<routeSteps.count {
            remaining += routeSteps[i].distance
        }

        remainingDistance = remaining
        distanceRemaining = remaining

        if totalDistance > 0 {
            let fractionLeft = remaining / totalDistance
            let remainingTimeSeconds = totalTime * fractionLeft
            remainingTime = remainingTimeSeconds
            timeRemaining = remainingTimeSeconds
        } else {
            remainingTime = 0
            timeRemaining = 0
        }

        updateETA()
        updateInstructions()
        updateEmissions()
    }

    private func updateETA() {
        guard remainingTime > 0 else {
            estimatedArrivalTime = nil
            eta = nil
            return
        }
        let value = Date().addingTimeInterval(remainingTime)
        estimatedArrivalTime = value
        eta = value
    }

    private func updateInstructions() {
        guard let step = currentStep else {
            currentInstruction = "Navigation complete"
            nextInstruction = currentInstruction
            return
        }

        let text = formatInstruction(from: step)
        currentInstruction = text
        nextInstruction = text
    }

    private func updateEmissions() {
        let distanceKm = remainingDistance / 1000.0
        let emissions = EmissionsCalculatorIndia.calculateEmissions(mode: transportMode.rawValue,
                                                                    distanceKm: distanceKm)
        emissionEstimate = emissions
    }

    private func formatInstruction(from step: MKRoute.Step) -> String {
        var instruction = step.instructions

        if instruction.isEmpty {
            let distance = step.distance
            if distance < 100 {
                instruction = "Continue for \(Int(distance)) m"
            } else {
                let km = distance / 1000
                let formatted = String(format: "%.1f", km)
                instruction = "Continue for \(formatted) km"
            }
        }
        return instruction
    }
}

// MARK: - MKPolyline Extension
extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

