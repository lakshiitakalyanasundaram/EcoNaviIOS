import SwiftUI
import MapKit
import CoreLocation

/// Bottom sheet shown after a destination is selected (search / map tap / saved place).
@MainActor
struct DirectionsSheetView: View {
    let destinationName: String
    let destinationCoordinate: CLLocationCoordinate2D

    @ObservedObject var locationManager: LocationManager
    @ObservedObject var navigationManager: NavigationManager
    @ObservedObject var routeService: RouteService

    @Binding var isPresented: Bool

    @State private var selectedMode: TransportMode = .car
    @State private var currentRoute: MKRoute?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            // Travel modes
            HStack(spacing: 12) {
                ForEach([TransportMode.car, .walk, .bike]) { mode in
                    Button {
                        selectedMode = mode
                        recalcRoute()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mode.icon)
                            Text(mode.displayName)
                                .font(.caption2)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(selectedMode == mode ? mode.color.opacity(0.15) : Color(.systemBackground))
                        .foregroundColor(selectedMode == mode ? mode.color : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            Group {
                if isLoading {
                    ProgressView("Finding route…")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let route = currentRoute {
                    summaryCard(for: route)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                } else {
                    Text("Select a mode to get directions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button {
                guard let route = currentRoute else { return }
                routeService.route = route
                navigationManager.startNavigationSession(route: route,
                                                        locationManager: locationManager,
                                                        transportMode: selectedMode)
                isPresented = false
            } label: {
                Text("GO")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(currentRoute == nil ? Color.gray.opacity(0.4) : Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(currentRoute == nil)
        }
        .padding([.horizontal, .bottom])
        .task {
            recalcRoute()
        }
    }

    private func summaryCard(for route: MKRoute) -> some View {
        let distanceKm = route.distance / 1000.0
        let durationMinutes = Int(route.expectedTravelTime / 60)
        let etaDate = Date().addingTimeInterval(route.expectedTravelTime)
        let emissions = EmissionsCalculatorIndia.calculateEmissions(
            mode: selectedMode.rawValue,
            distanceKm: distanceKm
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(durationMinutes) min")
                        .font(.title2.bold())
                    Text(DateFormatter.localizedString(from: etaDate,
                                                       dateStyle: .none,
                                                       timeStyle: .short))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f km", distanceKm))
                        .font(.headline)
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                        Text(String(format: "%.0f g CO₂", emissions))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(destinationName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func recalcRoute() {
        guard let origin = locationManager.location?.coordinate else {
            errorMessage = "Current location unavailable."
            currentRoute = nil
            return
        }

        isLoading = true
        errorMessage = nil
        currentRoute = nil

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
        request.transportType = selectedMode.mapKitTransportType
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.currentRoute = nil
                    return
                }
                guard let route = response?.routes.first else {
                    self.errorMessage = "No route found."
                    self.currentRoute = nil
                    return
                }
                self.currentRoute = route
                self.navigationManager.prepareRoute(route: route, mode: self.selectedMode)
            }
        }
    }
}

