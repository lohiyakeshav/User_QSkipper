import SwiftUI

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
                    }
                    
                    Spacer(minLength: 100) // Extra space for tab bar
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.white)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 0)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 1)
            }
            .onAppear {
                // Debug favorites
                print("🔍 FAVORITES: \(favoriteManager.favoriteDishes.count) dishes")
                favoriteManager.favoriteDishes.forEach { product in
                    print("  - \(product.name)")
                }
            }
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