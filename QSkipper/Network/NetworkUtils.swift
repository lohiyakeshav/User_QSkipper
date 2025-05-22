//
//  NetworkUtils.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import Foundation
import UIKit
import SwiftUI // For accessing our app's Utils folder
// ServerConfig is imported automatically since it's in the same module

// NetworkUtils for handling common network operations
class NetworkUtils {
    // Base URL for API endpoints - now using ServerConfig
    let baseURl: URL
    
    static let shared = NetworkUtils()
    
    init() {
        // Initialize with the primary URL from ServerConfig
        self.baseURl = URL(string: ServerConfig.primaryBaseURLWithSlash)!
    }
    
    enum NetworkUtilsError: Error, LocalizedError {
        case RestaurantNotFound
        case ImageNotFound
        case DishNotFound
        case RegistrationFailed
        case OrderFailed
        case ScheduledOrderFailed(String)
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
            case .ScheduledOrderFailed(let message):
                return "Failed to place scheduled order: \(message)"
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
        // Delegate to APIClient
        print("📡 NetworkUtils: Delegating fetchRestaurant to APIClient for ID: \(restaurantId)")
        
        do {
            return try await APIClient.shared.fetchRestaurant(with: restaurantId)
        } catch let error as APIClient.APIError {
            print("❌ APIClient error: \(error.localizedDescription)")
            
            // Convert APIClient errors to NetworkUtils errors for backward compatibility
            switch error {
            case .serverError(let code, _) where code == 404:
                throw NetworkUtilsError.RestaurantNotFound
            case .decodingFailed:
                throw NetworkUtilsError.JSONParsingError
            default:
                throw NetworkUtilsError.NetworkError
            }
        } catch {
            print("❌ Unexpected error: \(error.localizedDescription)")
            throw NetworkUtilsError.NetworkError
        }
    }
    
    func fetchRestaurants() async throws -> [Restaurant] {
        // Delegate to APIClient
        print("📡 NetworkUtils: Delegating fetchRestaurants to APIClient")
        
        do {
            return try await APIClient.shared.fetchRestaurants()
        } catch let error as APIClient.APIError {
            print("❌ APIClient error: \(error.localizedDescription)")
            
            // Convert APIClient errors to NetworkUtils errors for backward compatibility
            switch error {
            case .decodingFailed:
                throw NetworkUtilsError.JSONParsingError
            default:
                throw NetworkUtilsError.NetworkError
            }
        } catch {
            print("❌ Unexpected error: \(error.localizedDescription)")
            throw NetworkUtilsError.NetworkError
        }
    }
    
    func fetchRestaurantImage(photoId: String) async throws -> UIImage {
        // Check image cache first
        if let cachedImage = ImageCache.shared.getImage(forKey: "restaurant_\(photoId)") {
            print("✅ Using cached restaurant image for ID: \(photoId)")
            return cachedImage
        }
        
        // Delegate to APIClient for image loading with user-initiated priority
        print("📡 NetworkUtils: Delegating fetchRestaurantImage to APIClient for ID: \(photoId)")
        
        do {
            let urlString = "\(baseURl.absoluteString)get_restaurant_photo/\(photoId)"
            
            // Use a higher priority task but await its result directly
            let image = try await APIClient.shared.loadImage(from: urlString)
            
            // Cache the image to maintain compatibility with old code 
            ImageCache.shared.setImage(image, forKey: "restaurant_\(photoId)")
            
            return image
        } catch let error as APIClient.APIError {
            print("❌ APIClient error: \(error.localizedDescription)")
            
            // Create a fallback image with restaurant ID that's consistent
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 150))
            let fallbackImage = renderer.image { ctx in
                // Background gradient based on photoId for consistency
                let hash = abs(photoId.hash)
                
                // Create gradient colors based on hash
                let startRed = CGFloat((hash & 0xFF0000) >> 16) / 255.0
                let startGreen = CGFloat((hash & 0x00FF00) >> 8) / 255.0
                let startBlue = CGFloat(hash & 0x0000FF) / 255.0
                let startColor = UIColor(red: max(0.3, startRed), 
                                       green: max(0.3, startGreen), 
                                       blue: max(0.3, startBlue), 
                                       alpha: 1.0)
                
                let endRed = min(1.0, startRed + 0.3)
                let endGreen = min(1.0, startGreen + 0.3)
                let endBlue = min(1.0, startBlue + 0.3)
                let endColor = UIColor(red: endRed, green: endGreen, blue: endBlue, alpha: 1.0)
                
                // Draw gradient
                let colors = [startColor.cgColor, endColor.cgColor]
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let colorLocations: [CGFloat] = [0.0, 1.0]
                
                if let gradient = CGGradient(colorsSpace: colorSpace, 
                                           colors: colors as CFArray, 
                                           locations: colorLocations) {
                    ctx.cgContext.drawLinearGradient(gradient, 
                                                 start: CGPoint(x: 0, y: 0),
                                                 end: CGPoint(x: 200, y: 150),
                                                 options: [])
                }
                
                // Restaurant icon
                let icon = UIImage(systemName: "fork.knife")
                if let icon = icon {
                    let iconRect = CGRect(x: 85, y: 40, width: 30, height: 30)
                    icon.draw(in: iconRect, blendMode: .normal, alpha: 0.8)
                }
                
                // Draw restaurant ID text
                let idText = "ID: " + String(photoId.suffix(6))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.white
                ]
                
                let textSize = (idText as NSString).size(withAttributes: attrs)
                let textRect = CGRect(
                    x: (200 - textSize.width) / 2,
                    y: 90,
                    width: textSize.width,
                    height: textSize.height
                )
                
                (idText as NSString).draw(in: textRect, withAttributes: attrs)
            }
            
            // Cache the fallback
            ImageCache.shared.setImage(fallbackImage, forKey: "restaurant_\(photoId)")
            
            return fallbackImage
        } catch {
            // For unknown errors, create a simpler fallback
            print("❌ Unexpected error: \(error.localizedDescription)")
            throw NetworkUtilsError.ImageNotFound
        }
    }
    
    // MARK: - Product/Menu Endpoints
    
    func fetchMenu(for restaurantId: String) async throws -> [Product] {
        print("📡 NetworkUtils: Delegating fetchMenu to APIClient for restaurant: \(restaurantId)")
        
        do {
            let sanitizedId = restaurantId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? restaurantId
            let data = try await APIClient.shared.request(
                path: "/get_all_product/\(sanitizedId)"
            )
            
            // Try to decode the response using the same logic from the original method
            do {
                let decoder = JSONDecoder()
                
                // First try to decode as ProductsResponse which has the {"products": [...]} structure
                let productsResponse = try decoder.decode(ProductsResponse.self, from: data)
                return productsResponse.products
            } catch {
                // If that fails, try alternate approach
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let productsArray = json["products"] as? [[String: Any]] {
                    let productsData = try JSONSerialization.data(withJSONObject: productsArray)
                    return try JSONDecoder().decode([Product].self, from: productsData)
                }
                
                // If all approaches fail, return empty array for compatibility
                return []
            }
        } catch {
            print("❌ APIClient error: \(error.localizedDescription)")
            throw NetworkUtilsError.DishNotFound
        }
    }
    
    // Add a method to fetch products (alias for fetchMenu for backward compatibility)
    func fetchProducts(for restaurantId: String) async throws -> [Product] {
        return try await fetchMenu(for: restaurantId)
    }
    
    func fetchProductImage(photoId: String) async throws -> UIImage {
        // Check image cache first
        if let cachedImage = ImageCache.shared.getImage(forKey: "product_\(photoId)") {
            print("✅ Using cached product image for ID: \(photoId)")
            return cachedImage
        }
        
        print("📡 NetworkUtils: Delegating fetchProductImage to APIClient for ID: \(photoId)")
        
        do {
            let urlString = "\(baseURl.absoluteString)get_product_photo/\(photoId)"
            let image = try await APIClient.shared.loadImage(from: urlString)
            
            // Cache the image to maintain compatibility with old code
            ImageCache.shared.setImage(image, forKey: "product_\(photoId)")
            
            return image
        } catch {
            print("❌ Fetch product image error: \(error.localizedDescription)")
            
            // Try an alternative source - create a placeholder image with product ID 
            // that's consistent for the same product
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
            let placeholderImage = renderer.image { ctx in
                // Background color - derive from photoId hash for consistency
                let hash = abs(photoId.hash)
                let red = CGFloat((hash & 0xFF0000) >> 16) / 255.0
                let green = CGFloat((hash & 0x00FF00) >> 8) / 255.0
                let blue = CGFloat(hash & 0x0000FF) / 255.0
                
                let color = UIColor(red: max(0.3, red), green: max(0.3, green), blue: max(0.3, blue), alpha: 1.0)
                color.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
                
                // Draw product ID text
                let idText = String(photoId.suffix(6))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                
                let textSize = (idText as NSString).size(withAttributes: attrs)
                let textRect = CGRect(
                    x: (100 - textSize.width) / 2,
                    y: (100 - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                (idText as NSString).draw(in: textRect, withAttributes: attrs)
            }
            
            // Cache the placeholder
            ImageCache.shared.setImage(placeholderImage, forKey: "product_\(photoId)")
            
            return placeholderImage
        }
    }
    
    // MARK: - Top Picks Endpoint
    
    func fetchTopPicks() async throws -> [Product] {
        print("📡 NetworkUtils: Delegating fetchTopPicks to APIClient")
        
        do {
            return try await APIClient.shared.fetchTopPicks()
        } catch let error as APIClient.APIError {
            print("❌ APIClient error: \(error.localizedDescription)")
            
            // Convert APIClient errors to NetworkUtils errors for backward compatibility
            switch error {
            case .decodingFailed:
                throw NetworkUtilsError.JSONParsingError
            default:
                throw NetworkUtilsError.NetworkError
            }
        } catch {
            print("❌ Unexpected error: \(error.localizedDescription)")
            throw NetworkUtilsError.NetworkError
        }
    }
    
    // MARK: - Auth Endpoints
    
    func registerUser(registrationData: [String: Any]) async throws -> Bool {
        print("📡 NetworkUtils: Delegating registerUser to APIClient")
        
        do {
            // Convert registrationData to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: registrationData)
            
            // Send register request
            let data = try await APIClient.shared.request(
                path: "/register",
                method: "POST",
                body: jsonData,
                headers: ["Content-Type": "application/json"]
            )
            
            // Parse response (use same logic as original method)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success {
                return true
            }
            
            throw NetworkUtilsError.RegistrationFailed
        } catch {
            print("❌ API error during registration: \(error.localizedDescription)")
            throw NetworkUtilsError.RegistrationFailed
        }
    }
    
    func verifyOTP(otpData: [String: Any]) async throws -> Bool {
        print("📡 NetworkUtils: Delegating verifyOTP to APIClient")
        
        do {
            // Convert otpData to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: otpData)
            
            // Send OTP verification request
            let data = try await APIClient.shared.request(
                path: "/verify_otp",
                method: "POST",
                body: jsonData,
                headers: ["Content-Type": "application/json"]
            )
            
            // Parse response (use same logic as original method)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success {
                return true
            }
            
            throw NetworkUtilsError.OTPVerificationFailed
        } catch {
            print("❌ API error during OTP verification: \(error.localizedDescription)")
            throw NetworkUtilsError.OTPVerificationFailed
        }
    }
    
    // MARK: - Order Endpoints
    
    func placeOrder(orderData: [String: Any]) async throws -> String {
        print("📡 NetworkUtils: Delegating placeOrder to APIClient")
        
        // Determine if this is a scheduled order
        let isScheduledOrder = orderData["scheduleDate"] != nil
        print("📅 Order type: \(isScheduledOrder ? "Scheduled" : "Immediate")")
        
        if isScheduledOrder {
            print("📅 Scheduled date: \(String(describing: orderData["scheduleDate"]))")
            // For scheduled orders, always set takeAway to true as required by server
            var mutableOrderData = orderData
            mutableOrderData["takeAway"] = true
            print("📝 NetworkUtils: Setting takeAway to true for scheduled order")
            
            do {
                return try await APIClient.shared.placeOrder(orderData: mutableOrderData)
            } catch let error as APIClient.APIError {
                if case .serverError(let code, let data) = error {
                    // Try to extract error message from response
                    var errorMessage = "Server returned error \(code)"
                    if let data = data, 
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String {
                        errorMessage = message
                    }
                    print("❌ Scheduled order error: \(errorMessage)")
                    throw NetworkUtilsError.ScheduledOrderFailed(errorMessage)
                }
                throw NetworkUtilsError.ScheduledOrderFailed(error.localizedDescription)
            }
        }
        
        do {
            return try await APIClient.shared.placeOrder(orderData: orderData)
        } catch let error as APIClient.APIError {
            if case .serverError(let code, let data) = error {
                // Try to extract error message from response
                var errorMessage = "Server returned error \(code)"
                if let data = data, 
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    errorMessage = message
                }
                print("❌ Order error: \(errorMessage)")
                
                if isScheduledOrder {
                    throw NetworkUtilsError.ScheduledOrderFailed(errorMessage)
                } else {
                    throw NetworkUtilsError.OrderFailed
                }
            }
            
            if isScheduledOrder {
                throw NetworkUtilsError.ScheduledOrderFailed(error.localizedDescription)
            } else {
                throw NetworkUtilsError.OrderFailed
            }
        } catch {
            print("❌ API error during order placement: \(error.localizedDescription)")
            
            if isScheduledOrder {
                throw NetworkUtilsError.ScheduledOrderFailed(error.localizedDescription)
            } else {
                throw NetworkUtilsError.OrderFailed
            }
        }
    }
    
    // MARK: - Order Verification
    
    func verifyOrder(orderId: String) async throws -> Bool {
        print("📡 NetworkUtils: Delegating verifyOrder to APIClient")
        
        do {
            // Use the improved verifyOrder method in APIClient
            _ = try await APIClient.shared.verifyOrder(orderId: orderId)
            print("✅ NetworkUtils: Order verification successful")
            return true
        } catch {
            print("❌ NetworkUtils: Order verification failed: \(error.localizedDescription)")
            throw NetworkUtilsError.OrderFailed
        }
    }
}

// MARK: - Order Verification

// for verifying payment
//enum NetworkUtilsError: Error {
//    case networkError
//    case orderFailed
//}
//
//class PaymentAPI {
//    static let shared = PaymentAPI()
//    private init() {}
//
//    private let baseURL = URL(string: "https://qskipper-server-2ul5.onrender.com")!
//
//    func verifyOrder(orderId: String) async throws {
//        let url = baseURL.appendingPathComponent("verify-order")
//
//        struct VerifyOrderRequest: Codable {
//            let order_id: String
//        }
//
//        let payload = VerifyOrderRequest(order_id: orderId)
//        let requestData = try JSONEncoder().encode(payload)
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = requestData
//
//        let maxRetries = 3
//        var lastError: Error?
//
//        for attempt in 1...maxRetries {
//            do {
//                let (data, response) = try await URLSession.shared.data(for: request)
//
//                guard let httpResponse = response as? HTTPURLResponse else {
//                    throw NetworkUtilsError.networkError
//                }
//
//                if httpResponse.statusCode == 200 {
//                    print("✅ Payment verified successfully!")
//                    return
//                } else {
//                    print("❌ Server responded with status code: \(httpResponse.statusCode)")
//                    throw NetworkUtilsError.orderFailed
//                }
//            } catch {
//                lastError = error
//                print("❌ Attempt \(attempt) failed: \(error.localizedDescription)")
//                if attempt < maxRetries {
//                    let delay = Double(attempt) * 0.5
//                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
//                }
//            }
//        }
//
//        throw lastError ?? NetworkUtilsError.networkError
//    }
//}


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

struct NetworkUtilsEndpoints {
    // Use the centralized ServerConfig
    static let baseURL = ServerConfig.primaryBaseURL
    static let verifyOrder = "\(baseURL)/verify-order"
    
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
    
    // Railway server URL for backup and high-throughput endpoints
    static let railwayBaseURL = ServerConfig.railwayBaseURL
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
        return URL(string: "\(NetworkUtilsEndpoints.baseURL)/get_restaurant_photo/\(id)")
    }
    
    static func getProductImageUrl(id: Int) -> URL? {
        return URL(string: "\(NetworkUtilsEndpoints.baseURL)/get_product_photo/\(id)")
    }
    
    // Add more flexible methods that can handle both String and Int photoIds
    static func getImageUrl(photoId: String) -> URL? {
        if let id = Int(photoId) {
            return getImageUrl(id: id)
        }
        return URL(string: "\(NetworkUtilsEndpoints.baseURL)/get_restaurant_photo/\(photoId)")
    }
    
    static func getProductImageUrl(photoId: String) -> URL? {
        if let id = Int(photoId) {
            return getProductImageUrl(id: id)
        }
        return URL(string: "\(NetworkUtilsEndpoints.baseURL)/get_product_photo/\(photoId)")
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
