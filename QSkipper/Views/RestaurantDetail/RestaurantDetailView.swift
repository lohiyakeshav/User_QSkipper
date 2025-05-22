import SwiftUI

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @StateObject private var viewModel = RestaurantDetailViewModel()
    @EnvironmentObject private var orderManager: OrderManager
    @EnvironmentObject private var favoriteManager: FavoriteManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedCategory: String? = nil
    @State private var showCartSheet = false
    @State private var searchText: String = ""
    @State private var selectedProduct: Product? = nil
    
    // Default initializer with full restaurant data
    init(restaurant: Restaurant) {
        self.restaurant = restaurant
    }
    
    // New initializer with restaurantId and preloaded restaurant data to prevent redundant API calls
    init(restaurantId: String, preloadedRestaurant: Restaurant) {
        self.restaurant = preloadedRestaurant
        print("🔥 Using preloaded restaurant data for: \(preloadedRestaurant.name)")
    }
    
    // Initializer with just restaurant ID, loading rest from network
    init(restaurantId: String) {
        // Create a temporary restaurant object until we load the real data
        self.restaurant = Restaurant(
            id: restaurantId,
            name: "Loading...",
            estimatedTime: nil,
            cuisine: nil,
            photoId: nil,
            rating: 4.0,
            location: "Loading..."
        )
        
        // Load the full restaurant data
        Task {
            if let loadedRestaurant = try? await NetworkUtils.shared.fetchRestaurant(with: restaurantId) {
                // We'll update the view model in onAppear
                print("✅ Loaded restaurant details for: \(loadedRestaurant.name)")
            }
        }
    }
    
    var body: some View {
        ScrollView {
            restaurantContent
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🖥️ RestaurantDetailView appeared for: \(restaurant.name) (ID: \(restaurant.id))")
            
            // Trigger product loading
            print("🔄 Requesting products for restaurant ID: \(restaurant.id)")
            viewModel.loadProducts(for: restaurant.id)
            
            // If we initialized with just an ID, we need to load the restaurant details
            if restaurant.name == "Loading..." {
                print("🔍 Loading full restaurant details for ID: \(restaurant.id)")
                viewModel.loadRestaurant(id: restaurant.id)
            } else {
                // We have preloaded data, update the view model
                viewModel.setRestaurant(restaurant)
            }
        }
        .onDisappear {
            print("🖥️ RestaurantDetailView disappeared")
            // Clear cache when view disappears to prevent memory issues
            // We'll leave the cache for this specific restaurant but clear others
            let currentRestaurantId = restaurant.id
            Task {
                await MainActor.run {
                    // Clear all product cache except for the current restaurant
                    // This helps prevent memory issues while still allowing for quick return
                    viewModel.clearCache()
                }
            }
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailModal(
                product: product,
                restaurantId: viewModel.restaurant?.id ?? restaurant.id,
                restaurantName: viewModel.restaurant?.name ?? restaurant.name,
                onClose: { selectedProduct = nil }
            )
            .environmentObject(orderManager)
            .environmentObject(favoriteManager)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Restaurant Banner Section
    private var restaurantBanner: some View {
        ZStack(alignment: .top) {
            // Restaurant Banner Image - Use viewModel.restaurant if available
            RestaurantImageView(
                photoId: viewModel.restaurant?.photoId ?? restaurant.photoId,
                name: viewModel.restaurant?.name ?? restaurant.name
            )
            .frame(height: 200)
            .clipped()
            
            // Gradient Overlay for better text visibility
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 200)
            
            // Top Navigation Bar
            HStack {
                // Back Button
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                
                Spacer()
                
                // Title
                Text("About")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Cart Button
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
            .padding(.top, 12)
        }
    }
    
    // MARK: - Restaurant Header Section
    private var restaurantHeader: some View {
        VStack(alignment: .center, spacing: 10) {
            // Restaurant Name
            Text(viewModel.restaurant?.name ?? restaurant.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
            
            // Details Row
            HStack(spacing: 16) {
                // CUISINE WITH EMOJI - Add cuisine with appropriate emoji
                if let cuisine = viewModel.restaurant?.cuisine ?? restaurant.cuisine, !cuisine.isEmpty {
                    HStack(spacing: 6) {
                        Text(getCuisineEmoji(cuisine: cuisine))
                            .font(.system(size: 16))
                        
                        Text(cuisine)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                // DELIVERY TIME
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(AppColors.primaryGreen)
                        .font(.system(size: 13))
                    
                    let estimatedTime = viewModel.restaurant?.estimatedTime ?? restaurant.estimatedTime ?? "30-40"
                    Text("\(estimatedTime) mins")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                // RATING
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 13))
                    
                    let rating = viewModel.restaurant?.rating ?? restaurant.rating
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
    
    // MARK: - Menu Title Section
    private var menuTitleSection: some View {
        VStack(alignment: .center, spacing: 5) {
            Text("M E N U")
                .font(.system(size: 16, weight: .semibold))
                .tracking(4)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            
            // Decorative Line
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Rectangle()
                    .fill(AppColors.primaryGreen)
                    .frame(width: 50, height: 3)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 50)
        }
        .padding(.vertical, 10)
        .background(Color.white)
    }
    
    // MARK: - Category Filter Section
    private var categoryFilterSection: some View {
        Group {
            if !viewModel.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // "All" Category Button
                        CategoryButton(
                            name: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        
                        // Other Category Buttons
                        ForEach(viewModel.categories, id: \.self) { category in
                            CategoryButton(
                                name: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
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
    
    // MARK: - Products Section
    private var productsSection: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.products.isEmpty {
                emptyProductsView
            } else {
                productGridView
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                .scaleEffect(1.5)
            
            Text("Loading menu...")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Color.white)
    }
    
    private var emptyProductsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 40))
                .foregroundColor(AppColors.primaryGreen.opacity(0.5))
            
            Text("No menu items available")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Color.white)
    }
    
    private var productGridView: some View {
        Group {
            if selectedCategory == nil || viewModel.products.contains(where: { $0.category == selectedCategory }) {
                // Products are available for selected category (or all products if nil)
                let filteredProducts = selectedCategory == nil ?
                    viewModel.products :
                    viewModel.products.filter { $0.category == selectedCategory }
                
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 150, maximum: 180), spacing: 12),
                        GridItem(.flexible(minimum: 150, maximum: 180), spacing: 12)
                    ], 
                    spacing: 12
                ) {
                    ForEach(filteredProducts) { product in
                        MenuProductCard(
                            product: product,
                            restaurantId: viewModel.restaurant?.id ?? restaurant.id,
                            onTap: {
                                print("🔍 Selected product: \(product.name) (ID: \(product.id))")
                                print("   → Category: \(product.category ?? "nil")")
                                print("   → RestaurantId: \(product.restaurantId)")
                                selectedProduct = product
                            }
                        )
                        .frame(minHeight: 260)
                        .id(product.id) // Add explicit ID to help SwiftUI track items
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.white)
            } else {
                // No products available for selected category
                noCategoryItemsView
            }
        }
    }
    
    private var noCategoryItemsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(AppColors.primaryGreen.opacity(0.5))
            
            Text("No items found in this category")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Button {
                selectedCategory = nil
            } label: {
                Text("Show all items")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.primaryGreen)
                    .padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Color.white)
    }
    
    // MARK: - Main Content
    private var restaurantContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            restaurantBanner
            restaurantHeader
            menuTitleSection
            categoryFilterSection
            productsSection
        }
        .background(Color.gray.opacity(0.1))
        .edgesIgnoringSafeArea(.top)
    }
    
    // Helper function to get the emoji for a cuisine type
    private func getCuisineEmoji(cuisine: String) -> String {
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
}

// Helper Components

struct CategoryButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : AppColors.primaryGreen)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.primaryGreen : Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.primaryGreen, lineWidth: 1)
                )
        }
    }
}

struct MenuProductCard: View {
    let product: Product
    let restaurantId: String
    let onTap: () -> Void
    @State private var showingAddedToast = false
    @State private var quantity = 0
    @EnvironmentObject private var orderManager: OrderManager
    @EnvironmentObject private var favoriteManager: FavoriteManager
    @State private var isFavorite = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image and Info section that should be tappable
            VStack(alignment: .leading, spacing: 8) {
                // Product Image
                ZStack(alignment: .topTrailing) {
                    ProductImageView(photoId: product.photoId, name: product.name, category: product.category)
                        .scaledToFill()
                        .frame(height: 130)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Favorite button
                    Button {
                        favoriteManager.toggleFavorite(product)
                        // Update local state to match the favoriteManager state
                        isFavorite = favoriteManager.isFavorite(product)
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(isFavorite ? .red : .white)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    .padding(8)
                    // Prevent favorite button from triggering card tap
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded { _ in
                                favoriteManager.toggleFavorite(product)
                                isFavorite = favoriteManager.isFavorite(product)
                            }
                    )
                }
                
                // Product Info
                Text(product.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Rating and Price Row
                HStack {
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                        
                        Text(String(format: "%.1f", product.rating))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Price
                    Text("₹\(String(format: "%.0f", product.price))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.primaryGreen)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                print("🔍 Tapped product card area for: \(product.name)")
                onTap()
            }
            
            // Add to cart section - This should NOT trigger the modal
            HStack {
                if quantity > 0 {
                    // Show quantity controls
                    HStack {
                        Button {
                            print("➖ Minus button tapped for: \(product.name)")
                            if quantity > 1 {
                                quantity -= 1
                                orderManager.updateCartItemQuantity(productId: product.id, quantity: quantity)
                            } else {
                                quantity = 0
                                orderManager.removeFromCart(productId: product.id)
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(AppColors.primaryGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(BorderlessButtonStyle()) // Prevent tap propagation
                        
                        Text("\(quantity)")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(minWidth: 30)
                        
                        Button {
                            print("➕ Plus button tapped for: \(product.name)")
                            quantity += 1
                            orderManager.updateCartItemQuantity(productId: product.id, quantity: quantity)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(AppColors.primaryGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(BorderlessButtonStyle()) // Prevent tap propagation
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Show Add button
                    Button(action: {
                        print("➕ Add button tapped for: \(product.name)")
                        
                        var productToAdd = product
                        
                        // ENHANCED DEBUGGING: Log detailed information about the product
                        print("🔎 DEBUG: Add button tapped for product:")
                        print("  - Name: \(productToAdd.name)")
                        print("  - ID: \(productToAdd.id)")
                        print("  - RestaurantId: '\(productToAdd.restaurantId)'")
                        print("  - Price: \(productToAdd.price)")
                        print("  - Category: \(productToAdd.category ?? "nil")")
                        print("  - Current restaurantId parameter: '\(restaurantId)'")
                        
                        // CRITICAL FIX: Check if the product has an empty restaurantId and fix it
                        if productToAdd.restaurantId.isEmpty {
                            print("⚠️ Empty restaurantId detected, using current restaurant: \(restaurantId)")
                            
                            // Create a new product with the correct restaurantId
                            productToAdd = Product(
                                id: productToAdd.id,
                                name: productToAdd.name,
                                description: productToAdd.description,
                                price: productToAdd.price,
                                restaurantId: restaurantId,
                                category: productToAdd.category,
                                isAvailable: productToAdd.isAvailable,
                                rating: productToAdd.rating,
                                extraTime: productToAdd.extraTime,
                                photoId: productToAdd.photoId,
                                isVeg: productToAdd.isVeg
                            )
                        }
                        
                        // Set quantity first to show UI update
                        quantity = 1
                        
                        // Add to cart using the orderManager
                        orderManager.addToCart(product: productToAdd)
                        
                        // Show toast message
                        withAnimation {
                            showingAddedToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showingAddedToast = false
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            
                            if showingAddedToast {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Added")
                                    .font(.system(size: 12, weight: .semibold))
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Add")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(showingAddedToast ? Color.green : AppColors.primaryGreen)
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle()) // Prevent tap propagation
                }
            }
            .frame(height: 36)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .frame(minWidth: 0, maxWidth: .infinity)
        .onAppear {
            // Check if already in cart
            quantity = orderManager.getQuantityInCart(productId: product.id)
            print("🔍 onAppear: Checking product \(product.name) (ID: \(product.id))")
            print("   → RestaurantId: \(product.restaurantId)")
            print("   → Current quantity in cart: \(quantity)")
            
            // Check if already in favorites
            isFavorite = favoriteManager.isFavorite(product)
            print("   → Is favorite: \(isFavorite)")
            
            // Subscribe to favorite status change notifications
            NotificationCenter.default.addObserver(forName: FavoriteManager.favoriteStatusChangedNotification, object: nil, queue: .main) { notification in
                if let productId = notification.object as? String, productId == product.id {
                    // Update our local state if this product's favorite status changed
                    isFavorite = favoriteManager.isFavorite(product)
                    print("📣 Notification received: Updated favorite status for \(product.name) to \(isFavorite)")
                }
            }
        }
        .onDisappear {
            // Remove notification observer when view disappears
            NotificationCenter.default.removeObserver(self, name: FavoriteManager.favoriteStatusChangedNotification, object: nil)
        }
    }
}

struct ProductDetailModal: View {
    let product: Product
    let restaurantId: String
    let restaurantName: String
    let onClose: () -> Void
    @State private var quantity = 0
    @State private var showingAddedToast = false
    @State private var isFavorite = false
    @EnvironmentObject private var orderManager: OrderManager
    @EnvironmentObject private var favoriteManager: FavoriteManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // Product content
            VStack(spacing: 0) {
                // Product image and info header
                HStack(alignment: .top, spacing: 15) {
                    // Product image
                    ProductImageView(photoId: product.photoId, name: product.name, category: product.category)
                        .frame(width: 110, height: 110)
                        .cornerRadius(10)
                    
                    // Product info
                    VStack(alignment: .leading, spacing: 8) {
                        // Name
                        Text(product.name)
                            .font(.system(size: 18, weight: .bold))
                            .lineLimit(2)
                        
                        // Veg badge
                        if product.isVeg {
                            HStack(spacing: 4) {
                                Image(systemName: "leaf.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12))
                                Text("Vegetarian")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        // Rating
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 12))
                            
                            Text(String(format: "%.1f", product.rating))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        // Price
                        Text("₹\(String(format: "%.2f", product.price))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.primaryGreen)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Favorite button
                    Button {
                        favoriteManager.toggleFavorite(product)
                        // Update local state to match the favoriteManager state
                        isFavorite = favoriteManager.isFavorite(product)
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(isFavorite ? .red : .gray)
                    }
                    .padding(8)
                }
                .padding(.horizontal, 20)
                
                Divider()
                    .padding(.vertical, 16)
                
                // Details area
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Description
                        if let description = product.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text(description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Product details in a grid
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Details")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                // Category
                                if let category = product.category, !category.isEmpty {
                                    DetailRow(title: "Category", value: category)
                                }
                                
                                // Extra time
                                if let extraTime = product.extraTime, extraTime > 0 {
                                    DetailRow(title: "Extra Prep Time", value: "\(extraTime) minutes")
                                }
                                
                                // Availability
                                DetailRow(title: "Available", value: product.isAvailable ? "Yes" : "No")
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Extra spacing at bottom for button
                        Spacer(minLength: 80)
                    }
                }
                
                // Add to cart button - fixed at bottom
                VStack {
                    Divider()
                    
                    HStack {
                        if quantity > 0 {
                            // Show quantity controls
                            HStack {
                                Button {
                                    if quantity > 1 {
                                        quantity -= 1
                                        orderManager.updateCartItemQuantity(productId: product.id, quantity: quantity)
                                    } else {
                                        quantity = 0
                                        orderManager.removeFromCart(productId: product.id)
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 35, height: 35)
                                        .background(AppColors.primaryGreen)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                
                                Text("\(quantity)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(minWidth: 40)
                                
                                Button {
                                    quantity += 1
                                    orderManager.updateCartItemQuantity(productId: product.id, quantity: quantity)
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 35, height: 35)
                                        .background(AppColors.primaryGreen)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            // Show Add button
                            Button(action: {
                                var productToAdd = product
                                
                                // Ensure product has valid restaurantId
                                if productToAdd.restaurantId.isEmpty {
                                    productToAdd = Product(
                                        id: productToAdd.id,
                                        name: productToAdd.name,
                                        description: productToAdd.description,
                                        price: productToAdd.price,
                                        restaurantId: restaurantId,
                                        category: productToAdd.category,
                                        isAvailable: productToAdd.isAvailable,
                                        rating: productToAdd.rating,
                                        extraTime: productToAdd.extraTime,
                                        photoId: productToAdd.photoId,
                                        isVeg: productToAdd.isVeg
                                    )
                                }
                                
                                // Set quantity first to show UI update
                                quantity = 1
                                
                                // Add to cart
                                orderManager.addToCart(product: productToAdd)
                                
                                // Show toast message
                                withAnimation {
                                    showingAddedToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        showingAddedToast = false
                                    }
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    
                                    if showingAddedToast {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Added to Cart")
                                            .font(.system(size: 16, weight: .semibold))
                                    } else {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Add to Cart")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(showingAddedToast ? Color.green : AppColors.primaryGreen)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                }
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
            }
        }
        .background(Color.white)
        .onAppear {
            // Check if already in cart
            quantity = orderManager.getQuantityInCart(productId: product.id)
            
            // Check if already in favorites
            isFavorite = favoriteManager.isFavorite(product)
            
            // Subscribe to favorite status change notifications
            NotificationCenter.default.addObserver(forName: FavoriteManager.favoriteStatusChangedNotification, object: nil, queue: .main) { notification in
                if let productId = notification.object as? String, productId == product.id {
                    // Update our local state if this product's favorite status changed
                    isFavorite = favoriteManager.isFavorite(product)
                    print("📣 Modal: Notification received: Updated favorite status for \(product.name) to \(isFavorite)")
                }
            }
        }
        .onDisappear {
            // Remove notification observer when view disappears
            NotificationCenter.default.removeObserver(self, name: FavoriteManager.favoriteStatusChangedNotification, object: nil)
        }
    }
}

// Helper for detail rows
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RestaurantDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RestaurantDetailView(restaurant: Restaurant(
            id: "previewRestaurant",
            name: "Preview Restaurant",
            estimatedTime: "25-30",
            cuisine: "Various",
            photoId: nil,
            rating: 4.5,
            location: "Preview Location"
        ))
        .environmentObject(OrderManager.shared)
        .environmentObject(FavoriteManager.shared)
    }
} 