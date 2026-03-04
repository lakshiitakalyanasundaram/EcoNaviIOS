import SwiftUI
import CoreLocation
import MessageUI

struct SafetyView: View {
    @ObservedObject var safetyManager: SafetyManager
    @ObservedObject var locationManager: LocationManager
    @Binding var isPresented: Bool
    
    @State private var showContactPicker = false
    @State private var showAlertConfirmation = false
    @State private var showSOSConfirmation = false
    @State private var showLiveLocationOptions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "shield.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                
                Text("Safety Features")
                    .font(.title2.bold())
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Alert Contacts Section
                    SafetyOptionCard(
                        icon: "bell.fill",
                        title: "Alert Contacts",
                        description: "Send emergency alert to your favorite contacts",
                        color: .orange,
                        action: {
                            showAlertConfirmation = true
                        }
                    )
                    
                    // Live Location Section
                    SafetyOptionCard(
                        icon: "location.fill",
                        title: "Share Live Location",
                        description: safetyManager.isLiveLocationSharing 
                            ? "Live location sharing is active"
                            : "Enable live location sharing with favorite contacts",
                        color: .blue,
                        action: {
                            showLiveLocationOptions = true
                        }
                    )
                    .overlay(
                        Group {
                            if safetyManager.isLiveLocationSharing {
                                HStack {
                                    Spacer()
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 12, height: 12)
                                        .padding(.trailing, 16)
                                }
                            }
                        }
                    )
                    
                    // SOS Section
                    SafetyOptionCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "SOS Emergency",
                        description: "Call emergency services and alert contacts",
                        color: .red,
                        action: {
                            showSOSConfirmation = true
                        }
                    )
                    
                    // Favorite Contacts List
                    if !safetyManager.favoriteContacts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Favorite Contacts")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    showContactPicker = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            
                            ForEach(safetyManager.favoriteContacts) { contact in
                                ContactRow(
                                    contact: contact,
                                    safetyManager: safetyManager
                                )
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .confirmationDialog("Alert Contacts", isPresented: $showAlertConfirmation, titleVisibility: .visible) {
            Button("Send Alert") {
                safetyManager.alertFavoriteContacts(location: locationManager.location)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will send an emergency alert to all your favorite contacts.")
        }
        .confirmationDialog("SOS Emergency", isPresented: $showSOSConfirmation, titleVisibility: .visible) {
            Button("Call Emergency Services", role: .destructive) {
                safetyManager.sendSOSAlert(location: locationManager.location)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will call emergency services and alert all your favorite contacts. Use only in real emergencies!")
        }
        .sheet(isPresented: $showLiveLocationOptions) {
            LiveLocationView(
                safetyManager: safetyManager,
                locationManager: locationManager
            )
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView(safetyManager: safetyManager)
        }
    }
}

struct SafetyOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct ContactRow: View {
    let contact: Contact
    @ObservedObject var safetyManager: SafetyManager
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(contact.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.blue)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.subheadline.bold())
                
                Text(contact.phoneNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if contact.isLiveLocationEnabled {
                Image(systemName: "location.fill")
                    .foregroundStyle(.green)
            }
            
            Button {
                safetyManager.removeFavoriteContact(contact)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 8)
    }
}

struct LiveLocationView: View {
    @ObservedObject var safetyManager: SafetyManager
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Toggle("Enable Live Location Sharing", isOn: $safetyManager.isLiveLocationSharing)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if safetyManager.isLiveLocationSharing {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sharing with:")
                            .font(.headline)
                        
                        ForEach(safetyManager.favoriteContacts) { contact in
                            Toggle(contact.name, isOn: Binding(
                                get: { contact.isLiveLocationEnabled },
                                set: { _ in
                                    safetyManager.toggleLiveLocation(for: contact)
                                }
                            ))
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if safetyManager.isLiveLocationSharing {
                    Button {
                        safetyManager.startLiveLocationSharing(location: locationManager.location)
                    } label: {
                        Label("Start Sharing", systemImage: "location.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Live Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ContactPickerView: View {
    @ObservedObject var safetyManager: SafetyManager
    @Environment(\.dismiss) var dismiss
    
    @State private var contactName = ""
    @State private var phoneNumber = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $contactName)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section {
                    Button {
                        let contact = Contact(
                            name: contactName,
                            phoneNumber: phoneNumber,
                            isFavorite: true
                        )
                        safetyManager.addFavoriteContact(contact)
                        dismiss()
                    } label: {
                        Text("Add Contact")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(contactName.isEmpty || phoneNumber.isEmpty)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

