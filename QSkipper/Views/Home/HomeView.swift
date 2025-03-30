//
//  HomeView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

// Add Tab enum at the top of the file
enum Tab {
    case home
    case search
    case favorites
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
    
    private let restaurantManager = RestaurantManager.shared
    
    @MainActor
    func loadRestaurants() async {
        isLoading = true
        
        do {
            let fetchedRestaurants = try await restaurantManager.fetchAllRestaurants()
            // Ensure we're on the main thread for UI updates
            await MainActor.run {
                self.restaurants = fetchedRestaurants
                self.isLoading = false
            }
        } catch {
            // Ensure we're on the main thread for UI updates
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    @MainActor
    func loadTopPicks() async {
        print("🔍 Starting to load top picks")
        isLoadingTopPicks = true
        
        do {
            print("📡 Fetching top picks from network")
            let fetchedTopPicks = try await restaurantManager.fetchTopPicks()
            
            // Ensure we're on the main thread for UI updates
            await MainActor.run {
                print("✅ Successfully loaded \(fetchedTopPicks.count) top picks")
                self.topPicks = fetchedTopPicks
                self.isLoadingTopPicks = false
                
                // Debug print each top pick to verify data
                for (index, pick) in fetchedTopPicks.enumerated() {
                    print("🍽️ Top Pick #\(index + 1): \(pick.name), Price: ₹\(pick.price), PhotoID: \(pick.photoId ?? "None")")
                }
            }
        } catch {
            // Ensure we're on the main thread for UI updates
            await MainActor.run {
                print("❌ Error loading top picks: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoadingTopPicks = false
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
            estimatedTime: "30-40",
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
    @State private var selectedCategory: String? = nil
    
    // Keep categories as fallback but they'll be replaced with top picks
    let categories: [(name: String, icon: String)] = [
        ("North Indian", "🍛"),
        ("Fast Food", "🍔"),
        ("South Indian", "🥘"),
        ("Gujarati", "🍲"),
        ("Hakka", "🍜"),
        ("Sandwich", "🥪"),
        ("Street Food", "🌮"),
        ("Chicken", "🍗")
    ]
    
    var filteredRestaurants: [Restaurant] {
        var result = viewModel.restaurants
        
        // Filter by search text if provided
        if !searchText.isEmpty {
            result = result.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        
        // Filter by selected category if one is selected
        if let category = selectedCategory {
            // Improve category matching by standardizing case and allowing partial matches
            result = result.filter { 
                let cuisine = ($0.cuisine ?? "").lowercased()
                let searchCategory = category.lowercased()
                
                // Check if the cuisine contains the category or vice versa
                return cuisine.contains(searchCategory) || 
                       searchCategory.contains(where: { cuisine.contains(String($0)) })
            }
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
                case .search:
                    Text("Search Coming Soon")
                        .font(AppFonts.title)
                        .foregroundColor(AppColors.mediumGray)
                        .navigationBarHidden(true)
                case .favorites:
                    FavoritesView()
                        .environmentObject(favoriteManager)
                        .environmentObject(orderManager)
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
                        }
                    }
                    
                    TabBarItem(icon: "magnifyingglass", label: "Search", isSelected: selectedTab == .search) {
                        withAnimation {
                            selectedTab = .search
                        }
                    }
                    
                    TabBarItem(icon: "heart.fill", label: "Favorites", isSelected: selectedTab == .favorites) {
                        withAnimation {
                            selectedTab = .favorites
                        }
                    }
                    
                    TabBarItem(icon: "person", label: "Profile", isSelected: selectedTab == .profile) {
                        withAnimation(.easeInOut) {
                            selectedTab = .profile
                        }
                    }
                }
                .padding(.vertical, 15)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: -5)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .sheet(isPresented: $showCartSheet) {
            CartView()
                .environmentObject(orderManager)
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(onSelect: { newLocation in
                locationManager.locationName = newLocation
                isLoadingLocation = false
            })
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        Task {
            print("🔄 Loading initial data")
            // Load restaurants first
            await viewModel.loadRestaurants()
            // Then load top picks
            await viewModel.loadTopPicks()
        }
    }
    
    // Home content view
    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header section
                VStack(spacing: 8) {
                    // Location Header with centered cart button
                    HStack {
                        // Location button
                        Button {
                            showLocationPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(AppColors.primaryGreen)
                                
                                VStack(alignment: .leading) {
                                    Text("Delivery to")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                    
                                    Text(locationManager.locationName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black)
                                }
                                
                                Image(systemName: "chevron.down")
                                    .foregroundColor(AppColors.primaryGreen)
                                    .font(.system(size: 12))
                            }
                        }
                        
                        Spacer()
                        
                        // Cart button (now centered better)
                        Button {
                            showCartSheet = true
                        } label: {
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
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TOP PICKS FOR YOU")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        
                        if viewModel.isLoadingTopPicks {
                            // Loading state for top picks
                            HStack {
                                Spacer()
                                LottieWebAnimationView(
                                    webURL: "https://lottie.host/58ead3c3-f27b-4622-8361-5dbd66a16314/sIDRKWRbM3.lottie",
                                    loopMode: .loop,
                                    autoplay: true
                                )
                                .frame(width: 100, height: 100)
                                Spacer()
                            }
                        } else if viewModel.topPicks.isEmpty {
                            // Empty state
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 30))
                                        .foregroundColor(AppColors.mediumGray)
                                    
                                    Text("No top picks available")
                                        .font(AppFonts.body)
                                        .foregroundColor(AppColors.mediumGray)
                                    
                                    Button {
                                        Task {
                                            await viewModel.loadTopPicks()
                                        }
                                    } label: {
                                        Text("Refresh")
                                            .font(AppFonts.callToAction)
                                            .foregroundColor(AppColors.primaryGreen)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(AppColors.primaryGreen, lineWidth: 1)
                                            )
                                    }
                                }
                                .padding(.vertical, 25)
                                Spacer()
                            }
                        } else {
                            // Top picks horizontal scrolling list
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(viewModel.topPicks) { product in
                                        NavigationLink(destination: 
                                            RestaurantDetailView(restaurant: viewModel.getRestaurantForProduct(product))
                                                .environmentObject(orderManager)) {
                                            TopPickItemView(product: product)
                                                .transition(.asymmetric(
                                                    insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.7)),
                                                    removal: .scale(scale: 0.6).combined(with: .opacity).animation(.easeOut(duration: 0.25))
                                                ))
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    
                    // FOOD CATEGORIES - Replaced with visual category cards
                    VStack(alignment: .leading, spacing: 5) {
                        Text("CATEGORIES")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(categories, id: \.name) { category in
                                    Button {
                                        // Toggle category selection
                                        if selectedCategory == category.name {
                                            selectedCategory = nil
                                        } else {
                                            selectedCategory = category.name
                                        }
                                    } label: {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedCategory == category.name ? 
                                                        AppColors.primaryGreen.opacity(0.1) : Color.gray.opacity(0.1))
                                                    .frame(width: 60, height: 60)
                                                
                                                Text(category.icon)
                                                    .font(.system(size: 30))
                                            }
                                            
                                            Text(category.name)
                                                .font(.system(size: 12))
                                                .foregroundColor(selectedCategory == category.name ? 
                                                                AppColors.primaryGreen : Color.black)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(width: 70)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 5)
                        }
                    }
                    
                    // ALL RESTAURANTS Text
                    HStack {
                        Text("ALL RESTAURANTS")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Restaurant count
                    HStack {
                        Text("\(filteredRestaurants.count) Restaurant(s) available for you")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                    
                    // RESTAURANTS SECTION
                    VStack(spacing: 15) {
                        if viewModel.isLoading && viewModel.restaurants.isEmpty {
                            // Loading state for initial load
                            VStack(spacing: 20) {
                                LottieWebAnimationView(
                                    webURL: "https://lottie.host/58ead3c3-f27b-4622-8361-5dbd66a16314/sIDRKWRbM3.lottie",
                                    loopMode: .loop,
                                    autoplay: true
                                )
                                .frame(width: 120, height: 120)
                                
                                Text("Loading restaurants...")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.mediumGray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                        } else if filteredRestaurants.isEmpty {
                            // Empty state - no restaurants match filter
                            VStack(spacing: 15) {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppColors.mediumGray)
                                    .padding(.top, 40)
                                
                                Text(selectedCategory != nil ? 
                                     "No \(selectedCategory!) restaurants found" : 
                                     "No restaurants found matching '\(searchText)'")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.mediumGray)
                                    .multilineTextAlignment(.center)
                                
                                if selectedCategory != nil || !searchText.isEmpty {
                                    Button {
                                        // Reset filters
                                        selectedCategory = nil
                                        searchText = ""
                                    } label: {
                                        Text("Clear filters")
                                            .font(AppFonts.callToAction)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(AppColors.primaryGreen)
                                            .cornerRadius(20)
                                            .padding(.top, 10)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                        } else {
                            // Restaurant list
                            ForEach(filteredRestaurants) { restaurant in
                                NavigationLink(destination: RestaurantDetailView(restaurant: restaurant).environmentObject(orderManager)) {
                                    RestaurantItemView(restaurant: restaurant)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 100) // Add extra padding for the tab bar
                }
            }
        }
        .refreshable {
            Task {
                await viewModel.loadRestaurants()
                await viewModel.loadTopPicks()
            }
        }
    }
}

struct TopPickItemView: View {
    @EnvironmentObject var favoriteManager: FavoriteManager
    @EnvironmentObject var orderManager: OrderManager
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading) {
            // Product Image - using ProductImageView to load real images
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
                .foregroundColor(AppColors.darkGray)
                .lineLimit(1)
            
            HStack {
                Text("₹\(String(format: "%.0f", product.price))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.primaryGreen)
                
                Spacer()
                
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
}

struct RestaurantItemView: View {
    let restaurant: Restaurant
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Restaurant Image
            ZStack(alignment: .bottomLeading) {
                // Always use RestaurantImageView for consistency, passing both photoId and name
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
        .padding(.horizontal, 20)
    }
    
    // Reusable placeholder for restaurant images
    private var restaurantPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 150)
            .overlay(
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    if !restaurant.name.isEmpty {
                        Text(restaurant.name.prefix(1).uppercased())
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.top, 5)
                    }
                }
            )
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var action: (() -> Void)? = nil
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            // Reset the animation state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
            
            action?()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? AppColors.primaryGreen : Color.gray)
                    .scaleEffect(isSelected ? (isPressed ? 0.9 : 1.1) : 1.0)
                    .animation(isSelected ? .spring(response: 0.3, dampingFraction: 0.6) : .none, value: isPressed)
                
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? AppColors.primaryGreen : Color.gray)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
}

// Favorites View
struct FavoritesView: View {
    @EnvironmentObject var favoriteManager: FavoriteManager
    @EnvironmentObject var orderManager: OrderManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your Favorite Dishes")
                        .font(AppFonts.title)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    if favoriteManager.favoriteDishes.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            LottieWebAnimationView(
                                webURL: "https://lottie.host/20b64309-9089-4464-a4c5-f9a1ab3dbba1/l5b3WsrLuK.lottie",
                                loopMode: .loop,
                                autoplay: true
                            )
                            .frame(width: 200, height: 200)
                            Text("No favorite dishes yet")
                                .font(AppFonts.subtitle)
                                .foregroundColor(AppColors.mediumGray)
                            Text("Add some dishes to your favorites from the menu")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.mediumGray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                        .frame(height: 400)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                            ForEach(favoriteManager.favoriteDishes) { product in
                                FavoriteProductCard(product: product)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Extra space for tab bar
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FavoriteProductCard: View {
    @EnvironmentObject var favoriteManager: FavoriteManager
    @EnvironmentObject var orderManager: OrderManager
    @State private var showAddedToCart = false
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image
            ZStack(alignment: .topTrailing) {
                ProductImageView(photoId: product.photoId, name: product.name, category: product.category)
                    .frame(height: 120)
                    .cornerRadius(12)
                
                // Favorite button
                Button {
                    withAnimation {
                        favoriteManager.toggleFavorite(product)
                    }
                } label: {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.3)))
                }
                .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                Text("₹\(String(format: "%.0f", product.price))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.primaryGreen)
                
                // Add to cart button
                Button {
                    orderManager.addToCart(product: product)
                    withAnimation {
                        showAddedToCart = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showAddedToCart = false
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text(showAddedToCart ? "Added!" : "Add to Cart")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .background(showAddedToCart ? Color.green : AppColors.primaryGreen)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }
}

#Preview {
    NavigationView {
        HomeView()
    }
} 