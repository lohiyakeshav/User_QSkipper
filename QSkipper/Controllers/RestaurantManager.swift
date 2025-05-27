//
//  RestaurantManager.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import Foundation
import SwiftUI

class RestaurantManager: ObservableObject {
    static let shared = RestaurantManager()
    
    private let networkManager = SimpleNetworkManager.shared
    private let networkUtils = NetworkUtils.shared
    
    @Published var restaurants: [Restaurant] = []
    @Published var products: [String: [Product]] = [:] // Restaurant ID -> Products
    @Published var topPicks: [Product] = []
    
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    // Image caches
    private var restaurantImageCache: [String: UIImage] = [:]
    private var productImageCache: [String: UIImage] = [:]
    
    private init() {}
    
    // MARK: - Restaurant Methods
    
    // Fetch all restaurants
    @MainActor
    func fetchAllRestaurants() async throws -> [Restaurant] {
        self.isLoading = true
        self.error = nil
        
        // Store existing restaurants for fallback
        let existingRestaurants = self.restaurants
        
        do {
            print("📍 Fetching all restaurants...")
            let restaurants = try await networkUtils.fetchRestaurants()
            
            print("✅ Successfully fetched \(restaurants.count) restaurants")
            
            // Only update if we received data
            if !restaurants.isEmpty {
                self.restaurants = restaurants
            } else {
                print("⚠️ Received empty restaurants array, keeping existing data")
            }
            
            self.isLoading = false
            
            return restaurants
            
        } catch {
            print("❌ Error fetching restaurants: \(error)")
            self.error = error.localizedDescription
            self.isLoading = false
            
            // If we have existing data, return it instead of throwing
            if !existingRestaurants.isEmpty {
                print("✅ Returning \(existingRestaurants.count) existing restaurants despite fetch error")
                return existingRestaurants
            }
            
            throw error
        }
    }
    
    // Get restaurant image
    func getRestaurantImage(photoId: String?) async throws -> UIImage {
        // Check if image is already cached
        if let id = photoId, !id.isEmpty, let cachedImage = restaurantImageCache[id] {
            print("🖼️ Using cached restaurant image for ID: \(id)")
            return cachedImage
        }
        
        // Fallback image if photoId is nil or empty
        guard let id = photoId, !id.isEmpty else {
            print("⚠️ No photoId provided for restaurant - using fallback")
            return generatePlaceholderImage(for: "Restaurant", category: "dining")
        }
        
        do {
            print("🖼️ Fetching restaurant image for ID: \(id)")
            let image = try await networkUtils.fetchRestaurantImage(photoId: id)
            
            // Cache the image
            restaurantImageCache[id] = image
            print("✅ Restaurant image loaded and cached for ID: \(id)")
            
            return image
        } catch {
            print("❌ Error loading restaurant image: \(error)")
            
            // Generate a placeholder image instead of failing
            let placeholderImage = generatePlaceholderImage(for: "Restaurant", category: "dining")
            
            // Update error on main thread
            await MainActor.run {
                self.error = error.localizedDescription
            }
            
            return placeholderImage
        }
    }
    
    // MARK: - Product Methods
    
    // Fetch products for a restaurant
    @MainActor
    func fetchProducts(for restaurantId: String) async throws -> [Product] {
        self.isLoading = true
        self.error = nil
        
        print("🍔 Starting fetch products for restaurant ID: \(restaurantId)")
        
        do {
            let products = try await networkUtils.fetchProducts(for: restaurantId)
            
            print("✅ Successfully fetched \(products.count) products")
            
            if products.isEmpty {
                print("⚠️ No products found for restaurant ID: \(restaurantId)")
            } else {
                // Log the first few products for debugging
                for (index, product) in products.prefix(3).enumerated() {
                    print("📦 Product \(index+1): Name: \(product.name), Category: \(product.category ?? "N/A"), PhotoID: \(product.photoId ?? "None")")
                }
            }
            
            self.products[restaurantId] = products
            self.isLoading = false
            
            return products
            
        } catch {
            print("❌ Error fetching products: \(error)")
            self.error = error.localizedDescription
            self.isLoading = false
            throw error
        }
    }
    
    // Get product image
    func getProductImage(photoId: String?) async throws -> UIImage {
        // Check if image is already cached
        if let id = photoId, !id.isEmpty, let cachedImage = productImageCache[id] {
            print("🖼️ Using cached product image for ID: \(id)")
            return cachedImage
        }
        
        // Fallback image if photoId is nil or empty
        guard let id = photoId, !id.isEmpty else {
            print("⚠️ No photoId provided for product - using fallback")
            return generatePlaceholderImage(for: "Food", category: "food")
        }
        
        do {
            print("🖼️ Fetching product image for ID: \(id)")
            let image = try await networkUtils.fetchProductImage(photoId: id)
            
            // Cache the image
            productImageCache[id] = image
            print("✅ Product image loaded and cached for ID: \(id)")
            
            return image
        } catch {
            print("❌ Error loading product image: \(error)")
            
            // Generate a placeholder image instead of failing
            let placeholderImage = generatePlaceholderImage(for: "Product", category: "food")
            
            // Update error on main thread
            await MainActor.run {
                self.error = error.localizedDescription
            }
            
            return placeholderImage
        }
    }
    
    // MARK: - Top Picks
    
    // Fetch top picks
    @MainActor
    func fetchTopPicks() async throws -> [Product] {
        self.isLoading = true
        self.error = nil
        
        // Store existing top picks for fallback
        let existingTopPicks = self.topPicks
        
        print("🔍 RestaurantManager: Starting top picks fetch")
        
        do {
            print("📡 RestaurantManager: Calling networkUtils.fetchTopPicks()")
            let topPicks = try await networkUtils.fetchTopPicks()
            
            print("✅ RestaurantManager: Successfully fetched \(topPicks.count) top picks")
            
            // Log details of each top pick for debugging
            for (index, product) in topPicks.enumerated() {
                print("🍽️ Top Pick #\(index + 1): \(product.name), ID: \(product.id), RestaurantID: \(product.restaurantId), PhotoID: \(product.photoId ?? "None")")
            }
            
            // Only update if we received data
            if !topPicks.isEmpty {
                self.topPicks = topPicks
            } else {
                print("⚠️ Received empty top picks array, keeping existing data")
            }
            
            self.isLoading = false
            
            return topPicks
            
        } catch {
            print("❌ RestaurantManager: Error fetching top picks: \(error)")
            self.error = error.localizedDescription
            self.isLoading = false
            
            // If we have existing data, return it instead of throwing
            if !existingTopPicks.isEmpty {
                print("✅ Returning \(existingTopPicks.count) existing top picks despite fetch error")
                return existingTopPicks
            }
            
            // Only throw if we have no existing data
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    // Get restaurant by ID
    func getRestaurant(by id: String) -> Restaurant? {
        return restaurants.first { $0.id == id }
    }
    
    // Get products for a restaurant
    func getProducts(for restaurantId: String) -> [Product] {
        return products[restaurantId] ?? []
    }
    
    // Get product by ID
    func getProduct(by id: String, in restaurantId: String) -> Product? {
        return products[restaurantId]?.first { $0.id == id }
    }
    
    // Generate a placeholder image with gradient background and icon
    private func generatePlaceholderImage(for type: String, category: String, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Draw gradient background
            let colors: [UIColor]
            if category == "food" {
                colors = [UIColor(Color(hex: "#76b852")), UIColor(Color(hex: "#8DC26F"))]
            } else {
                colors = [UIColor(Color(hex: "#FF5F6D")), UIColor(Color(hex: "#FFC371"))]
            }
            
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map { $0.cgColor } as CFArray,
                locations: [0.0, 1.0]
            )!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Draw icon
            let iconName = category == "food" ? "fork.knife" : "building.2"
            if let icon = UIImage(systemName: iconName)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let iconSize = CGSize(width: size.width * 0.4, height: size.height * 0.4)
                let iconRect = CGRect(
                    x: (size.width - iconSize.width) / 2,
                    y: (size.height - iconSize.height) / 2,
                    width: iconSize.width,
                    height: iconSize.height
                )
                
                icon.draw(in: iconRect)
            }
            
            // Add type label
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: size.width * 0.12),
                .foregroundColor: UIColor.white
            ]
            
            let text = type
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: size.height * 0.7,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
} 