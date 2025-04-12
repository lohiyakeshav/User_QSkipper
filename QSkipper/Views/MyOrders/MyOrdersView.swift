//
//  MyOrdersView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 01/04/25.
//

import SwiftUI

struct MyOrdersView: View {
    @StateObject private var viewModel = MyOrdersViewModel()
    @EnvironmentObject private var orderManager: OrderManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.05).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("My Orders")
                            .font(AppFonts.title)
                            .foregroundColor(AppColors.darkGray)
                        
                        Spacer()
                        
                        // Cart button
                        NavigationLink(destination: CartView()
                            .environmentObject(orderManager)
                            .environmentObject(TabSelection.shared)) {
                            ZStack(alignment: .topTrailing) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColors.primaryGreen)
                                    .frame(width: 20, height: 20)
                                    .padding(8)
                                
                                // Show badge only if items in cart
                                if !orderManager.currentCart.isEmpty {
                                    CartBadge(count: orderManager.getTotalItems())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // Order status filter tabs
                    orderStatusFilterView
                    
                    // Orders list or empty state
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.filteredOrders.isEmpty {
                        emptyOrdersView
                    } else {
                        ordersListView
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.fetchUserOrders()
            }
            .refreshable {
                viewModel.fetchUserOrders()
            }
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 0)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 1)
            }
        }
    }
    
    // MARK: - Filter Tabs
    private var orderStatusFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "All" filter
                statusFilterButton(title: "All", status: nil)
                
                // Status filters
                statusFilterButton(title: "Pending", status: .pending)
                statusFilterButton(title: "Preparing", status: .preparing)
                statusFilterButton(title: "Ready", status: .readyForPickup)
                statusFilterButton(title: "Completed", status: .completed)
                statusFilterButton(title: "Cancelled", status: .cancelled)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color.white)
    }
    
    private func statusFilterButton(title: String, status: OrderStatus?) -> some View {
        let isSelected = viewModel.selectedStatus == status
        
        return Button {
            viewModel.selectedStatus = status
        } label: {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : AppColors.darkGray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.primaryGreen : Color.gray.opacity(0.1))
                .cornerRadius(20)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                .scaleEffect(1.5)
            Text("Loading orders...")
                .font(AppFonts.body)
                .foregroundColor(AppColors.mediumGray)
                .padding(.top, 20)
            Spacer()
        }
    }
    
    // MARK: - Empty State
    private var emptyOrdersView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bag")
                .font(.system(size: 60))
                .foregroundColor(AppColors.primaryGreen.opacity(0.4))
            
            Text("No orders yet")
                .font(AppFonts.subtitle)
                .foregroundColor(AppColors.darkGray)
            
            Text("Place your first order from our restaurants")
                .font(AppFonts.body)
                .foregroundColor(AppColors.mediumGray)
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: HomeView()) {
                Text("Explore Restaurants")
                    .font(AppFonts.button)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AppColors.primaryGreen)
                    .cornerRadius(10)
                    .padding(.horizontal, 60)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Orders List
    private var ordersListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.filteredOrders) { order in
                    NavigationLink(destination: OrderDetailView(order: order)) {
                        OrderItemCard(order: order)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 100) // Extra padding for tab bar
        }
    }
}

// MARK: - Order Item Card
struct OrderItemCard: View {
    let order: Order
    @State private var restaurantName: String = "Restaurant"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Restaurant name and order status
            HStack {
                Text(restaurantName)
                    .font(AppFonts.subtitle)
                    .foregroundColor(AppColors.darkGray)
                
                Spacer()
                
                Text(order.status.displayName)
                    .font(AppFonts.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor(for: order.status))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Divider()
            
            // Order info
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Order #\(order.id.suffix(6))")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.mediumGray)
                    
                    Text(formattedDate(order.createdAt))
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.mediumGray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("₹\(String(format: "%.2f", order.totalAmount))")
                        .font(AppFonts.subtitle)
                        .foregroundColor(AppColors.primaryGreen)
                    
                    Text("\(order.items.count) item\(order.items.count > 1 ? "s" : "")")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.mediumGray)
                }
            }
            
            // Items preview (first 2 items)
            let previewItems = Array(order.items.prefix(2))
            ForEach(previewItems) { item in
                HStack {
                    Text("• \(item.productName ?? "Item")")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.darkGray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("× \(item.quantity)")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.mediumGray)
                }
            }
            
            // If there are more items, show "and X more"
            if order.items.count > 2 {
                Text("and \(order.items.count - 2) more item\(order.items.count - 2 > 1 ? "s" : "")")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.mediumGray)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            // Try to get restaurant name
            Task {
                do {
                    if let restaurant = RestaurantManager.shared.getRestaurant(by: order.restaurantId) {
                        restaurantName = restaurant.name
                    } else {
                        // Try to fetch restaurants if not available
                        try await RestaurantManager.shared.fetchAllRestaurants()
                        if let restaurant = RestaurantManager.shared.getRestaurant(by: order.restaurantId) {
                            restaurantName = restaurant.name
                        }
                    }
                } catch {
                    print("Error fetching restaurant: \(error)")
                }
            }
        }
    }
    
    // Format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM, h:mm a"
        return formatter.string(from: date)
    }
    
    // Get status color
    private func statusColor(for status: OrderStatus) -> Color {
        switch status {
        case .pending:
            return Color.orange
        case .preparing:
            return Color.blue
        case .readyForPickup:
            return Color.purple
        case .completed:
            return AppColors.primaryGreen
        case .cancelled:
            return Color.red
        }
    }
}

// MARK: - ViewModel
class MyOrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var selectedStatus: OrderStatus? = nil
    
    var filteredOrders: [Order] {
        if let status = selectedStatus {
            return orders.filter { $0.status == status }
        } else {
            return orders
        }
    }
    
    func fetchUserOrders() {
        guard let userId = UserDefaultsManager.shared.getUserId() else {
            print("❌ Error: No user ID available")
            return
        }
        
        isLoading = true
        
        // Fetch orders
        Task {
            do {
                print("📤 Fetching orders for user: \(userId)")
                
                // Prepare request
                let url = URL(string: "http://localhost:5000/get-UserOrder/\(userId)")!
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // Get response status code
                if let httpResponse = response as? HTTPURLResponse {
                    print("📥 Received response with status code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        // Try to decode JSON response
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("📥 Response data: \(responseString)")
                        }
                        
                        // Parse orders from response
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let ordersData = json["orders"] as? [[String: Any]] {
                            
                            let parsedOrders = parseOrdersFromJSON(ordersData)
                            
                            await MainActor.run {
                                self.orders = parsedOrders.sorted(by: { $0.createdAt > $1.createdAt })
                                self.isLoading = false
                            }
                        } else {
                            print("❌ Error: Failed to parse orders from response")
                            await MainActor.run {
                                self.isLoading = false
                            }
                        }
                    } else {
                        print("❌ Error: Received non-200 status code: \(httpResponse.statusCode)")
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(responseString)")
                        }
                        
                        await MainActor.run {
                            self.isLoading = false
                        }
                    }
                } else {
                    print("❌ Error: Invalid response")
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                print("❌ Error fetching orders: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func parseOrdersFromJSON(_ ordersData: [[String: Any]]) -> [Order] {
        var result: [Order] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        for orderData in ordersData {
            if let id = orderData["oid"] as? String,
               let userId = orderData["uid"] as? String,
               let restaurantId = orderData["rid"] as? String,
               let totalAmount = orderData["total_amount"] as? Double,
               let statusString = orderData["status"] as? String,
               let orderTypeString = orderData["order_type"] as? String,
               let createdAtString = orderData["created_at"] as? String,
               let itemsData = orderData["items"] as? [[String: Any]] {
                
                let status = OrderStatus(rawValue: statusString) ?? .pending
                let orderType = OrderType(rawValue: orderTypeString) ?? .takeaway
                
                let createdAt = dateFormatter.date(from: createdAtString) ?? Date()
                var updatedAt: Date? = nil
                if let updatedAtString = orderData["updated_at"] as? String {
                    updatedAt = dateFormatter.date(from: updatedAtString)
                }
                
                var scheduledTime: Date? = nil
                if let scheduledTimeString = orderData["scheduled_time"] as? String {
                    scheduledTime = dateFormatter.date(from: scheduledTimeString)
                }
                
                // Parse order items
                var items: [OrderItem] = []
                for itemData in itemsData {
                    if let productId = itemData["pid"] as? String,
                       let quantity = itemData["quantity"] as? Int,
                       let price = itemData["price"] as? Double {
                        
                        let productName = itemData["product_name"] as? String
                        let item = OrderItem(productId: productId, quantity: quantity, price: price, productName: productName)
                        items.append(item)
                    }
                }
                
                let order = Order(
                    id: id,
                    userId: userId,
                    restaurantId: restaurantId,
                    items: items,
                    totalAmount: totalAmount,
                    status: status,
                    orderType: orderType,
                    scheduledTime: scheduledTime,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
                
                result.append(order)
            }
        }
        
        return result
    }
    
    // Function to check order status
    func checkOrderStatus(orderId: String) {
        Task {
            do {
                print("📤 Checking status for order: \(orderId)")
                
                // Prepare request
                let url = URL(string: "http://localhost:5000/order-status/\(orderId)")!
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // Get response status code
                if let httpResponse = response as? HTTPURLResponse {
                    print("📥 Received status response with code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        // Try to decode JSON response
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("📥 Status response data: \(responseString)")
                        }
                        
                        // Parse status from response
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let statusString = json["order_status"] as? String,
                           let status = OrderStatus(rawValue: statusString) {
                            
                            // Update order status in the orders array
                            await MainActor.run {
                                if let index = self.orders.firstIndex(where: { $0.id == orderId }) {
                                    var updatedOrder = self.orders[index]
                                    // We would need to create a new Order object since it's immutable
                                    // This is a simplification - in a real app we might have more fields to update
                                    let newOrder = Order(
                                        id: updatedOrder.id,
                                        userId: updatedOrder.userId,
                                        restaurantId: updatedOrder.restaurantId,
                                        items: updatedOrder.items,
                                        totalAmount: updatedOrder.totalAmount,
                                        status: status, // Updated status
                                        orderType: updatedOrder.orderType,
                                        scheduledTime: updatedOrder.scheduledTime,
                                        createdAt: updatedOrder.createdAt,
                                        updatedAt: Date() // New update time
                                    )
                                    self.orders[index] = newOrder
                                }
                            }
                        } else {
                            print("❌ Error: Failed to parse order status from response")
                        }
                    } else {
                        print("❌ Error: Received non-200 status code: \(httpResponse.statusCode)")
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(responseString)")
                        }
                    }
                }
            } catch {
                print("❌ Error checking order status: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    MyOrdersView()
        .environmentObject(OrderManager.shared)
} 
