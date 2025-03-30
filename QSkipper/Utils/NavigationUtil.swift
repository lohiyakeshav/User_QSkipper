//
//  NavigationUtil.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

/// Utility for programmatic SwiftUI navigation
struct NavigationUtil {
    /// Navigate to a view programmatically without a NavigationLink
    static func navigate<T: View>(to view: T) {
        // Get the root view controller
        if let window = UIApplication.shared.windows.first,
           let rootViewController = window.rootViewController {
            
            // Create a hosting controller for the SwiftUI view
            let hostingController = UIHostingController(rootView: view)
            
            // Recursively find the topmost presented view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            // Find the navigation controller
            if let navigationController = topController as? UINavigationController {
                // Push the view using the navigation controller
                navigationController.pushViewController(hostingController, animated: true)
            } else if let navigationController = topController.navigationController {
                // Push the view using the parent navigation controller
                navigationController.pushViewController(hostingController, animated: true)
            } else {
                // Present the view modally if no navigation controller is found
                topController.present(hostingController, animated: true)
            }
        }
    }
    
    /// Pop the current view from the navigation stack
    static func pop() {
        if let window = UIApplication.shared.windows.first,
           let rootViewController = window.rootViewController {
            
            // Recursively find the topmost presented view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            // Find the navigation controller
            if let navigationController = topController as? UINavigationController {
                // Pop the view using the navigation controller
                navigationController.popViewController(animated: true)
            } else if let navigationController = topController.navigationController {
                // Pop the view using the parent navigation controller
                navigationController.popViewController(animated: true)
            } else {
                // Dismiss the view if it was presented modally
                topController.dismiss(animated: true)
            }
        }
    }
} 