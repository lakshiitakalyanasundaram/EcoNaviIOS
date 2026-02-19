import SwiftUI
import MapKit
import CoreLocation

/// Add Stop sheet: search (MKLocalSearch) + category shortcuts. Inserts selected place as waypoint and recalculates route.
struct AddStopSheetView: View {
    @Binding var isPresented: Bool
    @ObservedObject var navigationManager: NavigationManager
    @ObservedObject var routeService: RouteService
    @ObservedObject var locationManager: LocationManager

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let categories: [(name: String, query: String, icon: String, color: Color)] = [
        ("Dinner", "restaurant dinner food", "fork.knife", .orange),
        ("Petrol Pumps", "petrol pump gas station", "fuelpump.fill", .blue),
        ("Hospitals", "hospital", "cross.case.fill", .red),
        ("Coffee Shops", "coffee cafe", "cup.and.saucer.fill", .brown),
        ("Parking", "parking", "parkingsign", .blue),
        ("EV Charging", "EV charging electric vehicle", "bolt.car.fill", .green)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar with voice hint (system keyboard dictation available when focused)
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search for a place", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { runSearch(query: searchText) }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        runSearch(query: searchText)
                    } label: {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.secondary)
                            .font(.body)
                    }
                    .accessibilityLabel("Voice search")
                }
                .padding(12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if isSearching {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let msg = errorMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                List {
                    Section("Categories") {
                        ForEach(categories, id: \.name) { cat in
                            Button {
                                runSearch(query: cat.query)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: cat.icon)
                                        .foregroundStyle(cat.color)
                                        .frame(width: 28)
                                    Text(cat.name)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    if !searchResults.isEmpty {
                        Section("Results") {
                            ForEach(Array(searchResults.enumerated()), id: \.offset) { _, item in
                                Button {
                                    addStopAndRecalc(item)
                                    isPresented = false
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(.red)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name ?? "Unknown")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Text([item.placemark.thoroughfare, item.placemark.locality].compactMap { $0 }.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Add Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
            .onChange(of: searchText) { newValue in
                if newValue.count >= 2 {
                    runSearch(query: newValue)
                } else {
                    searchResults = []
                    errorMessage = nil
                }
            }
        }
    }

    private func runSearch(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        errorMessage = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = q
        if let loc = locationManager.location {
            request.region = MKCoordinateRegion(
                center: loc.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
            )
        }
        request.resultTypes = [.pointOfInterest, .address]
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            Task { @MainActor in
                isSearching = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    searchResults = []
                    return
                }
                searchResults = response?.mapItems ?? []
                if searchResults.isEmpty {
                    errorMessage = "No places found"
                }
            }
        }
    }

    private func addStopAndRecalc(_ item: MKMapItem) {
        guard let origin = locationManager.location?.coordinate,
              let dest = navigationManager.destinationCoordinate else { return }
        navigationManager.waypoints.append(item)
        let waypoints = navigationManager.waypoints
        routeService.calculateRouteWithWaypoints(
            origin: origin,
            waypoints: waypoints,
            destination: dest,
            transportType: navigationManager.transportMode.mapKitTransportType
        )
    }
}
