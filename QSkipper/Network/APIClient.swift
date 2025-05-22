import Foundation
import UIKit

// ServerConfig is imported automatically since it's in the same module

// Model for decoding Top Picks response
struct TopPicksResponse: Codable {
    let products: [Product]
    
    // Support different response formats
    enum CodingKeys: String, CodingKey {
        case products
        case topPicks = "top-picks"
        case topPicksUnderscore = "top_picks"
        case allTopPicks = "allTopPicks"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try different possible keys for the products array
        if let products = try? container.decode([Product].self, forKey: .products) {
            self.products = products
        } else if let products = try? container.decode([Product].self, forKey: .topPicks) {
            self.products = products
        } else if let products = try? container.decode([Product].self, forKey: .topPicksUnderscore) {
            self.products = products
        } else if let products = try? container.decode([Product].self, forKey: .allTopPicks) {
            self.products = products
        } else {
            // If no products found under known keys, default to empty array
            self.products = []
        }
    }
    
    // Add encode method to complete Codable conformance
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(products, forKey: .products)
    }
}

/// Central API Client that handles all network requests with fallback and rate limiting
class APIClient {
    static let shared = APIClient()
    
    // Primary and secondary base URLs from ServerConfig
    private let renderBaseURL: URL
    private let railwayBaseURL: URL
    
    // Rate limiting
    private var lastRequestTime: [String: Date] = [:]
    // Maximum number of queued requests per endpoint
    private let maxQueuedRequestsPerEndpoint = 3
    // Dictionary to track queued requests by endpoint
    private var queuedRequestsByEndpoint: [String: Int] = [:]
    // Track initial loads to bypass rate limiting
    private var initialLoadCompleted: [String: Bool] = [:]
    
    // Increased rate limit for better performance
    private var minRequestInterval: TimeInterval {
        // Use a longer interval for top-picks to avoid excessive calls
        get {
            return 60 // 60 seconds between identical requests by default
        }
    }
    
    // Get rate limit interval based on the specific endpoint
    private func getRateLimitInterval(for path: String) -> TimeInterval {
        if path.contains("top-picks") {
            return 120 // 2 minutes for top-picks endpoint
        } else if path.contains("get_All_Restaurant") {
            return 90 // 1.5 minutes for restaurants endpoint
        } else if path.contains("get_Restaurant/") {
            return 60 // 60 seconds for individual restaurant endpoints
        } else if path.contains("get-UserOrder") {
            return 5 // Reduced to 5 seconds for user orders to avoid excessive rate limiting
        } else {
            return minRequestInterval // Default interval for other endpoints
        }
    }
    
    // Check if rate limiting should be applied, or if this is the first data load
    private func shouldApplyRateLimit(for path: String) -> Bool {
        // If this is the first request for this path, allow it without rate limiting
        if initialLoadCompleted[path] == nil {
            // Mark as completed for future requests
            initialLoadCompleted[path] = true
            print("🔑 First-time load for \(path) - bypassing rate limiter")
            return false
        }
        return true
    }
    
    // Special function for user orders - always uses railway server directly and bypasses rate limiting
    func fetchUserOrders(userId: String) async throws -> Data {
        print("🔵 APIClient: Using dedicated user orders function with Railway server")
        
        let path = "/get-UserOrder/\(userId)"
        
        // Always use Railway server for user orders to avoid render.com rate limits
        do {
            print("📡 APIClient: Fetching user orders from Railway (primary choice for user data)")
            let responseData = try await self.performRequest(
                baseURL: self.railwayBaseURL,
                path: path,
                method: "GET",
                body: nil,
                headers: nil
            )
            
            // Cache the response
            self.requestTimeQueue.sync {
                self.responseCache[path] = (responseData, Date())
            }
            
            return responseData
        } catch {
            print("⚠️ Railway server failed for user orders, falling back to render.com: \(error.localizedDescription)")
            
            // Only if Railway fails, try render.com as backup
            return try await self.performRequest(
                baseURL: self.renderBaseURL,
                path: path,
                method: "GET",
                body: nil,
                headers: nil
            )
        }
    }
    
    // Cache responses for certain endpoints to reduce API calls
    private var responseCache: [String: (data: Data, timestamp: Date)] = [:]
    // Different cache expiration for different endpoints
    private func getCacheMaxAge(for path: String) -> TimeInterval {
        if path.contains("top-picks") {
            return 600 // 10 minutes for top-picks endpoint
        } else if path.contains("get_All_Restaurant") {
            return 300 // 5 minutes for restaurants endpoint
        } else if path.contains("get_Restaurant/") {
            return 180 // 3 minutes for individual restaurant details
        } else if path.contains("get_all_product/") {
            return 180 // 3 minutes for restaurant menu items
        } else {
            return 120 // 2 minutes for other endpoints
        }
    }
    
    // Add a serial dispatch queue for thread-safe access to lastRequestTime
    private let requestTimeQueue = DispatchQueue(label: "com.qskipper.apiclient.requestTimeQueue")
    
    // Cache for images
    private let imageCache = ImageCache.shared
    
    // Sequential request management
    private let requestQueue = DispatchQueue(label: "com.qskipper.apiclient.requestQueue")
    private var isProcessingRequest = false
    private var pendingRequests: [(perform: () async throws -> Data, completion: (Result<Data, Error>) -> Void)] = []
    
    private init() {
        // Initialize URLs from ServerConfig
        self.renderBaseURL = URL(string: ServerConfig.renderBaseURL)!
        self.railwayBaseURL = URL(string: ServerConfig.railwayBaseURL)!
        
        print("🚀 APIClient initialized with primary: \(renderBaseURL.absoluteString)")
        print("🚀 Fallback URL: \(railwayBaseURL.absoluteString)")
    }
    
    enum APIError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case decodingFailed(Error)
        case networkError(Error)
        case serverError(Int, Data?)
        case rateLimited(TimeInterval)
        case noData
        case requestQueueFull
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: 
                return "Invalid URL"
            case .invalidResponse: 
                return "Invalid server response"
            case .decodingFailed(let error): 
                return "Failed to decode: \(error.localizedDescription)"
            case .networkError(let error): 
                return "Network error: \(error.localizedDescription)"
            case .serverError(let code, _): 
                return "Server error: \(code)"
            case .rateLimited(let nextAllowedTime): 
                return "Rate limited. Try again in \(Int(nextAllowedTime)) seconds"
            case .noData:
                return "No data received"
            case .requestQueueFull:
                return "Request queue is full"
            }
        }
    }
    
    /// Makes a request to the primary endpoint, with fallback to secondary on 503 errors.
    /// Also implements rate limiting based on endpoint path.
    ///
    /// - Parameters:
    ///   - path: The API endpoint path (e.g., "/top-picks")
    ///   - method: HTTP method (default: "GET")
    ///   - body: Optional request body for POST/PUT requests
    ///   - forceRequest: If true, bypasses rate limiting
    /// - Returns: Data from the successful response
    func request(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String]? = nil,
        forceRequest: Bool = false
    ) async throws -> Data {
        // For GET requests, check if we have a cached response that's still valid
        if method == "GET" && !forceRequest {
            if let cachedResponse = requestTimeQueue.sync(execute: { responseCache[path] }),
               Date().timeIntervalSince(cachedResponse.timestamp) < getCacheMaxAge(for: path) {
                print("✅ Using cached response for \(path), age: \(Int(Date().timeIntervalSince(cachedResponse.timestamp)))s")
                return cachedResponse.data
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Create a task with proper priority for the request
            Task(priority: .userInitiated) {
                // Add request to queue
                let requestTask: () async throws -> Data = {
                    // Check rate limiting (unless forced or first load)
                    if !forceRequest && self.shouldApplyRateLimit(for: path) {
                        // Use the serial queue to safely read from lastRequestTime
                        let shouldRateLimit = self.requestTimeQueue.sync { () -> Bool in
                            if let lastTime = self.lastRequestTime[path] {
                                let timeSinceLastRequest = Date().timeIntervalSince(lastTime)
                                let limitInterval = self.getRateLimitInterval(for: path)
                                if timeSinceLastRequest < limitInterval {
                                    let waitTime = limitInterval - timeSinceLastRequest
                                    print("⏱️ Rate limited for endpoint \(path). Last request: \(Int(timeSinceLastRequest))s ago, interval: \(Int(limitInterval))s")
                                    return true
                                }
                            }
                            return false
                        }
                        
                        if shouldRateLimit {
                            let waitTime = self.requestTimeQueue.sync { () -> TimeInterval in
                                let lastTime = self.lastRequestTime[path, default: Date().addingTimeInterval(-self.getRateLimitInterval(for: path))]
                                return self.getRateLimitInterval(for: path) - Date().timeIntervalSince(lastTime)
                            }
                            throw APIError.rateLimited(max(0, waitTime))
                        }
                    }
                    
                    // Update the last request time using the serial queue
                    self.requestTimeQueue.sync {
                        self.lastRequestTime[path] = Date()
                    }
                    
                    // First try primary server (Render)
                    do {
                        let responseData = try await self.performRequest(
                            baseURL: self.renderBaseURL,
                            path: path,
                            method: method,
                            body: body,
                            headers: headers
                        )
                        
                        // Cache the successful response for GET requests
                        if method == "GET" {
                            self.requestTimeQueue.sync {
                                self.responseCache[path] = (responseData, Date())
                            }
                        }
                        
                        return responseData
                    } catch let error {
                        // Check if we should try the fallback server
                        if case APIError.serverError(let statusCode, _) = error, statusCode == 503 {
                            print("🔀 Primary server returned 503, trying fallback server...")
                            
                            // Try secondary server (Railway)
                            let responseData = try await self.performRequest(
                                baseURL: self.railwayBaseURL,
                                path: path,
                                method: method,
                                body: body,
                                headers: headers
                            )
                            
                            // Cache the successful response for GET requests
                            if method == "GET" {
                                self.requestTimeQueue.sync {
                                    self.responseCache[path] = (responseData, Date())
                                }
                            }
                            
                            return responseData
                        } else {
                            // For non-503 errors, just rethrow
                            throw error
                        }
                    }
                }
                
                // Enqueue the request with higher priority
                do {
                    let result = try await self.enqueueAndWait(for: requestTask)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // New method to handle enqueuing directly from a Task
    private func enqueueAndWait(for request: @escaping () async throws -> Data) async throws -> Data {
        let requestPath = extractPathFromRequest(request)
        
        // Use a synchronized access to the dictionary to prevent race conditions
        let currentCount = requestTimeQueue.sync {
            return queuedRequestsByEndpoint[requestPath] ?? 0
        }
        
        // Check if we have too many queued requests for this endpoint
        if currentCount >= maxQueuedRequestsPerEndpoint {
            print("⚠️ Too many queued requests for endpoint: \(requestPath). Current queue: \(currentCount)")
            throw APIError.requestQueueFull
        }
        
        // Increment the counter for this endpoint in a thread-safe way
        requestTimeQueue.sync {
            queuedRequestsByEndpoint[requestPath] = (queuedRequestsByEndpoint[requestPath] ?? 0) + 1
        }
        
        defer {
            // Decrement the counter when done in a thread-safe way
            requestTimeQueue.sync {
                if let count = queuedRequestsByEndpoint[requestPath], count > 0 {
                    queuedRequestsByEndpoint[requestPath] = count - 1
                }
            }
        }
        
        return try await request()
    }
    
    // Extract path from request for tracking
    private func extractPathFromRequest(_ request: @escaping () async throws -> Data) -> String {
        // Generate a UUID string as a safe identifier for the request
        return UUID().uuidString
    }
    
    /// Load and cache an image from the given URL
    func loadImage(from urlString: String) async throws -> UIImage {
        // Check if image is in cache
        if let cachedImage = imageCache.getImage(forKey: urlString) {
            print("🖼️ Using cached image for \(urlString)")
            return cachedImage
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        // Use a placeholder image if in offline or error mode
        let placeholderImage = UIImage(systemName: "photo.fill") ?? UIImage()
        
        // Check if this is a retry attempt for a failed image
        let isRetryAttempt = urlString.contains("retry=true")
        
        // Define a maximum number of retries and alternate servers
        let maxRetries = 3
        let alternateServers = [
            renderBaseURL.absoluteString,
            railwayBaseURL.absoluteString,
            "https://qskipper-storage.s3.amazonaws.com",  // Check if S3 has the image
            "https://qskipper-cdn.netlify.app"            // Check if a CDN has the image
        ]
        
        // List of errors that should trigger the fallback mechanism
        let retryableErrors: [Int] = [500, 502, 503, 504, 429]
        
        // First try loading from the original URL
        do {
            // Loop through each server to try
            for (index, serverBase) in alternateServers.enumerated() {
                // Skip if this is a retry and we're on the first server (already tried)
                if isRetryAttempt && index == 0 {
                    continue
                }
                
                // Extract the path from the original URL
                let path = url.path
                
                // Create a new URL with the alternate server
                let alternateUrlString: String
                if path.hasPrefix("/get_product_photo/") || path.hasPrefix("/get_restaurant_photo/") {
                    // Try reconstructing the path with the ID as the key part
                    let components = path.components(separatedBy: "/")
                    if let idComponent = components.last, !idComponent.isEmpty {
                        alternateUrlString = "\(serverBase)\(path)"
                    } else {
                        continue // Skip this server if we can't extract the ID
                    }
                } else {
                    // Just use the original path with the new server
                    alternateUrlString = "\(serverBase)\(path)"
                }
                
                guard let alternateUrl = URL(string: alternateUrlString) else {
                    continue // Skip if URL is invalid
                }
                
                // Attempt to load from this server
                do {
                    print("🔄 Trying image from server \(index+1)/\(alternateServers.count): \(alternateUrlString)")
                    
                    let (data, response) = try await URLSession.shared.data(from: alternateUrl)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continue // Try next server if not an HTTP response
                    }
                    
                    // If we got a success response (200-299)
                    if (200...299).contains(httpResponse.statusCode) {
                        guard let image = UIImage(data: data) else {
                            continue // Try next server if data isn't an image
                        }
                        
                                                    // Cache the image with original key
                            imageCache.setImage(image, forKey: urlString)
                            
                            return image
                    } 
                    // If we got an error that's retryable, continue to the next server
                    else if retryableErrors.contains(httpResponse.statusCode) {
                        print("⚠️ Server \(index+1) returned status \(httpResponse.statusCode), trying next server")
                        continue
                    } 
                    // For other errors, throw
                    else {
                        throw APIError.serverError(httpResponse.statusCode, data)
                    }
                } catch {
                    // Try the next server on error
                    print("⚠️ Error loading from server \(index+1): \(error.localizedDescription)")
                    continue
                }
            }
            
            // If we reach here, we've tried all servers without success
            // Create a placeholder image with the ID text
            let finalRenderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
            let finalImage = finalRenderer.image { ctx in
                // Draw a gradient background
                let colors = [UIColor.systemBlue.cgColor, UIColor.systemIndigo.cgColor]
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 1.0])!
                ctx.cgContext.drawLinearGradient(gradient, 
                                              start: CGPoint(x: 0, y: 0),
                                              end: CGPoint(x: 100, y: 100),
                                              options: [])
                
                // Extract the ID from the URL
                let id = url.lastPathComponent
                
                // Draw text
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraphStyle
                ]
                
                // Draw "Image not found" text
                let notFoundString = NSAttributedString(string: "Image not\navailable", attributes: attrs)
                notFoundString.draw(in: CGRect(x: 10, y: 40, width: 80, height: 50))
            }
            
                            // Cache this fallback image
                imageCache.setImage(finalImage, forKey: urlString)
                
                return finalImage
        } catch {
            print("❌ All image loading attempts failed for \(urlString): \(error.localizedDescription)")
            
            // Create and return a fallback image 
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
            let fallbackImage = renderer.image { ctx in
                UIColor.systemGray5.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
                
                // Draw a message about the error
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.darkGray,
                    .paragraphStyle: paragraphStyle
                ]
                
                let message = NSAttributedString(string: "Image\nunavailable", attributes: attrs)
                message.draw(in: CGRect(x: 10, y: 40, width: 80, height: 40))
            }
            
                            // Cache this fallback image
                imageCache.setImage(fallbackImage, forKey: urlString)
                
                return fallbackImage
        }
    }
    
    // MARK: - Convenience methods for common API endpoints
    
    /// Fetch all restaurants
    func fetchRestaurants() async throws -> [Restaurant] {
        let data = try await request(path: "/get_All_Restaurant")
        
        do {
            // First try decoding with RestaurantsResponse wrapper
            let response = try JSONDecoder().decode(RestaurantsResponse.self, from: data)
            return response.restaurants
        } catch {
            // If that fails, try manual approach with Restaurant key
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let restaurantArray = json["Restaurant"] as? [[String: Any]] {
                let restaurantData = try JSONSerialization.data(withJSONObject: restaurantArray)
                return try JSONDecoder().decode([Restaurant].self, from: restaurantData)
            }
            
            // Try direct array as last resort
            do {
                return try JSONDecoder().decode([Restaurant].self, from: data)
            } catch {
                throw APIError.decodingFailed(error)
            }
        }
    }
    
    /// Fetch restaurant details
    func fetchRestaurant(with id: String) async throws -> Restaurant {
        let data = try await request(path: "/get_Restaurant/\(id)")
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let restaurantData = json["restaurant"] as? [String: Any] {
                
                // Safely unwrap or use defaults
                let restaurantId = (restaurantData["_id"] as? String) ?? id
                let name = (restaurantData["name"] as? String) ?? "Unknown Restaurant"
                let location = (restaurantData["location"] as? String) ?? "Unknown Location"
                let photoId = restaurantData["photoId"] as? String
                
                // Handle numeric or string rating
                let rating: Double
                if let ratingNum = restaurantData["rating"] as? NSNumber {
                    rating = ratingNum.doubleValue
                } else if let ratingString = restaurantData["rating"] as? String, 
                          let ratingDouble = Double(ratingString) {
                    rating = ratingDouble
                } else {
                    rating = 4.0
                }
                
                let cuisine = restaurantData["cuisine"] as? String
                
                // Handle estimated time that could be int or string
                let estimatedTime: String?
                if let timeInt = restaurantData["estimatedTime"] as? Int {
                    estimatedTime = "\(timeInt)"
                } else {
                    estimatedTime = restaurantData["estimatedTime"] as? String
                }
                
                // Create restaurant with explicit parameters
                return Restaurant(
                    id: restaurantId,
                    name: name,
                    estimatedTime: estimatedTime,
                    cuisine: cuisine,
                    photoId: photoId,
                    rating: rating,
                    location: location
                )
            } else {
                throw APIError.decodingFailed(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not extract restaurant data"]))
            }
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    /// Fetch top picks
    func fetchTopPicks() async throws -> [Product] {
        print("📡 APIClient: Starting fetchTopPicks request")
        
        let data = try await request(path: "/top-picks")
        
        print("📡 APIClient: Received top-picks response, data size: \(data.count) bytes")
        
        // Debug: Log the raw response data as a string if possible
        if let responseString = String(data: data, encoding: .utf8) {
            print("📡 APIClient: Top picks raw response: \(responseString)")
            
            // Check for specific keys in the response for better debugging
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📡 APIClient: Top-level keys found in response: \(json.keys.joined(separator: ", "))")
                
                // Check if allTopPicks exists and log its structure
                if let allTopPicks = json["allTopPicks"] as? [[String: Any]], !allTopPicks.isEmpty {
                    print("📡 APIClient: Found \(allTopPicks.count) items in 'allTopPicks' array")
                    if let firstItem = allTopPicks.first {
                        print("📡 APIClient: First item keys: \(firstItem.keys.joined(separator: ", "))")
                    }
                }
            }
        }
        
        // First try decoding with TopPicksResponse wrapper
        do {
            let response = try JSONDecoder().decode(TopPicksResponse.self, from: data)
            print("✅ APIClient: Successfully decoded top picks via wrapper: \(response.products.count) products")
            
            if response.products.isEmpty {
                print("⚠️ APIClient: TopPicksResponse.products array is empty")
                
                // If wrapper returned empty, try direct array decoding as a fallback
                do {
                    let products = try JSONDecoder().decode([Product].self, from: data)
                    print("✅ APIClient: Successfully decoded top picks as direct array: \(products.count) products")
                    return products
                } catch {
                    print("⚠️ APIClient: Direct array decoding failed: \(error.localizedDescription)")
                    
                    // Try manual JSON parsing as a last resort
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let allTopPicks = json["allTopPicks"] as? [[String: Any]] {
                            print("📡 APIClient: Attempting manual parsing of 'allTopPicks' array")
                            
                            let allTopPicksData = try JSONSerialization.data(withJSONObject: allTopPicks)
                            do {
                                let products = try JSONDecoder().decode([Product].self, from: allTopPicksData)
                                print("✅ APIClient: Successfully decoded \(products.count) products from manual parsing")
                                return products
                            } catch let error {
                                print("⚠️ APIClient: Manual parsing failed: \(error.localizedDescription)")
                                // Log the first item to see its structure
                                if let firstItem = allTopPicks.first {
                                    print("📡 APIClient: First item structure: \(firstItem)")
                                }
                            }
                        }
                    }
                }
            }
            
            return response.products
        } catch {
            print("⚠️ APIClient: TopPicksResponse decoding failed: \(error.localizedDescription)")
            
            // Try decoding directly as an array of products
            do {
                let products = try JSONDecoder().decode([Product].self, from: data)
                print("✅ APIClient: Successfully decoded top picks as direct array: \(products.count) products")
                return products
            } catch {
                print("⚠️ APIClient: Direct array decoding failed: \(error.localizedDescription)")
                
                // Try manual JSON parsing as a last resort
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Log all top-level keys
                    print("📡 APIClient: Top-level JSON keys: \(json.keys.joined(separator: ", "))")
                    
                    if let allTopPicks = json["allTopPicks"] as? [[String: Any]] {
                        print("📡 APIClient: Attempting manual parsing of 'allTopPicks' array with \(allTopPicks.count) items")
                        
                        let allTopPicksData = try JSONSerialization.data(withJSONObject: allTopPicks)
                        do {
                            let products = try JSONDecoder().decode([Product].self, from: allTopPicksData)
                            print("✅ APIClient: Successfully decoded \(products.count) products from manual parsing")
                            return products
                        } catch let decodeError {
                            print("⚠️ APIClient: Manual parsing failed: \(decodeError.localizedDescription)")
                            
                            // Last resort: Try to create Product objects manually
                            print("📡 APIClient: Attempting to manually construct Product objects")
                            var manualProducts: [Product] = []
                            
                            for (index, item) in allTopPicks.enumerated() {
                                if let id = item["_id"] as? String,
                                   let name = item["product_name"] as? String,
                                   let restaurantId = item["restaurant_id"] as? String {
                                    
                                    // Fix price extraction to use optional binding properly
                                    let price: Double
                                    if let priceNumber = item["product_price"] as? NSNumber {
                                        price = priceNumber.doubleValue
                                    } else if let priceString = item["product_price"] as? String, 
                                                      let parsedDouble = Double(priceString) {
                                        price = parsedDouble
                                    } else if let priceInt = item["product_price"] as? Int {
                                        price = Double(priceInt)
                                    } else {
                                        price = 0.0
                                    }
                                    
                                    let product = Product(
                                        id: id,
                                        name: name,
                                        description: item["description"] as? String,
                                        price: price,
                                        restaurantId: restaurantId,
                                        category: item["food_category"] as? String,
                                        isAvailable: item["availability"] as? Bool ?? true,
                                        rating: (item["rating"] as? NSNumber)?.doubleValue ?? 4.0,
                                        extraTime: item["extraTime"] as? Int ?? item["extra_time"] as? Int,
                                        photoId: item["photo_id"] as? String ?? id,
                                        isVeg: item["is_veg"] as? Bool ?? true
                                    )
                                    
                                    manualProducts.append(product)
                                    print("✅ APIClient: Manually created Product #\(index+1): \(name)")
                                } else {
                                    print("⚠️ APIClient: Failed to manually create Product #\(index+1)")
                                }
                            }
                            
                            if !manualProducts.isEmpty {
                                print("✅ APIClient: Successfully created \(manualProducts.count) products manually")
                                return manualProducts
                            }
                        }
                    } 
                    
                    // If we still can't decode, check for other possible keys
                    for (key, value) in json {
                        if let array = value as? [Any], !array.isEmpty {
                            print("📡 APIClient: Found array data under key: \(key), count: \(array.count)")
                            
                            if let itemsArray = value as? [[String: Any]] {
                                let itemsData = try JSONSerialization.data(withJSONObject: itemsArray)
                                do {
                                    let products = try JSONDecoder().decode([Product].self, from: itemsData)
                                    print("✅ APIClient: Successfully decoded products from key '\(key)': \(products.count) products")
                                    return products
                                } catch {
                                    print("⚠️ APIClient: Failed to decode array from key '\(key)': \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
                
                print("❌ APIClient: All top picks decoding approaches failed")
                throw APIError.decodingFailed(error)
            }
        }
    }
    
    /// Place an order
    func placeOrder(orderData: [String: Any]) async throws -> String {
        // Check if this is a scheduled order
        let path: String
        var modifiedOrderData = orderData
        
        if orderData["scheduleDate"] != nil {
            path = "/schedule-order-placed"
            // Always set takeAway to true for scheduled orders as required by server
            modifiedOrderData["takeAway"] = true
        } else {
            path = "/order-placed"
        }
        
        // Serialize the order data
        guard let requestBody = try? JSONSerialization.data(withJSONObject: modifiedOrderData) else {
            throw APIError.invalidURL
        }
        
        let data = try await request(
            path: path,
            method: "POST",
            body: requestBody,
            headers: ["Content-Type": "application/json"]
        )
        
        // Parse the response to get the order ID
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Check for "id" field (direct objectId)
            if let orderId = json["id"] as? String {
                return orderId
            }
            
            // Check for {"success": true, "data": {"orderId": "..."}} structure
            if let success = json["success"] as? Bool,
               success,
               let dataObj = json["data"] as? [String: Any],
               let orderId = dataObj["orderId"] as? String {
                return orderId
            }
        }
        
        // Check if the response is a plain string (ObjectId)
        if let responseText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: ""),
           responseText.count == 24, 
           responseText.range(of: "^[0-9a-f]+$", options: .regularExpression) != nil {
            return responseText
        }
        
        throw APIError.decodingFailed(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No valid order ID found in response"]))
    }
    
    // MARK: - Order verification
    
    /// Verify an order with retry and fallback mechanisms
    func verifyOrder(orderId: String) async throws -> Data {
        print("📡 APIClient: Starting order verification for \(orderId)")
        
        let jsonData = try JSONSerialization.data(withJSONObject: ["order_id": orderId])
        
        // Try both servers with retries for order verification to handle hibernation issues
        let maxRetries = 3
        var lastError: Error? = nil
        
        return try await Task(priority: .userInitiated) {
            // First try the primary server with retries
            for attempt in 1...maxRetries {
                do {
                    print("📡 APIClient: Verification attempt \(attempt)/\(maxRetries) on primary server")
                    let data = try await performRequest(
                        baseURL: renderBaseURL,
                        path: "/verify-order",
                        method: "POST",
                        body: jsonData,
                        headers: ["Content-Type": "application/json"]
                    )
                    print("✅ APIClient: Order verification successful on primary server")
                    return data
                } catch let error as APIError {
                    lastError = error
                    print("⚠️ APIClient: Primary server verification failed (attempt \(attempt)/\(maxRetries)): \(error.localizedDescription)")
                    
                    if case .serverError(let code, _) = error, code == 503 {
                        // Server is hibernating, wait and retry if not the last attempt
                        if attempt < maxRetries {
                            let delay = pow(2.0, Double(attempt - 1)) * 0.5
                            print("⏱️ APIClient: Waiting \(delay) seconds before retry...")
                            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    } else {
                        // For non-503 errors, break out and try the fallback server
                        break
                    }
                } catch {
                    lastError = error
                    print("⚠️ APIClient: Primary server verification failed with unexpected error: \(error.localizedDescription)")
                    break
                }
            }
            
            // If primary server failed, try the fallback server with retries
            print("🔀 APIClient: Trying fallback server for order verification")
            for attempt in 1...maxRetries {
                do {
                    print("📡 APIClient: Verification attempt \(attempt)/\(maxRetries) on fallback server")
                    let data = try await performRequest(
                        baseURL: railwayBaseURL,
                        path: "/verify-order",
                        method: "POST",
                        body: jsonData,
                        headers: ["Content-Type": "application/json"]
                    )
                    print("✅ APIClient: Order verification successful on fallback server")
                    return data
                } catch let error as APIError {
                    lastError = error
                    print("⚠️ APIClient: Fallback server verification failed (attempt \(attempt)/\(maxRetries)): \(error.localizedDescription)")
                    
                    if case .serverError(let code, _) = error, code == 503 {
                        // Server is hibernating, wait and retry if not the last attempt
                        if attempt < maxRetries {
                            let delay = pow(2.0, Double(attempt - 1)) * 0.5
                            print("⏱️ APIClient: Waiting \(delay) seconds before retry...")
                            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    } else {
                        // For non-503 errors, break out and give up
                        break
                    }
                } catch {
                    lastError = error
                    print("⚠️ APIClient: Fallback server verification failed with unexpected error: \(error.localizedDescription)")
                    break
                }
            }
            
            // If we get here, both servers failed
            print("❌ APIClient: All verification attempts failed on both servers")
            throw lastError ?? APIError.networkError(NSError(domain: "OrderVerification", code: -1))
        }.value
    }
    
    // MARK: - Order cancellation
    
    /// Cancel an order (used when payment fails)
    func cancelOrder(orderId: String) async throws -> Data {
        print("📡 APIClient: Starting order cancellation for \(orderId)")
        
        let jsonData = try JSONSerialization.data(withJSONObject: ["order_id": orderId])
        
        // Try both servers for order cancellation to ensure it gets processed
        let maxRetries = 3
        var lastError: Error? = nil
        
        for attempt in 1...maxRetries {
            // Try primary server first
            do {
                print("📡 APIClient: Cancellation attempt \(attempt)/\(maxRetries) on primary server")
                let data = try await performRequest(
                    baseURL: renderBaseURL,
                    path: "/cancel-order",
                    method: "POST",
                    body: jsonData,
                    headers: ["Content-Type": "application/json"]
                )
                print("✅ APIClient: Order cancellation successful on primary server")
                return data
            } catch let error {
                print("⚠️ APIClient: Order cancellation failed on primary server (attempt \(attempt)): \(error.localizedDescription)")
                lastError = error
                
                // Try secondary server immediately
                do {
                    print("📡 APIClient: Trying cancellation on secondary server")
                    let data = try await performRequest(
                        baseURL: railwayBaseURL,
                        path: "/cancel-order",
                        method: "POST",
                        body: jsonData,
                        headers: ["Content-Type": "application/json"]
                    )
                    print("✅ APIClient: Order cancellation successful on secondary server")
                    return data
                } catch let secondaryError {
                    print("⚠️ APIClient: Order cancellation failed on secondary server: \(secondaryError.localizedDescription)")
                    lastError = secondaryError
                }
            }
            
            // If both servers failed, wait before retrying
            try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
        }
        
        // If we reach here, all attempts failed
        throw lastError ?? APIError.networkError(NSError(domain: "OrderCancellation", code: -1))
    }
    
    // MARK: - Private helper methods
    
    private func performRequest(
        baseURL: URL,
        path: String,
        method: String,
        body: Data?,
        headers: [String: String]?
    ) async throws -> Data {
        let endpoint = path.hasPrefix("/") ? path : "/\(path)"
        let urlString = baseURL.absoluteString + endpoint
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        print("📡 APIClient: \(method) request to \(url.absoluteString)")
        print("📡 Full URL: \(url.absoluteString) (Server: \(baseURL.host ?? "unknown"))")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        
        // Set headers
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Set body for POST/PUT
        if let body = body {
            request.httpBody = body
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            if let bodyString = String(data: body, encoding: .utf8) {
                print("📤 Request body: \(bodyString)")
            }
        }
        
        // Implement retries for network errors
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                // Log response
                print("📥 Response status: \(httpResponse.statusCode) from \(baseURL.host ?? "unknown")")
                
                if httpResponse.statusCode >= 400 {
                    // For 503 errors, let the caller handle fallback logic
                    throw APIError.serverError(httpResponse.statusCode, data)
                }
                
                // Print response body for debugging (limit to ~500 chars)
                if let responseString = String(data: data, encoding: .utf8) {
                    let truncated = responseString.count > 500 ? 
                        responseString.prefix(500) + "... (truncated)" : responseString
                    print("📥 Response: \(truncated)")
                }
                
                return data
            } catch let error as URLError where [.timedOut, .notConnectedToInternet, .networkConnectionLost].contains(error.code) && attempt < maxRetries {
                lastError = error
                print("⚠️ Network error (attempt \(attempt)/\(maxRetries)): \(error.localizedDescription)")
                
                // Exponential backoff
                let delay = min(pow(2.0, Double(attempt - 1)), 8)
                print("⏱️ Waiting \(delay) seconds before retry...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                // For non-retryable errors, throw immediately
                throw error
            }
        }
        
        throw lastError ?? APIError.networkError(NSError(domain: "Unknown", code: -1))
    }
} 