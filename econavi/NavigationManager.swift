import Foundation
import MapKit
import CoreLocation
import Combine
import SwiftUI

/// Manages active navigation state and turn-by-turn instructions
@MainActor
class NavigationManager: ObservableObject {
    @Published var isNavigating = false
    @Published var currentInstruction: String?
    @Published var distanceRemaining: CLLocationDistance = 0
    @Published var timeRemaining: TimeInterval = 0
    @Published var currentStep: MKRoute.Step?
    @Published var nextStep: MKRoute.Step?
    @Published var transportMode: TransportMode = .walk
    @Published var estimatedArrivalTime: Date?
    
    private var route: MKRoute?
    private var userLocation: CLLocation?
    private var routeSteps: [MKRoute.Step] = []
    private var currentStepIndex = 0
    private var navigationStartTime: Date?
    
    /// Start navigation with a route and transport mode
    func startNavigation(route: MKRoute, userLocation: CLLocation, transportMode: TransportMode = .walk) {
        self.route = route
        self.userLocation = userLocation
        self.routeSteps = route.steps
        self.currentStepIndex = 0
        self.isNavigating = true
        self.transportMode = transportMode
        self.navigationStartTime = Date()
        
        // Calculate initial ETA
        updateETA()
        
        updateNavigationState()
    }
    
    /// Update navigation state based on current user location
    func updateLocation(_ location: CLLocation) {
        guard isNavigating, let route = route else { return }
        
        userLocation = location
        
        // Find closest step
        updateCurrentStep(from: location)
        
        // Calculate remaining distance and time
        calculateRemainingDistance(from: location)
        
        // Update instruction
        updateNavigationState()
    }
    
    /// Stop navigation
    func stopNavigation() {
        isNavigating = false
        route = nil
        currentInstruction = nil
        distanceRemaining = 0
        timeRemaining = 0
        currentStep = nil
        nextStep = nil
        routeSteps = []
        currentStepIndex = 0
        transportMode = .walk
        estimatedArrivalTime = nil
        navigationStartTime = nil
    }
    
    private func updateCurrentStep(from location: CLLocation) {
        var closestStep: MKRoute.Step?
        var closestDistance: CLLocationDistance = Double.infinity
        var closestIndex = 0
        
        for (index, step) in routeSteps.enumerated() {
            // Get coordinates from step polyline
            let coordinates = step.polyline.coordinates
            guard !coordinates.isEmpty else { continue }
            
            // Find closest point on step polyline
            for coordinate in coordinates {
                let stepLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = location.distance(from: stepLocation)
                
                if distance < closestDistance {
                    closestDistance = distance
                    closestStep = step
                    closestIndex = index
                }
            }
        }
        
        if let step = closestStep, closestIndex >= currentStepIndex {
            currentStepIndex = closestIndex
            currentStep = step
            
            // Get next step if available
            if closestIndex + 1 < routeSteps.count {
                nextStep = routeSteps[closestIndex + 1]
            } else {
                nextStep = nil
            }
        }
    }
    
    private func calculateRemainingDistance(from location: CLLocation) {
        guard let route = route else { return }
        
        var remainingDistance: CLLocationDistance = 0
        
        // Calculate distance from current location to end of current step
        if let currentStep = currentStep, currentStepIndex < routeSteps.count {
            let stepCoordinates = currentStep.polyline.coordinates
            if let lastCoordinate = stepCoordinates.last {
                let stepEnd = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
                remainingDistance += location.distance(from: stepEnd)
            }
        }
        
        // Add distance for remaining steps
        for i in (currentStepIndex + 1)..<routeSteps.count {
            remainingDistance += routeSteps[i].distance
        }
        
        distanceRemaining = remainingDistance
        
        // Estimate time remaining (using average speed based on route)
        let averageSpeed: CLLocationSpeed = 50_000 / 3600 // ~50 km/h in m/s
        timeRemaining = remainingDistance / averageSpeed
        
        // Update ETA
        updateETA()
    }
    
    private func updateETA() {
        guard timeRemaining > 0 else {
            estimatedArrivalTime = nil
            return
        }
        estimatedArrivalTime = Date().addingTimeInterval(timeRemaining)
    }
    
    /// Calculate carbon emissions for the route
    func calculateCarbonEmissions() -> Double {
        let distanceKm = distanceRemaining / 1000.0
        
        // Map transport mode to emission factor key
        let modeKey: String
        switch transportMode {
        case .walk:
            modeKey = "walk"
        case .bike:
            modeKey = "bike"
        case .car:
            modeKey = "car"
        case .publicTransport:
            modeKey = "bus" // Using bus as default for public transport
        }
        
        return EmissionsCalculatorIndia.calculateEmissions(mode: modeKey, distanceKm: distanceKm)
    }
    
    private func updateNavigationState() {
        guard let currentStep = currentStep else {
            currentInstruction = "Navigation complete"
            return
        }
        
        // Format instruction from step
        let instruction = formatInstruction(from: currentStep)
        currentInstruction = instruction
    }
    
    private func formatInstruction(from step: MKRoute.Step) -> String {
        var instruction = step.instructions
        
        if instruction.isEmpty {
            // Fallback instruction
            let distance = step.distance
            if distance < 100 {
                instruction = "Continue for \(Int(distance))m"
            } else {
                instruction = "Continue for \(String(format: "%.1f", distance / 1000))km"
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

