import SwiftUI
import MapKit

// MARK: - Collapsed / Expanded heights
private let collapsedHeight: CGFloat = 88
private let expandedHeight: CGFloat = 320
private let dragThreshold: CGFloat = 30

/// Overlay UI while navigating: top banner + bottom sheet with collapsed/expanded states (Apple Maps style).
@MainActor
struct NavigationModeView: View {
    @ObservedObject var navigationManager: NavigationManager
    @ObservedObject var routeService: RouteService
    @ObservedObject var locationManager: LocationManager

    @State private var sheetHeight: CGFloat = collapsedHeight
    @State private var gestureBaseHeight: CGFloat?
    @State private var showAddStop = false
    @State private var showReportIncident = false
    @State private var showVoiceControls = false

    private var isExpanded: Bool { sheetHeight > collapsedHeight + dragThreshold }

    var body: some View {
        VStack(spacing: 0) {
            // Top instruction banner
            if let instruction = navigationManager.nextInstruction {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.title2)
                        Text(instruction)
                            .font(.headline)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }

            Spacer(minLength: 0)

            // Bottom sheet: drag handle + content
            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Collapsed: ETA, distance, time, CO2
                HStack(alignment: .center, spacing: 16) {
                    if let eta = navigationManager.eta {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DateFormatter.localizedString(from: eta, dateStyle: .none, timeStyle: .short))
                                .font(.title2.bold())
                            Text("arrival")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(navigationManager.remainingTime / 60))")
                                .font(.title2.bold())
                            Text("min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.0f", navigationManager.remainingDistance / 1000.0))
                                .font(.title2.bold())
                            Text("km")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    // CO2 (Step 11)
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                        Text(String(format: "%.0f g CO₂", navigationManager.emissionEstimate))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(height: collapsedHeight - 24)

                if isExpanded {
                    NavigationControlSheetView(
                        navigationManager: navigationManager,
                        routeService: routeService,
                        locationManager: locationManager,
                        onAddStop: { showAddStop = true },
                        onReportIncident: { showReportIncident = true },
                        onVoiceControls: { showVoiceControls = true }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .frame(height: sheetHeight)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0.96), Color(.systemBackground).opacity(0.92)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 20, y: -4)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if gestureBaseHeight == nil { gestureBaseHeight = sheetHeight }
                        guard let base = gestureBaseHeight else { return }
                        let proposed = base - value.translation.height
                        sheetHeight = min(max(proposed, collapsedHeight), expandedHeight)
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.height
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if velocity < -80 {
                                sheetHeight = expandedHeight
                            } else if velocity > 80 {
                                sheetHeight = collapsedHeight
                            } else {
                                sheetHeight = sheetHeight > (collapsedHeight + expandedHeight) / 2 ? expandedHeight : collapsedHeight
                            }
                        }
                        gestureBaseHeight = nil
                    }
            )
            .onTapGesture(count: 1) {
                if !isExpanded {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        sheetHeight = expandedHeight
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showAddStop) {
            AddStopSheetView(
                isPresented: $showAddStop,
                navigationManager: navigationManager,
                routeService: routeService,
                locationManager: locationManager
            )
        }
        .sheet(isPresented: $showReportIncident) {
            ReportIncidentView(isPresented: $showReportIncident)
        }
        .sheet(isPresented: $showVoiceControls) {
            VoiceControlsPlaceholderView(isPresented: $showVoiceControls)
        }
    }
}

// MARK: - NavigationControlSheetView (Expanded content)
struct NavigationControlSheetView: View {
    @ObservedObject var navigationManager: NavigationManager
    @ObservedObject var routeService: RouteService
    @ObservedObject var locationManager: LocationManager
    var onAddStop: () -> Void
    var onReportIncident: () -> Void
    var onVoiceControls: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onAddStop) {
                    Label("Add Stop", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                ShareETAButton(navigationManager: navigationManager)
                Button(action: onReportIncident) {
                    Label("Report an Incident", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                Button(action: onVoiceControls) {
                    Label("Voice Controls", systemImage: "waveform.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                navigationManager.stopNavigation()
                routeService.clearRoute()
                locationManager.stopTracking()
                locationManager.stopHeadingUpdates()
            } label: {
                Text("End Route")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

// MARK: - Share ETA
private struct ShareETAButton: View {
    @ObservedObject var navigationManager: NavigationManager

    private var etaText: String {
        let timeStr: String
        if let eta = navigationManager.eta {
            timeStr = DateFormatter.localizedString(from: eta, dateStyle: .none, timeStyle: .short)
        } else {
            timeStr = "—"
        }
        let min = Int(navigationManager.remainingTime / 60)
        let km = navigationManager.remainingDistance / 1000.0
        return "My ETA is \(timeStr) (\(min) min, \(String(format: "%.1f", km)) km remaining)"
    }

    var body: some View {
        ShareLink(item: etaText, subject: Text("My ETA")) {
            Label("Share ETA", systemImage: "person.2.wave.2.fill")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Report Incident
private struct ReportIncidentView: View {
    @Binding var isPresented: Bool
    var body: some View {
        NavigationStack {
            List {
                Button("Accident") { isPresented = false }
                Button("Hazard") { isPresented = false }
                Button("Road closure") { isPresented = false }
                Button("Other") { isPresented = false }
            }
            .navigationTitle("Report an Incident")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
    }
}

// MARK: - Voice Controls placeholder
private struct VoiceControlsPlaceholderView: View {
    @Binding var isPresented: Bool
    var body: some View {
        NavigationStack {
            Text("Voice guidance and spoken instructions can be enabled here.")
                .padding()
            .navigationTitle("Voice Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { isPresented = false } } }
        }
    }
}
