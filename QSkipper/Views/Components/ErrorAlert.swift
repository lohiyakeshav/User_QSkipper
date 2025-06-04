//
//  ErrorAlert.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct ErrorAlert: ViewModifier {
    var error: String?
    var isPresented: Binding<Bool>
    var buttonTitle: String
    var onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert(
                determineAlertTitle(from: error),
                isPresented: isPresented,
                actions: {
                    Button(buttonTitle) {
                        onDismiss?()
                    }
                },
                message: {
                    Text(error ?? "An unknown error occurred")
                }
            )
    }
    
    // Helper function to determine a more specific alert title
    private func determineAlertTitle(from error: String?) -> String {
        guard let errorMessage = error else { return "Error" }
        
        if errorMessage.contains("Email already registered") {
            return "Account Exists"
        } else if errorMessage.contains("conflict") || errorMessage.contains("409") {
            return "Account Exists"
        } else if errorMessage.contains("Server error") || errorMessage.contains("500") {
            return "Server Error"
        } else if errorMessage.contains("network") || errorMessage.contains("connection") || 
                  errorMessage.contains("offline") || errorMessage.contains("internet") {
            return "Connection Issue"
        } else if errorMessage.contains("verification") || errorMessage.contains("OTP") {
            return "Verification Error"
        } else if errorMessage.contains("Invalid") {
            return "Validation Error"
        } else {
            return "Error"
        }
    }
}

extension View {
    func errorAlert(error: String?, isPresented: Binding<Bool>, buttonTitle: String = "OK", onDismiss: (() -> Void)? = nil) -> some View {
        self.modifier(ErrorAlert(error: error, isPresented: isPresented, buttonTitle: buttonTitle, onDismiss: onDismiss))
    }
} 