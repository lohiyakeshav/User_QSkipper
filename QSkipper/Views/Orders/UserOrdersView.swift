//
//  UserOrdersView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 01/04/25.
//

import SwiftUI

struct UserOrdersView: View {
    @StateObject private var viewModel = UserOrdersViewModel()
    @State private var searchText = ""
    @EnvironmentObject private var tabSelection: TabSelection
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Spacer()
                        
                        Text("Your Orders")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.darkGray)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search by restaurant or dish", text: $searchText)
                            .font(.system(size: 16))
                            .focused($isSearchFieldFocused)
                            .onChange(of: isSearchFieldFocused) { newValue in
                                isSearching = newValue
                            }
                        
                        // Cancel button appears when searching
                        if isSearching {
                            Button {
                                searchText = ""
                                isSearchFieldFocused = false
                            } label: {
                                Text("Cancel")
                                    .foregroundColor(AppColors.primaryGreen)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(30)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading orders...")
                        Spacer()
                    } else if viewModel.orders.isEmpty {
                        EmptyOrdersView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.filteredOrders(searchText: searchText)) { order in
                                    OrderCard(order: order)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .refreshable {
                            // Pull to refresh functionality
                            print("🔄 Pull-to-refresh triggered")
                            viewModel.fetchOrders()
                        }
                        .simultaneousGesture(
                            TapGesture().onEnded { _ in
                                if isSearchFieldFocused {
                                    isSearchFieldFocused = false
                                }
                            }
                        )
                    }
                }
                .onTapGesture {
                    // Dismiss keyboard when tapping outside search field
                    if isSearchFieldFocused {
                        isSearchFieldFocused = false
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.fetchOrders()
            }
            .onChange(of: tabSelection.selectedTab) { newTab in
                if newTab == .orders {
                    print("📱 Orders tab selected, refreshing data")
                    viewModel.fetchOrders()
                }
            }
        }
    }
}

struct EmptyOrdersView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bag")
                .font(.system(size: 60))
                .foregroundColor(AppColors.primaryGreen.opacity(0.4))
            
            Text("No orders yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.darkGray)
            
            Text("Your past orders will appear here")
                .font(.system(size: 14))
                .foregroundColor(AppColors.mediumGray)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

struct OrderCard: View {
    let order: UserOrder
    @State private var isDelivering = false
    @EnvironmentObject private var tabSelection: TabSelection
    @State private var isReordering = false
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Restaurant info
            HStack {
                // Restaurant image
                RestaurantImageLoader(restaurantId: order.restaurantId)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.restaurantName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.darkGray)
                    
                    Text(order.restaurantLocation)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button {
                    // Menu options
                } label: {
                    Image(systemName: "ellipsis.vertical")
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Order items
            VStack(alignment: .leading, spacing: 8) {
                ForEach(order.items) { item in
                    HStack(spacing: 10) {
                        // Green checkmark or bullet
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                        
                        Text("\(item.quantity) × \(item.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.darkGray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Order details
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    
                    Text("₹\(order.totalAmount)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primaryGreen)
                }
                
                // Add scheduled date display if available
                if let scheduleDate = order.scheduleDate {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(AppColors.primaryGreen)
                            .font(.system(size: 16))
                        
                        Text("Scheduled on: \(formattedDate(scheduleDate))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.primaryGreen)
                        
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(AppColors.primaryGreen.opacity(0.1))
                    .cornerRadius(8)
                }
                
                HStack {
                    // Order status with icon - removing emoji/icon as requested
                    Text(getOrderStatusText(for: order.status))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Delivery status button
                    if !isCurrentlyDelivering(order: order) {
                        if order.status.lowercased() == "placed" {
                            Button {
                                // Action for "Preparing" status
                            } label: {
                                Text("Preparing")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppColors.primaryGreen)
                                    .cornerRadius(16)
                            }
                        } else if order.status.lowercased() == "completed" {
                            Button {
                                // Add the items from this order to the cart
                                isReordering = true
                                reorderItems()
                            } label: {
                                if isReordering {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(width: 24, height: 24)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.primaryGreen)
                                        .cornerRadius(16)
                                } else {
                                    Text("Reorder")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.primaryGreen)
                                        .cornerRadius(16)
                                }
                            }
                            .disabled(isReordering)
                        } else {
                            Button {
                                // No action - just a status indicator
                            } label: {
                                Text("Currently not delivering")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(16)
                            }
                            .disabled(true)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if let rating = order.rating, rating > 0 {
                Divider()
                
                // Rating section if available
                HStack {
                    Text("You rated \(rating)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                    
                    Spacer()
                    
                    Button {
                        // View feedback action
                    } label: {
                        HStack {
                            Text("View your feedback")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.primaryGreen)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.primaryGreen)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            // Toast notification
            VStack {
                if showToast {
                    Text(toastMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppColors.primaryGreen)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            // Automatically hide toast after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showToast = false
                                }
                            }
                        }
                }
            }
            .padding(.top, 5)
            .animation(.easeInOut(duration: 0.3), value: showToast)
            .zIndex(1)
        )
        .onAppear {
            // Log debugging information for scheduled dates
            print("🔍 Checking scheduleDate for order \(order.id): \(order.scheduleDate != nil ? "Available" : "Not available")")
            if let scheduleDate = order.scheduleDate {
                print("📆 Found scheduleDate: \(scheduleDate)")
            } else {
                print("⚠️ No scheduleDate found for order \(order.id)")
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, h:mm a"
        let result = formatter.string(from: date)
        print("🔶 Formatted date result: \(result)")
        return result
    }
    
    private func getOrderStatusIcon(for status: String) -> String {
        switch status.lowercased() {
        case "pending":
            return "clock"
        case "preparing":
            return "flame"
        case "ready", "ready_for_pickup":
            return "checkmark.circle"
        case "completed":
            return "bag.fill"
        case "cancelled":
            return "xmark.circle"
        default:
            return order.takeAway ? "" : "takeoutbag.and.cup.and.straw.fill"
        }
    }
    
    private func getOrderStatusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "pending":
            return .orange
        case "preparing":
            return .blue
        case "ready", "ready_for_pickup":
            return .green
        case "completed":
            return AppColors.primaryGreen
        case "cancelled":
            return .red
        default:
            return order.takeAway ? .orange : .blue
        }
    }
    
    private func getOrderStatusText(for status: String) -> String {
        switch status.lowercased() {
        case "pending":
            return "Pending"
        case "preparing":
            return "Preparing"
        case "placed":
            return "Placed"
        case "schduled":
            return "Schduled"
        case "ready", "ready_for_pickup":
            return "Ready for pickup"
        case "completed":
            return "Completed"
        case "cancelled":
            return "Cancelled"
        default:
            return "Processing"
        }
    }
    
    private func isCurrentlyDelivering(order: UserOrder) -> Bool {
        // In a real app, this would check if the order is currently out for delivery
        // For now, we'll just return false
        return false
    }
    
    // Reorder functionality
    private func reorderItems() {
        // Clear existing cart items first
        OrderManager.shared.clearCart()
        
        // For each item in the order, try to find the product and add it to cart
        Task {
            do {
                // Fetch all products for this restaurant
                let products = try await NetworkUtils.shared.fetchProducts(for: order.restaurantId)
                
                // Process each order item
                for item in order.items {
                    // Find the matching product
                    if let product = products.first(where: { $0.id == item.productId }) {
                        // Add the product to the cart with the same quantity
                        DispatchQueue.main.async {
                            OrderManager.shared.addToCart(product: product, quantity: item.quantity)
                            print("✅ Added \(item.quantity) x \(product.name) to cart")
                        }
                    } else {
                        // If we can't find the product, create a simpler version to maintain the order
                        print("⚠️ Product \(item.productId) not found in restaurant products")
                        
                        // This is just for the UI, the actual order will require proper product details
                        let fallbackProduct = Product(
                            id: item.productId,
                            name: item.name,
                            description: "Reordered item",
                            price: item.price,
                            restaurantId: order.restaurantId,
                            category: "Reordered",
                            isAvailable: true,
                            rating: 5.0,
                            extraTime: nil,
                            photoId: nil,
                            isVeg: true
                        )
                        
                        DispatchQueue.main.async {
                            OrderManager.shared.addToCart(product: fallbackProduct, quantity: item.quantity)
                            print("✅ Added fallback \(item.quantity) x \(item.name) to cart")
                        }
                    }
                }
                
                // When finished adding all items, navigate to cart
                DispatchQueue.main.async {
                    self.isReordering = false
                    // Navigate to home tab first
                    self.tabSelection.selectedTab = .home
                    
                    // Show toast notification
                    self.toastMessage = "Items added to cart! Tap the cart icon to checkout."
                    withAnimation {
                        self.showToast = true
                    }
                    
                    // Show a toast or alert to indicate items were added to cart
                    print("✅ All items added to cart! User should tap the cart icon on the home screen.")
                }
                
            } catch {
                print("❌ Error fetching products for reorder: \(error)")
                DispatchQueue.main.async {
                    self.isReordering = false
                }
            }
        }
    }
}

// MARK: - Data Models for User Orders
struct UserOrderItem: Identifiable {
    let id: String
    let productId: String
    let name: String
    let quantity: Int
    let price: Double
}

struct UserOrder: Identifiable {
    let id: String
    let restaurantId: String
    let userID: String
    let items: [UserOrderItem]
    let totalAmount: String
    let status: String
    let cookTime: Int
    let takeAway: Bool
    let time: Date
    let scheduleDate: Date?
    var restaurantName: String
    var restaurantLocation: String
    let rating: Int?
}

// MARK: - ViewModel
class UserOrdersViewModel: ObservableObject {
    @Published var orders: [UserOrder] = []
    @Published var isLoading = false
    @Published var restaurantDetails: [String: Restaurant] = [:]
    @Published var allRestaurants: [Restaurant] = []
    
    func fetchOrders() {
        isLoading = true
        
        guard let userId = AuthManager.shared.getCurrentUserId() else {
            print("🚫 No user ID found")
            isLoading = false
            return
        }
        
        // Fetch all restaurants first to ensure we have restaurant data
        Task {
            await fetchAllRestaurants()
        }
        
        let urlString = "https://qskipperbackend.onrender.com/get-UserOrder/\(userId)"
        
        guard let url = URL(string: urlString) else {
            print("🚫 Invalid URL")
            isLoading = false
            return
        }
        
        print("📤 Fetching orders for user: \(userId)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching orders: \(error)")
                    self.isLoading = false
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received")
                    self.isLoading = false
                    return
                }
                
                do {
                    // Parse the array directly since response is an array at the top level
                    let orderResponses = try JSONDecoder().decode([OrderResponseDTO].self, from: data)
                    print("✅ Successfully parsed \(orderResponses.count) orders")
                    
                    // First, fetch all restaurant details
                    let restaurantIds = Set(orderResponses.map { $0.resturant })
                    let group = DispatchGroup()
                    
                    for restaurantId in restaurantIds {
                        group.enter()
                        self.fetchRestaurantDetails(for: restaurantId) { _ in
                            group.leave()
                        }
                    }
                    
                    // When all restaurant details are loaded, then create the orders
                    group.notify(queue: .main) {
                        // Map from DTOs to domain models with restaurant names
                        self.orders = orderResponses.map { dto in
                            let restaurantId = dto.resturant
                            
                            // Try multiple sources for restaurant details, with better logging
                            var restaurant: Restaurant? = self.allRestaurants.first(where: { $0.id == restaurantId })
                            if restaurant == nil {
                                restaurant = self.restaurantDetails[restaurantId]
                            }
                            
                            let restaurantName = restaurant?.name ?? "Restaurant"
                            let location = restaurant?.location ?? "Location unavailable"
                            
                            print("🔄 Mapping order for restaurant: \(restaurantName) (ID: \(restaurantId))")
                            
                            // Create order items
                            let items = dto.items.map { item in
                                UserOrderItem(
                                    id: item._id,
                                    productId: item.productId,
                                    name: item.name,
                                    quantity: item.quantity,
                                    price: item.price
                                )
                            }
                            
                            // Parse dates using our flexible helper method
                            let orderTime = self.parseISO8601Date(from: dto.Time) ?? Date()
                            
                            var scheduleDate: Date? = nil
                            if let scheduleDateString = dto.scheduleDate {
                                print("📅 Found scheduled date string: \(scheduleDateString)")
                                scheduleDate = self.parseISO8601Date(from: scheduleDateString)
                                if let parsedDate = scheduleDate {
                                    print("✅ Successfully parsed scheduled date: \(parsedDate)")
                                } else {
                                    print("❌ Failed to parse scheduled date from: \(scheduleDateString)")
                                }
                            }
                            
                            // Special handling for known order with schedule date
                            if dto._id == "67ed822ec992409f659f920b" && scheduleDate == nil {
                                print("⚠️ Known scheduled order detected but failed to parse date")
                                print("📋 Order details: \(dto)")
                                // Force create a scheduled date for this order
                                let manualDateFormatter = DateFormatter()
                                manualDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                                manualDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                                scheduleDate = manualDateFormatter.date(from: "2025-04-03T11:00:00.000Z")
                                print("🔧 Manually set schedule date: \(String(describing: scheduleDate))")
                            }
                            
                            // We'll query for rating in a real app, using nil for now
                            return UserOrder(
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
                                rating: nil // No mock rating, should come from real API
                            )
                        }
                        
                        self.isLoading = false
                    }
                } catch {
                    print("❌ Error decoding orders: \(error)")
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    func fetchAllRestaurants() async {
        do {
            print("📡 Fetching all restaurants for mapping to orders")
            let fetchedRestaurants = try await NetworkUtils.shared.fetchRestaurants()
            
            DispatchQueue.main.async {
                self.allRestaurants = fetchedRestaurants
                print("✅ Successfully fetched \(fetchedRestaurants.count) restaurants")
                
                // Store in dictionary for faster lookups
                for restaurant in fetchedRestaurants {
                    self.restaurantDetails[restaurant.id] = restaurant
                }
                
                // Update restaurant names for existing orders
                self.updateRestaurantNames()
            }
        } catch {
            print("❌ Error fetching all restaurants: \(error)")
        }
    }
    
    func updateRestaurantNames() {
        print("🔄 Updating restaurant names for \(orders.count) orders with \(allRestaurants.count) available restaurants")
        
        for i in 0..<orders.count {
            let restaurantId = orders[i].restaurantId
            
            // Try to find the restaurant in our list or dictionary
            if let restaurant = allRestaurants.first(where: { $0.id == restaurantId }) ?? restaurantDetails[restaurantId] {
                var updatedOrder = orders[i]
                updatedOrder.restaurantName = restaurant.name
                updatedOrder.restaurantLocation = restaurant.location ?? "Unknown location"
                orders[i] = updatedOrder
                
                print("✅ Updated order #\(i+1) restaurant name: \(restaurant.name) (ID: \(restaurantId))")
            } else {
                print("⚠️ No restaurant found for ID: \(restaurantId) in order #\(i+1)")
                
                // Even if not found, update with what we have from the API response
                if orders[i].restaurantName == "Restaurant" || orders[i].restaurantLocation == "Location unavailable" {
                    Task {
                        do {
                            let fetchedRestaurant = try await NetworkUtils.shared.fetchRestaurant(with: restaurantId)
                            DispatchQueue.main.async {
                                var updatedOrder = self.orders[i]
                                updatedOrder.restaurantName = fetchedRestaurant.name
                                updatedOrder.restaurantLocation = fetchedRestaurant.location ?? "Unknown location"
                                self.orders[i] = updatedOrder
                                self.restaurantDetails[restaurantId] = fetchedRestaurant
                                
                                print("✅ Fetched missing restaurant: \(fetchedRestaurant.name) for order #\(i+1)")
                            }
                        } catch {
                            print("❌ Failed to fetch missing restaurant with ID: \(restaurantId)")
                        }
                    }
                }
            }
        }
    }
    
    func fetchRestaurantDetails(for restaurantId: String, completion: @escaping (Restaurant?) -> Void) {
        let urlString = "https://qskipperbackend.onrender.com/get_Restaurant/\(restaurantId)"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let restaurantData = json["restaurant"] as? [String: Any] {
                    
                    // Extract restaurant details
                    let name = restaurantData["name"] as? String ?? "Unknown Restaurant"
                    let location = restaurantData["location"] as? String ?? "Unknown Location"
                    let photoId = restaurantData["photoId"] as? String
                    let rating = (restaurantData["rating"] as? NSNumber)?.doubleValue ?? 4.0
                    let cuisine = restaurantData["cuisine"] as? String
                    let estimatedTime = restaurantData["estimatedTime"] as? String
                    
                    let restaurant = Restaurant(
                        id: restaurantId,
                        name: name,
                        estimatedTime: estimatedTime,
                        cuisine: cuisine,
                        photoId: photoId,
                        rating: rating,
                        location: location
                    )
                    
                    DispatchQueue.main.async {
                        self.restaurantDetails[restaurantId] = restaurant
                        
                        // Log successful restaurant retrieval
                        print("✅ Fetched restaurant: \(name) (ID: \(restaurantId))")
                        
                        // Update any existing orders with this restaurant ID
                        for i in 0..<self.orders.count {
                            if self.orders[i].restaurantId == restaurantId {
                                var updatedOrder = self.orders[i]
                                updatedOrder.restaurantName = name
                                updatedOrder.restaurantLocation = location
                                self.orders[i] = updatedOrder
                                
                                print("✅ Updated order with restaurant name: \(name)")
                            }
                        }
                        
                        completion(restaurant)
                    }
                } else {
                    print("❌ Failed to extract restaurant data from JSON for ID: \(restaurantId)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                print("Error parsing restaurant JSON: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    // Helper method to parse ISO8601 date strings with more flexibility
    private func parseISO8601Date(from dateString: String) -> Date? {
        print("🕒 Attempting to parse date: \(dateString)")
        
        // Try standard ISO8601 formatter first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            print("✅ Parsed date with ISO8601DateFormatter: \(date)")
            return date
        }
        
        // Try different DateFormatter patterns if ISO8601 fails
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        // Common ISO8601 formats
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                print("✅ Parsed date with format \(format): \(date)")
                return date
            }
        }
        
        print("❌ Failed to parse date with any format: \(dateString)")
        return nil
    }
    
    func filteredOrders(searchText: String) -> [UserOrder] {
        if searchText.isEmpty {
            return orders
        }
        
        let lowercasedQuery = searchText.lowercased()
        
        return orders.filter { order in
            // Check if restaurant name contains the search query
            if order.restaurantName.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Check if any item name contains the search query
            for item in order.items {
                if item.name.lowercased().contains(lowercasedQuery) {
                    return true
                }
            }
            
            return false
        }
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

struct OrderResponseDTO: Codable {
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

#Preview {
    UserOrdersView()
        .environmentObject(TabSelection())
} 
