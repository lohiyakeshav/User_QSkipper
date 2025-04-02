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
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(authManager)
                .environmentObject(orderManager)
                .environmentObject(favoriteManager)
                .environmentObject(locationManager)
                .environmentObject(tabSelection)
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 0)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 1)
                }
        }
    }
}
