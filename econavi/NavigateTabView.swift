import SwiftUI
import CoreLocation
import MapKit
 
struct NavigateTabView: View {
    @Binding var origin: String
    @Binding var destination: String
    @Binding var showRoutes: Bool
    @Binding var selectedMode: String?
    @Binding var optimizationPrefs: RoutePreferences
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var routeService: RouteService
   
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    EmissionTipsCard()
                        .frame(minHeight: geometry.size.height * 0.5)
                }
                .padding()
            }
        }
    }
}
 
struct SearchCard: View {
    @Binding var origin: String
    @Binding var destination: String
    @Binding var originSuggestions: [PlaceSuggestion]
    @Binding var destinationSuggestions: [PlaceSuggestion]
    @Binding var showOriginSuggestions: Bool
    @Binding var showDestinationSuggestions: Bool
    @Binding var isLoadingLocation: Bool
    @ObservedObject var locationManager: LocationManager
    var onSearch: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Origin field
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading) {
                    TextField("Starting location", text: $origin)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: origin) { newValue in
                            if newValue.count >= 3 {
                                searchPlaces(query: newValue, isOrigin: true)
                            } else {
                                originSuggestions = []
                            }
                        }
                    
                    if showOriginSuggestions && !originSuggestions.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(originSuggestions) { suggestion in
                                    Button {
                                        origin = suggestion.displayName
                                        showOriginSuggestions = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "mappin.circle.fill")
                                            Text(suggestion.displayName)
                                                .font(.caption)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                Button {
                    useCurrentLocation(isOrigin: true)
                } label: {
                    Image(systemName: isLoadingLocation ? "hourglass" : "location.fill")
                        .foregroundColor(.blue)
                }
                .disabled(isLoadingLocation)
            }
            
            // Destination field
            HStack {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading) {
                    TextField("Where to?", text: $destination)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: destination) { newValue in
                            if newValue.count >= 3 {
                                searchPlaces(query: newValue, isOrigin: false)
                            } else {
                                destinationSuggestions = []
                            }
                        }
                    
                    if showDestinationSuggestions && !destinationSuggestions.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(destinationSuggestions) { suggestion in
                                    Button {
                                        destination = suggestion.displayName
                                        showDestinationSuggestions = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "mappin.circle.fill")
                                            Text(suggestion.displayName)
                                                .font(.caption)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
            Button(action: onSearch) {
                Label("Search Routes", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(origin.isEmpty || destination.isEmpty)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func useCurrentLocation(isOrigin: Bool) {
        isLoadingLocation = true
        locationManager.getCurrentLocation()
 
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard let location = locationManager.location else {
                isLoadingLocation = false
                return
            }
 
            let coordinate = location.coordinate
            let formatted = "Current Location"
 
            if isOrigin {
                origin = formatted
            } else {
                destination = formatted
            }
 
            isLoadingLocation = false
        }
    }
 
 
 
 
 
    
    private func searchPlaces(query: String, isOrigin: Bool) {
        // In a real app, you would use a geocoding API like MapKit's MKLocalSearch
        // For now, we'll use a simple mock
        let mockSuggestions = [
            PlaceSuggestion(displayName: "(query) Street, San Francisco", latitude: 37.7749, longitude: -122.4194),
            PlaceSuggestion(displayName: "(query) Avenue, San Francisco", latitude: 37.7849, longitude: -122.4094)
        ]
        
        if isOrigin {
            originSuggestions = mockSuggestions
            showOriginSuggestions = true
        } else {
            destinationSuggestions = mockSuggestions
            showDestinationSuggestions = true
        }
    }
}
 
struct RouteOptimizerCard: View {
    @Binding var preferences: RoutePreferences
    @Binding var prioritiesSet: Bool
    @Binding var showCompareRoutes: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Route Priorities", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        prioritiesSet = true
                        showCompareRoutes = true
                    }
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            PreferenceSlider(title: "Fastest Time", value: $preferences.time)
            PreferenceSlider(title: "Lowest Cost", value: $preferences.cost)
            PreferenceSlider(title: "Lowest Emissions", value: $preferences.emissions)
            
            Text("Adjust sliders to see routes that match your priorities.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    prioritiesSet = true
                    showCompareRoutes = true
                }
            } label: {
                Label("Compare Routes", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
 
struct CompareRoutesCard: View {
    @Binding var selectedMode: String?
    let optimizationPrefs: RoutePreferences
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var routeService: RouteService
    let destination: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compare Routes")
                .font(.headline)
            
            Text("Select your preferred route based on your priorities")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                routeOption("Walk", "figure.walk", "walk", .walking)
                routeOption("Bike", "bicycle", "bike", .walking)
                routeOption("Car", "car.fill", "car", .automobile)
                routeOption("Transit", "bus.fill", "transit", .transit)
            }
            
            if let selected = selectedMode {
                Text("Selected: (selected.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            
            if routeService.isCalculating {
                HStack {
                    ProgressView()
                    Text("Calculating route...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            
            if let route = routeService.route {
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.blue)
                        Text("(Int(route.expectedTravelTime / 60)) min")
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
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func routeOption(_ title: String, _ icon: String, _ value: String, _ transportType: MKDirectionsTransportType) -> some View {
        Button {
            withAnimation(.spring(response: 0.2)) {
                selectedMode = value
                calculateRoute(transportType: transportType)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(selectedMode == value ? .blue : .primary)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(selectedMode == value ? .blue : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedMode == value ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func calculateRoute(transportType: MKDirectionsTransportType) {
        guard let userLocation = locationManager.location else {
            locationManager.getCurrentLocation()
            return
        }
        
        // Geocode destination
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(destination) { placemarks, error in
            guard let placemark = placemarks?.first,
                  let destinationCoordinate = placemark.location?.coordinate else {
                return
            }
            
            DispatchQueue.main.async {
                routeService.calculateRoute(
                    from: userLocation.coordinate,
                    to: destinationCoordinate,
                    transportType: transportType
                )
            }
        }
    }
}
 
struct PreferenceSlider: View {
    let title: String
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("(Int(value))%")
                    .font(.caption.bold())
            }
            Slider(value: $value, in: 0...100, step: 5)
        }
    }
}
 
struct EmissionTipsCard: View {
    let tips: [EmissionTip] = [
        EmissionTip(title: "Bike Short Distances", description: "For trips under 5km, biking is faster than driving in urban areas and produces zero emissions.", impact: .high, icon: "🚴", savings: "Up to 1.1kg CO₂ per trip"),
        EmissionTip(title: "Use Public Transit", description: "Buses and trains produce 45-95% less CO₂ per passenger compared to single-occupancy vehicles.", impact: .high, icon: "🚌", savings: "175g CO₂ per 10km"),
        EmissionTip(title: "Walk When You Can", description: "Walking is the healthiest and greenest option for short trips. Aim for 10,000 steps daily!", impact: .medium, icon: "🚶", savings: "100% emissions free")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Emission Reduction Tips", systemImage: "leaf.fill")
                .font(.headline)
                .foregroundStyle(.green)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tips) { tip in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(tip.icon)
                                    .font(.title2)
                                Text(tip.title)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(tip.impact == .high ? "high" : tip.impact == .medium ? "medium" : "low")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(tip.impact == .high ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            Text(tip.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.green)
                                Text(tip.savings)
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
