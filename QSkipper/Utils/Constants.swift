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
    // Using system fonts instead of custom Satoshi fonts
    static let title = Font.system(size: 24, weight: .bold)
    static let subtitle = Font.system(size: 18, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let caption = Font.system(size: 14, weight: .regular)
    static let button = Font.system(size: 16, weight: .semibold)
    static let buttonText = Font.system(size: 16, weight: .bold)
    static let callToAction = Font.system(size: 14, weight: .medium)
    static let sectionTitle = Font.system(size: 18, weight: .bold)
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