//
//  Constants.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct AppColors {
    static let primaryGreen = Color(hex: "#34C759")
    static let darkGray = Color(hex: "#333333")
    static let lightGray = Color(hex: "#F2F2F2")
    static let mediumGray = Color(hex: "#999999")
    static let errorRed = Color(hex: "#FF3B30")
    static let backgroundWhite = Color.white
}

struct AppFonts {
    // Updated to use Satoshi fonts
    static let title = Font.custom("Satoshi-Bold", size: 24)
    static let subtitle = Font.custom("Satoshi-Medium", size: 18)
    static let body = Font.custom("Satoshi-Regular", size: 16)
    static let caption = Font.custom("Satoshi-Regular", size: 14)
    static let button = Font.custom("Satoshi-Medium", size: 16)
    static let buttonText = Font.custom("Satoshi-Bold", size: 16)
    static let callToAction = Font.custom("Satoshi-Medium", size: 14)
    static let sectionTitle = Font.custom("Satoshi-Bold", size: 18)
    
    // Fallback fonts in case custom fonts fail to load
    static let titleFallback = Font.system(size: 24, weight: .bold)
    static let subtitleFallback = Font.system(size: 18, weight: .semibold)
    static let bodyFallback = Font.system(size: 16, weight: .regular)
    static let captionFallback = Font.system(size: 14, weight: .regular)
    static let buttonFallback = Font.system(size: 16, weight: .semibold)
    static let callToActionFallback = Font.system(size: 14, weight: .medium)
}

struct AppConstants {
    // Default location for Galgotias University
    static let defaultLatitude = 28.4465
    static let defaultLongitude = 77.5131
    static let defaultLocation = "Galgotias University"
    
    // App settings
    static let appName = "QSkipper"
    static let defaultAnimationDuration = 0.3
}

// Extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 