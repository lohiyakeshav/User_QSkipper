//
//  HomeView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

// Update the Tab enum to remove the search option
enum Tab {
    case home
    case favorites
    case orders
    case profile
}

// Add FavoriteManager to manage favorite dishes
class FavoriteManager: ObservableObject {
    static let shared = FavoriteManager()
    
    @Published var favoriteDishes: [Product] = []
    
    private let userDefaultsKey = "favoriteDishes"
    
    // Add notification name for favorite status changes
    static let favoriteStatusChangedNotification = NSNotification.Name("FavoriteStatusChanged")
    
    init() {
        loadFavorites()
    }
    
    func toggleFavorite(_ product: Product) {
        if isFavorite(product) {
            // Remove from favorites
            favoriteDishes.removeAll { $0.id == product.id }
        } else {
            // Add to favorites
            favoriteDishes.append(product)
        }
        saveFavorites()
        
        // Post notification that favorite status changed
        NotificationCenter.default.post(name: FavoriteManager.favoriteStatusChangedNotification, object: product.id)
    }
    
    func isFavorite(_ product: Product) -> Bool {
        return favoriteDishes.contains { $0.id == product.id }
    }
    
    private func saveFavorites() {
        if let encodedData = try? JSONEncoder().encode(favoriteDishes) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsKey)
        }
    }
    
    private func loadFavorites() {
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedProducts = try? JSONDecoder().decode([Product].self, from: savedData) {
            favoriteDishes = decodedProducts
        }
    }
}

class HomeViewModel: ObservableObject {
    private let restaurantManager = RestaurantManager.shared
    private let networkUtils = NetworkUtils.shared
    private let networkDiagnostics = NetworkDiagnostics.shared
    
    @Published var restaurants: [Restaurant] = []
    @Published var topPicks: [Product] = []
    @Published var cuisines: [String] = []
    
    @Published var isLoading: Bool = false
    @Published var isLoadingTopPicks: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false
    @Published var lastRefreshTime: Date = Date()
    @Published var isConnected: Bool = true
    
    // Cache and cooldown management
    private var lastTopPicksRefreshTime: TimeInterval = 0
    private var lastRestaurantsRefreshTime: TimeInterval = 0
    private let cooldownPeriod: TimeInterval = 60 // 60 seconds cooldown
    
    // Keep track of restaurant detail requests to avoid duplicates
    private var lastRestaurantDetailRequests: [String: TimeInterval] = [:]
    private let restaurantDetailCooldown: TimeInterval = 120 // 2 minutes between detail requests
    
    // Store restaurant details to avoid repeated API calls
    private var restaurantDetailsCache: [String: Restaurant] = [:]
    private var pendingRestaurantRequests: Set<String> = []
    
    // Maximum number of retries for network operations
    private let maxRetries = 3
    
    // Initialize with connectivity monitoring
    init() {
        // Start monitoring network connectivity
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        // Check initial connectivity
        Task {
            let isNetworkAvailable = await networkDiagnostics.checkConnectivity()
            await MainActor.run {
                self.isConnected = isNetworkAvailable
                print("🌐 Initial network connectivity: \(isNetworkAvailable ? "Connected" : "Disconnected")")
                
                // Set appropriate error message if disconnected
                if !isNetworkAvailable {
                    self.errorMessage = "No internet connection. Please check your connection and try again."
                    self.showError = true
                }
            }
        }
        
        // Setup periodic connectivity checks
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                let isNetworkAvailable = await self.networkDiagnostics.checkConnectivity()
                await MainActor.run {
                    // Only update if connectivity status has changed
                    if self.isConnected != isNetworkAvailable {
                        self.isConnected = isNetworkAvailable
                        print("🌐 Network connectivity changed: \(isNetworkAvailable ? "Connected" : "Disconnected")")
                        
                        if !isNetworkAvailable {
                            self.errorMessage = "No internet connection. Please check your connection and try again."
                            self.showError = true
                        } else if self.errorMessage?.contains("internet connection") == true {
                            // Clear network-related error if we're back online
                            self.errorMessage = nil
                            self.showError = false
                        }
                    }
                }
            }
        }
    }
    
    // Helper method to batch process restaurant details
    func prefetchRestaurantDetails(for productList: [Product]) async {
        let restaurantIds = Set(productList.map { $0.restaurantId })
        let newRestaurantIds = restaurantIds.filter { 
            restaurantDetailsCache[$0] == nil && !pendingRestaurantRequests.contains($0)
        }
        
        guard !newRestaurantIds.isEmpty else { return }
        
        // Mark all as pending to prevent duplicate requests - do this on main actor
        await MainActor.run {
            for id in newRestaurantIds {
                pendingRestaurantRequests.insert(id)
            }
        }
        
        print("🔍 Prefetching details for \(newRestaurantIds.count) restaurants")
        
        // Process restaurant details sequentially with delay to avoid overwhelming server
        for id in newRestaurantIds {
            do {
                // Skip if we already have the restaurant in main list with good data
                if let existingRestaurant = restaurants.first(where: { $0.id == id }), 
                   existingRestaurant.name != "Restaurant" {
                    await MainActor.run {
                        restaurantDetailsCache[id] = existingRestaurant
                        pendingRestaurantRequests.remove(id)
                    }
                    continue
                }
                
                // Only make API call if we should fetch this restaurant
                let shouldFetch = await shouldFetchRestaurantDetails(forId: id)
                if shouldFetch {
                    // Try with retries for reliability
                    var retryCount = 0
                    var success = false
                    
                    while !success && retryCount < maxRetries {
                        do {
                            let restaurant = try await networkUtils.fetchRestaurant(with: id)
                            await MainActor.run {
                                restaurantDetailsCache[id] = restaurant
                                success = true
                            }
                        } catch {
                            retryCount += 1
                            if retryCount >= maxRetries {
                                print("⚠️ Failed to fetch restaurant \(id) after \(maxRetries) attempts: \(error.localizedDescription)")
                                // Log error but don't throw since this is a background prefetch operation
                                // and shouldn't fail the parent operation
                                success = false
                                break
                            }
                            
                            // Exponential backoff: 0.5s, 1s, 2s
                            let delay = TimeInterval(0.5 * pow(2.0, Double(retryCount - 1)))
                            print("⚠️ Retry \(retryCount)/\(maxRetries) for restaurant \(id) after \(delay)s")
                            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                    
                    // Add a small delay between requests
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                }
            } catch {
                print("⚠️ Failed to fetch restaurant \(id): \(error.localizedDescription)")
            }
            
            // Remove from pending regardless of success/failure - on main actor
            await MainActor.run {
                pendingRestaurantRequests.remove(id)
            }
        }
    }
    
    // Load all restaurants
    @MainActor
    func loadRestaurants() async {
        // First check network connectivity
        if !isConnected {
            errorMessage = "No internet connection. Please check your connection and try again."
            showError = true
            isLoading = false
            return
        }
        
        // Check cooldown timer
        let now = Date().timeIntervalSince1970
        if now - lastRestaurantsRefreshTime < cooldownPeriod && !restaurants.isEmpty {
            print("⏱️ Restaurant refresh cooldown active. Using cached data. Next refresh available in \(Int(cooldownPeriod - (now - lastRestaurantsRefreshTime)))s")
            isLoading = false
            return
        }
        
        // Prevent concurrent restaurant loads
        if isLoading {
            print("⚠️ Already loading restaurants, skipping duplicate request")
            return
        }
        
        // Set loading state but DON'T clear existing data
        isLoading = true
        errorMessage = nil
        showError = false
        
        // Store current data for rollback if needed
        let previousRestaurants = self.restaurants
        
        do {
            print("📡 HomeViewModel: Loading restaurants...")
            
            // Try with retries for reliability
            var retryCount = 0
            var fetchedRestaurants: [Restaurant] = []
            var lastError: Error? = nil
            
            while retryCount < maxRetries {
                do {
                    fetchedRestaurants = try await restaurantManager.fetchAllRestaurants()
                    
                    // Success, exit retry loop
                    print("✅ Successfully loaded \(fetchedRestaurants.count) restaurants on attempt \(retryCount + 1)")
                    break
                } catch {
                    retryCount += 1
                    lastError = error
                    print("⚠️ Error on attempt \(retryCount): \(error.localizedDescription)")
                    
                    // If this is our last retry, don't delay
                    if retryCount >= maxRetries {
                        print("❌ All \(maxRetries) attempts failed for restaurants")
                        break
                    }
                    
                    // Exponential backoff: 0.5s, 1s, 2s
                    let delay = TimeInterval(0.5 * pow(2.0, Double(retryCount - 1)))
                    print("⏱️ Retry \(retryCount)/\(maxRetries) after \(delay)s")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
            
            // Only update UI if we got new data
            if !fetchedRestaurants.isEmpty {
                self.restaurants = fetchedRestaurants
                
                // Update cache with fetched restaurants
                for restaurant in fetchedRestaurants {
                    restaurantDetailsCache[restaurant.id] = restaurant
                }
                
                // Extract cuisines after loading restaurants
                extractCuisines()
                lastRefreshTime = Date()
                lastRestaurantsRefreshTime = now
                print("✅ Updated UI with new restaurant data: \(fetchedRestaurants.count) items")
            } else if let error = lastError {
                // We exhausted retries and still have an error - set error state instead of throwing
                if error.localizedDescription.contains("offline") || 
                   error.localizedDescription.contains("network connection") ||
                   error.localizedDescription.contains("The Internet connection appears to be offline") {
                    errorMessage = "No internet connection. Please check your connection and try again."
                } else {
                    errorMessage = "Could not load restaurants: \(error.localizedDescription)"
                }
                showError = true
                print("❌ HomeViewModel: All restaurant retries failed: \(error.localizedDescription)")
                
                // Note: We're keeping the old data visible, so we don't clear restaurants here
                print("✅ Keeping existing data: \(previousRestaurants.count) restaurants")
            } else {
                // We got an empty response but no error - very unlikely
                print("⚠️ Empty restaurants response without error - keeping existing data")
            }
            
            isLoading = false
        } catch {
            print("❌ Error loading restaurants: \(error.localizedDescription)")
            
            if error.localizedDescription.contains("offline") || 
               error.localizedDescription.contains("network connection") ||
               error.localizedDescription.contains("The Internet connection appears to be offline") {
                errorMessage = "No internet connection. Please check your connection and try again."
            } else {
                errorMessage = "Could not load restaurants: \(error.localizedDescription)"
            }
            
            showError = true
            isLoading = false
            
            // Don't clear existing data on error
            print("✅ Keeping existing data after error: \(previousRestaurants.count) restaurants")
        }
    }
    
    // Extract unique cuisines from restaurants
    func extractCuisines() {
        var uniqueCuisines = Set<String>()
        
        // Collect all cuisines and filter out nil or empty values
        for restaurant in restaurants {
            if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                uniqueCuisines.insert(cuisine)
            }
        }
        
        // Convert to array and sort alphabetically
        cuisines = Array(uniqueCuisines).sorted()
    }
    
    func loadTopPicks() async {
        // First check network connectivity
        await MainActor.run {
            if !isConnected {
                errorMessage = "No internet connection. Please check your connection and try again."
                showError = true
                isLoadingTopPicks = false
                return
            }
        }
        
        // Check cooldown timer
        let now = Date().timeIntervalSince1970
        if now - lastTopPicksRefreshTime < cooldownPeriod && !topPicks.isEmpty {
            print("⏱️ TopPicks refresh cooldown active. Using cached data. Next refresh available in \(Int(cooldownPeriod - (now - lastTopPicksRefreshTime)))s")
            await MainActor.run {
                isLoadingTopPicks = false
            }
            return
        }
        
        // Store current data for possible rollback
        let previousTopPicks = await MainActor.run { self.topPicks }
        
        let isAlreadyLoading = await MainActor.run {
            let currentlyLoading = isLoadingTopPicks
            if !currentlyLoading {
                isLoadingTopPicks = true
                errorMessage = nil
            }
            return currentlyLoading
        }
        
        if isAlreadyLoading {
            print("⚠️ HomeViewModel: Already loading top picks, skipping duplicate request")
            return
        }
        
        do {
            print("📡 HomeViewModel: Fetching top picks from network")
            
            // Try with retries for reliability
            var retryCount = 0
            var fetchedTopPicks: [Product] = []
            var lastError: Error? = nil
            
            while retryCount < maxRetries {
                do {
                    fetchedTopPicks = try await networkUtils.fetchTopPicks()
                    
                    // Success, exit retry loop
                    print("✅ Successfully loaded \(fetchedTopPicks.count) top picks on attempt \(retryCount + 1)")
                    break
                } catch {
                    retryCount += 1
                    lastError = error
                    print("⚠️ Error on attempt \(retryCount): \(error.localizedDescription)")
                    
                    // If this is our last retry, don't delay
                    if retryCount >= maxRetries {
                        print("❌ All \(maxRetries) attempts failed for top picks")
                        break
                    }
                    
                    // Exponential backoff: 0.5s, 1s, 2s
                    let delay = TimeInterval(0.5 * pow(2.0, Double(retryCount - 1)))
                    print("⏱️ Retry \(retryCount)/\(maxRetries) after \(delay)s")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
            
            // Prefetch restaurant details for top picks to avoid redundant calls
            if !fetchedTopPicks.isEmpty {
                Task {
                    await prefetchRestaurantDetails(for: fetchedTopPicks)
                }
            }
            
            await MainActor.run {
                print("✅ HomeViewModel: Successfully loaded \(fetchedTopPicks.count) top picks")
                
                // Check if we have data after retries
                if !fetchedTopPicks.isEmpty {
                    // Only update if we got non-empty results
                    self.topPicks = fetchedTopPicks
                    lastTopPicksRefreshTime = now
                    print("✅ Updated UI with new top picks data: \(fetchedTopPicks.count) items")
                } else if let error = lastError {
                    // We exhausted retries and still have an error - set error state instead of throwing
                    if error.localizedDescription.contains("offline") || 
                       error.localizedDescription.contains("network connection") ||
                       error.localizedDescription.contains("The Internet connection appears to be offline") {
                        errorMessage = "No internet connection. Please check your connection and try again."
                    } else {
                        errorMessage = "Could not load top picks: \(error.localizedDescription)"
                    }
                    showError = true
                    print("❌ HomeViewModel: All retries failed: \(error.localizedDescription)")
                    
                    // Keep showing existing data
                    print("✅ Keeping existing data: \(self.topPicks.count) top picks")
                } else {
                    print("⚠️ HomeViewModel: Received empty top picks array")
                    // Keep existing top picks if they exist
                    if self.topPicks.isEmpty {
                        print("⚠️ HomeViewModel: No existing top picks, keeping empty array")
                    } else {
                        print("⚠️ HomeViewModel: Keeping existing \(self.topPicks.count) top picks")
                    }
                }
                
                isLoadingTopPicks = false
                lastRefreshTime = Date()
            }
        } catch {
            print("❌ HomeViewModel: Error loading top picks: \(error.localizedDescription)")
            
            await MainActor.run {
                // Only show error message if we don't have existing data
                if topPicks.isEmpty {
                    if error.localizedDescription.contains("offline") || 
                       error.localizedDescription.contains("network connection") ||
                       error.localizedDescription.contains("The Internet connection appears to be offline") {
                        errorMessage = "No internet connection. Please check your connection and try again."
                    } else {
                        errorMessage = "Could not load top picks: \(error.localizedDescription)"
                    }
                    showError = true
                } else {
                    print("⚠️ HomeViewModel: Error refreshing, but keeping existing \(self.topPicks.count) top picks")
                }
                isLoadingTopPicks = false
            }
        }
    }
    
    // Helper method to find the restaurant a product belongs to
    func getRestaurantForProduct(_ product: Product) -> Restaurant {
        // First check cached restaurant details
        if let cachedRestaurant = restaurantDetailsCache[product.restaurantId] {
            return cachedRestaurant
        }
        
        // Next try to find the restaurant in the main list
        if let restaurant = restaurants.first(where: { $0.id == product.restaurantId }) {
            // Cache for future use
            restaurantDetailsCache[product.restaurantId] = restaurant
            return restaurant
        }
        
        // Create a local copy of the restaurant ID to avoid capture issues
        let restaurantId = product.restaurantId
        
        // Launch a background task to fetch the restaurant details
        // We'll do this without checking shouldFetchRestaurantDetails first
        // since that now requires async/await which we can't do in a sync method
        Task {
            // Make the check inside the task instead
            if !pendingRestaurantRequests.contains(restaurantId) {
                let shouldFetch = await shouldFetchRestaurantDetails(forId: restaurantId)
                if shouldFetch {
                    await MainActor.run {
                        // Add to pending requests on main thread to prevent race conditions
                        pendingRestaurantRequests.insert(restaurantId)
                    }
                    
                    do {
                        let restaurant = try await networkUtils.fetchRestaurant(with: restaurantId)
                        await MainActor.run {
                            restaurantDetailsCache[restaurantId] = restaurant
                            // Remove from pending requests on main thread to avoid thread conflicts
                            pendingRestaurantRequests.remove(restaurantId)
                        }
                    } catch {
                        print("⚠️ Failed to fetch restaurant \(restaurantId): \(error.localizedDescription)")
                        // Make sure to always remove from pending on main thread
                        await MainActor.run {
                            pendingRestaurantRequests.remove(restaurantId)
                        }
                    }
                }
            }
        }
        
        // If not found, create a fallback restaurant object with minimal info
        return Restaurant(
            id: product.restaurantId, 
            name: "Restaurant", 
            estimatedTime: "30-40 mins",
            cuisine: product.category,
            photoId: nil,
            rating: product.rating,
            location: "Unknown location"
        )
    }
    
    // ADDED: Check if we should fetch restaurant details
    @MainActor
    func shouldFetchRestaurantDetails(forId restaurantId: String) -> Bool {
        let now = Date().timeIntervalSince1970
        if let lastRequestTime = lastRestaurantDetailRequests[restaurantId] {
            let timeElapsed = now - lastRequestTime
            if timeElapsed < restaurantDetailCooldown {
                print("⏱️ Restaurant detail cooldown for \(restaurantId). Next fetch in \(Int(restaurantDetailCooldown - timeElapsed))s")
                return false
            }
        }
        
        lastRestaurantDetailRequests[restaurantId] = now
        return true
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var orderManager = OrderManager.shared
    @StateObject private var favoriteManager = FavoriteManager.shared
    @EnvironmentObject private var preloadManager: PreloadManager
    @State private var showLocationPicker = false
    @State private var isLoadingLocation = false
    @State private var selectedTab: Tab = .home
    @State private var showCartSheet = false
    @State private var searchText = ""
    @State private var selectedCuisine: String? = nil
    @State private var isSearching = false
    @State private var isPullingToRefresh = false
    @State private var lastRefreshActionTime = Date().timeIntervalSince1970 - 60
    @State private var initialLoadStarted = false // Track if initial load has started
    @FocusState private var isSearchFieldFocused: Bool
    
    // Increase minimum refresh interval to prevent excessive refreshes
    private let minRefreshInterval: TimeInterval = 60 // 60 seconds between refreshes
    
    // Initializer to set initial loading states
    init() {
        let viewModel = HomeViewModel()
        viewModel.isLoading = true
        viewModel.isLoadingTopPicks = true
        
        // Use underscore to set the StateObject's wrapped value directly
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var filteredRestaurants: [Restaurant] {
        var result = viewModel.restaurants
        
        // Filter by search text if provided
        if !searchText.isEmpty {
            result = result.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        
        // Filter by selected cuisine if one is selected
        if let cuisine = selectedCuisine, !cuisine.isEmpty {
            result = result.filter { $0.cuisine?.lowercased() == cuisine.lowercased() }
        }
        
        return result
    }
    
    var body: some View {
        ZStack {
            // Main content based on selected tab
            Group {
                switch selectedTab {
                case .home:
                    homeContent
                        .navigationBarHidden(true)
                        .onAppear {
                            // Set loading indicators and start data fetch on first appearance
                            if !initialLoadStarted {
                                viewModel.isLoading = true
                                viewModel.isLoadingTopPicks = true
                                initialLoadStarted = true
                                loadData()
                            }
                        }
                case .favorites:
                    FavoritesView()
                        .environmentObject(favoriteManager)
                        .environmentObject(orderManager)
                        .environmentObject(TabSelection.shared)
                        .navigationBarHidden(true)
                case .orders:
                    UserOrdersView()
                        .environmentObject(orderManager)
                        .environmentObject(TabSelection.shared)
                        .navigationBarHidden(true)
                case .profile:
                    ProfileView()
                        .navigationBarHidden(true)
                }
            }
            
            // Custom Tab Bar Overlay
            VStack {
                Spacer()
                
                // Custom Tab Bar
                HStack(spacing: 0) {
                    TabBarItem(icon: "house.fill", label: "Home", isSelected: selectedTab == .home) {
                        withAnimation {
                            selectedTab = .home
                            TabSelection.shared.selectedTab = .home
                        }
                    }
                    
                    TabBarItem(icon: "heart.fill", label: "Favorites", isSelected: selectedTab == .favorites) {
                        withAnimation {
                            selectedTab = .favorites
                            TabSelection.shared.selectedTab = .favorites
                        }
                    }
                    
                    TabBarItem(icon: "list.bullet", label: "Orders", isSelected: selectedTab == .orders) {
                        withAnimation {
                            selectedTab = .orders
                            TabSelection.shared.selectedTab = .orders
                        }
                    }
                    
                    TabBarItem(icon: "person", label: "Profile", isSelected: selectedTab == .profile) {
                        withAnimation(.easeInOut) {
                            // Debug when switching to profile tab
                            if selectedTab != .profile {
                                print("🔄 Switching to Profile tab")
                                // Debug auth data
                                let userName = AuthManager.shared.getCurrentUserName()
                                let userId = AuthManager.shared.getCurrentUserId()
                                print("👤 User data before tab switch: name=\(userName ?? "nil"), id=\(userId ?? "nil")")
                            }
                            selectedTab = .profile
                            TabSelection.shared.selectedTab = .profile
                        }
                    }
                }
                .padding(.vertical, 15)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: -5)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .background(
            NavigationLink(destination: CartView()
                .environmentObject(orderManager)
                .environmentObject(TabSelection.shared), isActive: $showCartSheet) {
                EmptyView()
            }
        )
        .background(
            NavigationLink(destination: 
                LocationPickerView(onSelect: { newLocation in
                    locationManager.locationName = newLocation
                    isLoadingLocation = false
                    // Dismiss the LocationPickerView
                    showLocationPicker = false
                })
                .navigationBarBackButtonHidden(true)
            , isActive: $showLocationPicker) {
                EmptyView()
            }
        )
        .onAppear {
            print("📱 HomeView: View appeared")
            print("📱 HomeView: Current tab: \(selectedTab)")
            print("🛒 HomeView: Cart sheet state: \(showCartSheet)")
            
            loadData()
            
            // Add notification observer for cart opening
            print("🔔 HomeView: Setting up OpenCart notification observer")
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OpenCart"),
                object: nil,
                queue: .main
            ) { _ in
                print("🔔 HomeView: Received OpenCart notification")
                print("🛒 HomeView: Setting showCartSheet to true")
                showCartSheet = true
            }
            
            // Add notification observer for switching to Home tab from cart view
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SwitchToHomeTab"),
                object: nil,
                queue: .main
            ) { _ in
                print("🔔 HomeView: Received SwitchToHomeTab notification")
                withAnimation {
                    selectedTab = .home
                    TabSelection.shared.selectedTab = .home
                }
            }
        }
        .onDisappear {
            print("📱 HomeView: View disappeared")
            print("🔔 HomeView: Removing notification observers")
            // Remove notification observers when view disappears
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("OpenCart"),
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("SwitchToHomeTab"),
                object: nil
            )
        }
        .onChange(of: selectedTab) { newTab in
            print("🔄 HomeView: Tab changed to: \(newTab)")
        }
        .onChange(of: TabSelection.shared.selectedTab) { newTab in
            print("🔄 HomeView: TabSelection.shared changed to: \(newTab)")
            
            // Ensure local state stays in sync with shared state
            // Convert TabSelection.Tab to local Tab enum
            let localTab: Tab
            switch newTab {
            case .home:
                localTab = .home
            case .favorites:
                localTab = .favorites
            case .orders:
                localTab = .orders
            case .profile:
                localTab = .profile
            }
            
            if localTab != selectedTab {
                withAnimation {
                    selectedTab = localTab
                }
            }
        }
        .onChange(of: showCartSheet) { newValue in
            print("🛒 HomeView: Cart sheet state changed to: \(newValue)")
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loadData() {
        Task {
            // Check if we should debounce this refresh action
            let currentTime = Date().timeIntervalSince1970
            if currentTime - lastRefreshActionTime < minRefreshInterval {
                print("⏱️ Refresh action debounced - too soon since last refresh (\(Int(currentTime - lastRefreshActionTime))s). Need to wait \(Int(minRefreshInterval - (currentTime - lastRefreshActionTime)))s more.")
                
                // Still set loading to false to avoid UI getting stuck
                await MainActor.run {
                    viewModel.isLoading = false
                    viewModel.isLoadingTopPicks = false
                    isPullingToRefresh = false
                }
                return
            }
            
            // Set loading indicators only after debounce check
            await MainActor.run {
                viewModel.isLoading = true
                viewModel.isLoadingTopPicks = true
            }
            
            // Update the last refresh time BEFORE making any API calls
            await MainActor.run {
                lastRefreshActionTime = currentTime
            }
            
            print("🔄 Loading initial data")
            
            // Start loading both data types in parallel for faster initial load
            async let topPicksTask = loadTopPicksData()
            async let restaurantsTask = loadRestaurantsData()
            
            // Wait for both tasks to complete
            _ = await (topPicksTask, restaurantsTask)
            
            // Always reset the pulling state
            await MainActor.run {
                isPullingToRefresh = false
            }
        }
    }
    
    // Helper method to load top picks
    private func loadTopPicksData() async {
        // Check if preloaded data is available - safely access on MainActor
        let hasPreloadedTopPicks = await MainActor.run {
            return !preloadManager.topPicks.isEmpty
        }
        
        // OPTIMIZATION: Check if we already have top picks loaded in our ViewModel
        let alreadyHasTopPicks = await MainActor.run {
            return !viewModel.topPicks.isEmpty
        }
        
        // TOP PICKS LOADING
        if hasPreloadedTopPicks && !alreadyHasTopPicks {
            await MainActor.run {
                print("✅ Using preloaded top picks: \(preloadManager.topPicks.count) items")
                viewModel.topPicks = preloadManager.topPicks
                viewModel.isLoadingTopPicks = false
            }
        } else if !alreadyHasTopPicks {
            // Only load if absolutely necessary and we don't already have data
            print("🔄 Loading top picks from network (no preloaded or existing data)")
            await viewModel.loadTopPicks()
        } else {
            await MainActor.run {
                viewModel.isLoadingTopPicks = false
            }
            print("✅ Already have top picks loaded - skipping redundant API call")
        }
    }
    
    // Helper method to load restaurants
    private func loadRestaurantsData() async {
        // Small delay to allow UI to render loading indicators
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        // Check if preloaded data is available
        let hasPreloadedRestaurants = await MainActor.run {
            return !preloadManager.restaurants.isEmpty
        }
        
        // Check if we already have restaurants loaded
        let alreadyHasRestaurants = await MainActor.run {
            return !viewModel.restaurants.isEmpty
        }
        
        if hasPreloadedRestaurants && !alreadyHasRestaurants {
            await MainActor.run {
                print("✅ Using preloaded restaurants: \(preloadManager.restaurants.count) items")
                viewModel.restaurants = preloadManager.restaurants
                viewModel.extractCuisines()
                viewModel.isLoading = false
            }
        } else if !alreadyHasRestaurants {
            // Only load if absolutely necessary and we don't already have data
            print("🔄 Loading restaurants from network (no preloaded or existing data)")
            await viewModel.loadRestaurants()
        } else {
            await MainActor.run {
                viewModel.isLoading = false
            }
            print("✅ Already have restaurants loaded - skipping redundant API call")
        }
    }
    
    // Home content view
    private var homeContent: some View {
        NavigationView {
            ScrollView {
                // Pull to refresh control
                GeometryReader { geo in
                    if geo.frame(in: .global).minY > 80 && !isPullingToRefresh && !viewModel.isLoading {
                        Spacer()
                            .onAppear {
                                // Prevent excessive refreshes
                                let currentTime = Date().timeIntervalSince1970
                                if currentTime - lastRefreshActionTime < minRefreshInterval {
                                    print("⏱️ Pull-to-refresh debounced - need to wait \(Int(minRefreshInterval - (currentTime - lastRefreshActionTime)))s more")
                                    return
                                }
                                
                                isPullingToRefresh = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                
                                // Refresh data
                                Task {
                                    await loadData()
                                }
                            }
                    } else if geo.frame(in: .global).minY <= 0 {
                        Spacer()
                            .onAppear {
                                isPullingToRefresh = false
                            }
                    }
                }
                .frame(height: 0)
                
                // Refresh indicator
                if isPullingToRefresh || viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                            .scaleEffect(1.5)
                        Spacer()
                    }
                }
                
                VStack(spacing: 0) {
                    // Top bar with location and cart
                    HStack {
                        // Location selector button
                        Button {
                            isLoadingLocation = true
                            showLocationPicker = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ORDER FROM")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                    
                                    HStack(spacing: 4) {
                                        Text("\(locationManager.locationName)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.black)
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.black)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        
                        Spacer()
                        
                        // Last updated timestamp removed
                        
                        NavigationLink(destination: CartView()
                            .environmentObject(orderManager)
                            .environmentObject(TabSelection.shared)) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColors.primaryGreen)
                                    .frame(width: 20, height: 20)
                                    .padding(8)
                                
                                // Show badge only if items in cart
                                if !orderManager.currentCart.isEmpty {
                                    CartBadge(count: orderManager.getTotalItems())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    .padding(.bottom, 10)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("WHAT'S ON YOUR MIND?", text: $searchText)
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                            .focused($isSearchFieldFocused)
                            .onChange(of: isSearchFieldFocused) { newValue in
                                isSearching = newValue
                            }
                            
                        // Cancel button appears when searching
                        if isSearching {
                            Button {
                                searchText = ""
                                isSearchFieldFocused = false
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.primaryGreen)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 15)
                    .background(AppColors.lightGray)
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                }
                
                // Main scrollable content
                VStack(spacing: 15) {
                    // TOP PICKS SECTION - Always displayed at the top with priority
                    topPicksSection
                      .onAppear {
                          print("📱 Top picks section appeared")
                          // Only refresh if absolutely necessary - when completely empty
                          if viewModel.topPicks.isEmpty && !viewModel.isLoadingTopPicks && 
                             Date().timeIntervalSince1970 - lastRefreshActionTime > minRefreshInterval {
                              Task {
                                  print("🔄 Refreshing top picks from onAppear (empty data)")
                                  // Update refresh time before making the call to prevent simultaneous requests
                                  lastRefreshActionTime = Date().timeIntervalSince1970
                                  await viewModel.loadTopPicks()
                              }
                          } else {
                              print("⏱️ Skipping top picks refresh on section appear - already loaded or in progress")
                          }
                      }
                    
                    // CUISINES SECTION (Horizontal scrolling buttons)
                    cuisinesSection
                    
                    // ALL RESTAURANTS SECTION - Modified for better loading
                    restaurantsSection
                    
                    // Add bottom padding to ensure content isn't hidden behind the tab bar
                    Spacer(minLength: 100)
                }
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                        if isSearchFieldFocused {
                            isSearchFieldFocused = false
                        }
                    }
                )
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside search field
                if isSearchFieldFocused {
                    isSearchFieldFocused = false
                }
            }
            .background(Color.white)
        }
        // Pull to refresh
        .refreshable {
            let currentTime = Date().timeIntervalSince1970
            if currentTime - lastRefreshActionTime < minRefreshInterval {
                print("⏱️ Native refreshable debounced - need to wait \(Int(minRefreshInterval - (currentTime - lastRefreshActionTime)))s more")
                return
            }
            
            print("🔄 Native refreshable triggered")
            await loadData()
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 1)
        }
    }
    
    // Top Picks Section - Modified for better loading
    private var topPicksSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("TOP PICKS FOR YOU")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            
            if viewModel.isLoadingTopPicks {
                // Enhanced loading state
                VStack(spacing: 15) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                        .scaleEffect(1.5)
                    
                    Text("Loading top picks...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(Color.white)
            } else if viewModel.errorMessage != nil && viewModel.topPicks.isEmpty {
                // Error state with retry button
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                        .padding(.bottom, 5)
                    
                    Text("Couldn't load top picks")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
                    
                    Text(viewModel.errorMessage ?? "Network error")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 5)
                    
                    Button {
                        Task {
                            // Set loading state before fetching
                            await MainActor.run {
                                viewModel.isLoadingTopPicks = true
                                viewModel.errorMessage = nil
                            }
                            
                            // Check if we should debounce this refresh action
                            let currentTime = Date().timeIntervalSince1970
                            if currentTime - lastRefreshActionTime < minRefreshInterval {
                                print("⏱️ Manual refresh debounced - too soon since last refresh (\(Int(currentTime - lastRefreshActionTime))s)")
                                return
                            }
                            
                            // Update the last refresh time
                            lastRefreshActionTime = currentTime
                            
                            print("🔄 Manual refresh of top picks initiated")
                            await viewModel.loadTopPicks()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 10)
                        .background(AppColors.primaryGreen)
                        .cornerRadius(20)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(Color.white)
            } else if viewModel.topPicks.isEmpty {
                // Empty state with refresh button
                VStack {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.primaryGreen.opacity(0.5))
                        .padding(.bottom, 10)
                    
                    Text("No top picks available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
                    
                    Button {
                        Task {
                            // Set loading state before fetching
                            await MainActor.run {
                                viewModel.isLoadingTopPicks = true
                            }
                            
                            // Check if we should debounce this refresh action
                            let currentTime = Date().timeIntervalSince1970
                            if currentTime - lastRefreshActionTime < minRefreshInterval {
                                print("⏱️ Manual refresh debounced - too soon since last refresh (\(Int(currentTime - lastRefreshActionTime))s)")
                                return
                            }
                            
                            // Update the last refresh time
                            lastRefreshActionTime = currentTime
                            
                            print("🔄 Manual refresh of top picks initiated")
                            await viewModel.loadTopPicks()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.primaryGreen)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(AppColors.primaryGreen.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(Color.white)
            } else {
                // Horizontal scrolling list of top picks with refresh control
                RefreshableScrollView(height: 160, refreshing: $viewModel.isLoadingTopPicks, action: {
                    Task {
                        // Check if we should debounce this refresh action
                        let currentTime = Date().timeIntervalSince1970
                        if currentTime - lastRefreshActionTime < minRefreshInterval {
                            print("⏱️ Top picks refresh debounced - too soon since last refresh (\(Int(currentTime - lastRefreshActionTime))s)")
                            return
                        }
                        
                        // Update the last refresh time
                        await MainActor.run {
                            lastRefreshActionTime = currentTime
                        }
                        
                        print("🔄 Pull-to-refresh triggered for top picks")
                        await viewModel.loadTopPicks()
                    }
                }) {
                    HStack(spacing: 15) {
                        ForEach(viewModel.topPicks) { product in
                            TopPickCard(product: product, restaurant: viewModel.getRestaurantForProduct(product))
                                .environmentObject(orderManager)
                                .environmentObject(favoriteManager)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
    }
    
    // Cuisines Section - Modified for better loading
    private var cuisinesSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("CUISINES")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.top, 5)
            
            if viewModel.isLoading || viewModel.cuisines.isEmpty {
                // Enhanced loading state - show loader while restaurants load since cuisines come from there
                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                        .scaleEffect(1.2)
                    
                    Text("Loading cuisines...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.white)
            } else {
                // Horizontally scrolling cuisine buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // "All" button
                        CuisineButton(
                            cuisine: "All",
                            isSelected: selectedCuisine == nil,
                            action: {
                                selectedCuisine = nil
                            }
                        )
                        
                        // Cuisine filter buttons
                        ForEach(viewModel.cuisines, id: \.self) { cuisine in
                            CuisineButton(
                                cuisine: cuisine,
                                isSelected: selectedCuisine == cuisine,
                                action: {
                                    selectedCuisine = cuisine
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .background(Color.white)
            }
        }
    }
    
    // All Restaurants Section - Modified for better loading
    private var restaurantsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("ALL RESTAURANTS")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.top, 5)
            
            if viewModel.isLoading {
                // Enhanced loading state with better messaging
                VStack(spacing: 15) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                        .scaleEffect(1.5)
                    
                    Text("Loading restaurants...")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text("This might take a moment")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 200)
                .padding(.vertical, 60)
                .background(Color.white)
            } else if viewModel.errorMessage != nil && filteredRestaurants.isEmpty {
                // Error state with retry button
                VStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                        .padding(.bottom, 5)
                    
                    Text("Couldn't load restaurants")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
                    
                    Text(viewModel.errorMessage ?? "Network error")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 5)
                    
                    Button {
                        Task {
                            // Set loading state before fetching
                            await MainActor.run {
                                viewModel.isLoading = true
                                viewModel.errorMessage = nil
                            }
                            
                            // Check if we should debounce this refresh action
                            let currentTime = Date().timeIntervalSince1970
                            if currentTime - lastRefreshActionTime < minRefreshInterval {
                                print("⏱️ Restaurant retry debounced - too soon since last refresh (\(Int(currentTime - lastRefreshActionTime))s)")
                                return
                            }
                            
                            // Update the last refresh time
                            lastRefreshActionTime = currentTime
                            
                            print("🔄 Manual refresh of restaurants initiated")
                            await viewModel.loadRestaurants()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 10)
                        .background(AppColors.primaryGreen)
                        .cornerRadius(20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(Color.white)
            } else if filteredRestaurants.isEmpty {
                // Empty state
                VStack(spacing: 15) {
                    Image(systemName: "building.2")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.primaryGreen.opacity(0.5))
                    
                    Text("\(selectedCuisine != nil ? "No \(selectedCuisine!) restaurants" : "No restaurants") available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    if selectedCuisine != nil {
                        Button {
                            selectedCuisine = nil
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Show all restaurants")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.primaryGreen)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(AppColors.primaryGreen.opacity(0.1))
                            .cornerRadius(20)
                        }
                    } else {
                        Button {
                            Task {
                                // Set loading state before fetching
                                await MainActor.run {
                                    viewModel.isLoading = true
                                }
                                
                                // Check if we should debounce this refresh action
                                let currentTime = Date().timeIntervalSince1970
                                if currentTime - lastRefreshActionTime < minRefreshInterval {
                                    print("⏱️ Manual refresh debounced - too soon since last refresh (\(Int(currentTime - lastRefreshActionTime))s)")
                                    return
                                }
                                
                                // Update the last refresh time
                                lastRefreshActionTime = currentTime
                                
                                print("🔄 Manual refresh of restaurants initiated")
                                await viewModel.loadRestaurants()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.primaryGreen)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(AppColors.primaryGreen.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(Color.white)
            } else {
                // Restaurant list with pull-to-refresh capability
                LazyVStack(spacing: 15) {
                    ForEach(filteredRestaurants) { restaurant in
                        NavigationLink {
                            RestaurantDetailView(restaurant: restaurant)
                                .environmentObject(orderManager)
                                .environmentObject(favoriteManager)
                        } label: {
                            RestaurantCard(restaurant: restaurant)
                                .background(Color.white)
                                .cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal, 20)
                        }
                    }
                    
                    // Add bottom padding for tab bar
                    Spacer()
                        .frame(height: 20)
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
    }
}

// Helper view for cuisine filter buttons
struct CuisineButton: View {
    let cuisine: String
    let isSelected: Bool
    let action: () -> Void
    
    // Get appropriate emoji for cuisine
    private var emoji: String {
        let cuisine = cuisine.lowercased()
        
        if cuisine == "all" {
            return "🍽️"
        } else if cuisine.contains("pizza") {
            return "🍕"
        } else if cuisine.contains("burger") || cuisine.contains("fast food") {
            return "🍔"
        } else if cuisine.contains("dessert") || cuisine.contains("sweet") {
            return "🍰"
        } else if cuisine.contains("drink") || cuisine.contains("beverage") {
            return "🥤"
        } else if cuisine.contains("coffee") {
            return "☕"
        } else if cuisine.contains("breakfast") {
            return "🍳"
        } else if cuisine.contains("lunch") {
            return "🍱"
        } else if cuisine.contains("dinner") {
            return "🍲"
        } else if cuisine.contains("vegetarian") || cuisine.contains("veg") || cuisine.contains("gujarati") {
            return "🥗"
        } else if cuisine.contains("meat") || cuisine.contains("chicken") {
            return "🍗"
        } else if cuisine.contains("seafood") || cuisine.contains("fish") {
            return "🐟"
        } else if cuisine.contains("italian") {
            return "🍝"
        } else if cuisine.contains("chinese") || cuisine.contains("hakka") {
            return "🥢"
        } else if cuisine.contains("indian") || cuisine.contains("north indian") {
            return "🍛"
        } else if cuisine.contains("south indian") {
            return "🥘"
        } else if cuisine.contains("mexican") {
            return "🌮"
        } else if cuisine.contains("japanese") {
            return "🍱"
        } else if cuisine.contains("thai") {
            return "🥡"
        } else if cuisine.contains("sandwich") {
            return "🥪"
        } else if cuisine.contains("street food") {
            return "🌭"
        } else {
            return "🍴"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Circular emoji background
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.primaryGreen.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? AppColors.primaryGreen : Color.clear, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
                    
                    // Emoji
                    Text(emoji)
                        .font(.system(size: 30))
                }
                
                // Text below emoji
                Text(cuisine.prefix(1).uppercased() + cuisine.dropFirst())
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? AppColors.primaryGreen : .black)
                    .lineLimit(1)
                    .frame(width: 70)
            }
            .padding(.horizontal, 5)
            // Add a slight delay before executing the action to prevent UI freezing
            .contentShape(Rectangle())
        }
        // Prevent accidental double taps and improve performance
        .buttonStyle(CuisineButtonStyle())
    }
}

// Custom button style to improve touch handling
struct CuisineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// TabBar Item
struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppColors.primaryGreen : .gray)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? AppColors.primaryGreen : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Card Components

// TopPickCard - Card component for displaying a product in the top picks section
struct TopPickCard: View {
    let product: Product
    let restaurant: Restaurant
    @EnvironmentObject var orderManager: OrderManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    @State private var isInView: Bool = false
    
    var body: some View {
        NavigationLink(destination: 
            // Pass restaurant to detail view to avoid redundant API call
            RestaurantDetailView(restaurantId: product.restaurantId, preloadedRestaurant: restaurant)
        ) {
            VStack(alignment: .leading) {
                // Product Image
                ZStack(alignment: .topTrailing) {
                    ProductImageView(photoId: product.photoId, name: product.name, category: product.category)
                        .frame(width: 150, height: 100)
                        .clipped()
                        .cornerRadius(10)
                    
                    // Favorite button
                    Button {
                        favoriteManager.toggleFavorite(product)
                    } label: {
                        Image(systemName: favoriteManager.isFavorite(product) ? "heart.fill" : "heart")
                            .foregroundColor(favoriteManager.isFavorite(product) ? .red : .white)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.3)))
                            .font(.system(size: 12))
                    }
                    .padding(8)
                    .zIndex(1) // Ensure button is above the card content
                }
                
                // Product Info
                Text(product.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                HStack {
                    // Price
                    Text("₹\(String(format: "%.0f", product.price))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.primaryGreen)
                    
                    Spacer()
                    
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                        
                        Text(String(format: "%.1f", product.rating))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            .contentShape(Rectangle()) // Make entire card tappable
            .frame(width: 150)
            .padding(8)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(RestaurantCardButtonStyle()) // Use the same button style for consistency
    }
}

// RestaurantCard - Card component for displaying a restaurant in the all restaurants section
struct RestaurantCard: View {
    let restaurant: Restaurant
    @State private var hasAppeared = false
    @State private var isPreloading = false
    
    var body: some View {
        NavigationLink(destination: 
            // Pass the entire restaurant object to avoid redundant API call
            RestaurantDetailView(restaurantId: restaurant.id, preloadedRestaurant: restaurant)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                // Restaurant Image
                ZStack(alignment: .bottomLeading) {
                    RestaurantImageView(photoId: restaurant.photoId, name: restaurant.name)
                        .frame(height: 150)
                        .clipped()
                    
                    // Cuisine pill - safely handle optional cuisine
                    if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                        Text(cuisine)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .cornerRadius(15)
                            .padding(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
                .frame(height: 150)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Name and rating
                    HStack {
                        Text(restaurant.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Rating
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            
                            Text(String(format: "%.1f", restaurant.rating))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(15)
                    }
                    
                    // Location
                    Text(restaurant.location)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    // Estimated time - safely handle optional estimatedTime
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.primaryGreen)
                        
                        // Handle optional estimatedTime with proper formatting
                        Text("\(restaurant.estimatedTime ?? "30-40") mins")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.primaryGreen)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
            }
            .contentShape(Rectangle()) // Make entire card tappable
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .overlay(
                Rectangle() // Invisible touch overlay to ensure tap works properly
                    .fill(Color.clear)
                    .contentShape(Rectangle())
            )
        }
        .buttonStyle(RestaurantCardButtonStyle()) // Custom button style for better touch handling
    }
}

// Custom button style for restaurant cards to ensure full card is tappable
struct RestaurantCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    NavigationView {
        HomeView()
    }
} 
