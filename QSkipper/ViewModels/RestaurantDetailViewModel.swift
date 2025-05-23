import Foundation
import SwiftUI

class RestaurantDetailViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var categories: [String] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var restaurant: Restaurant? = nil
    
    // Cache to store products by restaurant ID
    private var productCache: [String: [Product]] = [:]
    
    // Keep track of in-progress loads to prevent duplicate requests
    private var activeLoads: [String: Bool] = [:]
    
    // Last time we loaded data for a particular restaurant
    private var lastLoadTimes: [String: Date] = [:]
    private let minLoadInterval: TimeInterval = 30 // 30 seconds cooldown
    
    private let networkUtils = NetworkUtils.shared
    
    func loadRestaurant(id: String) {
        // Prevent duplicate loading
        guard !isLoading else {
            print("⚠️ Already loading restaurant, skipping request")
            return
        }
        
        // Check if we recently loaded this restaurant (to prevent duplicate calls)
        if let lastLoadTime = lastLoadTimes[id] {
            let elapsed = Date().timeIntervalSince(lastLoadTime)
            if elapsed < minLoadInterval {
                print("⏱️ Recently loaded restaurant \(id), skipping request. Try again in \(Int(minLoadInterval - elapsed))s")
                return
            }
        }
        
        // Check if we already have this restaurant in memory
        if let existingRestaurant = RestaurantManager.shared.getRestaurant(by: id) {
            print("✅ Using cached restaurant data for: \(existingRestaurant.name)")
            self.restaurant = existingRestaurant
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("📱 Loading restaurant details for ID: \(id)")
                let fetchedRestaurant = try await networkUtils.fetchRestaurant(with: id)
                
                await MainActor.run {
                    self.restaurant = fetchedRestaurant
                    self.isLoading = false
                    self.lastLoadTimes[id] = Date()
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
        // Prevent duplicate loading of the same restaurant's products
        if activeLoads[restaurantId] == true {
            print("⚠️ RESTAURANT DETAIL: Already loading products for \(restaurantId), skipping duplicate request")
            return
        }
        
        // Check if we recently loaded products for this restaurant (to prevent rapid repeated calls)
        if let lastLoadTime = lastLoadTimes[restaurantId] {
            let elapsed = Date().timeIntervalSince(lastLoadTime)
            if elapsed < minLoadInterval {
                print("⏱️ RESTAURANT DETAIL: Recently loaded products for \(restaurantId), skipping request. Try again in \(Int(minLoadInterval - elapsed))s")
                return
            }
        }
        
        isLoading = true
        activeLoads[restaurantId] = true
        errorMessage = nil
        
        print("📱 RESTAURANT DETAIL: Starting product load for restaurant ID: \(restaurantId)")
        print("⏱️ Time: \(Date().formatted(date: .abbreviated, time: .standard))")
        
        // Check if we have cached products for this restaurant
        if let cachedProducts = productCache[restaurantId], !cachedProducts.isEmpty {
            print("🔍 RESTAURANT DETAIL: Using cached products for restaurant ID: \(restaurantId)")
            
            Task {
                await MainActor.run {
                    self.products = cachedProducts
                    self.extractCategories()
                    self.isLoading = false
                    self.activeLoads[restaurantId] = false
                    self.lastLoadTimes[restaurantId] = Date()
                    print("✅ RESTAURANT DETAIL: Loaded \(cachedProducts.count) products from cache")
                    print("📋 Categories: \(self.categories.joined(separator: ", "))")
                }
            }
            return
        }
        
        Task {
            do {
                print("📡 RESTAURANT DETAIL: Calling networkUtils.fetchProducts")
                var fetchedProducts = try await networkUtils.fetchProducts(for: restaurantId)
                
                // Debug: Print all products before fixing
                print("📋 RESTAURANT DETAIL: Fetched \(fetchedProducts.count) products:")
                fetchedProducts.forEach { product in
                    print("   → \(product.name) (ID: \(product.id), Category: \(product.category ?? "nil"), RestaurantId: \(product.restaurantId))")
                }
                
                // CRITICAL FIX: Ensure all products have the correct restaurantId
                // This fixes the issue where some products might have empty or incorrect restaurantIds
                if !fetchedProducts.isEmpty {
                    var fixedProducts = 0
                    for i in 0..<fetchedProducts.count {
                        if fetchedProducts[i].restaurantId.isEmpty || fetchedProducts[i].restaurantId != restaurantId {
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
                            fixedProducts += 1
                            print("🔧 Fixed restaurantId for product: \(product.name)")
                        }
                    }
                    if fixedProducts > 0 {
                        print("🔧 RESTAURANT DETAIL: Fixed restaurantId for \(fixedProducts) products")
                    }
                }
                
                await MainActor.run {
                    self.products = fetchedProducts
                    
                    // Store in cache for future use
                    self.productCache[restaurantId] = fetchedProducts
                    
                    self.extractCategories()
                    self.isLoading = false
                    self.activeLoads[restaurantId] = false
                    self.lastLoadTimes[restaurantId] = Date()
                    
                    // Debug: Print final products after fixing
                    print("✅ RESTAURANT DETAIL: Final \(self.products.count) products:")
                    self.products.forEach { product in
                        print("   → \(product.name) (ID: \(product.id), Category: \(product.category ?? "nil"), RestaurantId: \(product.restaurantId))")
                    }
                    
                    // Log product categories and count
                    print("📋 Categories: \(self.categories.joined(separator: ", "))")
                    
                    // Log price range
                    if let minPrice = fetchedProducts.map({ $0.price }).min(),
                       let maxPrice = fetchedProducts.map({ $0.price }).max() {
                        print("💰 Price range: ₹\(String(format: "%.2f", minPrice)) - ₹\(String(format: "%.2f", maxPrice))")
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load products: \(error.localizedDescription)"
                    self.isLoading = false
                    self.activeLoads[restaurantId] = false
                    print("❌ RESTAURANT DETAIL: Error loading products: \(error)")
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
    
    // Add method to set restaurant directly from preloaded data
    func setRestaurant(_ restaurant: Restaurant) {
        self.restaurant = restaurant
        print("✅ Updated restaurant in ViewModel with preloaded data: \(restaurant.name)")
    }
    
    // Add method to clear cache
    func clearCache() {
        print("🧹 RESTAURANT DETAIL: Clearing product cache")
        productCache.removeAll()
        lastLoadTimes.removeAll()
        activeLoads.removeAll()
    }
    
    // Clear cache for specific restaurant
    func clearCache(for restaurantId: String) {
        print("🧹 RESTAURANT DETAIL: Clearing cache for restaurant ID: \(restaurantId)")
        productCache[restaurantId] = nil
        lastLoadTimes[restaurantId] = nil
        activeLoads[restaurantId] = nil
    }
}