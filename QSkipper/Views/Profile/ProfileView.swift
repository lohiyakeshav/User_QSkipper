//
//  ProfileView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        ScrollView {
            profileContent
        }
        .background(Color.gray.opacity(0.05))
        .edgesIgnoringSafeArea(.bottom)
        .alert("Logout", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .onAppear {
            // Get user information
            let _ = authManager.getCurrentUserName()
            let _ = authManager.getCurrentUserEmail()
            let _ = authManager.getCurrentUserId()
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 1)
        }
    }
    
    // MARK: - Main Profile Content
    private var profileContent: some View {
        VStack(spacing: 0) {
            profileHeader
            accountSettingsSection
            supportSection
            logoutButton
            
            // Bottom spacer for tab bar
            Color.clear
                .frame(height: 100)
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 5) {
            // Welcome Text
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Hi, \(authManager.getCurrentUserName() ?? "User")")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.darkGray)
                    
                    Text("Welcome to QSkipper")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.mediumGray)
                }
                
                Spacer()
                
                // Profile avatar
                ZStack {
                    Circle()
                        .fill(AppColors.primaryGreen.opacity(0.1))
                        .frame(width: 70, height: 70)
                    
                    Text(getInitials())
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.primaryGreen)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            // User email
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(AppColors.primaryGreen)
                    .font(.system(size: 14))
                
                Text(authManager.getCurrentUserEmail() ?? "keshav.lohiyas@gmail.com")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.mediumGray)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .padding(.bottom, 10)
        .background(Color.white)
    }
    
    // MARK: - Account Settings Section
    private var accountSettingsSection: some View {
        VStack(spacing: 0) {
            // Section header
            Text("Account Settings")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(Color.gray.opacity(0.05))
            
            // Account settings menu
            VStack(spacing: 0) {
                MenuRow(icon: "bag", title: "My Orders") {
                    print("Navigate to My Orders")
                }
                
                Divider()
                    .padding(.leading, 60)
                
                MenuRow(icon: "mappin.and.ellipse", title: "Delivery Addresses") {
                    print("Navigate to Delivery Addresses")
                }
                
                Divider()
                    .padding(.leading, 60)
                
                MenuRow(icon: "creditcard", title: "Payment Methods") {
                    print("Navigate to Payment Methods")
                }
            }
            .background(Color.white)
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        VStack(spacing: 0) {
            // Section header
            Text("Support & About")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(Color.gray.opacity(0.05))
            
            // Support menu
            VStack(spacing: 0) {
                MenuRow(icon: "questionmark.circle", title: "Help Center") {
                    print("Navigate to Help Center")
                }
                
                Divider()
                    .padding(.leading, 60)
                
                MenuRow(icon: "info.circle", title: "About QSkipper") {
                    print("Navigate to About")
                }
            }
            .background(Color.white)
        }
    }
    
    // MARK: - Logout Button
    private var logoutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                
                Text("Logout")
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 30)
        }
    }
    
    private func getInitials() -> String {
        let name = authManager.getCurrentUserName() ?? ""
        
        // If name is empty, return "U" as fallback
        if name.isEmpty {
            return "U"
        }
        
        let components = name.components(separatedBy: " ")
        var initials = ""
        
        for component in components {
            if let firstChar = component.first {
                initials.append(firstChar)
            }
        }
        
        // If no initials could be extracted, return "U" as fallback
        return initials.isEmpty ? "U" : initials.prefix(2).uppercased()
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.primaryGreen)
                    .frame(width: 24, height: 24)
                    .padding(.leading, 20)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .padding(.leading, 15)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                    .padding(.trailing, 20)
            }
            .padding(.vertical, 15)
            .background(Color.white)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct OrderHistoryView: View {
    @StateObject private var orderManager = OrderManager.shared
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var selectedOrderStatus: OrderStatus?
    @State private var selectedOrderType: OrderType?
    
    var filteredOrders: [Order] {
        var result = orderManager.orders
        
        if let status = selectedOrderStatus {
            result = result.filter { $0.status == status }
        }
        
        if let type = selectedOrderType {
            result = result.filter { $0.orderType == type }
        }
        
        // Sort by most recent first
        return result.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.05).edgesIgnoringSafeArea(.all)
            
            VStack {
                // Filter options
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button {
                            selectedOrderStatus = nil
                            selectedOrderType = nil
                        } label: {
                            Text("All")
                                .font(AppFonts.body)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background((selectedOrderStatus == nil && selectedOrderType == nil) ? 
                                            AppColors.primaryGreen : Color.gray.opacity(0.2))
                                .foregroundColor((selectedOrderStatus == nil && selectedOrderType == nil) ? 
                                                .white : AppColors.darkGray)
                                .cornerRadius(20)
                        }
                        
                        // Status filters
                        Button {
                            selectedOrderStatus = .pending
                            selectedOrderType = nil
                        } label: {
                            Text("Pending")
                                .font(AppFonts.body)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(selectedOrderStatus == .pending ? 
                                            Color.orange : Color.gray.opacity(0.2))
                                .foregroundColor(selectedOrderStatus == .pending ? 
                                                .white : AppColors.darkGray)
                                .cornerRadius(20)
                        }
                        
                        Button {
                            selectedOrderStatus = .preparing
                            selectedOrderType = nil
                        } label: {
                            Text("Preparing")
                                .font(AppFonts.body)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(selectedOrderStatus == .preparing ? 
                                            Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedOrderStatus == .preparing ? 
                                                .white : AppColors.darkGray)
                                .cornerRadius(20)
                        }
                        
                        Button {
                            selectedOrderStatus = .readyForPickup
                            selectedOrderType = nil
                        } label: {
                            Text("Ready")
                                .font(AppFonts.body)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(selectedOrderStatus == .readyForPickup ? 
                                            AppColors.primaryGreen : Color.gray.opacity(0.2))
                                .foregroundColor(selectedOrderStatus == .readyForPickup ? 
                                                .white : AppColors.darkGray)
                                .cornerRadius(20)
                        }
                        
                        // Type filters
                        Button {
                            selectedOrderStatus = nil
                            selectedOrderType = .dineIn
                        } label: {
                            Text("Dine In")
                                .font(AppFonts.body)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(selectedOrderType == .dineIn ? 
                                            AppColors.primaryGreen : Color.gray.opacity(0.2))
                                .foregroundColor(selectedOrderType == .dineIn ? 
                                                .white : AppColors.darkGray)
                                .cornerRadius(20)
                        }
                        
                        Button {
                            selectedOrderStatus = nil
                            selectedOrderType = .takeaway
                        } label: {
                            Text("Takeaway")
                                .font(AppFonts.body)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(selectedOrderType == .takeaway ? 
                                            AppColors.primaryGreen : Color.gray.opacity(0.2))
                                .foregroundColor(selectedOrderType == .takeaway ? 
                                                .white : AppColors.darkGray)
                                .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                
                if orderManager.orders.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bag")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.mediumGray)
                        
                        Text("No Orders Yet")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.darkGray)
                        
                        Text("Your order history will appear here")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.mediumGray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredOrders.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.mediumGray)
                        
                        Text("No Orders Found")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.darkGray)
                        
                        Text("Try changing your filter options")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.mediumGray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredOrders) { order in
                                NavigationLink(destination: OrderDetailView(order: order)) {
                                    OrderItemView(order: order)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        await refreshOrders()
                    }
                }
            }
            
            if isLoading && !isRefreshing {
                LoadingView()
            }
        }
        .navigationTitle("Order History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await refreshOrders()
            }
        }
    }
    
    func refreshOrders() async {
        isRefreshing = true
        do {
            _ = try await orderManager.getUserOrders()
        } catch {
            print("Error fetching orders: \(error)")
        }
        isRefreshing = false
    }
}

struct OrderItemView: View {
    let order: Order
    @StateObject private var restaurantManager = RestaurantManager.shared
    @State private var restaurant: Restaurant?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(restaurant?.name ?? "Restaurant")
                    .font(AppFonts.subtitle)
                    .foregroundColor(AppColors.darkGray)
                
                Spacer()
                
                Text(order.status.displayName)
                    .font(AppFonts.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(for: order.status))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            HStack {
                Text(order.orderType.displayName)
                    .font(AppFonts.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(order.orderType == .dineIn ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8))
                    .cornerRadius(8)
                
                if let scheduledTime = order.scheduledTime {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        
                        Text(formatScheduledTime(scheduledTime))
                            .font(AppFonts.caption)
                    }
                    .foregroundColor(AppColors.primaryGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.primaryGreen.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Show first 2 items and "+ X more" if there are more
            let displayedItems = Array(order.items.prefix(2))
            let remainingCount = order.items.count - displayedItems.count
            
            ForEach(displayedItems) { item in
                HStack {
                    Text(item.productName ?? "Item")
                        .font(AppFonts.body)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("x\(item.quantity)")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.mediumGray)
                    
                    Text("$\(String(format: "%.2f", item.price * Double(item.quantity)))")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryGreen)
                }
            }
            
            if remainingCount > 0 {
                Text("+ \(remainingCount) more item\(remainingCount > 1 ? "s" : "")")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.mediumGray)
            }
            
            Divider()
            
            HStack {
                Text("Total:")
                    .font(AppFonts.body)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("$\(String(format: "%.2f", order.totalAmount))")
                    .font(AppFonts.body)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryGreen)
            }
            
            Text("Order Date: \(formattedDate(order.createdAt))")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.mediumGray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.vertical, 5)
        .onAppear {
            // Fetch restaurant info
            restaurant = restaurantManager.getRestaurant(by: order.restaurantId)
        }
    }
    
    private func statusColor(for status: OrderStatus) -> Color {
        switch status {
        case .pending:
            return Color.orange
        case .preparing:
            return Color.blue
        case .readyForPickup:
            return AppColors.primaryGreen
        case .completed:
            return AppColors.primaryGreen
        case .cancelled:
            return AppColors.errorRed
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatScheduledTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

struct OrderDetailView: View {
    let order: Order
    @StateObject private var restaurantManager = RestaurantManager.shared
    @State private var restaurant: Restaurant?
    @State private var isRefreshing = false
    @State private var orderStatus: OrderStatus
    
    init(order: Order) {
        self.order = order
        self._orderStatus = State(initialValue: order.status)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Order status card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: statusIcon(for: orderStatus))
                            .font(.system(size: 24))
                            .foregroundColor(statusColor(for: orderStatus))
                        
                        Text(orderStatus.displayName)
                            .font(AppFonts.subtitle)
                            .foregroundColor(statusColor(for: orderStatus))
                        
                        Spacer()
                        
                        Text("Order #\(order.id.suffix(6))")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.mediumGray)
                    }
                    
                    // Order type and scheduled time
                    HStack {
                        Text(order.orderType.displayName)
                            .font(AppFonts.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(order.orderType == .dineIn ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8))
                            .cornerRadius(8)
                        
                        if let scheduledTime = order.scheduledTime {
                            Spacer()
                            
                            HStack {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                
                                Text(formatDate(scheduledTime))
                                    .font(AppFonts.caption)
                            }
                            .foregroundColor(AppColors.primaryGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.primaryGreen.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Restaurant details card
                if let restaurant = restaurant {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Restaurant")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.darkGray)
                        
                        HStack(spacing: 12) {
                            // Restaurant logo
                            if let photoId = restaurant.photoId {
                                RestaurantImageView(photoId: photoId)
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text(restaurant.name.prefix(1).uppercased())
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            // Restaurant info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(restaurant.name)
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.darkGray)
                                
                                Text(restaurant.location)
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.mediumGray)
                            }
                            
                            Spacer()
                            
                            // Directions button
                            Button {
                                // Open maps with restaurant location
                            } label: {
                                Image(systemName: "location.fill")
                                    .foregroundColor(AppColors.primaryGreen)
                                    .padding(8)
                                    .background(AppColors.primaryGreen.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                
                // Order items card
                VStack(alignment: .leading, spacing: 10) {
                    Text("Order Items")
                        .font(AppFonts.subtitle)
                        .foregroundColor(AppColors.darkGray)
                    
                    ForEach(order.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.productName ?? "Item")
                                    .font(AppFonts.body)
                                
                                Text("$\(String(format: "%.2f", item.price))")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.mediumGray)
                            }
                            
                            Spacer()
                            
                            Text("x\(item.quantity)")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.mediumGray)
                                .frame(width: 40)
                            
                            Text("$\(String(format: "%.2f", item.price * Double(item.quantity)))")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.primaryGreen)
                                .frame(width: 60, alignment: .trailing)
                        }
                        
                        if item.id != order.items.last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Order summary card
                VStack(alignment: .leading, spacing: 10) {
                    Text("Bill Details")
                        .font(AppFonts.subtitle)
                        .foregroundColor(AppColors.darkGray)
                    
                    HStack {
                        Text("Item Total")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.mediumGray)
                        
                        Spacer()
                        
                        let subtotal = order.totalAmount * 0.93 // Approximation since we don't have the actual breakdown
                        Text("$\(String(format: "%.2f", subtotal))")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.darkGray)
                    }
                    
                    HStack {
                        Text("Convenience Fee (3%)")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.mediumGray)
                        
                        Spacer()
                        
                        Text("$\(String(format: "%.2f", 1.0))")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.darkGray)
                    }
                    
                    HStack {
                        Text("Tax 3%")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.mediumGray)
                        
                        Spacer()
                        
                        let tax = order.totalAmount * 0.03
                        Text("$\(String(format: "%.2f", tax))")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.darkGray)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.darkGray)
                        
                        Spacer()
                        
                        Text("$\(String(format: "%.2f", order.totalAmount))")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.primaryGreen)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Order information card
                VStack(alignment: .leading, spacing: 10) {
                    Text("Order Information")
                        .font(AppFonts.subtitle)
                        .foregroundColor(AppColors.darkGray)
                    
                    HStack {
                        Text("Order Date")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.mediumGray)
                        
                        Spacer()
                        
                        Text(formatDate(order.createdAt))
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.darkGray)
                    }
                    
                    HStack {
                        Text("Order ID")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.mediumGray)
                        
                        Spacer()
                        
                        Text(order.id)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.darkGray)
                    }
                    
                    HStack {
                        Text("Payment Method")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.mediumGray)
                        
                        Spacer()
                        
                        Text("Cash")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.darkGray)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            .padding()
        }
        .refreshable {
            await refreshOrderStatus()
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.gray.opacity(0.05).edgesIgnoringSafeArea(.all))
        .onAppear {
            // Fetch restaurant info
            restaurant = restaurantManager.getRestaurant(by: order.restaurantId)
            
            // Check order status
            Task {
                await refreshOrderStatus()
            }
        }
    }
    
    private func refreshOrderStatus() async {
        isRefreshing = true
        do {
            if let status = try await OrderManager.shared.getOrderStatus(orderId: order.id) {
                orderStatus = status
            }
        } catch {
            print("Error refreshing order status: \(error)")
        }
        isRefreshing = false
    }
    
    private func statusIcon(for status: OrderStatus) -> String {
        switch status {
        case .pending:
            return "clock"
        case .preparing:
            return "flame"
        case .readyForPickup:
            return "bag.fill"
        case .completed:
            return "checkmark.circle"
        case .cancelled:
            return "xmark.circle"
        }
    }
    
    private func statusColor(for status: OrderStatus) -> Color {
        switch status {
        case .pending:
            return Color.orange
        case .preparing:
            return Color.blue
        case .readyForPickup:
            return AppColors.primaryGreen
        case .completed:
            return AppColors.primaryGreen
        case .cancelled:
            return AppColors.errorRed
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        ProfileView()
    }
} 
