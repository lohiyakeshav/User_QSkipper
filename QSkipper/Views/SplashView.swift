//
//  SplashView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var isActive = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Image("splash_background")
                    .resizable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaledToFill()
                    .ignoresSafeArea()
                
                Image("Logo")
                    .resizable()
                    .frame(width: 120, height: 130)
                    .padding(.bottom, 60)
            }
            .onAppear {
                print("SplashView appeared")
                // Navigate to next screen after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    print("Timer completed, setting isActive to true")
                    withAnimation {
                        isActive = true
                    }
                }
            }
            .navigationBarHidden(true)
            .navigation(isActive: $isActive) {
                if authManager.isLoggedIn {
                    HomeView()
                } else {
                    StartView()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Extension to simplify navigation
extension View {
    func navigation<Destination: View>(isActive: Binding<Bool>, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        overlay(
            NavigationLink(
                destination: isActive.wrappedValue ? destination() : nil,
                isActive: isActive,
                label: { EmptyView() }
            )
            .hidden()
        )
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
            .environmentObject(AuthManager.shared)
    }
} 
