//
//  QButton.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct QButton: View {
    enum ButtonStyle {
        case primary
        case secondary
        case outline
    }
    
    var title: String
    var style: ButtonStyle = .primary
    var isLoading: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            if !isLoading {
                action()
            }
        }) {
            ZStack {
                buttonBackground
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                } else {
                    Text(title)
                        .font(AppFonts.button)
                        .foregroundColor(foregroundColor)
                }
            }
        }
        .frame(height: 50)
        .cornerRadius(10)
        .disabled(isLoading)
    }
    
    private var buttonBackground: some View {
        Group {
            switch style {
            case .primary:
                AppColors.primaryGreen
            case .secondary:
                AppColors.darkGray
            case .outline:
                Color.clear
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.primaryGreen, lineWidth: 1)
                    )
            }
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .secondary:
            return .white
        case .outline:
            return AppColors.primaryGreen
        }
    }
}

struct QButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            QButton(title: "Primary Button", style: .primary) {
                print("Primary button tapped")
            }
            
            QButton(title: "Secondary Button", style: .secondary) {
                print("Secondary button tapped")
            }
            
            QButton(title: "Outline Button", style: .outline) {
                print("Outline button tapped")
            }
            
            QButton(title: "Loading Button", isLoading: true) {
                print("Loading button tapped")
            }
        }
        .padding()
    }
} 