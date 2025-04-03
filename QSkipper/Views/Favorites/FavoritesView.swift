import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favoriteManager: FavoriteManager
    @EnvironmentObject var orderManager: OrderManager
    @EnvironmentObject var tabSelection: TabSelection
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with title and cart button
                    HStack {
                        Text("Your Favorite Dishes")
                            .font(AppFonts.title)
                        
                        Spacer()
                        
                        // Cart button - switch to home tab and then access cart
                        Button {
                            print("🛒 FavoritesView: Cart button tapped")
                            print("📱 FavoritesView: Current tab before switch: \(tabSelection.selectedTab)")
                            
                            // First switch to home tab where cart access works
                            tabSelection.selectedTab = .home
                            print("🔄 FavoritesView: Tab switched to home")
                            
                            // Small delay to ensure tab switch completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                print("🔔 FavoritesView: Posting OpenCart notification")
                                // Post notification to open cart
                                NotificationCenter.default.post(name: NSNotification.Name("OpenCart"), object: nil)
                            }
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
                    .padding(.top, 20)
                    
                    if favoriteManager.favoriteDishes.isEmpty {
                        // Full-width container for the empty state
                        ZStack {
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
                                    .multilineTextAlignment(.center)
                                Text("Add some dishes to your favorites from the menu")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.mediumGray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                // Add a browse button to encourage user action
                                Button {
                                    print("🔄 FavoritesView: Browse Restaurants button tapped")
                                    
                                    // Set the tab selection in TabSelection singleton
                                    tabSelection.selectedTab = .home
                                    
                                    // Post notification to ensure tab change is recognized by the HomeView
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        print("🔔 FavoritesView: Posting SwitchToHomeTab notification")
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("SwitchToHomeTab"),
                                            object: nil
                                        )
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 14))
                                        Text("Browse Restaurants")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 220)
                                    .padding(.vertical, 12)
                                    .background(AppColors.primaryGreen)
                                    .cornerRadius(10)
                                }
                                .padding(.top, 10)
                                
                                Spacer()
                            }
                            .padding(.top, 20)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity, minHeight: 500)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                            ForEach(favoriteManager.favoriteDishes) { product in
                                FavoriteProductCard(product: product)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Add bottom padding for tab bar
                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
            .background(Color.white)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 0)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 1)
            }
            .onAppear {
                print("📱 FavoritesView: View appeared")
                print("🔍 FAVORITES: \(favoriteManager.favoriteDishes.count) dishes")
                favoriteManager.favoriteDishes.forEach { product in
                    print("  - \(product.name)")
                }
                print("🛒 FavoritesView: Cart state - Items: \(orderManager.currentCart.count)")
            }
            .onDisappear {
                print("📱 FavoritesView: View disappeared")
            }
        }
    }
}

struct FavoriteProductCard: View {
    @EnvironmentObject var favoriteManager: FavoriteManager
    @EnvironmentObject var orderManager: OrderManager
    @State private var showAddedToCart = false
    @State private var quantity = 0
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
                
                // Add to cart or quantity controls
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
                    // Add to cart button
                    Button {
                        quantity = 1
                        
                        // CRITICAL FIX: Ensure product has a valid restaurantId
                        var productToAdd = product
                        
                        // Check and fix empty restaurantId
                        if productToAdd.restaurantId.isEmpty {
                            print("⚠️ FavoritesView: Empty restaurantId detected in favorite product: \(productToAdd.name)")
                            
                            // Try to find a valid restaurantId for this product using HomeViewModel
                            // Since we can't access HomeViewModel directly, we'll set a default
                            // This is a temporary fix - the proper restaurantId should come from the API
                            productToAdd = Product(
                                id: productToAdd.id,
                                name: productToAdd.name,
                                description: productToAdd.description,
                                price: productToAdd.price,
                                restaurantId: "default_restaurant_id", // Set a default to allow adding to cart
                                category: productToAdd.category,
                                isAvailable: productToAdd.isAvailable,
                                rating: productToAdd.rating,
                                extraTime: productToAdd.extraTime,
                                photoId: productToAdd.photoId,
                                isVeg: productToAdd.isVeg
                            )
                            
                            print("🔄 FavoritesView: Fixed restaurantId for product: \(productToAdd.name)")
                        }
                        
                        orderManager.addToCart(product: productToAdd)
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
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
        .onAppear {
            // Check if already in cart
            quantity = orderManager.getQuantityInCart(productId: product.id)
        }
    }
} 