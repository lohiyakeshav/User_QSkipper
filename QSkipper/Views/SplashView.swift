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
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                
                // Loading indicator or error at bottom
                VStack {
                    Spacer()
                    
                    if preloadManager.isLoading {
                        VStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Loading...")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.bottom, 80)
                    } else if showError {
                        VStack(spacing: 15) {
                            Text("Connection Error")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                            
                            Text(errorMessage)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                            
                            Button(action: {
                                startPreloading()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(25)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
            .onAppear {
                print("SplashView appeared")
                startPreloading()
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
    
    private func startPreloading() {
        // Reset error state
        showError = false
        errorMessage = ""
        
        if authManager.isLoggedIn {
            // Set timeout to ensure we don't hang indefinitely
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if preloadManager.isLoading {
                    print("⚠️ Preload timeout reached - proceeding anyway")
                    withAnimation {
                        isActive = true
                    }
                }
            }
            
            Task {
                do {
                    try await preloadManager.preloadData()
                    
                    // Navigate to next screen after data is loaded or after minimum delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("Timer completed, setting isActive to true")
                        withAnimation {
                            isActive = true
                        }
                    }
                } catch {
                    // Handle preload error
                    await MainActor.run {
                        showError = true
                        errorMessage = "Unable to connect to server. Please check your internet connection and try again."
                        print("❌ Preloading error: \(error.localizedDescription)")
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
}

// Manager to preload data during splash screen
class PreloadManager: ObservableObject {
    @Published var topPicks: [Product] = []
    @Published var restaurants: [Restaurant] = []
    @Published var isLoading = true
    @Published var hasError = false
    
    private let networkUtils = NetworkUtils.shared
    
    init() {
        // Initialize with empty arrays to ensure proper published property setup
        self.topPicks = []
        self.restaurants = []
        self.isLoading = true
    }
    
    func preloadData() async throws {
        // Ensure all @Published property access happens on the main thread
        await MainActor.run {
            print("🔄 PreloadManager: Starting preload")
            isLoading = true
            hasError = false
        }
        
        // Use a task group to load data in parallel with timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add task for restaurants
            group.addTask {
                do {
                    await MainActor.run {
                        print("🔄 PreloadManager: Preloading restaurants")
                    }
                    let fetchedRestaurants = try await self.networkUtils.fetchRestaurants()
                    await MainActor.run {
                        self.restaurants = fetchedRestaurants
                        print("✅ PreloadManager: Preloaded \(fetchedRestaurants.count) restaurants")
                    }
                } catch {
                    await MainActor.run {
                        print("❌ PreloadManager: Error preloading restaurants: \(error.localizedDescription)")
                    }
                    throw error
                }
            }
            
            // Add task for top picks
            group.addTask {
                do {
                    await MainActor.run {
                        print("🔄 PreloadManager: Preloading top picks")
                    }
                    let fetchedTopPicks = try await self.networkUtils.fetchTopPicks()
                    await MainActor.run {
                        self.topPicks = fetchedTopPicks
                        print("✅ PreloadManager: Preloaded \(fetchedTopPicks.count) top picks")
                    }
                } catch {
                    await MainActor.run {
                        print("❌ PreloadManager: Error preloading top picks: \(error.localizedDescription)")
                    }
                    throw error
                }
            }
            
            // Wait for all tasks to complete or throw an error
            try await group.waitForAll()
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
