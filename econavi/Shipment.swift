//
//  Shipment.swift
//  econavi
//
//  Created by lakshiita kalyanasundaram on 12/25/25.
//


import SwiftUI

struct Shipment: Identifiable {
    let id = UUID()
    let route: String          // e.g. "Delhi → Mumbai"
    let method: String         // Truck / Rail / Air
    let emissions: Double      // grams CO₂
    let icon: String           // SF Symbol
    let color: Color           // UI color
}
enum ShipmentMethod: String {
    case truck, rail, ship, air
}
