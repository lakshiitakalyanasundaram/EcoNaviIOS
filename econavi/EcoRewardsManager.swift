//
//  EcoRewardsManager.swift
//  econavi
//
//  Created by lakshiita kalyanasundaram on 12/25/25.
//

import Foundation
import Combine   
final class EcoRewardsManager: ObservableObject {
    @Published var totalCredits: Int = 0

    func addCredits(savedEmissionsGrams: Double) {
        let credits = Int(savedEmissionsGrams / 100)
        totalCredits += max(credits, 0)
    }
}
