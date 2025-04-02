//
//  NetworkUtils.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import Foundation
import UIKit
import SwiftUI // For accessing our app's Utils folder

// NetworkUtils for handling common network operations
class NetworkUtils {
    // Base URL for API endpoints
    let baseURl = URL(string: "https://queueskipperbackend.onrender.com/")!
    
    static let shared = NetworkUtils()
    
    enum NetworkUtilsError: Error, LocalizedError {
        case RestaurantNotFound
        case ImageNotFound
        case DishNotFound
        case RegistrationFailed
        case OrderFailed
        case LoginFailed
        case OTPVerificationFailed
        case NetworkError
        case JSONParsingError
        
        var errorDescription: String? {
            switch self {
            case .RestaurantNotFound:
                return "Restaurant not found"
            case .ImageNotFound:
                return "Image not found"
            case .DishNotFound:
                return "Dish not found"
            case .RegistrationFailed:
                return "Registration failed"
            case .OrderFailed:
                return "Failed to place order"
            case .LoginFailed:
                return "Login failed"
            case .OTPVerificationFailed:
                return "OTP verification failed"
            case .NetworkError:
                return "Network error occurred"
            case .JSONParsingError:
                return "Error parsing server response"
            }
        }
    }
    
    // MARK: - Restaurant Endpoints
    
    func fetchRestaurant(with restaurantId: String) async throws -> Restaurant {
        let url = baseURl.appendingPathComponent("get_Restaurant/\(restaurantId)")
        
        print("📡 Fetching restaurant details for ID: \(restaurantId) from: \(url.absoluteString)")
        
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🔄 Restaurant fetch attempt \(attempt)/\(maxRetries)")
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    throw NetworkUtilsError.NetworkError
                }
                
                if httpResponse.statusCode != 200 {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    throw NetworkUtilsError.RestaurantNotFound
                }
                
                // Print the response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Restaurant response: \(responseString)")
                }
                
                // Try to decode the response
                do {
                    // Try to decode as RestaurantResponse which has the {"restaurant": {...}} structure
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let restaurantData = json["restaurant"] as? [String: Any] {
                        
                        let id = restaurantData["_id"] as? String ?? restaurantId
                        let name = restaurantData["name"] as? String ?? "Unknown Restaurant"
                        let location = restaurantData["location"] as? String ?? "Unknown Location"
                        let photoId = restaurantData["photoId"] as? String
                        let rating = (restaurantData["rating"] as? NSNumber)?.doubleValue ?? 4.0
                        let cuisine = restaurantData["cuisine"] as? String
                        let estimatedTime = restaurantData["estimatedTime"] as? String
                        
                        let restaurant = Restaurant(
                            id: id,
                            name: name,
                            estimatedTime: estimatedTime,
                            cuisine: cuisine,
                            photoId: photoId,
                            rating: rating,
                            location: location
                        )
                        
                        print("✅ Successfully parsed restaurant: \(name)")
                        return restaurant
                    } else {
                        print("❌ Could not extract restaurant data from JSON")
                        throw NetworkUtilsError.JSONParsingError
                    }
                } catch {
                    print("❌ JSON Parsing Error: \(error)")
                    throw NetworkUtilsError.JSONParsingError
                }
            } catch {
                lastError = error
                print("❌ Restaurant fetch attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Wait before retrying (exponential backoff)
                if attempt < maxRetries {
                    let delay = Double(attempt) * 0.5 // 0.5s, 1s, 1.5s
                    print("⏱️ Waiting \(delay)s before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // If all attempts failed, throw the last error or a default error
        throw lastError ?? NetworkUtilsError.RestaurantNotFound
    }
    
    func fetchRestaurants() async throws -> [Restaurant] {
        let url = baseURl.appendingPathComponent("get_All_Restaurant")
        
        print("📡 Fetching restaurants from: \(url.absoluteString)")
        
        // Add retry logic for resilience
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🔄 Restaurant fetch attempt \(attempt)/\(maxRetries)")
                
                // Create a request with timeout settings
                var request = URLRequest(url: url)
                request.timeoutInterval = 15 // Shorter timeout (15 seconds instead of default 60)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    throw NetworkUtilsError.NetworkError
                }
                
                if httpResponse.statusCode != 200 {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    throw NetworkUtilsError.NetworkError
                }
                
                // Print the response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Restaurant response: \(responseString)")
                    print("📄 Response length: \(data.count) bytes")
                    print("📄 HTTP Status: \(httpResponse.statusCode)")
                    
                    // Print HTTP headers
                    print("📄 HTTP Headers:")
                    httpResponse.allHeaderFields.forEach { key, value in
                        print("  \(key): \(value)")
                    }
                }
                
                // Try to decode the response
                do {
                    let decoder = JSONDecoder()
                    
                    // First try to decode as RestaurantsResponse which has the {"Restaurant": [...]} structure
                    let restaurantsResponse = try decoder.decode(RestaurantsResponse.self, from: data)
                    print("✅ Successfully decoded \(restaurantsResponse.restaurants.count) restaurants from RestaurantsResponse")
                    return restaurantsResponse.restaurants
                } catch {
                    print("❌ JSON Parsing Error: \(error)")
                    
                    // If that fails, try alternate approach with dynamic key decoding
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let restaurantArray = json["Restaurant"] as? [[String: Any]] {
                            print("✅ Found Restaurant array using manual JSON parsing, attempting to decode individual restaurants")
                            
                            // Convert back to data
                            let restaurantData = try JSONSerialization.data(withJSONObject: restaurantArray)
                            
                            // Decode array of restaurants
                            let restaurants = try JSONDecoder().decode([Restaurant].self, from: restaurantData)
                            print("✅ Successfully decoded \(restaurants.count) restaurants with manual approach")
                            return restaurants
                        } else {
                            print("❌ Could not extract Restaurant array from JSON")
                            throw NetworkUtilsError.JSONParsingError
                        }
                    } catch {
                        print("❌ Alternative parsing also failed: \(error)")
                        throw NetworkUtilsError.JSONParsingError
                    }
                }
            } catch {
                lastError = error
                print("❌ Restaurant fetch attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Wait before retrying (exponential backoff)
                if attempt < maxRetries {
                    let delay = Double(attempt) * 0.5 // 0.5s, 1s, 1.5s
                    print("⏱️ Waiting \(delay)s before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // Try alternate endpoint format (without /admin/)
        print("🔄 Trying fallback URL for restaurants...")
        let fallbackUrlString = "https://qskipper.com/api/get_All_Restaurant"
        
        guard let fallbackUrl = URL(string: fallbackUrlString) else {
            print("❌ Failed to create fallback URL")
            throw lastError ?? NetworkUtilsError.NetworkError
        }
        
        do {
            print("📡 Trying fallback URL: \(fallbackUrlString)")
            let (data, response) = try await URLSession.shared.data(from: fallbackUrl)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response from fallback URL")
                throw NetworkUtilsError.NetworkError
            }
            
            if httpResponse.statusCode != 200 {
                print("❌ HTTP Error from fallback URL: \(httpResponse.statusCode)")
                throw NetworkUtilsError.NetworkError
            }
            
            // Try to decode with the same approaches as before
            do {
                let decoder = JSONDecoder()
                
                // First try RestaurantsResponse
                if let restaurantsResponse = try? decoder.decode(RestaurantsResponse.self, from: data) {
                    print("✅ Successfully decoded \(restaurantsResponse.restaurants.count) restaurants from fallback URL")
                    return restaurantsResponse.restaurants
                }
                
                // Try manual approach with Restaurant key
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let restaurantArray = json["Restaurant"] as? [[String: Any]] {
                    
                    let restaurantData = try JSONSerialization.data(withJSONObject: restaurantArray)
                    let restaurants = try JSONDecoder().decode([Restaurant].self, from: restaurantData)
                    print("✅ Successfully decoded \(restaurants.count) restaurants from fallback URL with manual approach")
                    return restaurants
                }
                
                // Try direct array decoding as last resort
                if let restaurants = try? decoder.decode([Restaurant].self, from: data) {
                    print("✅ Successfully decoded \(restaurants.count) restaurants as direct array from fallback URL")
                    return restaurants
                }
                
                print("❌ All fallback parsing approaches failed")
                throw NetworkUtilsError.JSONParsingError
            } catch {
                print("❌ Fallback parsing failed: \(error)")
                throw NetworkUtilsError.JSONParsingError
            }
        } catch {
            print("❌ Fallback URL failed: \(error)")
            
            // Try using the backup hardcoded URL (render.com server)
            let backupUrl = URL(string: "https://queueskipperbackend.onrender.com/get_All_Restaurant")!
            print("🔄 Trying backup URL: \(backupUrl.absoluteString)")
            
            do {
                let (data, response) = try await URLSession.shared.data(from: backupUrl)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response from backup URL")
                    throw NetworkUtilsError.NetworkError
                }
                
                if httpResponse.statusCode != 200 {
                    print("❌ HTTP Error from backup URL: \(httpResponse.statusCode)")
                    throw NetworkUtilsError.NetworkError
                }
                
                // Try all decoding approaches
                if let restaurantsResponse = try? JSONDecoder().decode(RestaurantsResponse.self, from: data) {
                    print("✅ Successfully decoded \(restaurantsResponse.restaurants.count) restaurants from backup URL")
                    return restaurantsResponse.restaurants
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let restaurantArray = json["Restaurant"] as? [[String: Any]] {
                    
                    let restaurantData = try JSONSerialization.data(withJSONObject: restaurantArray)
                    if let restaurants = try? JSONDecoder().decode([Restaurant].self, from: restaurantData) {
                        print("✅ Successfully decoded \(restaurants.count) restaurants from backup URL with manual approach")
                        return restaurants
                    }
                }
                
                // Last resort - try direct array
                if let restaurants = try? JSONDecoder().decode([Restaurant].self, from: data) {
                    print("✅ Successfully decoded \(restaurants.count) restaurants as direct array from backup URL")
                    return restaurants
                }
                
                // If all attempts failed, throw the error
                print("❌ Backup URL also failed: \(error)")
                throw lastError ?? NetworkUtilsError.RestaurantNotFound
            }
        }
    }
    
    func fetchRestaurantImage(photoId: String) async throws -> UIImage {
        // Check image cache first
        if let cachedImage = ImageCache.shared.getImage(forKey: "restaurant_\(photoId)") {
            print("✅ Using cached restaurant image for ID: \(photoId)")
            return cachedImage
        }
        
        // Use the correct endpoint structure
        let urlString = "\(baseURl.absoluteString)get_restaurant_photo/\(photoId)"
        
        print("📡 Fetching restaurant image from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for restaurant image")
            throw NetworkUtilsError.NetworkError
        }
        
        // Add retry logic for network resilience
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🔄 Restaurant image fetch attempt \(attempt)/\(maxRetries) for ID: \(photoId)")
                
                // Create a request with timeout settings
                var request = URLRequest(url: url)
                request.timeoutInterval = 15 // Shorter timeout (15 seconds instead of default 60)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    throw NetworkUtilsError.NetworkError
                }
                
                if httpResponse.statusCode != 200 {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    throw NetworkUtilsError.ImageNotFound
                }
                
                guard let image = UIImage(data: data) else {
                    print("❌ Could not create image from data")
                    throw NetworkUtilsError.ImageNotFound
                }
                
                // Cache the loaded image
                ImageCache.shared.setImage(image, forKey: "restaurant_\(photoId)")
                
                print("✅ Successfully loaded restaurant image")
                return image
                
            } catch {
                lastError = error
                print("❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Wait before retrying (exponential backoff)
                if attempt < maxRetries {
                    let delay = Double(attempt) * 0.5 // 0.5s, 1s, 1.5s
                    print("⏱️ Waiting \(delay)s before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All attempts failed, try a fallback solution
        print("🔄 Trying fallback solution after \(maxRetries) failed attempts...")
        
        // Try alternate endpoint format (without /admin/)
        let fallbackUrlString = "https://qskipper.com/api/get_restaurant_photo/\(photoId)"
        
        guard let fallbackUrl = URL(string: fallbackUrlString) else {
            print("❌ Failed to create fallback URL")
            throw lastError ?? NetworkUtilsError.ImageNotFound
        }
        
        do {
            print("📡 Trying fallback URL: \(fallbackUrlString)")
            let (data, response) = try await URLSession.shared.data(from: fallbackUrl)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response from fallback URL")
                throw NetworkUtilsError.NetworkError
            }
            
            if httpResponse.statusCode != 200 {
                print("❌ HTTP Error from fallback URL: \(httpResponse.statusCode)")
                throw NetworkUtilsError.ImageNotFound
            }
            
            guard let image = UIImage(data: data) else {
                print("❌ Could not create image from fallback data")
                throw NetworkUtilsError.ImageNotFound
            }
            
            // Cache the loaded image
            ImageCache.shared.setImage(image, forKey: "restaurant_\(photoId)")
            
            print("✅ Successfully loaded restaurant image from fallback URL")
            return image
            
        } catch {
            print("❌ Failed to load restaurant image (including fallback): \(error)")
            
            // Return a placeholder image instead of throwing an error
            if let placeholderImage = UIImage(systemName: "fork.knife") {
                print("⚠️ Using system placeholder image")
                return placeholderImage
            }
            
            // If even the system placeholder fails, create a simple colored image
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
            let placeholderImage = renderer.image { ctx in
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [UIColor(red: 1, green: 0.6, blue: 0.4, alpha: 1).cgColor, 
                             UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1).cgColor] as CFArray,
                    locations: [0, 1]
                )!
                
                let startPoint = CGPoint(x: 0, y: 0)
                let endPoint = CGPoint(x: 100, y: 100)
                ctx.cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
            }
            
            print("⚠️ Using generated placeholder image")
            return placeholderImage
        }
    }
    
    // MARK: - Product Endpoints
    
    func fetchProducts(for restaurantId: String) async throws -> [Product] {
        // Use the correct endpoint structure
        let urlString = "\(baseURl.absoluteString)get_all_product/\(restaurantId)"
        
        print("📡 Fetching products from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for products")
            throw NetworkUtilsError.NetworkError
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw NetworkUtilsError.NetworkError
            }
            
            if httpResponse.statusCode != 200 {
                print("❌ HTTP Error: \(httpResponse.statusCode)")
                throw NetworkUtilsError.DishNotFound
            }
            
            // Print the full response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Full products response: \(responseString)")
            }
            
            // Try to decode the response
            do {
                let decoder = JSONDecoder()
                
                // First, try to decode as ProductsResponse
                let productsResponse = try decoder.decode(ProductsResponse.self, from: data)
                print("✅ Successfully decoded \(productsResponse.products.count) products using ProductsResponse")
                return productsResponse.products
            } catch let initialError {
                print("❌ Initial JSON Parsing Error: \(initialError)")
                
                // If that fails, try manual JSON parsing to extract the products
                do {
                    // Try various potential structures
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Look for products array under various keys
                        let possibleKeys = ["products", "Products", "items", "dishes", "menuItems", "allProducts"]
                        
                        for key in possibleKeys {
                            if let productsArray = json[key] as? [[String: Any]] {
                                print("✅ Found products array using key: \(key)")
                                
                                // Convert back to data
                                let productsData = try JSONSerialization.data(withJSONObject: productsArray)
                                
                                // Decode array of products
                                let products = try JSONDecoder().decode([Product].self, from: productsData)
                                print("✅ Successfully decoded \(products.count) products with manual approach")
                                return products
                            }
                        }
                        
                        // If we get here, try to see if it's a direct array
                        if let productsArray = json as? [[String: Any]] {
                            print("✅ Found products as direct root array")
                            
                            // Convert back to data
                            let productsData = try JSONSerialization.data(withJSONObject: productsArray)
                            
                            // Decode array of products
                            let products = try JSONDecoder().decode([Product].self, from: productsData)
                            print("✅ Successfully decoded \(products.count) products from root array")
                            return products
                        }
                        
                        // If we get here, we couldn't find a recognized structure
                        print("❌ Could not find products array in JSON with known keys")
                        
                        // Last attempt: let's try to use the custom decoder in ProductsResponse directly
                        if initialError is DecodingError {
                            let newDecoder = JSONDecoder()
                            let productsResponse = try newDecoder.decode(ProductsResponse.self, from: data)
                            print("✅ Successfully decoded \(productsResponse.products.count) products using ProductsResponse fallback")
                            return productsResponse.products
                        }
                    } else if let directArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        // The response might be a direct array
                        print("✅ Response is a direct array")
                        
                        // Convert back to data
                        let productsData = try JSONSerialization.data(withJSONObject: directArray)
                        
                        // Decode array of products
                        let products = try JSONDecoder().decode([Product].self, from: productsData)
                        print("✅ Successfully decoded \(products.count) products from direct array")
                        return products
                    }
                } catch let fallbackError {
                    print("❌ Fallback parsing also failed: \(fallbackError)")
                }
                
                // If all parsing attempts fail, return empty array
                print("⚠️ All parsing attempts failed - returning empty array")
                return []
            }
            
        } catch {
            print("❌ Network request failed: \(error)")
            throw NetworkUtilsError.NetworkError
        }
    }
    
    func fetchProductImage(photoId: String) async throws -> UIImage {
        // Check image cache first
        if let cachedImage = ImageCache.shared.getImage(forKey: "product_\(photoId)") {
            print("✅ Using cached product image for ID: \(photoId)")
            return cachedImage
        }
        
        // Use the correct endpoint structure
        let urlString = "\(baseURl.absoluteString)get_product_photo/\(photoId)"
        
        print("📡 Fetching product image from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for product image")
            throw NetworkUtilsError.NetworkError
        }
        
        // Add retry logic for network resilience
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🔄 Image fetch attempt \(attempt)/\(maxRetries) for ID: \(photoId)")
                
                // Create a request with timeout settings
                var request = URLRequest(url: url)
                request.timeoutInterval = 15 // Shorter timeout (15 seconds instead of default 60)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    throw NetworkUtilsError.NetworkError
                }
                
                if httpResponse.statusCode != 200 {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    throw NetworkUtilsError.ImageNotFound
                }
                
                guard let image = UIImage(data: data) else {
                    print("❌ Could not create image from data")
                    throw NetworkUtilsError.ImageNotFound
                }
                
                // Cache the loaded image
                ImageCache.shared.setImage(image, forKey: "product_\(photoId)")
                
                print("✅ Successfully loaded product image")
                return image
                
            } catch {
                lastError = error
                print("❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Wait before retrying (exponential backoff)
                if attempt < maxRetries {
                    let delay = Double(attempt) * 0.5 // 0.5s, 1s, 1.5s
                    print("⏱️ Waiting \(delay)s before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All attempts failed, try a fallback solution
        print("🔄 Trying fallback solution after \(maxRetries) failed attempts...")
        
        // Try alternate endpoint format (without /admin/)
        let fallbackUrlString = "https://qskipper.com/api/get_product_photo/\(photoId)"
        
        guard let fallbackUrl = URL(string: fallbackUrlString) else {
            print("❌ Failed to create fallback URL")
            throw lastError ?? NetworkUtilsError.ImageNotFound
        }
        
        do {
            print("📡 Trying fallback URL: \(fallbackUrlString)")
            let (data, response) = try await URLSession.shared.data(from: fallbackUrl)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response from fallback URL")
                throw NetworkUtilsError.NetworkError
            }
            
            if httpResponse.statusCode != 200 {
                print("❌ HTTP Error from fallback URL: \(httpResponse.statusCode)")
                throw NetworkUtilsError.ImageNotFound
            }
            
            guard let image = UIImage(data: data) else {
                print("❌ Could not create image from fallback data")
                throw NetworkUtilsError.ImageNotFound
            }
            
            // Cache the loaded image
            ImageCache.shared.setImage(image, forKey: "product_\(photoId)")
            
            print("✅ Successfully loaded product image from fallback URL")
            return image
            
        } catch {
            print("❌ Failed to load product image (including fallback): \(error)")
            
            // Return a placeholder image instead of throwing an error
            if let placeholderImage = UIImage(systemName: "photo.fill") {
                print("⚠️ Using system placeholder image")
                return placeholderImage
            }
            
            // If even the system placeholder fails, create a simple colored image
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
            let placeholderImage = renderer.image { ctx in
                UIColor.systemGray4.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            }
            
            print("⚠️ Using generated placeholder image")
            return placeholderImage
        }
    }
    
    // MARK: - Top Picks
    
    func fetchTopPicks() async throws -> [Product] {
        // Fix: Use the correct endpoint "top-picks" with hyphen instead of underscore
        let url = baseURl.appendingPathComponent("top-picks")
        
        print("📡 Fetching top picks from: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response for top picks")
                throw NetworkUtilsError.NetworkError
            }
            
            if httpResponse.statusCode != 200 {
                print("❌ HTTP Error for top picks: \(httpResponse.statusCode)")
                throw NetworkUtilsError.NetworkError
            }
            
            // Print the response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Top picks response: \(responseString)")
            }
            
            do {
                // Try to decode with the TopPicksResponse model that handles multiple formats
                let decoder = JSONDecoder()
                let topPicksResponse = try decoder.decode(TopPicksResponse.self, from: data)
                
                if !topPicksResponse.allTopPicks.isEmpty {
                    print("✅ Successfully decoded \(topPicksResponse.allTopPicks.count) top picks using TopPicksResponse")
                    return topPicksResponse.allTopPicks
                }
                
                // If TopPicksResponse failed to find items, try alternative approaches
                
                // Try decoding as an array of products directly
                if let products = try? decoder.decode([Product].self, from: data) {
                    print("✅ Successfully decoded \(products.count) top picks as direct array")
                    return products
                }
                
                // If that fails, try decoding with a wrapper object
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Try various possible keys
                    let possibleKeys = ["top-picks", "topPicks", "top_picks", "allTopPicks", "products", "dishes"]
                    
                    for key in possibleKeys {
                        if let productsArray = json[key] as? [[String: Any]] {
                            print("✅ Found top picks array using key: \(key)")
                            
                            // Convert back to data
                            let productsData = try JSONSerialization.data(withJSONObject: productsArray)
                            
                            // Decode array of products
                            let products = try decoder.decode([Product].self, from: productsData)
                            print("✅ Successfully decoded \(products.count) top picks using key: \(key)")
                            return products
                        }
                    }
                }
                
                // If all attempts fail, log and return empty array
                print("⚠️ No top picks found in response or unable to parse")
                return []
                
            } catch {
                print("❌ Failed to decode top picks: \(error)")
                throw NetworkUtilsError.JSONParsingError
            }
            
        } catch {
            print("❌ Network request for top picks failed: \(error)")
            throw NetworkUtilsError.NetworkError
        }
    }
    
    // MARK: - User Authentication
    
    func registerUser(email: String, name: String, phone: String?) async throws -> String {
        let url = baseURl.appendingPathComponent("register")
        
        var registerData: [String: Any] = [
            "email": email,
            "username": name
        ]
        
        if let phone = phone {
            registerData["phone"] = phone
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: registerData) else {
            throw NetworkUtilsError.JSONParsingError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkUtilsError.NetworkError
            }
            
            if httpResponse.statusCode != 200 {
                throw NetworkUtilsError.RegistrationFailed
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool,
                      success,
                      let otp = json["otp"] as? String else {
                    throw NetworkUtilsError.RegistrationFailed
                }
                
                return otp
            } catch {
                throw NetworkUtilsError.JSONParsingError
            }
            
        } catch {
            throw NetworkUtilsError.NetworkError
        }
    }
    
    func verifyOTP(email: String, otp: String) async throws -> User {
        let url = baseURl.appendingPathComponent("verify_otp")
        
        let verificationData: [String: Any] = [
            "email": email,
            "otp": otp
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: verificationData) else {
            throw NetworkUtilsError.JSONParsingError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkUtilsError.NetworkError
            }
            
            if httpResponse.statusCode != 200 {
                throw NetworkUtilsError.OTPVerificationFailed
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                let authResponse = try decoder.decode(AuthResponse.self, from: data)
                
                guard let user = authResponse.user else {
                    throw NetworkUtilsError.OTPVerificationFailed
                }
                
                return user
            } catch {
                throw NetworkUtilsError.JSONParsingError
            }
            
        } catch {
            throw NetworkUtilsError.NetworkError
        }
    }
    
    // MARK: - Order Management
    
    func submitOrder(orderRequest: PlaceOrderRequest) async throws -> Order {
        let url = baseURl.appendingPathComponent("order-placed")
        
        // Log UserDefaults state
        print("🔍 Checking UserDefaults state before order submission:")
        print("   - User ID: \(UserDefaults.standard.string(forKey: "userID") ?? "nil")")
        print("   - User Email: \(UserDefaults.standard.string(forKey: "user_email") ?? "nil")")
        print("   - User Name: \(UserDefaults.standard.string(forKey: "user_name") ?? "nil")")
        print("   - Is Logged In: \(UserDefaults.standard.bool(forKey: "is_logged_in"))")
        
        // Log order request details
        print("📦 Order Request Details:")
        print("   - User ID: \(orderRequest.userId)")
        print("   - Restaurant ID: \(orderRequest.restaurantId)")
        print("   - Total Amount: \(orderRequest.totalAmount)")
        print("   - Number of Items: \(orderRequest.items.count)")
        print("   - Order Type: \(orderRequest.orderType)")
        if let scheduledTime = orderRequest.scheduledTime {
            print("   - Scheduled Time: \(scheduledTime)")
        }
        
        // Ensure `restaurantId` is present
        guard !orderRequest.restaurantId.isEmpty else {
            print("❌ Error: Restaurant ID is missing from order")
            throw NSError(domain: "QueueSkipper", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "❌ Error: Restaurant ID is missing from order"
            ])
        }
        
        // Convert the order request to dictionary
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let orderData = try encoder.encode(orderRequest)
        
        // Log the JSON payload
        if let jsonString = String(data: orderData, encoding: .utf8) {
            print("📤 JSON Payload:")
            print(jsonString)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = orderData
        
        do {
            print("🌐 Sending order request to: \(url.absoluteString)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log response details
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Error: Invalid HTTP response")
                throw NetworkUtilsError.NetworkError
            }
            
            print("📥 Response Status Code: \(httpResponse.statusCode)")
            print("📥 Response Headers:")
            httpResponse.allHeaderFields.forEach { key, value in
                print("   \(key): \(value)")
            }
            
            // Convert response data to string for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Response Data:")
                print(responseString)
            }
            
            // Check for success (Status Code: 200)
            guard httpResponse.statusCode == 200 else {
                print("❌ Error: Unexpected status code: \(httpResponse.statusCode)")
                throw NSError(domain: "QueueSkipper", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Unexpected status code: \(httpResponse.statusCode)"
                ])
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                let orderResponse = try decoder.decode(OrderResponse.self, from: data)
                
                guard let order = orderResponse.order else {
                    print("❌ Error: Order data is missing from response")
                    throw NetworkUtilsError.OrderFailed
                }
                
                print("✅ Order placed successfully!")
                print("   - Order ID: \(order.id)")
                print("   - Status: \(order.status)")
                print("   - Total Amount: \(order.totalAmount)")
                
                return order
            } catch {
                print("❌ Error decoding order response: \(error)")
                throw NetworkUtilsError.JSONParsingError
            }
            
        } catch {
            print("❌ Network error: \(error)")
            throw NetworkUtilsError.NetworkError
        }
    }
}

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case requestFailed(Error)
    case decodingFailed(Error)
    case serverError(Int, Data?)
    case unknown
    
    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid URL requested"
        case .invalidResponse:
            return "Invalid response received from the server"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .serverError(let code, let data):
            if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                return "Server error with status code: \(code), message: \(errorMessage)"
            }
            return "Server error with status code: \(code)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

struct APIEndpoints {
    static let baseURL = "https://queueskipperbackend.onrender.com"
    
    // Authentication endpoints
    static let register = baseURL + "/register"
    static let verifyRegister = baseURL + "/verify-register"
    static let login = baseURL + "/login"
    static let verifyLogin = baseURL + "/verify-login"
    
    // Restaurant endpoints
    static let getAllRestaurants = baseURL + "/get_All_Restaurant"
    static func getRestaurantPhoto(pid: String) -> String {
        let sanitizedId = pid.trimmingCharacters(in: .whitespacesAndNewlines)
        print("Creating restaurant photo URL with ID: '\(sanitizedId)'")
        return baseURL + "/get_restaurant_photo/\(sanitizedId)"
    }
    
    // Product endpoints
    static func getAllProducts(pid: String) -> String {
        return baseURL + "/get_all_product/\(pid)"
    }
    static func getProductPhoto(pid: String) -> String {
        let sanitizedId = pid.trimmingCharacters(in: .whitespacesAndNewlines)
        print("Creating product photo URL with ID: '\(sanitizedId)'")
        return baseURL + "/get_product_photo/\(sanitizedId)"
    }
    
    // Order endpoints
    static let topPicks = baseURL + "/top-picks"
    static let orderPlaced = baseURL + "/order-placed"
    static let scheduleOrderPlaced = baseURL + "/schedule-order-placed"
    static func getOrderStatus(oid: String) -> String {
        return baseURL + "/order-status/\(oid)"
    }
    static func getUserOrders(uid: String) -> String {
        return baseURL + "/get-UserOrder/\(uid)"
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    private let session: URLSession
    
    // Add a debug logging control flag
    #if DEBUG
    private let debugLogging = true
    #else
    private let debugLogging = false
    #endif
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // 30 second timeout
        self.session = URLSession(configuration: config)
    }
    
    // Helper method for controlled logging
    private func log(_ message: String) {
        #if DEBUG
        if debugLogging {
            print(message)
        }
        #endif
    }
    
    func makeRequest<T: Decodable>(url: String, method: String = "GET", body: Data? = nil, headers: [String: String]? = nil, retries: Int = 3) async throws -> T {
        var lastError: Error? = nil
        
        // Attempt the request with retries
        for attempt in 1...max(1, retries) {
            do {
                return try await performRequest(url: url, method: method, body: body, headers: headers)
            } catch let error {
                lastError = error
                log("Request failed (attempt \(attempt)/\(retries)): \(error.localizedDescription)")
                
                // Only retry on network/connection errors
                if let urlError = error as? URLError, 
                   [URLError.notConnectedToInternet, 
                    URLError.networkConnectionLost,
                    URLError.timedOut].contains(urlError.code) {
                    
                    // Wait with exponential backoff before retrying
                    let delay = Double(min(1 << (attempt - 1), 8)) // 1, 2, 4, 8 seconds max
                    log("Retrying in \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else if error.localizedDescription.contains("Socket is not connected") {
                    // Handle this specific error string that might not be a standard URLError
                    let delay = Double(min(1 << (attempt - 1), 8))
                    log("Socket not connected, retrying in \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    // Non-retriable error, throw immediately
                    throw error
                }
            }
        }
        
        // If we got here, all retries failed
        throw lastError ?? NetworkError.requestFailed(NSError(domain: "Unknown", code: -1))
    }
    
    // Split out the actual request logic to support retries
    private func performRequest<T: Decodable>(url: String, method: String = "GET", body: Data? = nil, headers: [String: String]? = nil) async throws -> T {
        guard let url = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Set default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers if provided
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Set body data for POST, PUT requests
        if let body = body {
            request.httpBody = body
        }
        
        do {
            log("Network request: \(method) \(url)")
            if let body = body, let bodyString = String(data: body, encoding: .utf8) {
                log("Request body: \(bodyString)")
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            log("Response received: Status \(httpResponse.statusCode)")
            
            // Debug info - log first part of response data for debugging
            if let dataString = String(data: data.prefix(500), encoding: .utf8) {
                log("Response data preview: \(dataString)" + (data.count > 500 ? "... (truncated)" : ""))
            }
            
            // Print complete response for debugging
            log("Headers: \(httpResponse.allHeaderFields)")
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .useDefaultKeys // Let models handle custom key names
                
                // Configure date decoding
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                // Try to print the JSON before decoding
                if let jsonObject = try? JSONSerialization.jsonObject(with: data),
                   let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    log("Formatted JSON: \(jsonString)")
                }
                
                // Handle error responses with proper status codes
                if httpResponse.statusCode >= 400 {
                    throw NetworkError.serverError(httpResponse.statusCode, data)
                }
                
                // Try to decode
                return try decoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                log("Detailed decoding error: \(decodingError)")
                
                // Print more information about the decoding error
                switch decodingError {
                case .typeMismatch(let type, let context):
                    log("Type mismatch: expected \(type), at path: \(context.codingPath), debug description: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    log("Value not found: expected \(type), at path: \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    log("Key not found: \(key), at path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    log("Data corrupted: \(context.debugDescription)")
                @unknown default:
                    log("Unknown decoding error")
                }
                
                throw NetworkError.decodingFailed(decodingError)
            }
            
        } catch let error as NetworkError {
            throw error
        } catch {
            log("Network request failed: \(error)")
            throw NetworkError.requestFailed(error)
        }
    }
    
    // Image loading function
    func loadImage(from urlString: String, retries: Int = 3) async throws -> Data {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for image loading: \(urlString)")
            throw NetworkError.invalidURL
        }
        
        print("📷 Loading image from URL: \(url.absoluteString)")
        var lastError: Error? = nil
        
        // Attempt the request with retries
        for attempt in 1...max(1, retries) {
            do {
                print("📡 Image loading attempt \(attempt)/\(retries)...")
                
                // Use a custom URLRequest with custom cache policy
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                request.timeoutInterval = 30
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("🔶 Image response status: \(httpResponse.statusCode), data size: \(data.count) bytes, content-type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
                
                // Check if the response is actually JSON (server error) instead of image data
                if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   contentType.contains("application/json") {
                    // This is likely a JSON error response, not an image
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorJson["message"] as? String {
                        print("❌ Server returned error JSON instead of image: \(message)")
                        throw NetworkError.serverError(httpResponse.statusCode, data)
                    } else {
                        print("❌ Server returned JSON instead of image data")
                        throw NetworkError.serverError(httpResponse.statusCode, data)
                    }
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("❌ Server error loading image: HTTP \(httpResponse.statusCode)")
                    throw NetworkError.serverError(httpResponse.statusCode, nil)
                }
                
                // Validate that this is actually an image
                if data.isEmpty {
                    print("❌ Empty data received from image URL")
                    throw NetworkError.requestFailed(NSError(domain: "Empty data", code: -1))
                }
                
                // Try to determine if the data might be an image
                if data.count >= 16 {
                    let headerBytes = [UInt8](data.prefix(16))
                    let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
                    let jpegSignature: [UInt8] = [0xFF, 0xD8]
                    
                    let isPng = headerBytes.prefix(4).elementsEqual(pngSignature)
                    let isJpeg = headerBytes.prefix(2).elementsEqual(jpegSignature)
                    
                    if !isPng && !isJpeg {
                        print("⚠️ Warning: Data may not be an image (signature check failed)")
                        
                        // Try to see if it's a JSON error message
                        if let jsonString = String(data: data, encoding: .utf8),
                           jsonString.contains("error") || jsonString.contains("message") {
                            print("❌ Server returned JSON error instead of image: \(jsonString)")
                            throw NetworkError.requestFailed(NSError(domain: "Server returned error: \(jsonString)", code: -1))
                        }
                        
                        // If UIKit is available, try to validate with UIImage
                        #if canImport(UIKit)
                        if UIImage(data: data) == nil {
                            print("❌ Data is not a valid image (UIImage validation failed)")
                            throw NetworkError.requestFailed(NSError(domain: "Invalid image data", code: -1))
                        }
                        #endif
                    }
                }
                
                print("✅ Successfully loaded image: \(data.count) bytes")
                return data
                
            } catch let error {
                lastError = error
                print("❌ Image loading attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Only retry on network/connection errors
                if let urlError = error as? URLError, 
                   [URLError.notConnectedToInternet, 
                    URLError.networkConnectionLost,
                    URLError.timedOut,
                    URLError.cannotConnectToHost,
                    URLError.cannotFindHost,
                    URLError.dnsLookupFailed].contains(urlError.code) {
                    
                    // Wait with exponential backoff before retrying
                    let delay = Double(min(1 << (attempt - 1), 8)) // 1, 2, 4, 8 seconds max
                    print("⏳ Retrying image load in \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else if error.localizedDescription.contains("Socket is not connected") ||
                          error.localizedDescription.contains("The network connection was lost") {
                    // Handle these specific error strings that might not be standard URLErrors
                    let delay = Double(min(1 << (attempt - 1), 8))
                    print("⏳ Network issue, retrying image load in \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    // Non-retriable error, throw immediately
                    print("❌ Non-retriable error loading image: \(error)")
                    throw error
                }
            }
        }
        
        // If we got here, all retries failed
        print("❌ All \(retries) image loading attempts failed")
        throw lastError ?? NetworkError.requestFailed(NSError(domain: "Unknown", code: -1))
    }
}

// Helper for creating image URLs
extension NetworkUtils {
    static func getImageUrl(id: Int) -> URL? {
        return URL(string: "\(APIEndpoints.baseURL)/get_restaurant_photo/\(id)")
    }
    
    static func getProductImageUrl(id: Int) -> URL? {
        return URL(string: "\(APIEndpoints.baseURL)/get_product_photo/\(id)")
    }
    
    // Add more flexible methods that can handle both String and Int photoIds
    static func getImageUrl(photoId: String) -> URL? {
        if let id = Int(photoId) {
            return getImageUrl(id: id)
        }
        return URL(string: "\(APIEndpoints.baseURL)/get_restaurant_photo/\(photoId)")
    }
    
    static func getProductImageUrl(photoId: String) -> URL? {
        if let id = Int(photoId) {
            return getProductImageUrl(id: id)
        }
        return URL(string: "\(APIEndpoints.baseURL)/get_product_photo/\(photoId)")
    }
    
    // Parse API responses to get detailed error messages
    static func parseErrorResponse(data: Data) -> String? {
        // Try to parse as a JSON error message
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let errorMessage = json["message"] as? String {
                return errorMessage
            } else if let error = json["error"] as? String {
                return error
            }
        }
        
        // Try to parse as plain text
        return String(data: data, encoding: .utf8)
    }
    
    // Direct image fetching method similar to the UIKit approach
    static func fetchImage(from url: URL) async throws -> UIImage {
        print("🖼️ Directly fetching image from URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Verify we received HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw NetworkError.invalidResponse
        }
        
        // Check for JSON error response
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("application/json") {
            // Try to extract error message from JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                print("❌ Server returned JSON error instead of image: \(message)")
                throw NetworkError.serverError(httpResponse.statusCode, data)
            } else {
                print("❌ Server returned JSON instead of image data")
                throw NetworkError.serverError(httpResponse.statusCode, data)
            }
        }
        
        // Check for success status code
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Server returned error status: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode, data)
        }
        
        // Attempt to create image from data
        guard let image = UIImage(data: data) else {
            print("❌ Failed to create image from data")
            throw NetworkError.requestFailed(NSError(domain: "Invalid image data", code: -1))
        }
        
        print("✅ Successfully loaded image: \(data.count) bytes")
        return image
    }
} 
