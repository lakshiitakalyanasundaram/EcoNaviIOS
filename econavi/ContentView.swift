import SwiftUI
import MapKit
import CoreLocation

// MARK: - ContentView
struct ContentView: View {

    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService = SearchService()
    @StateObject private var safetyManager = SafetyManager()
    @StateObject private var routeService = RouteService() // Shared route service
    @StateObject private var navigationManager = NavigationManager() // Shared navigation manager

    @State private var origin = "Current Location"
    @State private var destination = ""
    @State private var showRoutes = false
    @State private var selectedMode: String?
    @State private var optimizationPrefs = RoutePreferences()
    @State private var showSheet = false
    @State private var showSuggestions = false
    @State private var isInteractingWithSheet = false
    @State private var showSafetyView = false

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )

    var body: some View {
        ZStack {

            // MARK: COLOR-CODED MAP
            ColorCodedMapView(
                locationManager: locationManager,
                routeService: routeService,
                navigationManager: navigationManager
            )
            .ignoresSafeArea()

            // MARK: NAVIGATION OVERLAY (At the bottom)
            if navigationManager.isNavigating {
                VStack {
                    Spacer()
                    NavigationOverlay(
                        navigationManager: navigationManager,
                        routeService: routeService,
                        locationManager: locationManager,
                        onStop: {
                            // Stop navigation
                            navigationManager.stopNavigation()
                            locationManager.stopTracking()
                            
                            // Clear routes
                            routeService.clearRoute()
                            
                            // Recenter to current location
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                // Get fresh location and trigger recenter
                                locationManager.getCurrentLocation()
                                NotificationCenter.default.post(name: .recenterToCurrentLocation, object: nil)
                            }
                        }
                    )
                }
                .ignoresSafeArea(edges: .bottom)
                .zIndex(100) // Ensure it's above everything
            }

            // MARK: TOP SEARCH BAR + SUGGESTIONS
            VStack(alignment: .leading, spacing: 12) {
                // Search Bar
                HStack(spacing: 12) {
                    Button { showSheet = true } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("Search places", text: $destination)
                            .font(.system(size: 16))
                            .onChange(of: destination) { newValue in
                                // Only show suggestions if not interacting with sheet and destination is being typed
                                if !isInteractingWithSheet && newValue.count >= 2 {
                                    searchService.updateQuery(newValue)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showSuggestions = true
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.2)) {
                                        showSuggestions = false
                                    }
                                }
                            }
                        
                        if !destination.isEmpty {
                            Button {
                                destination = ""
                                withAnimation(.spring(response: 0.2)) {
                                    showSuggestions = false
                                }
                                searchService.clear()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)

                    Button {
                        showSafetyView = true
                    } label: {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Suggestions (only show when not interacting with sheet)
                if showSuggestions && !searchService.results.isEmpty && !isInteractingWithSheet {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(searchService.results.enumerated()), id: \.element.id) { index, result in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        destination = result.title
                                        showSuggestions = false
                                        showRoutes = true
                                        isInteractingWithSheet = true
                                    }
                                    searchService.clear()
                                    showSheet = true
                                } label: {
                                    HStack(spacing: 14) {
                                        // Icon with background
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                                .frame(width: 40, height: 40)
                                            
                                            Image(systemName: index < 3 ? "star.fill" : "mappin.circle.fill")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundStyle(index < 3 ? Color.orange : Color.blue)
                                        }

                                        // Text content
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.title)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        Spacer()

                                        // Distance badge
                                        if result.distance > 0 {
                                            HStack(spacing: 4) {
                                                Image(systemName: "location.fill")
                                                    .font(.system(size: 10))
                                                Text(result.distance < 1000 ? "\(Int(result.distance))m" : String(format: "%.1f km", result.distance / 1000))
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.systemGray6), in: Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < searchService.results.count - 1 {
                                    Divider()
                                        .padding(.leading, 70)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: min(400, CGFloat(searchService.results.count) * 70))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }

        // MARK: SAFETY VIEW
        .sheet(isPresented: $showSafetyView) {
            SafetyView(
                safetyManager: safetyManager,
                locationManager: locationManager,
                isPresented: $showSafetyView
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        
        // MARK: BOTTOM SHEET
        .sheet(isPresented: $showSheet) {
            SidebarView(
                origin: $origin,
                destination: $destination,
                showRoutes: $showRoutes,
                selectedMode: $selectedMode,
                optimizationPrefs: $optimizationPrefs,
                locationManager: locationManager,
                routeService: routeService,
                onClose: { 
                    showSheet = false
                    isInteractingWithSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.clear)
            .onAppear {
                isInteractingWithSheet = true
                withAnimation(.spring(response: 0.2)) {
                    showSuggestions = false
                }
            }
            .onDisappear {
                isInteractingWithSheet = false
            }
        }

        .onAppear {
            locationManager.requestPermission()
            locationManager.getCurrentLocation()
        }

        .onChange(of: locationManager.location) {
            if let loc = locationManager.location {
                region.center = loc.coordinate
                searchService.updateUserLocation(loc)
            }
        }
    }
}
struct SidebarView: View {

    @Binding var origin: String
    @Binding var destination: String
    @Binding var showRoutes: Bool
    @Binding var selectedMode: String?
    @Binding var optimizationPrefs: RoutePreferences
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var routeService: RouteService
    var onClose: (() -> Void)?

    @State private var selectedTab: SidebarTab = .navigate

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 12) {

                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 40, height: 5)

                Picker("", selection: $selectedTab) {
                    Text("Navigate").tag(SidebarTab.navigate)
                    Text("Shipment").tag(SidebarTab.shipment)
                    Text("Track").tag(SidebarTab.track)
                    Text("Rewards").tag(SidebarTab.rewards)
                }
                .pickerStyle(.segmented)
                .padding()

                TabView(selection: $selectedTab) {
                    NavigateTabView(
                        origin: $origin,
                        destination: $destination,
                        showRoutes: $showRoutes,
                        selectedMode: $selectedMode,
                        optimizationPrefs: $optimizationPrefs,
                        locationManager: locationManager,
                        routeService: routeService
                    )
                    .tag(SidebarTab.navigate)

                    ShipmentTabView().tag(SidebarTab.shipment)
                    TrackTabView().tag(SidebarTab.track)
                    RewardsTabView().tag(SidebarTab.rewards)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }
}
struct RouteComparisonSheet: View {
    @Binding var selectedMode: String?
    let optimizationPrefs: RoutePreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compare Routes")
                .font(.headline)

            HStack {
                route("Walk", "figure.walk", "walk")
                route("Bike", "bicycle", "bike")
                route("Car", "car.fill", "car")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func route(_ title: String, _ icon: String, _ value: String) -> some View {
        Button {
            selectedMode = value
        } label: {
            VStack {
                Image(systemName: icon)
                Text(title)
                    .font(.caption)
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}


