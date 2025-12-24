//
//  econaviApp.swift
//  econavi
//
//  Created by lakshiita kalyanasundaram on 12/24/25.
//

import SwiftUI
import CoreData

@main
struct econaviApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
