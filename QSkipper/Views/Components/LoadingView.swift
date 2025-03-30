//
//  LoadingView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct LoadingView: View {
    var message: String
    @State private var animationOpacity = 0.0
    @State private var textOpacity = 0.0
    @State private var scale = 0.8
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            // Loading card
            VStack(spacing: 16) {
                // Enhanced loading animation
                LottieWebAnimationView(
                    webURL: "https://lottie.host/58ead3c3-f27b-4622-8361-5dbd66a16314/sIDRKWRbM3.lottie",
                    loopMode: .loop,
                    autoplay: true,
                    contentMode: .scaleAspectFit
                )
                .frame(width: 120, height: 120)
                
                // Message with typing animation
                Text(message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.darkGray)
                    .opacity(textOpacity)
                    .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            )
            .scaleEffect(scale)
            .opacity(animationOpacity)
        }
        .onAppear {
            // Sequence of animations for a polished experience
            withAnimation(.easeOut(duration: 0.2)) {
                animationOpacity = 1.0
                scale = 1.0
            }
            
            // Slightly delayed text animation for a typing effect
            withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
                textOpacity = 1.0
            }
        }
    }
}

// A view modifier to conditionally add a loading overlay
struct LoadingViewModifier: ViewModifier {
    let isLoading: Bool
    let message: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isLoading {
                LoadingView(message: message)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
    }
}

extension View {
    func loading(isLoading: Bool, message: String = "Loading...") -> some View {
        modifier(LoadingViewModifier(isLoading: isLoading, message: message))
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            LoadingView(message: "Processing your request...")
        }
    }
} 