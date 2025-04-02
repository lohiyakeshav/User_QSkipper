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
    
    // Default initializer with full restaurant data
    init(restaurant: Restaurant) {
        self.restaurant = restaurant
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
            viewModel.loadProducts(for: restaurant.id)
            
            // If we initialized with just an ID, we need to load the restaurant details
            if restaurant.name == "Loading..." {
                viewModel.loadRestaurant(id: restaurant.id)
            }
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
                            .fill(AppColors.primaryGreen.opacity(0.1))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: "cart.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.primaryGreen)
                            .frame(width: 20, height: 20)
                            .padding(9)
                        
                        // Show badge only if items in cart
                        let restaurantId = viewModel.restaurant?.id ?? restaurant.id
                        if !orderManager.currentCart.isEmpty && orderManager.currentRestaurantId == restaurantId {
                            Text("\(orderManager.getTotalItems())")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 10, y: -10)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Restaurant Info Section
    private var restaurantInfo: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Restaurant Name - Use viewModel.restaurant if available, otherwise use the passed restaurant
            Text(viewModel.restaurant?.name ?? restaurant.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
            
            // Restaurant Details in Row
            restaurantDetailRow
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
    
    private var restaurantDetailRow: some View {
        HStack(spacing: 20) {
            // Free Delivery Tag
            HStack(spacing: 5) {
                Image(systemName: "indianrupeesign")
                    .foregroundColor(AppColors.primaryGreen)
                    .font(.system(size: 13))
                
                Text("Free Delivery")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            // Delivery Time - Use viewModel.restaurant if available
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .foregroundColor(AppColors.primaryGreen)
                    .font(.system(size: 13))
                
                let estimatedTime = viewModel.restaurant?.estimatedTime ?? restaurant.estimatedTime ?? "20-30"
                Text("\(estimatedTime) mins")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            // Rating - Use viewModel.restaurant if available
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 13))
                
                let rating = viewModel.restaurant?.rating ?? restaurant.rating
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
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
                            restaurantId: viewModel.restaurant?.id ?? restaurant.id
                        )
                        .frame(minHeight: 260)
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
            restaurantInfo
            menuTitleSection
            categoryFilterSection
            productsSection
        }
        .background(Color.gray.opacity(0.1))
        .edgesIgnoringSafeArea(.top)
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
    @State private var showingAddedToast = false
    @State private var quantity = 0
    @EnvironmentObject private var orderManager: OrderManager
    @EnvironmentObject private var favoriteManager: FavoriteManager
    @State private var isFavorite = false
    
    var body: some View {
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
                    isFavorite.toggle()
                    if isFavorite {
                        favoriteManager.toggleFavorite(product)
                    } else {
                        favoriteManager.toggleFavorite(product)
                    }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .white)
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.3)))
                }
                .padding(8)
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
            .fixedSize(horizontal: false, vertical: true)
            
            // Add to cart button
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
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(AppColors.primaryGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        Text("\(quantity)")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(minWidth: 30)
                        
                        Button {
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
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Show Add button
                    Button(action: {
                        // ACTION: Put all logic here to ensure it gets triggered properly
                        print("🔶 Add button tapped directly - should work!")
                        
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
                                restaurantId: restaurantId, // Set the correct restaurantId from the property
                                category: productToAdd.category,
                                isAvailable: productToAdd.isAvailable,
                                rating: productToAdd.rating,
                                extraTime: productToAdd.extraTime,
                                photoId: productToAdd.photoId,
                                isVeg: productToAdd.isVeg
                            )
                        }
                        
                        // SPECIAL FIX: For specific problematic products like Omelette
                        if productToAdd.name.lowercased().contains("omlette") || 
                           productToAdd.name.lowercased().contains("omelette") || 
                           productToAdd.name.lowercased().contains("mixed soft") {
                            print("🔧 Applying special handling for known problematic product: \(productToAdd.name)")
                            
                            // Ensure price is valid
                            let validPrice = productToAdd.price > 0 ? productToAdd.price : 120.0
                            print("📊 Current price: \(productToAdd.price), Using price: \(validPrice)")
                            
                            // Force set the restaurant ID using the parameter passed to this component
                            productToAdd = Product(
                                id: productToAdd.id,
                                name: productToAdd.name,
                                description: productToAdd.description,
                                price: validPrice, // Use fixed price if current price is invalid
                                restaurantId: restaurantId,
                                category: productToAdd.category,
                                isAvailable: productToAdd.isAvailable,
                                rating: productToAdd.rating,
                                extraTime: productToAdd.extraTime,
                                photoId: productToAdd.photoId,
                                isVeg: productToAdd.isVeg
                            )
                        }
                        
                        print("🧩 Adding product: \(productToAdd.name), restaurantId: \(productToAdd.restaurantId)")
                        
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
                        // LABEL: Create the visual button here
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
                    .buttonStyle(PlainButtonStyle()) // Remove any default button styling
                    .contentShape(Rectangle()) // Ensure the entire area is tappable
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