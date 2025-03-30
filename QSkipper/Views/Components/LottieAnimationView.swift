//
//  LottieAnimationView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 28/03/25.
//

import SwiftUI

// Enhanced animated loading view with microanimations
struct LottieWebAnimationView: View {
    let webURL: String
    let loopMode: LoopMode
    let autoplay: Bool
    let contentMode: UIView.ContentMode
    
    @State private var isAnimating = false
    @State private var pulsate = false
    @State private var rotationAngle = 0.0
    
    init(
        webURL: String = "https://lottie.host/20b64309-9089-4464-a4c5-f9a1ab3dbba1/l5b3WsrLuK.lottie",
        loopMode: LoopMode = .loop,
        autoplay: Bool = true,
        contentMode: UIView.ContentMode = .scaleAspectFit
    ) {
        self.webURL = webURL
        self.loopMode = loopMode
        self.autoplay = autoplay
        self.contentMode = contentMode
    }
    
    var body: some View {
        ZStack {
            // Outer pulsating circle
            Circle()
                .fill(AppColors.primaryGreen.opacity(0.15))
                .frame(width: pulsate ? 160 : 150, height: pulsate ? 160 : 150)
                .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulsate)
            
            // Inner circle
            Circle()
                .fill(AppColors.primaryGreen.opacity(0.3))
                .frame(width: 120, height: 120)
            
            // Multiple rotating elements for a more dynamic effect
            ForEach(0..<3) { index in
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .stroke(AppColors.primaryGreen, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 100 - CGFloat(index * 20), height: 100 - CGFloat(index * 20))
                    .rotationEffect(.degrees(rotationAngle + Double(index * 120)))
            }
            
            // Center icon
            Image(systemName: "arrow.triangle.2.circlepath")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(AppColors.primaryGreen)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 2)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
            pulsate = true
            
            // Create a continuous rotation animation
            withAnimation(Animation.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// Simple enum to mimic lottie functionality
enum LoopMode {
    case loop
    case playOnce
    case autoReverse
}

struct LottieWebAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            LottieWebAnimationView()
                .frame(width: 200, height: 200)
        }
    }
} 