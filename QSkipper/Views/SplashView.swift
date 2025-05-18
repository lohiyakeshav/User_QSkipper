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
    @StateObject private var preloadManager = PreloadManager()
    
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
                    .frame(width: 140, height: 140)
                    .padding(.bottom, 60)
                
                // Loading indicator at bottom
                if preloadManager.isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .padding(.bottom, 80)
                    }
                }
            }
            .onAppear {
                print("SplashView appeared")
                
                // Start preloading data
                if authManager.isLoggedIn {
                    Task {
                        await preloadManager.preloadData()
                        
                        // Navigate to next screen after data is loaded or after minimum delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            print("Timer completed, setting isActive to true")
                            withAnimation {
                                isActive = true
                            }
                        }
                    }
                } else {
                    // If not logged in, just show splash for fixed time
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    print("Timer completed, setting isActive to true")
                    withAnimation {
                        isActive = true
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigation(isActive: $isActive) {
                if authManager.isLoggedIn {
                    HomeView()
                        .environmentObject(preloadManager)
                } else {
                    StartView()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Manager to preload data during splash screen
class PreloadManager: ObservableObject {
    @Published var topPicks: [Product] = []
    @Published var restaurants: [Restaurant] = []
    @Published var isLoading = true
    
    private let networkUtils = NetworkUtils.shared
    
    init() {
        // Initialize with empty arrays to ensure proper published property setup
        self.topPicks = []
        self.restaurants = []
        self.isLoading = true
    }
    
    func preloadData() async {
        // Ensure all @Published property access happens on the main thread
        await MainActor.run {
            print("🔄 PreloadManager: Starting preload")
            isLoading = true
        }
        
        // First load top picks
        do {
            // Log outside MainActor is fine for non-published properties
            await MainActor.run {
                print("🔄 PreloadManager: Preloading top picks")
            }
            let fetchedTopPicks = try await networkUtils.fetchTopPicks()
            await MainActor.run {
                self.topPicks = fetchedTopPicks
                print("✅ PreloadManager: Preloaded \(fetchedTopPicks.count) top picks")
            }
        } catch {
            await MainActor.run {
                print("❌ PreloadManager: Error preloading top picks: \(error.localizedDescription)")
            }
        }
        
        // Then load restaurants
        do {
            await MainActor.run {
                print("🔄 PreloadManager: Preloading restaurants")
            }
            let fetchedRestaurants = try await networkUtils.fetchRestaurants()
            await MainActor.run {
                self.restaurants = fetchedRestaurants
                print("✅ PreloadManager: Preloaded \(fetchedRestaurants.count) restaurants")
            }
        } catch {
            await MainActor.run {
                print("❌ PreloadManager: Error preloading restaurants: \(error.localizedDescription)")
            }
        }
        
        // Mark loading as complete
        await MainActor.run {
            isLoading = false
            print("✅ PreloadManager: Preloading completed")
        }
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
