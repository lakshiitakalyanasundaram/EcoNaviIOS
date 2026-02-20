import Foundation
import MapKit
import CoreLocation
import Combine
import SwiftUI

// MARK: - Instruction timing (STEP 14)
enum InstructionTimingState: String {
    case none       // > 500 m to next maneuver
    case prepare    // < 500 m
    case upcoming   // < 200 m
    case now        // < 50 m
}

// MARK: - Route segment overlays (STEP 4: grey completed / blue remaining)
final class CompletedRouteOverlay: MKPolyline {}
final class RemainingRouteOverlay: MKPolyline {}

// MARK: - Trip completion summary (STEP 17)
struct TripCompletionSummary: Equatable {
    let distanceKm: Double
    let carbonGrams: Double
    let mode: String
}

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

    // Active navigation session (STEP 10, 14)
    @Published var snappedLocation: CLLocationCoordinate2D?
    @Published var distanceToNextManeuver: CLLocationDistance?
    @Published var instructionTimingState: InstructionTimingState = .none
    @Published var isOffRoute: Bool = false

    // STEP 1, 4: Completed (grey) vs remaining (blue) route segments
    @Published private(set) var completedRoutePolyline: MKPolyline?
    @Published private(set) var remainingRoutePolyline: MKPolyline?

    // STEP 17: Trip completion banner
    @Published var tripJustCompleted: TripCompletionSummary?

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

    // Internals (STEP 14: delegate set in LocationManager only; STEP 15: weak to prevent leaks)
    private weak var sessionLocationManager: LocationManager?
    private var userLocation: CLLocation?
    private var routeSteps: [MKRoute.Step] = []
    private var routeLegs: [MKRoute] = []
    private var lastRecalcLocation: CLLocation?
    private var tripStartLocation: CLLocation?
    private let recalcThreshold: CLLocationDistance = 80 // meters
    private let stepAdvanceThreshold: CLLocationDistance = 35 // meters to advance to next step
    private let offRouteThreshold: CLLocationDistance = 50 // STEP 8
    private let destinationArrivalThreshold: CLLocationDistance = 30 // STEP 6: 30 meters
    private let instructionPrepareDistance: CLLocationDistance = 500 // STEP 14
    private let instructionUpcomingDistance: CLLocationDistance = 200
    private let instructionNowDistance: CLLocationDistance = 50

    var remainingDistanceComputed: CLLocationDistance { remainingDistance }
    var remainingTimeComputed: TimeInterval { remainingTime }

    // MARK: Public API

    /// Prepare a route preview (used by DirectionsSheetView before GO).
    func prepareRoute(route: MKRoute, mode: TransportMode) {
        self.route = route
        self.currentRoute = route
        self.transportMode = mode
        self.routeSteps = route.steps
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
        self.routeSteps = route.steps
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

    /// Start a live navigation session with optional multi-leg route (waypoints). STEP 14: LocationManager keeps single delegate.
    func startNavigationSession(routeLegs legs: [MKRoute], locationManager: LocationManager, transportMode: TransportMode = .walk) {
        let loc = locationManager.location
        self.sessionLocationManager = locationManager
        self.tripStartLocation = loc
        self.routeLegs = legs
        self.route = legs.first
        self.currentRoute = legs.first
        self.userLocation = loc
        self.transportMode = transportMode
        self.routeSteps = legs.flatMap { $0.steps }
        self.currentStepIndex = 0
        self.currentStep = routeSteps.first
        self.nextStep = routeSteps.dropFirst().first
        self.userHeading = locationManager.heading?.trueHeading
        lastRecalcLocation = nil
        completedRoutePolyline = nil
        remainingRoutePolyline = nil
        tripJustCompleted = nil
        locationManager.startTracking()
        locationManager.startHeadingUpdates()
        isNavigating = true
        navigationModeActive = true
        updateMetrics()
    }

    /// Replace current route with new legs (e.g. after adding a waypoint or recalc). Keeps session active.
    func applyRouteLegs(_ legs: [MKRoute]) {
        guard isNavigating, !legs.isEmpty else { return }
        self.routeLegs = legs
        self.route = legs.first
        self.currentRoute = legs.first
        self.routeSteps = legs.flatMap { $0.steps }
        self.currentStepIndex = min(currentStepIndex, routeSteps.count)
        self.currentStep = routeSteps.indices.contains(currentStepIndex) ? routeSteps[currentStepIndex] : routeSteps.first
        self.nextStep = routeSteps.dropFirst(currentStepIndex + 1).first
        isOffRoute = false
        completedRoutePolyline = nil
        remainingRoutePolyline = nil
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
    /// `recalcHandler` is called when we want to recalc the route via MKDirections (off-route or periodic).
    func updateLocation(_ location: CLLocation,
                        recalcHandler: ((_ from: CLLocationCoordinate2D, _ to: CLLocationCoordinate2D, _ type: MKDirectionsTransportType) -> Void)? = nil) {
        guard isNavigating else { return }
        let effectiveRoute = routeLegs.first ?? route
        guard effectiveRoute != nil else { return }

        userLocation = location

        // STEP 2, 3: Snap and trim route into completed (travelled) vs remaining (upcoming)
        let routePolylines = routeLegs.map(\.polyline)
        let allCoords = routePolylines.flatMap { $0.coordinates }
        let snapped: CLLocationCoordinate2D
        if let (point, _) = Self.nearestPointOnPolylines(from: location, polylines: routePolylines) {
            snapped = point
            snappedLocation = point
        } else {
            snapped = location.coordinate
            snappedLocation = location.coordinate
        }
        if !allCoords.isEmpty {
            let (completedCoords, remainingCoords) = Self.splitRoute(at: snapped, coordinates: allCoords)
            completedRoutePolyline = Self.makePolyline(completedCoords, completed: true)
            remainingRoutePolyline = Self.makePolyline(remainingCoords, completed: false)
        }

        // STEP 8: Off-route detection – recalc only when first going off-route
        let distanceToRoute = Self.distanceFromLocation(location, toPolylines: routePolylines)
        if distanceToRoute > offRouteThreshold {
            let wasOffRoute = isOffRoute
            isOffRoute = true
            if !wasOffRoute, let dest = destinationCoordinate {
                recalcHandler?(location.coordinate, dest, transportMode.mapKitTransportType)
            }
        }

        if let r = effectiveRoute {
            updateCurrentStep(from: location, in: r)
        }

        // STEP 6, 7: Arrival – end session when within 30m of destination
        if let dest = destinationCoordinate {
            let destLocation = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
            if location.distance(from: destLocation) < destinationArrivalThreshold {
                endNavigationSession(arrivalLocation: location)
                return
            }
        }

        updateMetrics()

        // STEP 14: Distance to next maneuver and instruction timing
        if currentStepIndex < routeSteps.count, let step = currentStep, let loc = userLocation {
            let coords = step.polyline.coordinates
            if let endCoord = coords.last {
                let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
                let toManeuver = loc.distance(from: endLocation)
                distanceToNextManeuver = toManeuver
                if toManeuver < instructionNowDistance {
                    instructionTimingState = .now
                } else if toManeuver < instructionUpcomingDistance {
                    instructionTimingState = .upcoming
                } else if toManeuver < instructionPrepareDistance {
                    instructionTimingState = .prepare
                } else {
                    instructionTimingState = .none
                }
            } else {
                distanceToNextManeuver = nil
                instructionTimingState = .none
            }
        } else {
            distanceToNextManeuver = nil
            instructionTimingState = .none
        }

        // Periodic recalc (e.g. progress along route) – not when off-route to avoid double recalc
        if !isOffRoute, let last = lastRecalcLocation, let dest = destinationCoordinate {
            if location.distance(from: last) > recalcThreshold {
                lastRecalcLocation = location
                recalcHandler?(location.coordinate, dest, transportMode.mapKitTransportType)
            }
        } else if lastRecalcLocation == nil {
            lastRecalcLocation = location
        }
    }

    /// STEP 7, 8: End session on arrival – stop updates, compute trip stats, write reward, show banner.
    func endNavigationSession(arrivalLocation: CLLocation) {
        // STEP 8: Stop CLLocationManager and heading updates
        sessionLocationManager?.stopTracking()
        sessionLocationManager?.stopHeadingUpdates()
        sessionLocationManager = nil

        // STEP 9, 10: Trip distance and carbon
        let tripDistanceM: CLLocationDistance
        if let completed = completedRoutePolyline, !completed.coordinates.isEmpty {
            tripDistanceM = Self.polylineLength(completed.coordinates)
        } else if let start = tripStartLocation {
            tripDistanceM = start.distance(from: arrivalLocation)
        } else {
            tripDistanceM = 0
        }
        let tripDistanceKm = tripDistanceM / 1000.0
        let tripCarbonGrams = EmissionsCalculatorIndia.calculateEmissions(mode: transportMode.rawValue, distanceKm: tripDistanceKm)

        let modeName = transportMode.rawValue
        tripJustCompleted = TripCompletionSummary(distanceKm: tripDistanceKm, carbonGrams: tripCarbonGrams, mode: modeName)
        clearSession(clearTripBanner: false)

        // STEP 11, 12: Write to Supabase rewards (STEP 13: weak self)
        let credits = max(1, EmissionsCalculatorIndia.calculateCarbonCredits(savedEmissionsGrams: tripCarbonGrams))
        let reason = String(format: "Trip %.2f km", tripDistanceKm)
        Task { [weak self] in
            await UserDataManager.shared.addRewardPoints(credits, reason: reason)
        }
    }

    /// User tapped "End Route" – stop updates and clear state (no reward).
    func stopNavigation() {
        sessionLocationManager?.stopTracking()
        sessionLocationManager?.stopHeadingUpdates()
        sessionLocationManager = nil
        clearSession(clearTripBanner: true)
    }

    /// STEP 8, 15: Reset all session state; no timers to cancel (STEP 13).
    private func clearSession(clearTripBanner: Bool = true) {
        if clearTripBanner { tripJustCompleted = nil }
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
        tripStartLocation = nil
        snappedLocation = nil
        distanceToNextManeuver = nil
        instructionTimingState = .none
        isOffRoute = false
        completedRoutePolyline = nil
        remainingRoutePolyline = nil
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

        // STEP 5: Prefer remaining distance from remaining polyline when available
        var remaining: CLLocationDistance
        if let rem = remainingRoutePolyline {
            remaining = Self.polylineLength(rem.coordinates)
        } else {
            remaining = 0
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

    // MARK: - Geometry helpers (STEP 8, 10)

    /// Minimum distance from location to any polyline in meters.
    private static func distanceFromLocation(_ location: CLLocation, toPolylines polylines: [MKPolyline]) -> CLLocationDistance {
        var minDistance: CLLocationDistance = .greatestFiniteMagnitude
        for polyline in polylines {
            let (_, dist) = nearestPointOnPolyline(from: location, polyline: polyline)
            if dist < minDistance { minDistance = dist }
        }
        return minDistance
    }

    /// Nearest point on any of the polylines and its distance. Returns nil if polylines empty.
    private static func nearestPointOnPolylines(from location: CLLocation, polylines: [MKPolyline]) -> (CLLocationCoordinate2D, CLLocationDistance)? {
        var bestPoint = location.coordinate
        var bestDistance: CLLocationDistance = .greatestFiniteMagnitude
        for polyline in polylines {
            let (point, dist) = nearestPointOnPolyline(from: location, polyline: polyline)
            if dist < bestDistance {
                bestDistance = dist
                bestPoint = point
            }
        }
        guard bestDistance != .greatestFiniteMagnitude else { return nil }
        return (bestPoint, bestDistance)
    }

    /// Nearest point on polyline segment and distance from location.
    private static func nearestPointOnPolyline(from location: CLLocation, polyline: MKPolyline) -> (CLLocationCoordinate2D, CLLocationDistance) {
        let coords = polyline.coordinates
        guard coords.count >= 2 else {
            if let first = coords.first {
                let c = CLLocation(latitude: first.latitude, longitude: first.longitude)
                return (first, location.distance(from: c))
            }
            return (location.coordinate, 0)
        }
        var best = location.coordinate
        var bestDist: CLLocationDistance = .greatestFiniteMagnitude
        for i in 0..<(coords.count - 1) {
            let a = coords[i]
            let b = coords[i + 1]
            let (point, dist) = nearestPointOnSegment(location: location, segmentStart: a, segmentEnd: b)
            if dist < bestDist {
                bestDist = dist
                best = point
            }
        }
        return (best, bestDist)
    }

    /// Nearest point on line segment A-B from location.
    private static func nearestPointOnSegment(location: CLLocation, segmentStart A: CLLocationCoordinate2D, segmentEnd B: CLLocationCoordinate2D) -> (CLLocationCoordinate2D, CLLocationDistance) {
        let P = location.coordinate
        let a = A.latitude - P.latitude
        let b = A.longitude - P.longitude
        let c = B.latitude - A.latitude
        let d = B.longitude - A.longitude
        let dot = a * c + b * d
        let lenSq = c * c + d * d
        var t: Double = 1
        if lenSq > 0 {
            t = max(0, min(1, dot / lenSq))
        }
        let nearest = CLLocationCoordinate2D(
            latitude: A.latitude + t * (B.latitude - A.latitude),
            longitude: A.longitude + t * (B.longitude - A.longitude)
        )
        let nearestLoc = CLLocation(latitude: nearest.latitude, longitude: nearest.longitude)
        return (nearest, location.distance(from: nearestLoc))
    }

    // MARK: - STEP 1, 3: Split route at snapped point (completed vs remaining)

    private static func splitRoute(at snapped: CLLocationCoordinate2D, coordinates: [CLLocationCoordinate2D]) -> (completed: [CLLocationCoordinate2D], remaining: [CLLocationCoordinate2D]) {
        guard coordinates.count >= 2 else {
            if coordinates.count == 1 {
                return ([snapped], [snapped])
            }
            return ([], [])
        }
        let loc = CLLocation(latitude: snapped.latitude, longitude: snapped.longitude)
        var bestIndex = 0
        var bestDist: CLLocationDistance = .greatestFiniteMagnitude
        for i in 0..<(coordinates.count - 1) {
            let (_, d) = nearestPointOnSegment(location: loc, segmentStart: coordinates[i], segmentEnd: coordinates[i + 1])
            if d < bestDist {
                bestDist = d
                bestIndex = i
            }
        }
        let completed = Array(coordinates.prefix(bestIndex + 1)) + [snapped]
        let remaining = [snapped] + Array(coordinates.suffix(from: bestIndex + 1))
        return (completed, remaining)
    }

    private static func makePolyline(_ coords: [CLLocationCoordinate2D], completed: Bool) -> MKPolyline? {
        guard coords.count >= 2 else { return nil }
        var arr = coords
        if completed {
            return CompletedRouteOverlay(coordinates: &arr, count: arr.count)
        } else {
            return RemainingRouteOverlay(coordinates: &arr, count: arr.count)
        }
    }

    private static func polylineLength(_ coords: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard coords.count >= 2 else { return 0 }
        var total: CLLocationDistance = 0
        for i in 0..<(coords.count - 1) {
            let a = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let b = CLLocation(latitude: coords[i + 1].latitude, longitude: coords[i + 1].longitude)
            total += a.distance(from: b)
        }
        return total
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

