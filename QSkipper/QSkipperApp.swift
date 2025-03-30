//
//  QSkipperApp.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI
import CoreText

@main
struct QSkipperApp: App {
    // Initialize shared state managers
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var orderManager = OrderManager.shared
    @StateObject private var favoriteManager = FavoriteManager.shared
    @StateObject private var locationManager = LocationManager.shared
    
    init() {
        // Register custom Satoshi fonts
        registerFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(authManager)
                .environmentObject(orderManager)
                .environmentObject(favoriteManager)
                .environmentObject(locationManager)
        }
    }
    
    // Function to register custom fonts
    private func registerFonts() {
        // Attempt to programmatically register fonts from the bundle
        let fontNames = [
            "SatoshiRegular.otf",
            "SatoshiMedium.otf", 
            "SatoshiMediumItalic.otf",
            "SatoshiItalic.otf",
            "SatoshiLight.otf",
            "SatoshiLightItalic.otf", 
            "SatoshiBlackItalic.otf",
            "SatoshiBold.otf",
            "SatoshiBoldItalic.otf",
            "SatoshiBlack.otf"
        ]
        
        fontNames.forEach { fontName in
            // Look for font in the bundle resources first
            if let fontURL = Bundle.main.url(forResource: fontName.components(separatedBy: ".").first, withExtension: "otf") {
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            } else {
                // Try to find it in the Core/Fonts directory
                if let fontURL = Bundle.main.url(forResource: "Core/Fonts/\(fontName.components(separatedBy: ".").first!)", withExtension: "otf") {
                    CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
                } else {
                    print("⚠️ Failed to load font: \(fontName)")
                }
            }
        }
        
        // Print registered font names for debugging
        #if DEBUG
        for family in UIFont.familyNames.sorted() {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family).sorted() {
                print("   Font: \(name)")
            }
        }
        #endif
    }
}
