import SwiftUI
import MapKit

// MARK: - Layout constants
private let collapsedHeight: CGFloat = 92
private let expandedHeight: CGFloat = 340
private let dragThreshold: CGFloat = 30
private let topBannerCornerRadius: CGFloat = 16
private let bottomSheetCornerRadius: CGFloat = 20

/// Navigation overlay: top instruction banner + bottom floating sheet (Apple Maps visual hierarchy).
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
            // STEP 8: Off-route banner
            if navigationManager.isOffRoute {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Recalculating route…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // MARK: Top Navigation Banner – STEP 5/6 (nextInstruction), STEP 14 (timing)
            if let instruction = navigationManager.nextInstruction {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.primary)
                        Text(instruction)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    // STEP 14: Distance to next maneuver (prepare / upcoming / now)
                    if let dist = navigationManager.distanceToNextManeuver {
                        let timing = navigationManager.instructionTimingState
                        Group {
                            switch timing {
                            case .now:
                                Text("Now")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            case .upcoming:
                                Text("In \(Int(dist)) m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .prepare:
                                Text("In \(Int(dist)) m")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            case .none:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: topBannerCornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, navigationManager.isOffRoute ? 4 : 8)
            }

            Spacer(minLength: 0)

            // MARK: Bottom floating sheet (Steps 6, 7, 8, 10)
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.primary.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                // Collapsed: glassmorphic bar (Step 7, 12)
                HStack(alignment: .center, spacing: 20) {
                    // ETA – Headline
                    if let eta = navigationManager.eta {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DateFormatter.localizedString(from: eta, dateStyle: .none, timeStyle: .short))
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("arrival")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    // Remaining time & distance – Subheadline
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(navigationManager.remainingTime / 60)) min")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("remaining")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f km", navigationManager.remainingDistance / 1000.0))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("distance")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    // CO₂ – Caption (Step 12)
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text(String(format: "%.0f g CO₂", navigationManager.emissionEstimate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(minHeight: collapsedHeight - 28)

                if isExpanded {
                    NavigationControlSheetView(
                        navigationManager: navigationManager,
                        routeService: routeService,
                        locationManager: locationManager,
                        onAddStop: { showAddStop = true },
                        onReportIncident: { showReportIncident = true },
                        onVoiceControls: { showVoiceControls = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(height: sheetHeight)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: bottomSheetCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, y: -6)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .safeAreaPadding(.bottom, 0)
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
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
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
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
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

// MARK: - NavigationControlSheetView (Step 8 – Apple Maps style grouped buttons)
struct NavigationControlSheetView: View {
    @ObservedObject var navigationManager: NavigationManager
    @ObservedObject var routeService: RouteService
    @ObservedObject var locationManager: LocationManager
    var onAddStop: () -> Void
    var onReportIncident: () -> Void
    var onVoiceControls: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            // Grouped row: Add Stop, Share ETA, Report, Voice
            VStack(spacing: 0) {
                NavigationControlRow(icon: "plus.circle.fill", title: "Add Stop", color: .blue, action: onAddStop)
                Divider().padding(.leading, 52)
                ShareETAButton(navigationManager: navigationManager)
                Divider().padding(.leading, 52)
                NavigationControlRow(icon: "exclamationmark.triangle.fill", title: "Report an Incident", color: .red, action: onReportIncident)
                Divider().padding(.leading, 52)
                NavigationControlRow(icon: "waveform.circle.fill", title: "Voice Controls", color: .gray, action: onVoiceControls)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(role: .destructive) {
                navigationManager.stopNavigation()
                routeService.clearRoute()
                locationManager.stopTracking()
                locationManager.stopHeadingUpdates()
            } label: {
                Text("End Route")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NavigationControlRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
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
            HStack(spacing: 14) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .frame(width: 28, alignment: .center)
                Text("Share ETA")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
