//
//  QSkipperApp.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

@main
struct QSkipperApp: App {
    // Initialize shared state managers
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var orderManager = OrderManager.shared
    @StateObject private var favoriteManager = FavoriteManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var tabSelection = TabSelection()
    
    init() {
        // Pre-initialize image cache
        let _ = ImageCache.shared
        
        // Ensure server connectivity is checked early
        Task {
            print("🌐 Performing initial connectivity check...")
            let isConnected = await NetworkDiagnostics.shared.checkConnectivity()
            print("🌐 Initial connectivity check result: \(isConnected ? "Connected" : "Disconnected")")
        }
        
        // Initialize API client to prepare for network requests
        let _ = APIClient.shared
        
        print("📱 QSkipper App initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(authManager)
                .environmentObject(orderManager)
                .environmentObject(favoriteManager)
                .environmentObject(locationManager)
                .environmentObject(tabSelection)
                .preferredColorScheme(.light)
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 0)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 1)
                }
                .onAppear {
                    print("📱 App window appeared - setting up initial UI state")
                }
        }
    }
}
