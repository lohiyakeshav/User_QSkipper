//
//  SplashView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

// Create a shared background to reuse across views
struct AppBackground: View {
    var body: some View {
        Image("splash_background")
            .resizable()
            .scaledToFill()
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .edgesIgnoringSafeArea(.all)
    }
}

struct SplashView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var isActive = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Image
                AppBackground()
                
                // Logo centered
                VStack {
                    Spacer()
                    
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Navigate to next screen after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
            .background(
                NavigationLink(
                    destination: destinationView,
                    isActive: $isActive,
                    label: { EmptyView() }
                )
            )
        }
        .navigationViewStyle(.stack)
    }
    
    @ViewBuilder
    var destinationView: some View {
        if authManager.isLoggedIn {
            // User is already logged in, navigate to Home
            HomeView()
        } else {
            // User is not logged in, navigate to Welcome screen
            StartView()
                .navigationBarHidden(true)
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
} 