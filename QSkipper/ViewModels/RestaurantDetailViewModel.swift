import Foundation
import SwiftUI

class RestaurantDetailViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var categories: [String] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var restaurant: Restaurant? = nil
    
    private let networkUtils = NetworkUtils.shared
    
    func loadRestaurant(id: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("📱 Loading restaurant details for ID: \(id)")
                let fetchedRestaurant = try await networkUtils.fetchRestaurant(with: id)
                
                await MainActor.run {
                    self.restaurant = fetchedRestaurant
                    self.isLoading = false
                    print("✅ Loaded restaurant: \(fetchedRestaurant.name)")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load restaurant: \(error.localizedDescription)"
                    self.isLoading = false
                    print("❌ Error loading restaurant: \(error)")
                }
            }
        }
    }
    
    func loadProducts(for restaurantId: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("Loading products for restaurant: \(restaurantId)")
                var fetchedProducts = try await networkUtils.fetchProducts(for: restaurantId)
                
                // CRITICAL FIX: Ensure all products have the correct restaurantId
                // This fixes the issue where some products might have empty or incorrect restaurantIds
                if !fetchedProducts.isEmpty {
                    for i in 0..<fetchedProducts.count {
                        if fetchedProducts[i].restaurantId.isEmpty {
                            // Copy the product with corrected restaurantId
                            let product = fetchedProducts[i]
                            let correctedProduct = Product(
                                id: product.id,
                                name: product.name,
                                description: product.description,
                                price: product.price,
                                restaurantId: restaurantId, // Set the correct restaurantId
                                category: product.category,
                                isAvailable: product.isAvailable,
                                rating: product.rating,
                                extraTime: product.extraTime,
                                photoId: product.photoId,
                                isVeg: product.isVeg
                            )
                            fetchedProducts[i] = correctedProduct
                            print("⚠️ Fixed empty restaurantId for product: \(correctedProduct.name)")
                        }
                    }
                }
                
                await MainActor.run {
                    self.products = fetchedProducts
                    self.extractCategories()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load products: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error loading products: \(error)")
                }
            }
        }
    }
    
    private func extractCategories() {
        // Get unique categories
        var uniqueCategories = Set<String>()
        for product in products {
            if let category = product.category, !category.isEmpty {
                uniqueCategories.insert(category)
            }
        }
        
        // Convert to array and sort
        self.categories = Array(uniqueCategories).sorted()
    }
} 