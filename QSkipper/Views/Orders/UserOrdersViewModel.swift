import SwiftUI
import Foundation

// MARK: - ViewModel
class UserOrdersViewModel: ObservableObject {
    @Published var orders: [UserOrder] = []
    @Published var isLoading = false
    @Published var restaurantDetails: [String: Restaurant] = [:]
    @Published var allRestaurants: [Restaurant] = []
    @Published var errorMessage: String? = nil
    @Published var lastRefreshTime: Date? = nil
    
    // Track restaurant loading state
    private var restaurantFetchTasks: [String: Task<Void, Never>] = [:]
    private var restaurantLoadingStates: [String: Bool] = [:]
    
    // Computed property to determine if any restaurant data is loading
    var isLoadingRestaurantData: Bool {
        return restaurantLoadingStates.values.contains(true)
    }
    
    // Better filtering function with clear variable names
    func filteredOrders(searchText: String) -> [UserOrder] {
        guard !searchText.isEmpty else {
            return orders
        }
        
        let lowercasedQuery = searchText.lowercased()
        return orders.filter { order in
            // Search by restaurant name
            if order.restaurantName.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Search by dish name
            if order.items.contains(where: { $0.name.lowercased().contains(lowercasedQuery) }) {
                return true
            }
            
            return false
        }
    }
    
    func fetchOrders() {
        // Don't start loading if we're already loading
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        guard let userId = AuthManager.shared.getCurrentUserId() else {
            print("🚫 No user ID found")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Please log in to view your orders"
            }
            return
        }
        
        // Use Task for better async handling
        Task {
            do {
                // First fetch all restaurants to have the data available
                try await fetchAllRestaurants()
                
                // Now fetch the orders
                let orders = try await fetchUserOrdersAPI(userId: userId)
                
                // Process orders on the main thread
                await MainActor.run {
                    self.orders = orders
                    self.isLoading = false
                    self.lastRefreshTime = Date()
                    print("✅ Successfully loaded \(orders.count) orders")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Could not load orders: \(error.localizedDescription)"
                    print("❌ Error fetching orders: \(error)")
                }
            }
        }
    }
    
    // Dedicated method for API call
    private func fetchUserOrdersAPI(userId: String) async throws -> [UserOrder] {
        print("📡 UserOrdersViewModel: Using optimized user orders fetch method")
        
        // Use APIClient's dedicated user orders function that bypasses rate limiting
        // and uses the Railway server directly for better performance
        let data = try await APIClient.shared.fetchUserOrders(userId: userId)
        
        guard !data.isEmpty else {
            print("❌ Empty data received from orders API")
            throw NSError(domain: "UserOrdersViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data received from server"])
        }
        
        // Debug: Print the raw response data
        if let responseString = String(data: data, encoding: .utf8) {
            print("📋 Raw orders response: \(responseString)")
            
            // Add debug analysis
            print("🔍 DEBUG: Analyzing response format...")
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("🔍 Response is an object with keys: \(json.keys)")
                    
                    // Check if it has an 'orders' key
                    if json["orders"] != nil {
                        print("✅ Found 'orders' key - should use OrdersWrapper")
                    } else {
                        print("ℹ️ No 'orders' key - likely direct array")
                    }
                } else if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    print("🔍 Response is a direct array with \(jsonArray.count) items")
                    
                    // Look at first item structure
                    if !jsonArray.isEmpty {
                        print("🔍 First item has keys: \(jsonArray[0].keys)")
                    }
                }
            } catch {
                print("❌ JSON analysis error: \(error)")
            }
        }
        
        // Create a decoder with appropriate date decoding strategy
        let decoder = JSONDecoder()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            print("🕒 Attempting to parse date: \(dateString)")
            
            // Try parsing with the ISO8601DateFormatter first
            if let date = dateFormatter.date(from: dateString) {
                print("✅ Parsed date with ISO8601DateFormatter: \(date)")
                return date
            }
            
            // Fallback to multiple formats if needed
            let fallbackFormatters = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss"
            ].map { format -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }
            
            for formatter in fallbackFormatters {
                if let date = formatter.date(from: dateString) {
                    print("✅ Parsed date with fallback formatter \(formatter.dateFormat ?? ""): \(date)")
                    return date
                }
            }
            
            print("❌ Failed to parse date: \(dateString)")
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Date string \(dateString) does not match any supported format"
                )
            )
        }
        
        do {
            // First try to decode as direct array
            let orderResponses: [UserOrderResponseDTO] = try decoder.decode([UserOrderResponseDTO].self, from: data)
            print("✅ Successfully parsed \(orderResponses.count) orders")
            return await mapResponsesToOrders(orderResponses)
        } catch {
            print("❌ Failed to decode orders as array, trying alternative format: \(error)")
            
            // Try alternative format (orders wrapped in an object)
            do {
                let wrapper = try decoder.decode(UserOrdersWrapper.self, from: data)
                print("✅ Successfully parsed \(wrapper.orders?.count ?? 0) orders from wrapper")
                
                guard let orderResponses: [UserOrderResponseDTO] = wrapper.orders, !orderResponses.isEmpty else {
                    print("📋 No orders found for user")
                    return []
                }
                
                return await mapResponsesToOrders(orderResponses)
            } catch {
                print("❌ Failed to decode orders with wrapper: \(error)")
                throw error
            }
        }
    }
    
    // Process order responses with restaurant data
    private func mapResponsesToOrders(_ responses: [UserOrderResponseDTO]) async -> [UserOrder] {
        var mappedOrders: [UserOrder] = []
        
        for dto: UserOrderResponseDTO in responses {
            let restaurantId = dto.resturant
            
            // Use restaurant data if we have it, otherwise provide defaults
            let restaurantName = getRestaurantName(for: restaurantId)
            let location = getRestaurantLocation(for: restaurantId)
            
            print("🔄 Mapping order for restaurant: \(restaurantName) (ID: \(restaurantId))")
            
            // Create order items
            let items = dto.items.map { itemDto in
                UserOrderItem(
                    id: itemDto._id,
                    productId: itemDto.productId,
                    name: itemDto.name,
                    quantity: itemDto.quantity,
                    price: Double(itemDto.price) ?? 0.0
                )
            }
            
            // Parse order time
            let orderTime = parseISO8601Date(from: dto.Time) ?? Date()
            
            // Parse schedule date if available
            var scheduleDate: Date? = nil
            if let scheduleDateString = dto.scheduleDate {
                print("📅 Found scheduled date string: \(scheduleDateString)")
                scheduleDate = parseISO8601Date(from: scheduleDateString)
                
                if let date = scheduleDate {
                    print("✅ Successfully parsed scheduled date: \(date)")
                } else {
                    print("❌ Failed to parse scheduled date: \(scheduleDateString)")
                }
            }
            
            // Create the order
            let order = UserOrder(
                id: dto._id,
                restaurantId: restaurantId,
                userID: dto.userID,
                items: items,
                totalAmount: dto.totalAmount,
                status: dto.status,
                cookTime: dto.cookTime,
                takeAway: dto.takeAway,
                time: orderTime,
                scheduleDate: scheduleDate,
                restaurantName: restaurantName,
                restaurantLocation: location,
                rating: nil
            )
            
            mappedOrders.append(order)
            
            // Fetch restaurant image in background without blocking
            if !hasRestaurantDetails(for: restaurantId) {
                fetchRestaurantDetailsInBackground(for: restaurantId)
            }
        }
        
        return mappedOrders
    }
    
    // MARK: - Restaurant Data Helpers
    
    func fetchAllRestaurants() async throws {
        print("📡 Fetching all restaurants for mapping to orders")
        
        do {
            let restaurants = try await APIClient.shared.fetchRestaurants()
            await MainActor.run {
                self.allRestaurants = restaurants
                
                // Create a dictionary for quick lookups
                for restaurant in restaurants {
                    self.restaurantDetails[restaurant.id] = restaurant
                }
                
                print("✅ Successfully fetched \(restaurants.count) restaurants")
            }
        } catch {
            print("❌ Error fetching restaurants: \(error)")
            // Don't throw here - we can still show orders with placeholder data
        }
    }
    
    func fetchRestaurantDetailsInBackground(for restaurantId: String) {
        // Cancel any existing task for this restaurant
        restaurantFetchTasks[restaurantId]?.cancel()
        
        // Create a new task
        let task = Task {
            print("📸 Loading restaurant details for ID: \(restaurantId)")
            restaurantLoadingStates[restaurantId] = true
            
            do {
                let restaurant = try await APIClient.shared.fetchRestaurant(with: restaurantId)
                
                await MainActor.run {
                    self.restaurantDetails[restaurantId] = restaurant
                    
                    // Update orders that use this restaurant
                    var updatedOrders = self.orders
                    for i in 0..<updatedOrders.count {
                        if updatedOrders[i].restaurantId == restaurantId {
                            updatedOrders[i].restaurantName = restaurant.name ?? "Restaurant"
                            updatedOrders[i].restaurantLocation = restaurant.location ?? "Unknown location"
                        }
                    }
                    self.orders = updatedOrders
                }
            } catch {
                print("❌ Error fetching restaurant data: \(error.localizedDescription)")
            }
            
            restaurantLoadingStates[restaurantId] = false
        }
        
        restaurantFetchTasks[restaurantId] = task
    }
    
    // Helpers for restaurant data
    func hasRestaurantDetails(for restaurantId: String) -> Bool {
        return restaurantDetails[restaurantId] != nil
    }
    
    func getRestaurantName(for restaurantId: String) -> String {
        return restaurantDetails[restaurantId]?.name ?? "Restaurant"
    }
    
    func getRestaurantLocation(for restaurantId: String) -> String {
        return restaurantDetails[restaurantId]?.location ?? "Unknown location"
    }
    
    // MARK: - Date parsing
    
    func parseISO8601Date(from string: String) -> Date? {
        // Enhanced date parsing with multiple formats
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        print("🕒 Attempting to parse date: \(string)")
        
        // Try with ISO8601 formatter first
        if let date = iso8601Formatter.date(from: string) {
            print("✅ Parsed date with ISO8601DateFormatter: \(date)")
            return date
        }
        
        // Fallback to other formats
        let fallbackFormatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss"
        ].map { format -> DateFormatter in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }
        
        for formatter in fallbackFormatters {
            if let date = formatter.date(from: string) {
                print("✅ Parsed date with fallback formatter: \(date)")
                return date
            }
        }
        
        // If all parsing attempts fail
        print("❌ Failed to parse date: \(string)")
        return nil
    }
}

// Data Transfer Objects that match the API response structure
struct OrderItemDTO: Codable {
    let productId: String
    let name: String
    let quantity: Int
    let price: Double
    let _id: String
}

// Define explicit types for order response
struct UserOrderResponseDTO: Codable {
    let _id: String
    let resturant: String
    let userID: String
    let items: [OrderItemDTO]
    let totalAmount: String
    let status: String
    let cookTime: Int
    let takeAway: Bool
    let Time: String
    let scheduleDate: String?
    let __v: Int
}

// Make OrdersWrapper conform to Decodable only since we only need to decode it
struct UserOrdersWrapper: Codable {
    let status: String?
    let message: String?
    let orders: [UserOrderResponseDTO]?
} 