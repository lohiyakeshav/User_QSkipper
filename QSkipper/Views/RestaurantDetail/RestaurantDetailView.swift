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
    
    var body: some View {
        ScrollView {
            restaurantContent
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadProducts(for: restaurant.id)
        }
        .overlay(cartFloatingButton)
    }
    
    // MARK: - Restaurant Banner Section
    private var restaurantBanner: some View {
        ZStack(alignment: .top) {
            // Restaurant Banner Image
            RestaurantImageView(photoId: restaurant.photoId, name: restaurant.name)
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Restaurant Info Section
    private var restaurantInfo: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Restaurant Name
            Text(restaurant.name)
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
            
            // Delivery Time
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .foregroundColor(AppColors.primaryGreen)
                    .font(.system(size: 13))
                
                Text("\(restaurant.estimatedTime ?? "20-30") mins")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            // Rating
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 13))
                
                Text(String(format: "%.1f", restaurant.rating))
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
                            addToCart: {
                                orderManager.addToCart(product: product)
                            }
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
    
    // MARK: - Cart Floating Button
    private var cartFloatingButton: some View {
        VStack {
            Spacer()
            
            // Only show if cart is not empty
            if !orderManager.currentCart.isEmpty {
                NavigationLink(destination: CartView()) {
                    HStack(spacing: 15) {
                        // Cart icon with count
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "cart.fill")
                                .foregroundColor(AppColors.primaryGreen)
                            
                            // Badge
                            Text("\(orderManager.getTotalItems())")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 12, y: -12)
                        }
                        
                        Text("View Cart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("₹\(String(format: "%.0f", orderManager.getCartTotal()))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background(AppColors.primaryGreen)
                    .cornerRadius(25)
                    .shadow(color: AppColors.primaryGreen.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
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
    let addToCart: () -> Void
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
                    Button {
                        addToCart()
                        quantity = 1
                        withAnimation {
                            showingAddedToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showingAddedToast = false
                            }
                        }
                    } label: {
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
                        .background(showingAddedToast ? Color.green : AppColors.primaryGreen)
                        .cornerRadius(8)
                    }
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
            // Check if already in favorites
            isFavorite = favoriteManager.isFavorite(product)
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