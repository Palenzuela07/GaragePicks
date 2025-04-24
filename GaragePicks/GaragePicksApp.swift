//
//  GaragePicksApp.swift
//  GaragePicks
//
//  Created by Michael Palenzuela on 4/21/25.
//

import SwiftUI

@main
struct GaragePicksApp: App {
    // Simple error manager as a singleton with lazy initialization
    static let errorManager: ErrorManager = {
        // Initialize safely
        let manager = ErrorManager()
        print("Error manager initialized successfully")
        return manager
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Print a startup message to verify app initialization
                    print("GaragePicks app started successfully")
                }
        }
    }
}

// Simple global error handler - kept as separate class
class ErrorManager {
    private(set) var lastError: String?
    private let logQueue = DispatchQueue(label: "com.garagepicks.errorlog", qos: .background)
    
    init() {
        print("Initializing ErrorManager")
    }
    
    func logError(_ message: String) {
        // Log the error on a background queue to avoid blocking the main thread
        logQueue.async {
            print("ERROR: \(message)")
            DispatchQueue.main.async {
                self.lastError = message
            }
        }
    }
}
