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
                let fetchedProducts = try await networkUtils.fetchProducts(for: restaurantId)
                
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