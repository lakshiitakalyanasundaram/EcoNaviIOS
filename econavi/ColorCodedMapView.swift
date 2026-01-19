import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Notification
extension Notification.Name {
    static let navigationLocationUpdated =
        Notification.Name("navigationLocationUpdated")
    static let recenterToCurrentLocation =
        Notification.Name("recenterToCurrentLocation")
}

// MARK: - MAIN VIEW
struct ColorCodedMapView: View {

    @ObservedObject var locationManager: LocationManager
    @ObservedObject var routeService: RouteService
    @ObservedObject var navigationManager: NavigationManager

    @StateObject private var placeSearchService = PlaceSearchService()

    @State private var selectedPlaceType: PlaceType?
    @State private var selectedPlace: MapPlace?

    @State private var showPlaceDetail = false
    @State private var showPins = true
    @State private var hasCenteredInitially = false
    @State private var showStartLocationDialog = false
    @State private var showTransportSelection = false
    @State private var useCurrentLocationAsStart = true
    @State private var selectedTransportMode: TransportMode = .walk

    @State private var recenterTrigger = UUID()

    var body: some View {
        ZStack {

            // MAP
            EnhancedMapView(
                places: showPins ? placeSearchService.places : [],
                selectedPlace: $selectedPlace,
                recenterTrigger: recenterTrigger,
                userLocation: locationManager.location,
                route: routeService.route,
                isNavigating: navigationManager.isNavigating,
                onPlaceTapped: { place in
                    selectedPlace = place
                    showStartLocationDialog = true
                }
            )
            .ignoresSafeArea()

            // SIDE PANEL
            VStack {
                Spacer()
                SidePanelView(
                    selectedType: $selectedPlaceType,
                    isSearching: placeSearchService.isSearching,
                    showPins: $showPins,
                    onPlaceTypeSelected: handlePlaceTypeSelection
                )
                .padding(.init(top: 0, leading: 16, bottom: 100, trailing: 0))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // START LOCATION DIALOG
            if showStartLocationDialog, let place = selectedPlace {
                StartLocationDialog(
                    place: place,
                    isPresented: $showStartLocationDialog,
                    useCurrentLocation: $useCurrentLocationAsStart,
                    onConfirm: {
                        showStartLocationDialog = false
                        showTransportSelection = true
                    }
                )
            }

            // TRANSPORT SELECTION
            if showTransportSelection, let place = selectedPlace {
                TransportSelectionView(
                    place: place,
                    userLocation: locationManager.location,
                    routeService: routeService,
                    isPresented: $showTransportSelection,
                    selectedMode: $selectedTransportMode,
                    onRouteCalculated: {
                        showTransportSelection = false
                        showPlaceDetail = true
                    }
                )
            }

            // PLACE DETAIL
            if showPlaceDetail, let place = selectedPlace {
                VStack {
                    Spacer()
                    PlaceDetailView(
                        place: place,
                        userLocation: locationManager.location,
                        route: routeService.route,
                        routeService: routeService,
                        navigationManager: navigationManager,
                        locationManager: locationManager,
                        selectedTransportMode: $selectedTransportMode,
                        isPresented: $showPlaceDetail
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            locationManager.requestPermission()
            // Request location immediately
            locationManager.getCurrentLocation()
            
            // Also try to get location after a short delay in case permission wasn't granted yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if locationManager.location == nil {
                    locationManager.getCurrentLocation()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .recenterToCurrentLocation)) { _ in
            recenterTrigger = UUID()
        }
        .onChange(of: locationManager.location) { loc in
            // Center to location when first received
            if let location = loc, !hasCenteredInitially {
                hasCenteredInitially = true
                // Trigger recenter immediately and also after a delay to ensure map is ready
                recenterTrigger = UUID()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    recenterTrigger = UUID()
                }
            }

            if let location = loc, navigationManager.isNavigating {
                navigationManager.updateLocation(location)
                NotificationCenter.default.post(
                    name: .navigationLocationUpdated,
                    object: location
                )
            }
        }
        .onChange(of: locationManager.authorizationStatus) { status in
            // When permission is granted, get location and center
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && !hasCenteredInitially {
                locationManager.getCurrentLocation()
            }
        }
    }

    private func handlePlaceTypeSelection(_ placeType: PlaceType) {
        if selectedPlaceType != placeType {
            placeSearchService.clearPlaces()
            selectedPlace = nil
        }

        selectedPlaceType = placeType

        guard let userLocation = locationManager.location else {
            locationManager.getCurrentLocation()
            return
        }

        placeSearchService.searchPlaces(
            type: placeType,
            location: userLocation
        )
    }
}

//////////////////////////////////////////////////////////////
// MARK: - MAP VIEW
//////////////////////////////////////////////////////////////

struct EnhancedMapView: UIViewRepresentable {

    let places: [MapPlace]
    @Binding var selectedPlace: MapPlace?
    let recenterTrigger: UUID
    let userLocation: CLLocation?
    let route: MKRoute?
    let isNavigating: Bool
    let onPlaceTapped: (MapPlace) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        context.coordinator.mapView = mapView
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Disable MapKit's default POI icons so our custom pins show correctly
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsPointsOfInterest = false
        
        // Set initial region to a default location (will be updated when user location is available)
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946), // Default to Bangalore
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
        mapView.setRegion(defaultRegion, animated: false)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.followUser(_:)),
            name: .navigationLocationUpdated,
            object: nil
        )

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {

        updateAnnotations(on: mapView)
        updateRoute(on: mapView)

        // LOCK GESTURES DURING NAVIGATION (but allow zoom)
        mapView.isScrollEnabled = !isNavigating
        mapView.isRotateEnabled = !isNavigating
        mapView.isPitchEnabled = !isNavigating
        // Allow zoom during navigation for better user control
        mapView.isZoomEnabled = true

        // Handle recenter trigger
        if context.coordinator.lastRecenterTrigger != recenterTrigger {
            context.coordinator.lastRecenterTrigger = recenterTrigger
            // Ensure we have a location before recentering
            if userLocation != nil {
                recenter(mapView)
            } else if let userLoc = mapView.userLocation.location {
                // Fallback to map's user location if available
                let region = MKCoordinateRegion(
                    center: userLoc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                mapView.setRegion(region, animated: true)
            }
        }

        // Handle navigation mode changes - only update when actually changing
        let newTrackingMode: MKUserTrackingMode = isNavigating ? .followWithHeading : .none
        if mapView.userTrackingMode != newTrackingMode {
            // Use a flag to prevent multiple rapid changes
            if !context.coordinator.isChangingTrackingMode {
                context.coordinator.isChangingTrackingMode = true
                mapView.userTrackingMode = newTrackingMode
                
                // Reset route bounds flag when starting navigation
                if isNavigating {
                    context.coordinator.hasSetRouteBounds = false
                    // Set initial route bounds only once when navigation starts
                    if let route = route {
                        let routeId = "\(route.distance)-\(route.expectedTravelTime)"
                        if context.coordinator.lastRouteIdentifier != routeId {
                            context.coordinator.lastRouteIdentifier = routeId
                            context.coordinator.hasSetRouteBounds = true
                            
                            // Set route bounds with proper padding for bottom navigation overlay
                            let rect = route.polyline.boundingMapRect
                            mapView.setVisibleMapRect(
                                rect,
                                edgePadding: UIEdgeInsets(top: 140, left: 40, bottom: 200, right: 40),
                                animated: true
                            )
                        }
                    }
                } else {
                    // Clear route tracking when not navigating
                    context.coordinator.lastRouteIdentifier = nil
                    context.coordinator.hasSetRouteBounds = false
                }
                
                // Reset flag after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    context.coordinator.isChangingTrackingMode = false
                }
            }
        }

        // Only fit pins when not navigating and not already centered
        // Also prevent fitting during navigation to avoid conflicts
        if !isNavigating && !context.coordinator.isChangingTrackingMode && context.coordinator.lastRecenterTrigger == recenterTrigger {
            fitPinsIfNeeded(mapView)
        }
    }

    private func updateRoute(on mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        if let route = route {
            mapView.addOverlay(route.polyline)
        }
    }

    private func recenter(_ mapView: MKMapView) {
        guard let location = userLocation else {
            // Fallback: try to use map's user location
            if let userLoc = mapView.userLocation.location {
                let region = MKCoordinateRegion(
                    center: userLoc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                mapView.setRegion(region, animated: true)
            }
            return
        }
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
    }

    private func fitPinsIfNeeded(_ mapView: MKMapView) {
        let annotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        guard !annotations.isEmpty else { return }

        var rect = MKMapRect.null
        for a in annotations {
            let p = MKMapPoint(a.coordinate)
            rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 0.01, height: 0.01))
        }

        // Only update if the rect is significantly outside the visible area
        let visibleRect = mapView.visibleMapRect
        let intersection = visibleRect.intersection(rect)
        let intersectionArea = intersection.width * intersection.height
        let rectArea = rect.width * rect.height
        
        // If less than 80% of the pins rect is visible, update the map
        if intersectionArea < rectArea * 0.8 {
            mapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 120, left: 80, bottom: 160, right: 80),
                animated: true
            )
        }
    }

    private func updateAnnotations(on mapView: MKMapView) {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        mapView.addAnnotations(places.map { ColoredAnnotation(place: $0) })
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: EnhancedMapView
        weak var mapView: MKMapView?
        var lastRecenterTrigger: UUID?
        var lastRouteIdentifier: String?
        var lastLocationUpdate: Date?
        var hasSetRouteBounds = false
        var isChangingTrackingMode = false

        init(_ parent: EnhancedMapView) {
            self.parent = parent
        }

        @objc func followUser(_ note: Notification) {
            guard
                parent.isNavigating,
                let location = note.object as? CLLocation,
                let mapView = mapView
            else { return }

            // Throttle location updates to prevent excessive map updates
            let now = Date()
            if let lastUpdate = lastLocationUpdate, now.timeIntervalSince(lastUpdate) < 2.0 {
                return
            }
            lastLocationUpdate = now

            // When using userTrackingMode.followWithHeading, MapKit handles following automatically
            // Don't manually interfere with region updates to prevent zoom loops
            // Only update if tracking mode is somehow not active (shouldn't happen during navigation)
            if mapView.userTrackingMode == .none && !isChangingTrackingMode {
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
                mapView.setRegion(region, animated: true)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Skip user location
            if annotation is MKUserLocation { return nil }
            
            guard let coloredAnnotation = annotation as? ColoredAnnotation else { return nil }
            
            let identifier = "ColoredPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // Configure marker with place type color and icon
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = UIColor(coloredAnnotation.place.placeType.color)
                // Force custom icon instead of MapKit's default POI icons
                if let iconImage = UIImage(systemName: coloredAnnotation.place.placeType.icon) {
                    markerView.glyphImage = iconImage
                    markerView.glyphTintColor = .white
                } else {
                    // Fallback to default icon if system icon not found
                    markerView.glyphImage = nil
                    markerView.glyphText = String(coloredAnnotation.place.placeType.icon.prefix(1))
                }
                markerView.displayPriority = .required
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let a = view.annotation as? ColoredAnnotation else { return }
            parent.onPlaceTapped(a.place)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let r = MKPolylineRenderer(overlay: overlay)
            r.strokeColor = .systemBlue
            r.lineWidth = 5
            return r
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: - ANNOTATION
//////////////////////////////////////////////////////////////

class ColoredAnnotation: NSObject, MKAnnotation {
    let place: MapPlace
    var coordinate: CLLocationCoordinate2D { place.coordinate }
    var title: String? { place.name }
    init(place: MapPlace) { self.place = place }
}

//////////////////////////////////////////////////////////////
// MARK: - SIDE PANEL
//////////////////////////////////////////////////////////////

struct SidePanelView: View {
    @Binding var selectedType: PlaceType?
    let isSearching: Bool
    @Binding var showPins: Bool
    let onPlaceTypeSelected: (PlaceType) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation {
                    showPins.toggle()
                }
            } label: {
                Image(systemName: showPins ? "eye.fill" : "eye.slash.fill")
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if showPins {
                ForEach(PlaceType.allCases) { type in
                    Button {
                        onPlaceTypeSelected(type)
                    } label: {
                        Image(systemName: type.icon)
                            .frame(width: 44, height: 44)
                            .background(type.color)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: - START LOCATION DIALOG
//////////////////////////////////////////////////////////////

struct StartLocationDialog: View {
    let place: MapPlace
    @Binding var isPresented: Bool
    @Binding var useCurrentLocation: Bool
    
    let onConfirm: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                Text("Start Navigation?")
                    .font(.title2.bold())
                
                Text("Do you want to start from your current location?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Toggle("Use Current Location", isOn: $useCurrentLocation)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Continue") {
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(40)
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: - TRANSPORT SELECTION
//////////////////////////////////////////////////////////////

struct TransportSelectionView: View {
    let place: MapPlace
    let userLocation: CLLocation?
    @ObservedObject var routeService: RouteService
    @Binding var isPresented: Bool
    @Binding var selectedMode: TransportMode
    @State private var internalSelectedMode: TransportMode?
    
    let onRouteCalculated: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                Text("Select Transport Mode")
                    .font(.title2.bold())
                
                Text(place.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(TransportMode.allCases) { mode in
                        TransportModeButton(
                            mode: mode,
                            isSelected: internalSelectedMode == mode,
                            action: {
                                internalSelectedMode = mode
                                selectedMode = mode
                                calculateRoute(for: mode)
                            }
                        )
                    }
                }
                
                if routeService.isCalculating {
                    ProgressView("Calculating route...")
                        .padding()
                }
                
                if let error = routeService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(40)
            .onChange(of: routeService.route) { route in
                if route != nil && !routeService.isCalculating {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onRouteCalculated()
                    }
                }
            }
        }
    }
    
    private func calculateRoute(for mode: TransportMode) {
        guard let userLocation = userLocation else { return }
        
        routeService.calculateRoute(
            from: userLocation.coordinate,
            to: place.coordinate,
            transportType: mode.mapKitTransportType
        )
    }
}

struct TransportModeButton: View {
    let mode: TransportMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(isSelected ? .white : mode.color)
                
                Text(mode.displayName)
                    .font(.caption.bold())
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? mode.color : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? mode.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

//////////////////////////////////////////////////////////////
// MARK: - PLACE DETAIL
//////////////////////////////////////////////////////////////

struct PlaceDetailView: View {
    let place: MapPlace
    let userLocation: CLLocation?
    let route: MKRoute?
    @ObservedObject var routeService: RouteService
    @ObservedObject var navigationManager: NavigationManager
    @ObservedObject var locationManager: LocationManager
    @Binding var selectedTransportMode: TransportMode
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(place.placeType.color)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: place.placeType.icon)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                    
                    if let address = place.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let route = route {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.blue)
                        Text("\(Int(route.expectedTravelTime / 60)) min")
                            .font(.subheadline.bold())
                    }
                    
                    HStack {
                        Image(systemName: "ruler.fill")
                            .foregroundStyle(.green)
                        Text(String(format: "%.1f km", route.distance / 1000))
                            .font(.subheadline.bold())
                    }
                }
            }
            
            Button {
                if let route = route {
                    startNavigation()
                } else {
                    // If no route, calculate with default walking mode
                    calculateRouteForPlace()
                }
            } label: {
                Label(
                    route != nil ? "Start Navigation" : "Calculate Route",
                    systemImage: route != nil ? "arrow.triangle.turn.up.right.diamond.fill" : "map.fill"
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(route != nil ? place.placeType.color : Color.gray)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(routeService.isCalculating)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding()
    }
    
    private func startNavigation() {
        // Wait for route if still calculating
        if routeService.isCalculating {
            return
        }
        
        guard let route = routeService.route, let userLocation = userLocation else {
            // If no route, try to calculate it first
            calculateRouteForPlace()
            return
        }
        
        // Close detail view first with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
        
        // Start location tracking and navigation after a brief delay to allow view to close
        // Use a longer delay to ensure UI is fully settled and prevent glitches
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Ensure we have a valid route and location before starting
            guard let currentRoute = self.routeService.route,
                  let currentLocation = self.locationManager.location else {
                return
            }
            
            // Use the selected transport mode
            self.locationManager.startTracking()
            self.navigationManager.startNavigation(route: currentRoute, userLocation: currentLocation, transportMode: self.selectedTransportMode)
        }
    }
    
    private func calculateRouteForPlace() {
        guard let userLocation = userLocation else {
            locationManager.getCurrentLocation()
            // Try again after location is available
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                calculateRouteForPlace()
            }
            return
        }
        
        // Use walking as default transport type
        routeService.calculateRoute(
            from: userLocation.coordinate,
            to: place.coordinate,
            transportType: .walking
        )
        
        // Wait for route calculation, then start navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if routeService.route != nil {
                startNavigation()
            }
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: - NAVIGATION OVERLAY
//////////////////////////////////////////////////////////////

struct NavigationOverlay: View {
    @ObservedObject var navigationManager: NavigationManager
    @ObservedObject var routeService: RouteService
    @ObservedObject var locationManager: LocationManager
    let onStop: () -> Void
    
    private var carbonEmissions: Double {
        navigationManager.calculateCarbonEmissions()
    }
    
    private var etaString: String {
        guard let eta = navigationManager.estimatedArrivalTime else {
            return "Calculating..."
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: eta)
    }
    
    var body: some View {
        // Bottom navigation bar with improved UI/UX
        VStack(spacing: 0) {
            // Main instruction and info
            HStack(spacing: 16) {
                // Transport mode icon
                ZStack {
                    Circle()
                        .fill(navigationManager.transportMode.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: navigationManager.transportMode.icon)
                        .font(.title3)
                        .foregroundColor(navigationManager.transportMode.color)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Instruction
                    if let instruction = navigationManager.currentInstruction {
                        Text(instruction)
                            .font(.headline.bold())
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    } else {
                        Text("Continue for \(navigationManager.distanceRemaining < 1000 ? "\(Int(navigationManager.distanceRemaining))m" : String(format: "%.1f km", navigationManager.distanceRemaining / 1000))")
                            .font(.headline.bold())
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    }
                    
                    // Distance and time
                    HStack(spacing: 16) {
                        if navigationManager.distanceRemaining > 0 {
                            Label(
                                navigationManager.distanceRemaining < 1000
                                    ? "\(Int(navigationManager.distanceRemaining))m"
                                    : String(format: "%.1f km", navigationManager.distanceRemaining / 1000),
                                systemImage: "arrow.up"
                            )
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        }
                        
                        if navigationManager.timeRemaining > 0 {
                            Label(
                                "\(Int(navigationManager.timeRemaining / 60)) min",
                                systemImage: "clock.fill"
                            )
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Stop button
                Button {
                    onStop()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // ETA and Carbon Emissions
            HStack(spacing: 20) {
                // ETA
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ETA")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(etaString)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                // Carbon Emissions
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Carbon")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(EmissionsCalculatorIndia.formatEmissions(carbonEmissions))
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

