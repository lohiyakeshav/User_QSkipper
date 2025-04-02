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
    @Published var restaurants: [Restaurant] = []
    @Published var topPicks: [Product] = []
    @Published var isLoading = false
    @Published var isLoadingTopPicks = false
    @Published var errorMessage: String? = nil
    @Published var showError = false
    @Published var cuisines: [String] = []
    
    private let networkUtils = NetworkUtils.shared
    
    func loadRestaurants() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            showError = false
        }
        
        do {
            print("📡 Fetching restaurants from network: \(networkUtils.baseURl.absoluteString)get_All_Restaurant")
            let fetchedRestaurants = try await networkUtils.fetchRestaurants()
            
            await MainActor.run {
                print("✅ Successfully loaded \(fetchedRestaurants.count) restaurants")
                self.restaurants = fetchedRestaurants
                
                // Extract unique cuisines from restaurants
                extractCuisines()
                isLoading = false
            }
        } catch {
            print("❌ Error loading restaurants: \(error.localizedDescription)")
            
            await MainActor.run {
                errorMessage = "Could not load restaurants: \(error.localizedDescription)"
                showError = true
                isLoading = false
            }
        }
    }
    
    // Extract unique cuisines from restaurants
    private func extractCuisines() {
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
        await MainActor.run {
            isLoadingTopPicks = true
            errorMessage = nil
            showError = false
        }
        
        do {
            print("📡 Fetching top picks from network")
            let fetchedTopPicks = try await networkUtils.fetchTopPicks()
            
            await MainActor.run {
                print("✅ Successfully loaded \(fetchedTopPicks.count) top picks")
                self.topPicks = fetchedTopPicks
                isLoadingTopPicks = false
            }
        } catch {
            print("❌ Error loading top picks: \(error.localizedDescription)")
            
            await MainActor.run {
                errorMessage = "Could not load top picks: \(error.localizedDescription)"
                showError = true
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
    @State private var showLocationPicker = false
    @State private var isLoadingLocation = false
    @State private var selectedTab: Tab = .home
    @State private var showCartSheet = false
    @State private var searchText = ""
    @State private var selectedCuisine: String? = nil
    
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
        }
        .onDisappear {
            print("📱 HomeView: View disappeared")
            print("🔔 HomeView: Removing OpenCart notification observer")
            // Remove notification observer when view disappears
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("OpenCart"),
                object: nil
            )
        }
        .onChange(of: selectedTab) { newTab in
            print("🔄 HomeView: Tab changed to: \(newTab)")
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
            print("🔄 Loading initial data")
            
            // Load restaurants first with a timeout
            await viewModel.loadRestaurants()
            
            // Then load top picks
            await viewModel.loadTopPicks()
        }
    }
    
    // Home content view
    private var homeContent: some View {
        NavigationView {
            ScrollView {
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
                        
                        NavigationLink(destination: CartView()
                            .environmentObject(orderManager)
                            .environmentObject(TabSelection.shared)) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(AppColors.primaryGreen.opacity(0.1))
                                    .frame(width: 38, height: 38)
                                
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppColors.primaryGreen)
                                    .frame(width: 20, height: 20)
                                    .padding(9)
                                
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
                            .foregroundColor(.gray)
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
                    // TOP PICKS SECTION
                    topPicksSection
                    
                    // CUISINES SECTION (Horizontal scrolling buttons)
                    cuisinesSection
                    
                    // ALL RESTAURANTS SECTION
                    restaurantsSection
                    
                    // Add bottom padding to ensure content isn't hidden behind the tab bar
                    Spacer(minLength: 100)
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
                // Empty state
                VStack {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.primaryGreen.opacity(0.5))
                        .padding(.bottom, 10)
                    
                    Text("No top picks available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(Color.white)
            } else {
                // Horizontal scrolling list of top picks
                ScrollView(.horizontal, showsIndicators: false) {
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
