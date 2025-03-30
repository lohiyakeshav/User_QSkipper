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
            .alert(isPresented: isPresented) {
                Alert(
                    title: Text("Error"),
                    message: Text(error ?? "An unknown error occurred"),
                    dismissButton: .default(Text(buttonTitle)) {
                        onDismiss?()
                    }
                )
            }
    }
}

extension View {
    func errorAlert(error: String?, isPresented: Binding<Bool>, buttonTitle: String = "OK", onDismiss: (() -> Void)? = nil) -> some View {
        self.modifier(ErrorAlert(error: error, isPresented: isPresented, buttonTitle: buttonTitle, onDismiss: onDismiss))
    }
} 