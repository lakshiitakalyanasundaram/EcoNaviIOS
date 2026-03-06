//
//  TravelPlannerViewModel.swift
//  econavi
//
//  Created by lakshiita kalyanasundaram on 3/4/26.
//

import Foundation
import MapKit
import Combine

@MainActor
class TravelPlannerViewModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var destination: String = ""
    @Published var selectedDate: Date = Date()
    @Published var selectedTime: Date = Date()
    @Published var selectedTransportMode: TravelMode = .car
    @Published var selectedTrafficLevel: TrafficLevel = .moderate
    
    @Published var isCalculating: Bool = false
    @Published var currentTrip: TripPlan?
    @Published var travelSummary: TravelSummary?
    @Published var alternativeOptions: [AlternativeTravelOption] = []
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Private Properties
    
    private let emissionCalculator = EmissionCalculator.shared
    private let locationManager = CLLocationManager()
    private var searchCompleter = MKLocalSearchCompleter()
    private var searchResults: [MKLocalSearchCompletion] = []
    
    @Published var searchSuggestions: [MKLocalSearchCompletion] = []
    
    override init() {
        super.init()
        setupLocationManager()
        setupSearchCompleter()
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    private func setupSearchCompleter() {
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        
        if let userLocation = locationManager.location?.coordinate {
            let region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
            searchCompleter.region = region
        }
    }
    
    // MARK: - Search
    
    func updateDestinationSearch(_ text: String) {
        if text.isEmpty {
            searchSuggestions = []
            return
        }
        
        if let userLocation = locationManager.location?.coordinate {
            let region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
            searchCompleter.region = region
        }
        
        searchCompleter.queryFragment = text
    }
    
    // MARK: - Route Calculation
    
    func calculateRoute(to destination: String) async {
        isCalculating = true
        errorMessage = nil
        
        do {
            // Get user's current location
            guard let userLocation = locationManager.location?.coordinate else {
                errorMessage = "Unable to get your current location. Please enable location services."
                showError = true
                isCalculating = false
                return
            }
            
            // Search for destination
            let destinationCoordinate = try await searchDestination(destination)
            
            // Calculate route based on transport mode
            let departureDateTime = Calendar.current.date(
                bySettingHour: Calendar.current.component(.hour, from: selectedTime),
                minute: Calendar.current.component(.minute, from: selectedTime),
                second: 0,
                of: selectedDate
            ) ?? selectedDate
            
            var route: MKRoute
            var routeName: String? = nil
            var arrivalTime: Date? = nil
            var trafficLevel: TrafficLevel
            
            // Use transit routing for bus and metro
            if selectedTransportMode == .bus || selectedTransportMode == .metro {
                do {
                    let (transitRoute, transitRouteName) = try await calculateTransitRoute(
                        from: userLocation,
                        to: destinationCoordinate,
                        departureDate: departureDateTime
                    )
                    route = transitRoute
                    routeName = transitRouteName
                    let durationSeconds = route.expectedTravelTime
                    arrivalTime = departureDateTime.addingTimeInterval(durationSeconds)
                    trafficLevel = .low
                } catch {
                    // Transit not available, fall back to car
                    route = try await calculateMKRoute(
                        from: userLocation,
                        to: destinationCoordinate
                    )
                    trafficLevel = emissionCalculator.estimateTrafficLevel(
                        distance: route.distance,
                        expectedTravelTime: route.expectedTravelTime
                    )
                    routeName = "Transit (using car estimate)"
                }
            } else {
                // Use regular routing for car, bike, walk
                route = try await calculateMKRoute(
                    from: userLocation,
                    to: destinationCoordinate
                )
                
                trafficLevel = emissionCalculator.estimateTrafficLevel(
                    distance: route.distance,
                    expectedTravelTime: route.expectedTravelTime
                )
            }
            
            // Extract route information
            let distanceKm = route.distance / 1000
            let durationSeconds = route.expectedTravelTime
            let durationMinutes = Int(durationSeconds / 60)
            let averageSpeedKmh = (distanceKm / durationSeconds) * 3600
            
            // Create trip plan
            let trip = TripPlan(
                destination: destination,
                destinationCoordinate: destinationCoordinate,
                departureDate: selectedDate,
                departureTime: selectedTime,
                transportMode: selectedTransportMode,
                distanceKm: distanceKm,
                estimatedDurationMinutes: durationMinutes,
                congestionFactor: trafficLevel.congestionFactor,
                trafficLevel: trafficLevel,
                routeName: routeName,
                arrivalTime: arrivalTime ?? departureDateTime.addingTimeInterval(durationSeconds)
            )
            
            self.currentTrip = trip
            
            // Predict emission (standardized rule-based model, grams CO₂)
            let emissionG = EmissionsCalculatorIndia.calculateEmissions(
                mode: selectedTransportMode.rawValue,
                distanceKm: distanceKm
            )
            
            // Create travel summary
            let finalArrivalTime = arrivalTime ?? departureDateTime.addingTimeInterval(durationSeconds)
            let summary = TravelSummary(
                destination: destination,
                transportMode: selectedTransportMode,
                distanceKm: distanceKm,
                estimatedDurationMinutes: durationMinutes,
                estimatedArrivalTime: finalArrivalTime,
                trafficLevel: trafficLevel,
                // TravelSummary stores kg; convert from standardized grams.
                predictedEmissionKg: emissionG / 1000.0,
                exceedsLimit: emissionG > 2000.0,
                routeName: routeName
            )
            
            self.travelSummary = summary
            
            // Generate alternatives if emission is high
            if summary.exceedsLimit {
                let alternatives = await emissionCalculator.suggestAlternatives(
                    originalTrip: trip,
                    originalEmission: emissionG
                )
                self.alternativeOptions = Array(alternatives.prefix(3))
            }
            
        } catch {
            errorMessage = "Failed to calculate route: \(error.localizedDescription)"
            showError = true
        }
        
        isCalculating = false
    }
    
    // MARK: - Private Helpers
    
    private func searchDestination(_ query: String) async throws -> CLLocationCoordinate2D {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        if let userLocation = locationManager.location?.coordinate {
            let region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
            request.region = region
        }
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        if let firstResult = response.mapItems.first {
            return firstResult.placemark.coordinate
        }
        
        throw NSError(
            domain: "TravelPlanner",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Destination not found"]
        )
    }
    
    private func calculateMKRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportTypeForMode(selectedTransportMode)
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        if let route = response.routes.first {
            return route
        }
        
        throw NSError(
            domain: "TravelPlanner",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "No route found"]
        )
    }
    
    private func calculateTransitRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        departureDate: Date
    ) async throws -> (route: MKRoute, routeName: String?) {
        let request = MKDirections.Request()
        
        let sourceItem = MKMapItem(placemark: MKPlacemark(coordinate: source))
        let destItem = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        
        request.source = sourceItem
        request.destination = destItem
        request.transportType = .transit
        request.departureDate = departureDate
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else {
                throw NSError(
                    domain: "TravelPlanner",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Transit data unavailable"]
                )
            }
            
            var routeName: String? = nil
            if let firstStep = route.steps.first {
                let instructions = firstStep.instructions
                if instructions.contains("Bus") {
                    if let busMatch = instructions.range(of: "Bus\\s+\\S+", options: .regularExpression) {
                        routeName = String(instructions[busMatch])
                    }
                } else if instructions.contains("Metro") || instructions.contains("Train") {
                    if let metroMatch = instructions.range(of: "(Metro|Train)\\s+\\S+\\s+\\S*", options: .regularExpression) {
                        routeName = String(instructions[metroMatch])
                    }
                }
            }
            
            return (route, routeName)
        } catch {
            // Fallback to car routing
            let carRequest = MKDirections.Request()
            carRequest.source = sourceItem
            carRequest.destination = destItem
            carRequest.transportType = .automobile
            carRequest.requestsAlternateRoutes = false
            
            let carDirections = MKDirections(request: carRequest)
            let carResponse = try await carDirections.calculate()
            
            guard let carRoute = carResponse.routes.first else {
                throw NSError(
                    domain: "TravelPlanner",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No route found"]
                )
            }
            
            return (carRoute, "Transit Route (car estimate)")
        }
    }
    
    private func transportTypeForMode(_ mode: TravelMode) -> MKDirectionsTransportType {
        switch mode {
        case .car:
            return .automobile
        case .bus, .metro:
            return .transit
        case .twoWheeler:
            return .walking
        case .walk:
            return .walking
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        destination = ""
        selectedDate = Date()
        selectedTime = Date()
        selectedTransportMode = .car
        selectedTrafficLevel = .moderate
        currentTrip = nil
        travelSummary = nil
        alternativeOptions = []
        errorMessage = nil
        searchSuggestions = []
    }
}

// MARK: - CLLocationManagerDelegate

extension TravelPlannerViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let userLocation = locations.last?.coordinate {
            let region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
            searchCompleter.region = region
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Location error: \(error.localizedDescription)"
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension TravelPlannerViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchSuggestions = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search error: \(error.localizedDescription)")
    }
}
