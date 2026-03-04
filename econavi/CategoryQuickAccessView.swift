import SwiftUI
import MapKit
import CoreLocation

/// Quick access category buttons for Home Map (Dinner, Petrol, Hospitals, etc.). Tapping opens search results sheet.
struct CategoryQuickAccessView: View {
    var userLocation: CLLocation?
    var onDestinationSelected: (String, CLLocationCoordinate2D) -> Void

    @State private var selectedCategory: Cat? = nil
    @State private var categoryResults: [MKMapItem] = []
    @State private var isSearching = false

    /// STEP 9: Category → MKPointOfInterestCategory (no naturalLanguageQuery).
    private let categories: [(name: String, category: MKPointOfInterestCategory, icon: String, color: Color)] = [
        ("Dinner", .restaurant, "fork.knife", .orange),
        ("Petrol", .gasStation, "fuelpump.fill", .blue),
        ("Hospitals", .hospital, "hospital", .red),
        ("Coffee", .cafe, "cup.and.saucer.fill", .brown),
        ("Parking", .parking, "parkingsign", .blue),
        ("EV Charging", .evCharger, "bolt.car.fill", .green)
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(categories, id: \.name) { cat in
                Button {
                    selectedCategory = Cat(id: cat.name, category: cat.category)
                } label: {
                    Image(systemName: cat.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(cat.color, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .sheet(item: $selectedCategory) { cat in
            CategoryResultsSheet(
                categoryName: cat.id,
                userLocation: userLocation,
                results: $categoryResults,
                isSearching: $isSearching,
                onSelect: { name, coord in
                    selectedCategory = nil
                    onDestinationSelected(name, coord)
                },
                onDismiss: { selectedCategory = nil }
            )
        }
        .onChange(of: selectedCategory) { new in
            if let cat = new {
                runCategorySearch(cat.category)
            } else {
                categoryResults = []
            }
        }
    }

    /// STEP 9: MKLocalPointsOfInterestRequest; EV Charging uses same fallback as Add Stop (avoids MKErrorDomain 4).
    private func runCategorySearch(_ category: MKPointOfInterestCategory) {
        guard let loc = userLocation else { return }
        isSearching = true
        categoryResults = []

        if category == .evCharger {
            Task { @MainActor in
                let items = await EVChargingSearchHelper.searchEVCharging(center: loc.coordinate)
                isSearching = false
                categoryResults = items
            }
            return
        }

        let request = MKLocalPointsOfInterestRequest(center: loc.coordinate, radius: 5000)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            Task { @MainActor in
                isSearching = false
                categoryResults = response?.mapItems ?? []
            }
        }
    }
}

private struct Cat: Identifiable, Equatable {
    let id: String
    let category: MKPointOfInterestCategory
}

private struct CategoryResultsSheet: View {
    let categoryName: String
    let userLocation: CLLocation?
    @Binding var results: [MKMapItem]
    @Binding var isSearching: Bool
    var onSelect: (String, CLLocationCoordinate2D) -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Finding \(categoryName)…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    Text("No results found")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                            Button {
                                let name = item.name ?? "Location"
                                let coord = item.placemark.coordinate
                                onSelect(name, coord)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(.red)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Unknown")
                                            .font(.subheadline.weight(.medium))
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
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}
