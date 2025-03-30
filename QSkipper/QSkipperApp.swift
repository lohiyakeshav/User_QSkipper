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
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(authManager)
                .environmentObject(orderManager)
                .environmentObject(favoriteManager)
                .environmentObject(locationManager)
        }
    }
}
