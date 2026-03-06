//
//  DailyTravelPlannerView.swift
//  econavi
//
//  Created by lakshiita kalyanasundaram on 3/4/26.
//

import SwiftUI
import MapKit
import UserNotifications

struct DailyTravelPlannerView: View {
    
    @StateObject private var viewModel = TravelPlannerViewModel()
    @State private var showDestinationSuggestions = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with reset button
                headerCard
                
                // Input Form
                VStack(spacing: 16) {
                    // Destination Input
                    destinationCard
                    
                    // Date Picker
                    dateCard
                    
                    // Time Picker
                    timeCard
                    
                    // Transport Mode Selector
                    transportModeCard
                    
                    // Calculate Button
                    calculateButton
                    
                    // Schedule Notification Button
                    if viewModel.travelSummary != nil {
                        scheduleNotificationButton
                    }
                    
                    // Reset Button
                    resetButton
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                
                // Results Section
                if let summary = viewModel.travelSummary {
                    travelSummaryCard(summary)
                    
                    if summary.exceedsLimit {
                        warningCard(summary)
                    }
                    
                    if !viewModel.alternativeOptions.isEmpty {
                        alternativesCard
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
    
    // MARK: - Header with Reset Button
    
    private var headerCard: some View {
        HStack {
            Image(systemName: "leaf.fill")
                .font(.title2)
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Travel Planner")
                    .font(.title2.bold())
                Text("Plan eco-friendly trips")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.reset()
                    showDestinationSuggestions = false
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1), in: Circle())
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
    
    // MARK: - Destination Card
    
    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Destination", systemImage: "mappin.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter destination", text: $viewModel.destination)
                        .onSubmit {
                            showDestinationSuggestions = false
                        }
                        .onChange(of: viewModel.destination) { _, newValue in
                            viewModel.updateDestinationSearch(newValue)
                            showDestinationSuggestions = !newValue.isEmpty
                        }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Search suggestions
                if showDestinationSuggestions && !viewModel.searchSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.searchSuggestions.prefix(5), id: \.self) { suggestion in
                            Button {
                                viewModel.destination = suggestion.title
                                showDestinationSuggestions = false
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(suggestion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                            }
                            .foregroundStyle(.primary)
                            
                            if suggestion != viewModel.searchSuggestions.last {
                                Divider()
                            }
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Date Card
    
    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Departure Date", systemImage: "calendar")
                .font(.subheadline.bold())
                .foregroundStyle(.blue)
            
            HStack(spacing: 12) {
                Image(systemName: "calendar.circle.fill")
                    .foregroundStyle(.orange)
                
                DatePicker(
                    "",
                    selection: $viewModel.selectedDate,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Time Card
    
    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Departure Time", systemImage: "clock.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.blue)
            
            HStack(spacing: 12) {
                Image(systemName: "clock.circle.fill")
                    .foregroundStyle(.red)
                
                DatePicker(
                    "",
                    selection: $viewModel.selectedTime,
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Transport Mode Card
    
    private var transportModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Transport Mode", systemImage: "car.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.blue)
            
            HStack(spacing: 8) {
                ForEach(TravelMode.allCases, id: \.self) { mode in
                    VStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 18))
                        Text(mode.displayName)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.selectedTransportMode == mode ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                    .foregroundStyle(viewModel.selectedTransportMode == mode ? .blue : .secondary)
                    .cornerRadius(10)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            viewModel.selectedTransportMode = mode
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Calculate Button
    
    private var calculateButton: some View {
        Button {
            Task {
                await viewModel.calculateRoute(to: viewModel.destination)
            }
        } label: {
            if viewModel.isCalculating {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Calculating...")
                }
            } else {
                Label("Calculate Impact", systemImage: "bolt.fill")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
        .disabled(viewModel.destination.isEmpty || viewModel.isCalculating)
        .opacity(viewModel.destination.isEmpty || viewModel.isCalculating ? 0.6 : 1.0)
    }
    
    // MARK: - Schedule Notification Button
    
    private var scheduleNotificationButton: some View {
        Button {
            requestNotificationPermission()
        } label: {
            Label("Schedule Reminder", systemImage: "bell.badge.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Reset Button
    
    private var resetButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.reset()
                showDestinationSuggestions = false
            }
        } label: {
            Label("Clear All", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .background(Color.red.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Travel Summary Card
    
    private func travelSummaryCard(_ summary: TravelSummary) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: summary.emissionStatus.icon)
                    .font(.title2)
                    .foregroundStyle(Color(summary.emissionStatus.color))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trip Summary")
                        .font(.headline.weight(.semibold))
                    Text(summary.emissionStatus.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Trip Details Grid
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    detailCell(
                        icon: "location.fill",
                        title: "Destination",
                        value: summary.destination
                    )
                    
                    detailCell(
                        icon: "car.fill",
                        title: "Mode",
                        value: summary.transportMode.displayName
                    )
                }
                
                // Transit route info if available
                if let routeName = summary.routeName {
                    HStack(spacing: 16) {
                        detailCell(
                            icon: summary.transportMode == .bus ? "bus.fill" : "train.side.front.car",
                            title: "Route",
                            value: routeName
                        )
                        
                        detailCell(
                            icon: "clock.fill",
                            title: "Departs",
                            value: formatTime(summary.estimatedArrivalTime)
                        )
                    }
                }
                
                HStack(spacing: 16) {
                    detailCell(
                        icon: "ruler",
                        title: "Distance",
                        value: String(format: "%.1f km", summary.distanceKm)
                    )
                    
                    detailCell(
                        icon: "clock.fill",
                        title: "Duration",
                        value: "\(summary.estimatedDurationMinutes) min"
                    )
                }
                
                HStack(spacing: 16) {
                    detailCell(
                        icon: "checkmark.circle.fill",
                        title: "ETA",
                        value: formatTime(summary.estimatedArrivalTime)
                    )
                    
                    detailCell(
                        icon: "wind",
                        title: "Traffic",
                        value: summary.trafficLevel.displayName
                    )
                }
            }
            
            Divider()
            
            // Emission Card
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Predicted Carbon Emission")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(EmissionsCalculatorIndia.formatEmission(summary.predictedEmissionKg * 1000.0))
                        .font(.title3.bold())
                }
                
                Spacer()
            }
            .padding(12)
            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
    
    // MARK: - Warning Card
    
    private func warningCard(_ summary: TravelSummary) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("High Carbon Travel")
                        .font(.headline.weight(.semibold))
                    Text("This trip exceeds recommended Indian urban transport carbon levels")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Daily Limit")
                        .font(.caption)
                    Spacer()
                    Text(EmissionsCalculatorIndia.formatEmission(2000.0))
                        .font(.caption.weight(.medium))
                }
                
                HStack {
                    Text("Your Trip")
                        .font(.caption)
                    Spacer()
                    Text(EmissionsCalculatorIndia.formatEmission(summary.predictedEmissionKg * 1000.0))
                        .font(.caption.weight(.medium))
                }
                
                HStack {
                    Text("Exceeds by")
                        .font(.caption)
                    Spacer()
                    Text(EmissionsCalculatorIndia.formatEmission(max(0, (summary.predictedEmissionKg - summary.dailyUrbanCarbonLimit) * 1000.0)))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }
            }
            .padding(12)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
    
    // MARK: - Alternatives Card
    
    private var alternativesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                
                Text("Suggested Alternatives")
                    .font(.headline.weight(.semibold))
            }
            
            Divider()
            
            VStack(spacing: 10) {
                ForEach(viewModel.alternativeOptions) { alternative in
                    alternativeOptionCell(alternative)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
    
    private func alternativeOptionCell(_ option: AlternativeTravelOption) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: option.transportMode.icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.transportMode.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(formatTime(option.departureTime) + " • \(option.estimatedDurationMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(EmissionsCalculatorIndia.formatEmission(option.predictedEmissionKg * 1000.0))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                    
                    if option.emissionSavingsKg > 0 {
                        Text("-" + EmissionsCalculatorIndia.formatEmission(option.emissionSavingsKg * 1000.0))
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            Divider()
                .opacity(0.3)
        }
    }
    
    // MARK: - Helper Views
    
    private func detailCell(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - Notification Helper
    
    private func requestNotificationPermission() {
        guard let summary = viewModel.travelSummary else { return }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    scheduleReminder(for: summary)
                }
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleReminder(for summary: TravelSummary) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Travel!"
        content.body = "Your trip to \(summary.destination) starts now. Did you begin your journey?"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        // Add action buttons
        let yesAction = UNNotificationAction(identifier: "START_JOURNEY", title: "Yes, I Started", options: .foreground)
        let notYetAction = UNNotificationAction(identifier: "NOT_YET", title: "Not Yet", options: [])
        let category = UNNotificationCategory(identifier: "TRIP_REMINDER", actions: [yesAction, notYetAction], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        content.categoryIdentifier = "TRIP_REMINDER"
        
        // Calculate time interval from now to departure time
        let departureTimeInterval = Calendar.current.dateComponents([.hour, .minute], from: viewModel.selectedTime)
        let departureDateTime = Calendar.current.date(
            bySettingHour: departureTimeInterval.hour ?? 0,
            minute: departureTimeInterval.minute ?? 0,
            second: 0,
            of: viewModel.selectedDate
        ) ?? viewModel.selectedDate
        
        let timeUntilDeparture = max(1, departureDateTime.timeIntervalSinceNow)
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeUntilDeparture,
            repeats: false
        )
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification scheduled successfully")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DailyTravelPlannerView()
}
