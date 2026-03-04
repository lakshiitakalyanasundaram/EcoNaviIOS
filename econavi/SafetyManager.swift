import Foundation
import CoreLocation
import Contacts
import MessageUI
import UIKit
import Combine

@MainActor
class SafetyManager: ObservableObject {
    @Published var favoriteContacts: [Contact] = []
    @Published var isLiveLocationSharing = false
    @Published var alertMessage = ""
    
    private let userDefaultsKey = "FavoriteContacts"
    
    init() {
        loadFavoriteContacts()
    }
    
    // MARK: - Contact Management
    
    func loadFavoriteContacts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let contacts = try? JSONDecoder().decode([Contact].self, from: data) {
            favoriteContacts = contacts
        } else {
            // Default contacts for demo
            favoriteContacts = [
                Contact(name: "Emergency Contact 1", phoneNumber: "+1234567890", isFavorite: true),
                Contact(name: "Emergency Contact 2", phoneNumber: "+1234567891", isFavorite: true)
            ]
            saveFavoriteContacts()
        }
    }
    
    func saveFavoriteContacts() {
        if let data = try? JSONEncoder().encode(favoriteContacts) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    func addFavoriteContact(_ contact: Contact) {
        let newContact = Contact(
            name: contact.name,
            phoneNumber: contact.phoneNumber,
            isFavorite: true,
            isLiveLocationEnabled: contact.isLiveLocationEnabled
        )
        favoriteContacts.append(newContact)
        saveFavoriteContacts()
    }
    
    func removeFavoriteContact(_ contact: Contact) {
        favoriteContacts.removeAll { $0.id == contact.id }
        saveFavoriteContacts()
    }
    
    func toggleLiveLocation(for contact: Contact) {
        if let index = favoriteContacts.firstIndex(where: { $0.id == contact.id }) {
            favoriteContacts[index].isLiveLocationEnabled.toggle()
            saveFavoriteContacts()
        }
    }
    
    // MARK: - Alert Contacts
    
    func alertFavoriteContacts(location: CLLocation?) {
        let locationText = location != nil 
            ? "My location: \(location!.coordinate.latitude), \(location!.coordinate.longitude)"
            : "Location unavailable"
        
        let message = """
        🚨 EMERGENCY ALERT 🚨
        
        I need help! Please check on me.
        
        \(locationText)
        
        Sent from EcoNavi Safety
        """
        
        alertMessage = message
        
        // Send SMS to all favorite contacts
        for contact in favoriteContacts where contact.isFavorite {
            sendSMS(to: contact.phoneNumber, message: message)
        }
    }
    
    private func sendSMS(to phoneNumber: String, message: String) {
        if MFMessageComposeViewController.canSendText() {
            let messageComposeVC = MFMessageComposeViewController()
            messageComposeVC.recipients = [phoneNumber]
            messageComposeVC.body = message
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(messageComposeVC, animated: true)
            }
        } else {
            // Fallback: Open Messages app with pre-filled message
            if let url = URL(string: "sms:\(phoneNumber)&body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    // MARK: - Live Location Sharing
    
    func startLiveLocationSharing(location: CLLocation?) {
        isLiveLocationSharing = true
        
        guard let location = location else { return }
        
        let locationText = "https://maps.apple.com/?ll=\(location.coordinate.latitude),\(location.coordinate.longitude)"
        let message = """
        📍 Live Location Sharing
        
        I'm sharing my live location with you.
        
        \(locationText)
        
        Sent from EcoNavi Safety
        """
        
        // Share with contacts who have live location enabled
        for contact in favoriteContacts where contact.isLiveLocationEnabled {
            sendSMS(to: contact.phoneNumber, message: message)
        }
    }
    
    func stopLiveLocationSharing() {
        isLiveLocationSharing = false
    }
    
    // MARK: - SOS Emergency
    
    func callEmergencyServices() {
        // Call emergency services (varies by country)
        // 911 for US, 112 for EU, etc.
        let emergencyNumber = "911" // You can make this configurable
        
        if let url = URL(string: "tel://\(emergencyNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    func sendSOSAlert(location: CLLocation?) {
        let locationText = location != nil
            ? "Emergency at: \(location!.coordinate.latitude), \(location!.coordinate.longitude)"
            : "Location unavailable"
        
        let message = """
        🆘 SOS EMERGENCY 🆘
        
        I need immediate help!
        
        \(locationText)
        
        Sent from EcoNavi Safety
        """
        
        alertMessage = message
        
        // Send to all favorite contacts
        for contact in favoriteContacts where contact.isFavorite {
            sendSMS(to: contact.phoneNumber, message: message)
        }
        
        // Also call emergency services
        callEmergencyServices()
    }
}

