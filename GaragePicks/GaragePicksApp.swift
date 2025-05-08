//
//  GaragePicksApp.swift
//  GaragePicks
//
//  Created by Michael Palenzuela on 4/21/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🚀 Initializing Firebase...")
        FirebaseApp.configure()
        print("✅ Firebase initialized successfully")
        
        // Verify Firebase configuration
        if let app = FirebaseApp.app() {
            print("📱 Firebase app name: \(app.name)")
            print("🔑 Firebase options: \(app.options)")
        } else {
            print("❌ Firebase app not configured properly")
        }
        
        return true
    }
}

@main
struct GaragePicksApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Use a lazy property wrapper instead of static initialization
    private let errorManager = ErrorManager()
    
    // Add state for tracking initialization
    @State private var isInitialized = false
    
    init() {
        // Add any debug logging here
        print("GaragePicksApp initializing...")
        
        // Set up error handling for uncaught exceptions
        NSSetUncaughtExceptionHandler { exception in
            print("UNCAUGHT EXCEPTION: \(exception)")
            print("Reason: \(exception.reason ?? "unknown")")
            print("Stack trace: \(exception.callStackSymbols.joined(separator: "\n"))")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Wrap LoginView in a safe initialization
                if isInitialized {
                    LoginView()
                } else {
                    // Show a loading view until initialization is complete
                    ProgressView("Loading...")
                        .onAppear {
                            // Delay initialization slightly to ensure UI is ready
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // Initialize app safely
                                print("Safe initialization starting...")
                                isInitialized = true
                                print("Safe initialization complete")
                            }
                        }
                }
            }
            .onAppear {
                print("GaragePicksApp appeared successfully")
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
