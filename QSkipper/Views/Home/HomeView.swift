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
    
    @Published var restaurants: [Restaurant] = []
    @Published var topPicks: [Product] = []
    @Published var cuisines: [String] = []
    
    @Published var isLoading: Bool = false
    @Published var isLoadingTopPicks: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false
    @Published var lastRefreshTime: Date = Date()
    
    // Cache and cooldown management
    private var lastTopPicksRefreshTime: TimeInterval = 0
    private var lastRestaurantsRefreshTime: TimeInterval = 0
    private let cooldownPeriod: TimeInterval = 30 // 30 seconds cooldown
    
    // Load all restaurants
    @MainActor
    func loadRestaurants() async {
        // Check cooldown timer
        let now = Date().timeIntervalSince1970
        if now - lastRestaurantsRefreshTime < cooldownPeriod && !restaurants.isEmpty {
            print("⏱️ Restaurant refresh cooldown active. Using cached data. Next refresh available in \(Int(cooldownPeriod - (now - lastRestaurantsRefreshTime)))s")
            return
        }
        
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            print("📡 HomeViewModel: Loading restaurants...")
            let fetchedRestaurants = try await restaurantManager.fetchAllRestaurants()
            
            print("✅ Successfully loaded \(fetchedRestaurants.count) restaurants")
            self.restaurants = fetchedRestaurants
            
            // Extract cuisines after loading restaurants
            extractCuisines()
            isLoading = false
            lastRefreshTime = Date()
            lastRestaurantsRefreshTime = now
        } catch {
            print("❌ Error loading restaurants: \(error.localizedDescription)")
            errorMessage = "Could not load restaurants: \(error.localizedDescription)"
            showError = true
            isLoading = false
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
        // Check cooldown timer
        let now = Date().timeIntervalSince1970
        if now - lastTopPicksRefreshTime < cooldownPeriod && !topPicks.isEmpty {
            print("⏱️ TopPicks refresh cooldown active. Using cached data. Next refresh available in \(Int(cooldownPeriod - (now - lastTopPicksRefreshTime)))s")
            return
        }
        
        if isLoadingTopPicks {
            print("⚠️ HomeViewModel: Already loading top picks, skipping duplicate request")
            return
        }
        
        await MainActor.run {
            isLoadingTopPicks = true
            errorMessage = nil
        }
        
        do {
            print("📡 HomeViewModel: Fetching top picks from network")
            let fetchedTopPicks = try await networkUtils.fetchTopPicks()
            
            await MainActor.run {
                print("✅ HomeViewModel: Successfully loaded \(fetchedTopPicks.count) top picks")
                
                if !fetchedTopPicks.isEmpty {
                    // Only update if we got non-empty results
                    self.topPicks = fetchedTopPicks
                    lastTopPicksRefreshTime = now
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
                if topPicks.isEmpty {
                    // Only show error if we don't have any existing top picks
                    errorMessage = "Could not load top picks: \(error.localizedDescription)"
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
        // Try to find the restaurant by ID
        if let restaurant = restaurants.first(where: { $0.id == product.restaurantId }) {
            return restaurant
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
    @FocusState private var isSearchFieldFocused: Bool
    
    private let minRefreshInterval: TimeInterval = 30
    
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
                print("⏱️ Refresh action debounced - too soon since last refresh (\(Int(currentTime - lastRefreshActionTime))s)")
                return
            }
            
            // Update the last refresh time
            await MainActor.run {
                lastRefreshActionTime = currentTime
            }
            
            print("🔄 Loading initial data")
            
            // Check if preloaded data is available - safely access on MainActor
            let hasPreloadedTopPicks = await MainActor.run {
                return !preloadManager.topPicks.isEmpty
            }
            
            if hasPreloadedTopPicks {
                await MainActor.run {
                    print("✅ Using preloaded top picks: \(preloadManager.topPicks.count) items")
                    viewModel.topPicks = preloadManager.topPicks
                }
            } else {
                // Load top picks first
                print("🔄 Starting top picks load")
                await viewModel.loadTopPicks()
                print("✅ Top picks load completed")
            }
            
            // Check if preloaded restaurants are available - safely access on MainActor
            let hasPreloadedRestaurants = await MainActor.run {
                return !preloadManager.restaurants.isEmpty
            }
            
            if hasPreloadedRestaurants {
                await MainActor.run {
                    print("✅ Using preloaded restaurants: \(preloadManager.restaurants.count) items")
                    viewModel.restaurants = preloadManager.restaurants
                    viewModel.extractCuisines()
                }
            } else {
                // Then load restaurants
                print("🔄 Starting restaurants load")
                await viewModel.loadRestaurants()
                print("✅ Restaurants load completed")
            }
            
            // If top picks are still empty after initial load, try refreshing them again
            if viewModel.topPicks.isEmpty {
                print("🔄 Top picks still empty, trying to refresh...")
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                await viewModel.loadTopPicks()
            }
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
                                isPullingToRefresh = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                
                                // Refresh data
                                Task {
                                    // Check if we should debounce this refresh action
                                    let currentTime = Date().timeIntervalSince1970
                                    if currentTime - lastRefreshActionTime < minRefreshInterval {
                                        print("⏱️ Main pull-to-refresh debounced - too soon since last refresh (\(Int(currentTime - lastRefreshActionTime))s)")
                                        await MainActor.run {
                                            isPullingToRefresh = false
                                        }
                                        return
                                    }
                                    
                                    // Update the last refresh time
                                    await MainActor.run {
                                        lastRefreshActionTime = currentTime
                                    }
                                    
                                    print("🔄 Pull-to-refresh triggered for entire view")
                                    
                                    // Load sequentially - top picks first, then restaurants
                                    print("🔄 Starting sequential refresh - top picks first")
                                    await viewModel.loadTopPicks()
                                    print("✅ Pull-to-refresh top picks completed")
                                    
                                    print("🔄 Starting sequential refresh - restaurants")
                                    await viewModel.loadRestaurants()
                                    print("✅ Pull-to-refresh restaurants completed")
                                    
                                    isPullingToRefresh = false
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
                            .padding()
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
                          // If the top picks are empty when the section appears, try to load them
                          if viewModel.topPicks.isEmpty && !viewModel.isLoadingTopPicks {
                              Task {
                                  print("🔄 Refreshing top picks from onAppear")
                                  await viewModel.loadTopPicks()
                              }
                          }
                      }
                    
                    // CUISINES SECTION (Horizontal scrolling buttons)
                    cuisinesSection
                    
                    // ALL RESTAURANTS SECTION
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
            await loadData()
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 1)
        }
    }
    
    // Top Picks Section
    private var topPicksSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("TOP PICKS FOR YOU")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            
            if viewModel.isLoadingTopPicks {
                // Loading state
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                        .scaleEffect(1.5)
                        .frame(height: 160)
                }
                .frame(maxWidth: .infinity)
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
    
    // Cuisines Section
    private var cuisinesSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("CUISINES")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.top, 5)
            
            if viewModel.cuisines.isEmpty {
                if viewModel.isLoading {
                    // Loading state
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                            .padding(.vertical, 15)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Empty state
                    Text("No cuisines available")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                }
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
            }
        }
    }
    
    // All Restaurants Section
    private var restaurantsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("ALL RESTAURANTS")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.top, 5)
            
            if viewModel.isLoading {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                        .scaleEffect(1.5)
                    
                    Text("Loading restaurants...")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
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
                            Text("Show all restaurants")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.primaryGreen)
                        }
                        .padding(.top, 5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Restaurant count
                Text("\(filteredRestaurants.count) Restaurant\(filteredRestaurants.count == 1 ? "" : "s") available for you")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                
                // List of restaurants
                LazyVStack(spacing: 15) {
                    ForEach(filteredRestaurants) { restaurant in
                        RestaurantCard(restaurant: restaurant)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 10)
                .padding(.bottom, 80) // Extra padding for tab bar
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
        }
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
    
    var body: some View {
        NavigationLink(destination: RestaurantDetailView(restaurant: restaurant)) {
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
            .frame(width: 150)
            .padding(8)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(PlainButtonStyle()) // Fix navigation link appearance
    }
}

// RestaurantCard - Card component for displaying a restaurant in the all restaurants section
struct RestaurantCard: View {
    let restaurant: Restaurant
    
    var body: some View {
        NavigationLink(destination: RestaurantDetailView(restaurant: restaurant)) {
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
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle()) // Fix navigation link appearance
    }
}

#Preview {
    NavigationView {
        HomeView()
    }
} 
