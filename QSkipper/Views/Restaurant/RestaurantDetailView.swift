//
//  RestaurantDetailView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

class RestaurantDetailViewModel: ObservableObject {
    let restaurant: Restaurant
    
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showError = false
    
    // Grouped products by category
    @Published var productsByCategory: [String: [Product]] = [:]
    @Published var categories: [String] = []
    
    private let restaurantManager = RestaurantManager.shared
    
    init(restaurant: Restaurant) {
        self.restaurant = restaurant
    }
    
    @MainActor
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("Fetching products for restaurant ID: \(restaurant.id)")
            let fetchedProducts = try await restaurantManager.fetchProducts(for: restaurant.id)
            
            print("Successfully fetched \(fetchedProducts.count) products")
            
            // Update on main thread using MainActor
            self.products = fetchedProducts
            
            // Group products by category
            self.productsByCategory = Dictionary(grouping: fetchedProducts) { product in
                product.category ?? "Other"
            }
            
            // Sort categories
            self.categories = self.productsByCategory.keys.sorted()
            
            self.isLoading = false
        } catch {
            print("Error fetching products: \(error)")
            if let networkError = error as? SimpleNetworkError {
                switch networkError {
                case .decodingFailed(let decodingError):
                    print("Decoding error details: \(decodingError)")
                    self.errorMessage = "Failed to decode products: \(decodingError)"
                case .serverError(let statusCode, _):
                    print("Server error: \(statusCode)")
                    self.errorMessage = "Server error: \(statusCode)"
                default:
                    self.errorMessage = error.localizedDescription
                }
            } else {
                self.errorMessage = error.localizedDescription
            }
            self.showError = true
            self.isLoading = false
        }
    }
}

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @StateObject private var viewModel: RestaurantDetailViewModel
    @EnvironmentObject private var orderManager: OrderManager
    @EnvironmentObject private var favoriteManager: FavoriteManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedCategory: String? = nil
    @State private var showCart = false
    @State private var animateCart = false
    
    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        self._viewModel = StateObject(wrappedValue: RestaurantDetailViewModel(restaurant: restaurant))
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color(hex: "#F9F9F9").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Restaurant Banner with Back Button and Share Button
                ZStack(alignment: .top) {
                    // Restaurant image 
                    RestaurantImageView(photoId: restaurant.photoId, name: restaurant.name)
                        .frame(height: 220)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear, Color.black.opacity(0.4)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipped()
                    
                    // Top navigation bar
                    HStack {
                        Button {
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .regular))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                        
                        Button {
                            // Share functionality
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                
                // Restaurant Info Card
                VStack(alignment: .leading, spacing: 6) {
                    Text(restaurant.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                    
                    // Rating and cuisine
                    HStack(spacing: 15) {
                        // Rating stars
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 14))
                            
                            Text(String(format: "%.1f", restaurant.rating))
                                .font(.system(size: 14, weight: .medium))
                        }
                        
                        // Dot separator
                        Circle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 4, height: 4)
                        
                        // Cuisine
                        if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                            Text(cuisine)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Delivery info
                    HStack(spacing: 15) {
                        // Free delivery
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(AppColors.primaryGreen)
                                .font(.system(size: 14))
                            
                            Text("Free Delivery")
                                .font(.system(size: 14))
                        }
                        
                        // Dot separator
                        Circle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 4, height: 4)
                        
                        // Delivery time
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(AppColors.primaryGreen)
                                .font(.system(size: 14))
                            
                            Text("\(restaurant.estimatedTime ?? "20-30") min")
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 15)
                .padding(.bottom, 10)
                .background(Color.white)
                
                // M E N U Separator
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    
                    Text("M E N U")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                
                // Category Tabs
                if !viewModel.categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.categories, id: \.self) { category in
                                Button {
                                    withAnimation {
                                        selectedCategory = category
                                    }
                                } label: {
                                    Text(category)
                                        .font(.system(size: 14, weight: selectedCategory == category ? .bold : .medium))
                                        .foregroundColor(selectedCategory == category ? .white : .black)
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedCategory == category ? 
                                                AppColors.primaryGreen : 
                                                Color.white
                                        )
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                }
                
                // Menu Items
                ScrollView {
                    VStack(spacing: 0) {
                        if selectedCategory == nil {
                            // Show all categories if none is selected
                            ForEach(viewModel.categories, id: \.self) { category in
                                categorySection(category: category)
                            }
                        } else if let selectedCategory = selectedCategory,
                                  let products = viewModel.productsByCategory[selectedCategory] {
                            // Show only the selected category
                            categoryProductsView(products: products)
                        }
                    }
                    .padding(.bottom, orderManager.currentCart.isEmpty ? 20 : 100)
                }
                
                Spacer()
            }
            
            // Floating Cart Button
            if !orderManager.currentCart.isEmpty {
                VStack {
                    Spacer()
                    
                    Button {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        showCart = true
                    } label: {
                        HStack {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .scaleEffect(animateCart ? 1.2 : 1.0)
                                    .animation(Animation.easeInOut(duration: 0.3).repeatCount(1), value: animateCart)
                                
                                // Badge count
                                CartBadge(count: orderManager.currentCart.count)
                                    .scaleEffect(0.8)
                                    .offset(x: 8, y: -8)
                            }
                            
                            Text("\(orderManager.getTotalItems()) items")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("$\(String(format: "%.2f", orderManager.getTotalAmount()))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white)
                        }
                        .padding(15)
                        .background(
                            ZStack {
                                AppColors.primaryGreen.opacity(0.9)
                                AppColors.primaryGreen
                                    .shadow(color: AppColors.primaryGreen.opacity(0.3), radius: 3, x: 0, y: 2)
                            }
                        )
                        .cornerRadius(12)
                        .shadow(color: AppColors.primaryGreen.opacity(0.4), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            
            // Loading overlay
            if viewModel.isLoading {
                LoadingView()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Set current restaurant if not already set
            if orderManager.currentRestaurantId != restaurant.id {
                orderManager.clearCart()
                orderManager.currentRestaurantId = restaurant.id
            }
            
            // Select the first category by default
            if selectedCategory == nil && !viewModel.categories.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    selectedCategory = viewModel.categories.first
                }
            }
            
            Task {
                await viewModel.loadProducts()
            }
        }
        .onChange(of: orderManager.currentCart.count) { newCount in
            if newCount > 0 {
                // Animate cart icon when items are added
                animateCart = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateCart = false
                }
            }
        }
        .errorAlert(error: viewModel.errorMessage, isPresented: $viewModel.showError)
        .sheet(isPresented: $showCart) {
            CartView()
        }
    }
    
    // Helper function to create a section for each category
    private func categorySection(category: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category)
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.top, 15)
                .padding(.bottom, 5)
            
            if let products = viewModel.productsByCategory[category] {
                categoryProductsView(products: products)
            }
        }
    }
    
    // Helper function to show products for a category
    private func categoryProductsView(products: [Product]) -> some View {
        VStack(spacing: 0) {
            ForEach(products) { product in
                MenuItemView(product: product)
            }
        }
    }
}

struct RestaurantHeaderView: View {
    let restaurant: Restaurant
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background Image
            RestaurantImageView(photoId: restaurant.photoId, name: restaurant.name)
                .frame(height: 200)
                .clipped()
            
            // Dark overlay for readability
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            
            // Restaurant name
            VStack(alignment: .leading, spacing: 8) {
                Text(restaurant.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 5)
                
                HStack {
                    // Rating
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        
                        Text(String(format: "%.1f", restaurant.rating))
                            .font(AppFonts.body)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    // Location
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                        
                        Text(restaurant.location)
                            .font(AppFonts.caption)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
    }
    
    // Restaurant placeholder
    private var restaurantPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 200)
            
            VStack(spacing: 10) {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.8))
                
                if !restaurant.name.isEmpty {
                    Text(restaurant.name.prefix(1).uppercased())
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
        }
    }
}

struct MenuItemView: View {
    @EnvironmentObject var orderManager: OrderManager
    @EnvironmentObject var favoriteManager: FavoriteManager
    let product: Product
    @State private var quantity = 0
    @State private var showAddedToCart = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Product info row
            HStack(alignment: .top, spacing: 12) {
                // VEG/NON-VEG Indicator
                Rectangle()
                    .fill(product.isVeg ? Color.green : Color.red)
                    .frame(width: 16, height: 16)
                    .cornerRadius(2)
                    .padding(.top, 2)
                
                // Product details
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.darkGray)
                    
                    if let description = product.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.mediumGray)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text("₹\(Int(product.price))")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppColors.darkGray)
                        
                        if product.rating > 0 {
                            Spacer()
                                .frame(width: 8)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 12))
                                
                                Text(String(format: "%.1f", product.rating))
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Favorite button
                        Button {
                            favoriteManager.toggleFavorite(product)
                        } label: {
                            Image(systemName: favoriteManager.isFavorite(product) ? "heart.fill" : "heart")
                                .foregroundColor(favoriteManager.isFavorite(product) ? .red : .gray)
                                .font(.system(size: 18))
                        }
                        .padding(.leading, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Product image and add button
                ZStack(alignment: .bottomTrailing) {
                    if quantity == 0 {
                        // Add button when quantity is 0
                        Button {
                            addToCart()
                        } label: {
                            Text("ADD")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppColors.primaryGreen)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(AppColors.primaryGreen, lineWidth: 1)
                                )
                        }
                        .zIndex(1)
                        .offset(y: 8)
                    } else {
                        // Quantity control when quantity > 0
                        HStack(spacing: 0) {
                            Button {
                                decreaseQuantity()
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(AppColors.primaryGreen)
                            }
                            
                            Text("\(quantity)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.primaryGreen)
                                .frame(width: 30, height: 24)
                                .background(Color.white)
                                .overlay(
                                    Rectangle()
                                        .stroke(AppColors.primaryGreen, lineWidth: 1)
                                )
                            
                            Button {
                                increaseQuantity()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(AppColors.primaryGreen)
                            }
                        }
                        .cornerRadius(5)
                        .zIndex(1)
                        .offset(y: 8)
                    }
                    
                    // Product image
                    ProductImageView(photoId: product.photoId, name: product.name, category: product.category)
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                }
                .frame(width: 80)
            }
            
            Divider()
                .padding(.top, 5)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .onAppear {
            // Set initial quantity from cart if exists
            quantity = orderManager.getQuantityInCart(productId: product.id)
        }
    }
    
    // Add to cart function
    private func addToCart() {
        orderManager.addToCart(product: product)
        quantity = 1
        
        // Show added animation
        withAnimation {
            showAddedToCart = true
        }
        
        // Hide after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showAddedToCart = false
            }
        }
    }
    
    // Increase quantity
    private func increaseQuantity() {
        quantity += 1
        orderManager.updateCartItemQuantity(productId: product.id, quantity: quantity)
    }
    
    // Decrease quantity
    private func decreaseQuantity() {
        if quantity > 0 {
            quantity -= 1
            if quantity == 0 {
                orderManager.removeFromCart(productId: product.id)
            } else {
                orderManager.updateCartItemQuantity(productId: product.id, quantity: quantity)
            }
        }
    }
}

#Preview {
    // Add a custom initializer to Restaurant
    let sampleRestaurant = Restaurant(
        id: "1",
        name: "Burger King",
        estimatedTime: "30-40",
        cuisine: "Fast Food",
        photoId: nil,
        rating: 4.5,
        location: "123 Main St"
    )
    
    NavigationView {
        RestaurantDetailView(restaurant: sampleRestaurant)
            .environmentObject(OrderManager.shared)
            .environmentObject(FavoriteManager.shared)
    }
} 
