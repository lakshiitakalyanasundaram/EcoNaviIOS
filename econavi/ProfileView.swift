import SwiftUI
import MapKit
import CoreLocation
import Combine
import PhotosUI

struct ProfileView: View {
    @Binding var isPresented: Bool

    // Lightweight auth (demo) persisted across app launches
    @AppStorage("auth.isSignedIn") private var isSignedIn = false
    @AppStorage("auth.email") private var signedInEmail = ""
    @AppStorage("auth.displayName") private var signedInName = "Guest"

    @State private var showSignIn = false

    @State private var savedPlacesCount = 0
    @State private var currentPreference = "Driving"
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProfileHeaderRow(
                        name: isSignedIn ? signedInName : "Not signed in",
                        email: isSignedIn ? signedInEmail : "Sign in to sync places, reports, and preferences",
                        initials: initials(from: isSignedIn ? signedInName : "Guest")
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    NavigationLink(destination: PlacesView(savedPlacesCount: $savedPlacesCount)) {
                        ProfileRow(icon: "square.stack.fill", iconColor: .purple, title: "Places") {
                            Text("\(savedPlacesCount)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink(destination: ReportsView()) {
                        ProfileRow(icon: "exclamationmark.bubble.fill", iconColor: .red, title: "Reports")
                    }

                    NavigationLink(destination: OfflineMapsView()) {
                        ProfileRow(icon: "arrow.down.circle.fill", iconColor: .gray, title: "Offline Maps") {
                            Text("Download")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink(destination: PreferencesView(currentPreference: $currentPreference)) {
                        ProfileRow(icon: "slider.horizontal.3", iconColor: .gray, title: "Preferences") {
                            Text(currentPreference)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    if isSignedIn {
                        Button(role: .destructive) {
                            isSignedIn = false
                            signedInEmail = ""
                            signedInName = "Guest"
                        } label: {
                            Text("Sign Out")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } else {
                        Button {
                            showSignIn = true
                        } label: {
                            Text("Sign In")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .fullScreenCover(isPresented: $showSignIn) {
                SignInView(
                    isPresented: $showSignIn,
                    onSignIn: { email, password in
                        // Demo auth: accept any non-empty credentials
                        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              !password.isEmpty
                        else { return }
                        isSignedIn = true
                        signedInEmail = email
                        signedInName = displayName(fromEmail: email)
                        showSignIn = false
                    }
                )
            }
        }
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").compactMap { $0.first }.map(String.init)
        if parts.isEmpty { return "G" }
        return parts.prefix(2).joined().uppercased()
    }

    private func displayName(fromEmail email: String) -> String {
        let base = email.split(separator: "@").first.map(String.init) ?? "User"
        if base.isEmpty { return "User" }
        // Capitalize first letter for a nicer “native” feel
        return base.prefix(1).uppercased() + base.dropFirst()
    }
}

// MARK: - Profile (Apple Maps-style) Building Blocks

private struct ProfileHeaderRow: View {
    let name: String
    let email: String
    let initials: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 86, height: 86)

                Text(initials)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 18)

            Text(name)
                .font(.title2.bold())

            Text(email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // subtle spacing like Apple’s profile card
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(icon: String, iconColor: Color, title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28)

            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            trailing()
        }
    }
}

// MARK: - Offline Maps Flow (Apple Maps-inspired)

private struct OfflineMapRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var downloadedMB: Double
    var totalMB: Double
    var lastUpdated: String

    init(id: UUID = UUID(), name: String, downloadedMB: Double, totalMB: Double, lastUpdated: String) {
        self.id = id
        self.name = name
        self.downloadedMB = downloadedMB
        self.totalMB = totalMB
        self.lastUpdated = lastUpdated
    }
}

@MainActor
private final class OfflineMapsStore: ObservableObject {
    @Published var maps: [OfflineMapRecord] = []

    private let storageKey = "offlineMaps.records.v1"

    init() {
        load()
    }

    func addDownload(for placeName: String) {
        let total = Double.random(in: 250...520).rounded(toPlaces: 1)
        let record = OfflineMapRecord(
            name: placeName,
            downloadedMB: 0,
            totalMB: total,
            lastUpdated: "Downloading…"
        )
        maps.insert(record, at: 0)
        save()
        simulateDownload(for: record.id)
    }

    private func simulateDownload(for id: UUID) {
        guard let idx = maps.firstIndex(where: { $0.id == id }) else { return }

        let total = maps[idx].totalMB
        // simulate ~4–8 seconds
        let steps = Int.random(in: 18...28)
        let increment = total / Double(steps)

        Task { [weak self] in
            guard let self else { return }
            for _ in 0..<steps {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let i = self.maps.firstIndex(where: { $0.id == id }) else { return }
                self.maps[i].downloadedMB = min(total, self.maps[i].downloadedMB + increment)
                self.save()
            }
            guard let i = self.maps.firstIndex(where: { $0.id == id }) else { return }
            self.maps[i].downloadedMB = total
            self.maps[i].lastUpdated = "Just now"
            self.save()
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([OfflineMapRecord].self, from: data) {
            maps = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(maps) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}

@MainActor
private final class OfflineMapSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = Array(completer.results.prefix(12))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

private struct OfflineMapsView: View {
    @StateObject private var store = OfflineMapsStore()
    @State private var showDownloadNewMap = false

    var body: some View {
        List {
            Section {
                if store.maps.isEmpty {
                    Text("No Offline Maps")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.maps) { map in
                        NavigationLink(destination: OfflineMapDetailView(map: map)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(map.name)
                                    .font(.headline)
                                Text(String(format: "%.1f MB of %.1f MB", map.downloadedMB, map.totalMB))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    showDownloadNewMap = true
                } label: {
                    Text("Download New Map")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Section("Settings") {
                NavigationLink(destination: OfflineMapsSettingsView()) {
                    HStack {
                        Text("Downloads")
                        Spacer()
                        Text("Wi‑Fi Only")
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Automatic Updates", isOn: .constant(true))
                Toggle("Optimise Storage", isOn: .constant(false))
                Toggle("Only Use Offline Maps", isOn: .constant(false))
                    .disabled(true) // mirrors disabled look in screenshot
            }
        }
        .navigationTitle("Offline Maps")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showDownloadNewMap) {
            DownloadNewMapView(
                isPresented: $showDownloadNewMap,
                onDownload: { placeName in
                    store.addDownload(for: placeName)
                }
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct DownloadNewMapView: View {
    @Binding var isPresented: Bool
    let onDownload: (String) -> Void
    @StateObject private var searchService = OfflineMapSearchService()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search city", text: $searchService.query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                        Spacer()
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                if !searchService.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        ForEach(searchService.results, id: \.self) { completion in
                            Button {
                                let name = [completion.title, completion.subtitle]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " ")
                                onDownload(completion.title)
                                isPresented = false
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .foregroundStyle(.primary)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Download New Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(.regularMaterial, in: Circle())
                    }
                }
            }
        }
    }
}

private struct OfflineMapDetailView: View {
    let map: OfflineMapRecord
    @State private var rename = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 12)

            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 220, height: 160)
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Label("Resize", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                                .padding(12)
                        }
                    }
                )

            Text(map.name)
                .font(.title2.bold())
            Text(String(format: "%.1f MB", map.totalMB))
                .foregroundStyle(.secondary)

            Button("Rename") {
                rename = true
            }
            .buttonStyle(.bordered)

            VStack(alignment: .leading, spacing: 6) {
                Text("Gunjan’s iPhone")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Map Updated")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                    Text(map.lastUpdated)
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)

            Button(role: .destructive) {
                // demo
            } label: {
                Text("Delete Map")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.horizontal)

            Text("This map may have been downloaded outside the region it depicts and isn’t intended for use in all regions. When you enter or leave the region, connect to the internet to ensure you’re using the map intended for the region you’re in.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename", isPresented: $rename) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Rename is a placeholder in this demo UI.")
        }
    }
}

private struct OfflineMapsSettingsView: View {
    var body: some View {
        Form {
            Section("Downloads") {
                Picker("Downloads", selection: .constant("Wi‑Fi Only")) {
                    Text("Wi‑Fi Only").tag("Wi‑Fi Only")
                    Text("Wi‑Fi & Cellular").tag("Wi‑Fi & Cellular")
                }
            }
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reports Flow (Apple Maps-inspired)

private enum ReportIssueType: String, CaseIterable, Identifiable {
    case reportSomethingMissing = "Report Something Missing"
    case reportStreetIssue = "Report Street Issue"
    case reportPlaceIssue = "Report Place Issue"
    case reportRouteIssue = "Report Route Issue"
    case reportIncident = "Report an Incident"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .reportSomethingMissing: return "magnifyingglass.circle"
        case .reportStreetIssue: return "signpost.right.fill"
        case .reportPlaceIssue: return "mappin.and.ellipse"
        case .reportRouteIssue: return "point.topleft.down.curvedto.point.bottomright.up"
        case .reportIncident: return "exclamationmark.triangle"
        }
    }
}

private struct ReportsView: View {
    @State private var showReportSheet = false
    @State private var selectedIssue: ReportIssueType?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
                Spacer()
                Text("No Reports")
                    .font(.title2.bold())
                Text("You can report a street issue, place issue, route issue by tapping “Report a New Issue”. Issues you report will appear here.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
                Spacer()
            }

            Button {
                showReportSheet = true
            } label: {
                Label("Report a New Issue", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Report", isPresented: $showReportSheet, titleVisibility: .hidden) {
            ForEach(ReportIssueType.allCases) { issue in
                Button(issue.rawValue) { selectedIssue = issue }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $selectedIssue) { issue in
            ReportFlowRootView(issue: issue)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Reports Flow (multi-step, Apple Maps-style)

private enum ReportPlaceIssueOption: String, CaseIterable, Identifiable {
    case nameWrong = "Name is wrong"
    case addressWrong = "Address or location on map is wrong"
    case phoneWrong = "Phone number or website is wrong"
    case hoursWrong = "Hours are wrong"
    case closed = "It is closed"
    case categoryWrong = "Category is wrong"
    case other = "Other or multiple things are wrong"
    var id: String { rawValue }
}

private enum IncidentType: String, CaseIterable, Identifiable {
    case crash = "Crash"
    case speedCheck = "Speed Check"
    case traffic = "Traffic"
    case roadworks = "Roadworks"
    case hazard = "Hazard"
    case roadClosure = "Road Closure"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .crash: return "car.fill"
        case .speedCheck: return "gauge.with.dots.needle.50percent"
        case .traffic: return "car.2.fill"
        case .roadworks: return "person.fill.turn.down"
        case .hazard: return "exclamationmark.triangle.fill"
        case .roadClosure: return "nosign"
        }
    }
    var color: Color {
        switch self {
        case .crash: return .red
        case .speedCheck: return .blue
        case .traffic: return .orange
        case .roadworks: return .yellow
        case .hazard: return .yellow
        case .roadClosure: return .red
        }
    }
}

private enum ReportFlowDestination: Hashable {
    case choosePlace(for: ReportIssueType)
    case placeIssueOptions(placeTitle: String)
    case routeIssueChooseTrip
    case routeIssueChooseStep(tripTitle: String)
    case incidentType
    case incidentDetail(type: IncidentType)
    case somethingMissing
    case streetIssue
}

private struct ReportFlowRootView: View {
    let issue: ReportIssueType
    @Environment(\.dismiss) private var dismiss
    @State private var path: [ReportFlowDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch issue {
                case .reportSomethingMissing:
                    ReportSomethingMissingView(onDone: { dismiss() })
                case .reportStreetIssue:
                    ReportStreetIssueView(onDone: { dismiss() })
                case .reportPlaceIssue:
                    ChoosePlaceView(
                        title: "Choose a Place",
                        onSelect: { placeTitle in
                            path.append(.placeIssueOptions(placeTitle: placeTitle))
                        },
                        onClose: { dismiss() }
                    )
                case .reportRouteIssue:
                    RouteIssueChooseTripView(
                        onSelectTrip: { tripTitle in
                            path.append(.routeIssueChooseStep(tripTitle: tripTitle))
                        },
                        onClose: { dismiss() }
                    )
                case .reportIncident:
                    IncidentTypePickerView(
                        onSelect: { type in
                            path.append(.incidentDetail(type: type))
                        },
                        onClose: { dismiss() }
                    )
                }
            }
            .navigationDestination(for: ReportFlowDestination.self) { destination in
                switch destination {
                case .placeIssueOptions(let placeTitle):
                    PlaceIssueOptionsView(placeTitle: placeTitle, onDone: { dismiss() })
                case .routeIssueChooseStep(let tripTitle):
                    RouteIssueChooseStepView(tripTitle: tripTitle, onDone: { dismiss() }, onBack: { _ = path.popLast() })
                case .incidentDetail(let type):
                    IncidentDetailView(type: type, onDone: { dismiss() }, onBack: { _ = path.popLast() })
                default:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Step: Choose a place (MapKit autocomplete, Apple Maps-style)

@MainActor
private final class ReportPlaceSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = Array(completer.results.prefix(20))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

// MARK: - Shared map card with live MapKit map

@MainActor
private final class ReportLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region: MKCoordinateRegion

    private let manager = CLLocationManager()

    override init() {
        let defaultCenter = CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946)
        region = MKCoordinateRegion(
            center: defaultCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        region.center = location.coordinate
    }
}

private struct ReportLocationMapCard: View {
    let hintText: String

    @StateObject private var locationManager = ReportLocationManager()
    @State private var trackingMode: MapUserTrackingMode = .follow

    var body: some View {
        Map(
            coordinateRegion: $locationManager.region,
            interactionModes: .all,
            showsUserLocation: true,
            userTrackingMode: $trackingMode
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(height: 220)
        .overlay(
            VStack {
                Spacer()
                Text(hintText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    )
            }
        )
        .onAppear {
            locationManager.requestLocation()
        }
    }
}

private struct ChoosePlaceView: View {
    let title: String
    let onSelect: (String) -> Void
    let onClose: () -> Void

    @StateObject private var search = ReportPlaceSearchService()

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                if search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Text("Start typing to search for a place.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(search.results, id: \.self) { completion in
                            Button {
                                onSelect(completion.title)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .foregroundStyle(.primary)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(.regularMaterial, in: Circle())
                    }
                }
            }

            // Bottom search bar like Apple Maps “Choose a Place”
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Enter a Place…", text: $search.query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                Spacer()
                Image(systemName: "mic.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
    }
}

// MARK: - Step: Place issue options

private struct PlaceIssueOptionsView: View {
    let placeTitle: String
    let onDone: () -> Void

    @State private var selected: ReportPlaceIssueOption?

    var body: some View {
        List {
            Section {
                Text("What issue do you want to report about \(placeTitle)?")
                    .font(.title3.bold())
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }

            Section {
                ForEach(ReportPlaceIssueOption.allCases) { option in
                    Button(option.rawValue) { selected = option }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Report an Issue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onDone()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(.regularMaterial, in: Circle())
                }
            }
        }
        .alert("Thanks", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            Button("OK") { selected = nil }
        } message: {
            Text("This is a demo UI. The selected issue would be submitted to Apple Maps in the real app.")
        }
    }
}

// MARK: - Route issue flow (simplified, Apple Maps-inspired)

private struct RouteIssueChooseTripView: View {
    let onSelectTrip: (String) -> Void
    let onClose: () -> Void

    // Demo “recent directions” list to mimic Apple Maps
    private let recentTrips: [(String, String, String)] = [
        ("NMI", "5 January", "airplane"),
        ("AMD", "5 January", "figure.walk"),
        ("Bengaluru", "27 December", "car.fill")
    ]

    var body: some View {
        List {
            Section {
                Text("Report an Issue")
                    .font(.title3.bold())
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                ForEach(recentTrips, id: \.0) { trip in
                    Button {
                        onSelectTrip(trip.0)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: trip.2)
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.0)
                                Text(trip.1)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Report an Issue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(.regularMaterial, in: Circle())
                }
            }
        }
    }
}

private struct RouteIssueChooseStepView: View {
    let tripTitle: String
    let onDone: () -> Void
    let onBack: () -> Void

    private let steps: [(String, String, String)] = [
        ("From My Location", "Airport, Ahmedabad", "building.2.fill"),
        ("Turn right", "250 m", "arrow.turn.up.right"),
        ("Turn left", "40 m", "arrow.turn.up.left"),
        ("At the roundabout…", "500 m", "dot.circle.and.hand.point.up.left.fill")
    ]

    var body: some View {
        List {
            Section {
                Text("Which step in your directions to \(tripTitle) was wrong?")
                    .font(.title3.bold())
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }

            Section("Route steps") {
                ForEach(steps, id: \.0) { s in
                    HStack(spacing: 12) {
                        Image(systemName: s.2)
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.0)
                            Text(s.1)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Report an Issue")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(.regularMaterial, in: Circle())
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onDone()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(.regularMaterial, in: Circle())
                }
            }
        }
    }
}

// MARK: - Incident flow (with working photo attachments)

private struct IncidentTypePickerView: View {
    let onSelect: (IncidentType) -> Void
    let onClose: () -> Void

    var body: some View {
        List {
            Section("Incident Type") {
                ForEach(IncidentType.allCases) { type in
                    Button {
                        onSelect(type)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(type.color)
                                    .frame(width: 34, height: 34)
                                Image(systemName: type.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(type.rawValue)
                            Spacer()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Report an Incident")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(.regularMaterial, in: Circle())
                }
            }
        }
    }
}

private struct IncidentDetailView: View {
    let type: IncidentType
    let onDone: () -> Void
    let onBack: () -> Void

    @State private var optionalInfo = ""

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Location On Map")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                ReportLocationMapCard(
                    hintText: "Move the map to the correct location. Expand to use the full map."
                )

                HStack {
                    Text("OPTIONAL INFORMATION")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(max(0, 1000 - optionalInfo.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $optionalInfo)
                    .frame(minHeight: 90)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                Text("Photos")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                PhotosPicker(selection: $pickedItems, maxSelectionCount: 6, matching: .images) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 120, height: 90)
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("Add Photo")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !images.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(images.enumerated()), id: \.offset) { _, img in
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 90, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .clipped()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
        .navigationTitle(type.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(.regularMaterial, in: Circle())
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onDone()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(.regularMaterial, in: Circle())
                }
            }
        }
        .onChange(of: pickedItems) { _ in
            Task {
                images.removeAll()
                for item in pickedItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        images.append(ui)
                    }
                }
            }
        }
    }
}

// MARK: - Street / Missing (kept simple but correct entry points)

private struct ReportSomethingMissingView: View {
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("What is missing from this location?")
                    .font(.title2.bold())
                    .padding(.top, 8)

                ReportLocationMapCard(
                    hintText: "Required: Move the map to the location where something is missing. Expand to use the full map."
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Report Something Missing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(.regularMaterial, in: Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onDone() } label: {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(.regularMaterial, in: Circle())
                    }
                }
            }
        }
    }
}

private struct ReportStreetIssueView: View {
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("What issue do you want to report about this street?")
                    .font(.title2.bold())
                    .padding(.top, 8)

                ReportLocationMapCard(
                    hintText: "Required: Move the map to the street you want to report about. Expand to use the full map."
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Report an Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(.regularMaterial, in: Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onDone() } label: {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(.regularMaterial, in: Circle())
                    }
                }
            }
        }
    }
}

// MARK: - Preferences Flow (Apple Maps-inspired)

private enum DirectionsMode: String, CaseIterable, Identifiable {
    case driving = "Driving"
    case walking = "Walking"
    case transit = "Transit"
    case cycling = "Cycling"
    var id: String { rawValue }
}

private struct PreferencesView: View {
    @Binding var currentPreference: String

    @State private var directionsMode: DirectionsMode = .driving
    @State private var avoidTolls = false
    @State private var avoidHighways = false
    @State private var avoidHillsWalking = false
    @State private var avoidBusyRoadsWalking = false
    @State private var avoidHillsCycling = false
    @State private var avoidBusyRoadsCycling = false
    @State private var transitBus = true
    @State private var transitMetro = true
    @State private var transitLocalTrain = true
    @State private var transitFerry = true

    var body: some View {
        List {
            Section("Directions") {
                ForEach(DirectionsMode.allCases) { mode in
                    HStack {
                        Text(mode.rawValue)
                        Spacer()
                        if directionsMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        directionsMode = mode
                        currentPreference = mode.rawValue
                    }
                }
            }

            Section("Driving") {
                Toggle("Avoid Tolls", isOn: $avoidTolls)
                Toggle("Avoid Highways", isOn: $avoidHighways)
            }

            Section("Walking") {
                Toggle("Avoid Hills", isOn: $avoidHillsWalking)
                Toggle("Avoid Busy Roads", isOn: $avoidBusyRoadsWalking)
            }

            Section("Cycling") {
                Toggle("Avoid Hills", isOn: $avoidHillsCycling)
                Toggle("Avoid Busy Roads", isOn: $avoidBusyRoadsCycling)
            }

            Section("Transit") {
                Toggle("Bus", isOn: $transitBus)
                Toggle("Metro & Light Rail", isOn: $transitMetro)
                Toggle("Local Train", isOn: $transitLocalTrain)
                Toggle("Ferry", isOn: $transitFerry)
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Places (placeholder)

private struct PlacesView: View {
    @Binding var savedPlacesCount: Int

    var body: some View {
        List {
            Section {
                Text("Saved places will appear here.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Auth Flow

private struct SignInView: View {
    @Binding var isPresented: Bool
    let onSignIn: (String, String) -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var showInvalid = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                }

                Section {
                    Button {
                        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, !password.isEmpty else {
                            showInvalid = true
                            return
                        }
                        onSignIn(trimmed, password)
                    } label: {
                        Text("Sign In")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .alert("Missing information", isPresented: $showInvalid) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter your email and password.")
            }
        }
    }
}

#Preview {
    ProfileView(isPresented: .constant(true))
}
