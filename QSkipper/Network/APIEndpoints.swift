import Foundation

/// Centralized definitions of all API endpoints
struct APIEndpoints {
    // Base paths
    static let baseRenderURL = "https://qskipperbackend.onrender.com"
    static let baseRailwayURL = "https://qskipperserver-production.up.railway.app"
    
    // Authentication
    static let register = "/register"
    static let verifyOTP = "/verify_otp"
    static let verifyRegister = "/verify-register"
    static let login = "/login"
    static let verifyLogin = "/verify-login"
    
    // Restaurants
    static let getAllRestaurants = "/get_All_Restaurant"
    
    static func getRestaurant(_ id: String) -> String {
        return "/get_Restaurant/\(id)"
    }
    
    static func getRestaurantPhoto(_ id: String) -> String {
        // Sanitize ID to prevent path traversal
        let sanitizedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return "/get_restaurant_photo/\(sanitizedId)"
    }
    
    // Products/Menu
    static func getAllProducts(restaurantId: String) -> String {
        // Sanitize ID to prevent path traversal
        let sanitizedId = restaurantId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? restaurantId
        return "/get_all_product/\(sanitizedId)"
    }
    
    static func getProductPhoto(_ id: String) -> String {
        // Sanitize ID to prevent path traversal
        let sanitizedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return "/get_product_photo/\(sanitizedId)"
    }
    
    // Orders
    static let topPicks = "/top-picks"
    static let orderPlaced = "/order-placed"
    static let scheduleOrderPlaced = "/schedule-order-placed"
    static let verifyOrder = "/verify-order"
    
    static func getOrderStatus(_ orderId: String) -> String {
        let sanitizedId = orderId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? orderId
        return "/order-status/\(sanitizedId)"
    }
    
    static func getUserOrders(_ userId: String) -> String {
        let sanitizedId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        return "/get-UserOrder/\(sanitizedId)"
    }
    
    // Diagnostics
    static let ping = "/ping"
} 