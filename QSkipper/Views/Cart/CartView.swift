//
//  CartView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct CartView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var orderManager: OrderManager
    @StateObject private var controller = CartViewController()
    @Environment(\.dismiss) private var dismiss
    @State private var showPaymentView = false
    @State private var showCancelAlert = false
    @State private var showPaymentError = false
    @State private var errorMessage = ""
    
    // Get current user ID from your custom auth system
    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "userId") ?? ""
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Custom navigation bar
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(AppColors.primaryGreen)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    Spacer()
                    
                    Text("Your Cart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.darkGray)
                    
                    Spacer()
                    
                    // Empty view for balance
                    Color.clear
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                
                Divider()
                
                // Main cart content
                CartContentView(
                    orderManager: orderManager,
                    controller: controller,
                    showPaymentView: $showPaymentView,
                    showCancelAlert: $showCancelAlert,
                    showPaymentError: $showPaymentError,
                    errorMessage: $errorMessage,
                    currentUserId: currentUserId,
                    presentationMode: presentationMode
                )
            }
            
            if controller.showOrderSuccess {
                // Present the OrderSuccessView as a full screen overlay
                Color.white
                    .ignoresSafeArea()
                    .overlay(
                        OrderSuccessView(
                            cartManager: orderManager,
                            orderId: controller.orderId
                        )
                        .environmentObject(TabSelection.shared)
                    )
            }
            
            if controller.isProcessing {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Processing payment...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $controller.showSchedulePicker) {
            SchedulePickerSheet(
                selectedDate: $controller.scheduledDate,
                isScheduled: $controller.isSchedulingOrder,
                onConfirm: {}
            )
        }
        .alert("Cancel Order?", isPresented: $showCancelAlert) {
            Button("No", role: .cancel) { }
            Button("Yes", role: .destructive) {
                orderManager.clearCart()
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to cancel your order?")
        }
        .alert("Payment Error", isPresented: $showPaymentError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .navigationDestination(isPresented: $controller.showPaymentView) {
            Group {
                if let orderRequest = controller.currentOrderRequest {
                    // Use explicit argument labels to avoid order dependency
                    let restaurantName = controller.restaurant?.name ?? "Restaurant"
                    let totalAmount = controller.getTotalAmount()
                    let tipAmount = Double(controller.selectedTipAmount) / 100 * totalAmount
                    
                    PaymentView(
                        cartManager: orderManager,
                        orderRequest: orderRequest,
                        restaurantName: restaurantName,
                        totalAmount: totalAmount,
                        tipAmount: tipAmount,
                        isScheduledOrder: controller.isSchedulingOrder,
                        scheduledTime: controller.isSchedulingOrder ? controller.scheduledDate : nil
                    )
                } else {
                    Text("Unable to process order")
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            // Load restaurant details
            controller.loadRestaurantDetails()
            // Hide tab bar when view appears
            hideTabBar(true)
            
            // Add a slight delay to ensure the tab bar is hidden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hideTabBar(true)
            }
        }
        .onDisappear {
            // Show tab bar when view disappears
            hideTabBar(false)
        }
        .ignoresSafeArea(.keyboard)
        // Use the view modifier as an additional measure
        .hideTabBar(true)
    }
    
    // Function to hide tab bar more reliably
    private func hideTabBar(_ hidden: Bool) {
        // Update UITabBar appearance
        let tabBarAppearance = UITabBarAppearance()
        if hidden {
            tabBarAppearance.configureWithTransparentBackground()
            tabBarAppearance.backgroundColor = UIColor.clear
            tabBarAppearance.shadowColor = UIColor.clear
            
            // Make all colors transparent
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .clear
            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .clear
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
        } else {
            tabBarAppearance.configureWithDefaultBackground()
        }
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Directly hide/show the tab bar using multiple approaches
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes
            let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
            for windowScene in windowScenes {
                for window in windowScene.windows {
                    // Approach 1: Direct access to tab bar controller
                    if let rootViewController = window.rootViewController as? UITabBarController {
                        // Hide both the tab bar and its items
                        rootViewController.tabBar.isHidden = hidden
                        rootViewController.tabBar.isTranslucent = hidden
                        
                        // Move tab bar off-screen if hidden
                        if hidden {
                            rootViewController.tabBar.frame.origin.y = UIScreen.main.bounds.height + 100
                            // Make items invisible
                            for item in rootViewController.tabBar.items ?? [] {
                                item.isEnabled = false
                                item.title = nil
                                item.image = nil
                                item.selectedImage = nil
                            }
                        } else {
                            // Reset position
                            rootViewController.tabBar.frame.origin.y = UIScreen.main.bounds.height - rootViewController.tabBar.frame.height
                            // Restore items
                            for item in rootViewController.tabBar.items ?? [] {
                                item.isEnabled = true
                            }
                        }
                    }
                    
                    // Approach 2: When tab bar controller is not the root
                    if let tabBarController = window.rootViewController?.tabBarController {
                        tabBarController.tabBar.isHidden = hidden
                        tabBarController.tabBar.isTranslucent = hidden
                        
                        if hidden {
                            tabBarController.tabBar.frame.origin.y = UIScreen.main.bounds.height + 100
                            // Set user interaction enabled to false for all tab bar items
                            for item in tabBarController.tabBar.items ?? [] {
                                item.isEnabled = false
                                item.title = nil
                                item.image = nil
                                item.selectedImage = nil
                            }
                        } else {
                            // Reset position
                            tabBarController.tabBar.frame.origin.y = UIScreen.main.bounds.height - tabBarController.tabBar.frame.height
                            // Restore items
                            for item in tabBarController.tabBar.items ?? [] {
                                item.isEnabled = true
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Cart Content View
struct CartContentView: View {
    @ObservedObject var orderManager: OrderManager
    @ObservedObject var controller: CartViewController
    @Binding var showPaymentView: Bool
    @Binding var showCancelAlert: Bool
    @Binding var showPaymentError: Bool
    @Binding var errorMessage: String
    let currentUserId: String
    let presentationMode: Binding<PresentationMode>
    @EnvironmentObject private var tabSelection: TabSelection
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if orderManager.currentCart.isEmpty {
                EmptyCartView()
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            CartHeaderView()
                            OrderTypeSelectionView(orderManager: orderManager)
                            CartItemsListView(orderManager: orderManager)
                            AddMoreButtonView(
                                orderManager: orderManager,
                                controller: controller,
                                presentationMode: presentationMode
                            )
                            DeliveryOptionsView(controller: controller)
                            
                            if let restaurant = controller.restaurant {
                                RestaurantDetailsView(restaurant: restaurant, controller: controller)
                            }
                            
                            BillDetailsView(orderManager: orderManager, controller: controller)
                            
                            // Pay Now button inside ScrollView
                            Button {
                                print("🔄 Place Order button tapped")
                                controller.placeOrder()
                            } label: {
                                if controller.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Pay Now")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(orderManager.currentCart.isEmpty ? Color.gray : AppColors.primaryGreen)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .disabled(controller.isProcessing || orderManager.currentCart.isEmpty)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onChange(of: controller.showPaymentView) { newValue in
            print("🔄 showPaymentView changed to: \(newValue)")
            showPaymentView = newValue
            if newValue {
                print("🎯 Attempting to navigate with orderRequest: \(String(describing: controller.currentOrderRequest))")
            }
        }
    }
}

// MARK: - Empty Cart View
struct EmptyCartView: View {
    @EnvironmentObject private var tabSelection: TabSelection
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(AppColors.primaryGreen.opacity(0.4))
            
            Text("Your cart is empty")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.darkGray)
            
            Text("Add some items to your cart")
                .font(.system(size: 14))
                .foregroundColor(AppColors.mediumGray)
                .multilineTextAlignment(.center)
            
            Button {
                // Go to home tab to browse restaurants
                tabSelection.selectedTab = .home
            } label: {
                Text("Browse Restaurants")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AppColors.primaryGreen)
                    .cornerRadius(10)
                    .padding(.horizontal, 60)
            }
            
            Spacer()
        }
        .frame(height: 400)
        .padding(.top, 40)
    }
}

// MARK: - Header View
struct CartHeaderView: View {
    var body: some View {
        HStack {
            Text("Order Summary")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.darkGray)
                .padding(.leading, 16)
            
            Spacer()
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Order Type Selection
struct OrderTypeSelectionView: View {
    @ObservedObject var orderManager: OrderManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Capsule()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 40)
                    .overlay(
                        HStack(spacing: 0) {
                            // Pick Up button
                            Button {
                                orderManager.selectedOrderType = .takeaway
                            } label: {
                                Text("Pick Up")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(orderManager.selectedOrderType == .takeaway ? .white : AppColors.darkGray)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        orderManager.selectedOrderType == .takeaway ?
                                        Capsule().fill(Color.green) : Capsule().fill(Color.clear)
                                    )
                                    .padding(3)
                            }
                            
                            // Dine In button
                            Button {
                                orderManager.selectedOrderType = .dineIn
                            } label: {
                                Text("Dine In")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(orderManager.selectedOrderType == .dineIn ? .white : AppColors.darkGray)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        orderManager.selectedOrderType == .dineIn ?
                                        Capsule().fill(Color.green) : Capsule().fill(Color.clear)
                                    )
                                    .padding(3)
                            }
                        }
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}

// MARK: - Cart Items List
struct CartItemsListView: View {
    @ObservedObject var orderManager: OrderManager
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(orderManager.currentCart.indices, id: \.self) { index in
                let item = orderManager.currentCart[index]
                
                HStack(spacing: 12) {
                    // Product image
                    ProductImageView(photoId: item.product.photoId, name: item.product.name, category: item.product.category)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                    
                    // Product details
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.product.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.darkGray)
                        
                        Text("₹\(String(format: "%.2f", item.product.price))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.darkGray)
                    }
                    
                    Spacer()
                    
                    // Quantity selector
                    HStack {
                        Button {
                            if item.quantity > 1 {
                                orderManager.decrementItem(at: index)
                            } else {
                                // When quantity is 1, remove item from cart
                                orderManager.removeFromCart(productId: item.productId)
                            }
                        } label: {
                            Text("−")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 36, height: 36)
                        }
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Text("\(item.quantity)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                        
                        Button {
                            orderManager.incrementItem(at: index)
                        } label: {
                            Text("+")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 36, height: 36)
                        }
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, 16)
                
                if index < orderManager.currentCart.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 20)
        .background(Color.white)
    }
}

// MARK: - Add More Button
struct AddMoreButtonView: View {
    @ObservedObject var orderManager: OrderManager
    @ObservedObject var controller: CartViewController
    let presentationMode: Binding<PresentationMode>
    
    var body: some View {
        Button {
            presentationMode.wrappedValue.dismiss()
        } label: {
            HStack {
                Spacer()
                Image(systemName: "plus")
                    .foregroundColor(AppColors.darkGray)
                Text("Add more")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.darkGray)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}

// MARK: - Delivery Options
struct DeliveryOptionsView: View {
    @ObservedObject var controller: CartViewController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delivery Options")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.darkGray)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            HStack(spacing: 10) {
                // Now option
                Button {
                    controller.isSchedulingOrder = false
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(controller.isSchedulingOrder ? AppColors.darkGray : AppColors.primaryGreen)
                        
                        Text("As soon as possible")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.mediumGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(controller.isSchedulingOrder ? Color.clear : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(controller.isSchedulingOrder ? Color.gray.opacity(0.3) : AppColors.primaryGreen, lineWidth: 1)
                    )
                }
                
                // Schedule option
                Button {
                    controller.showSchedulePicker = true
                    controller.isSchedulingOrder = true
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Schedule Later")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(controller.isSchedulingOrder ? AppColors.primaryGreen : AppColors.darkGray)
                        
                        if controller.isSchedulingOrder {
                            Text(formattedScheduleDate(for: controller.scheduledDate))
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.darkGray)
                        } else {
                            Text("Select time")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.mediumGray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(controller.isSchedulingOrder ? Color.gray.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(controller.isSchedulingOrder ? AppColors.primaryGreen : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    private func formattedScheduleDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Restaurant Details
struct RestaurantDetailsView: View {
    let restaurant: Restaurant
    @ObservedObject var controller: CartViewController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restaurant Details")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.darkGray)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Restaurant image
                    RestaurantImageView(photoId: restaurant.photoId, name: restaurant.name)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                    
                    // Restaurant details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(restaurant.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.darkGray)
                        
                        Text(restaurant.location)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.mediumGray)
                            .lineLimit(2)
                        
                        Text(restaurant.estimatedTime != nil ? "\(restaurant.estimatedTime!) delivery time" : "30-40 min delivery time")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.mediumGray)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                // Scheduled info when scheduled
                if controller.isSchedulingOrder {
                    ZStack {
                        Rectangle()
                            .fill(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(AppColors.primaryGreen)
                                
                                Text("Order scheduled for:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.darkGray)
                                
                                Spacer()
                                
                                Button {
                                    controller.showSchedulePicker = true
                                } label: {
                                    Text("Change")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppColors.primaryGreen)
                                }
                            }
                            
                            Text(formattedScheduleDate(for: controller.scheduledDate))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.darkGray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .frame(height: 60)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color.white)
    }
    
    private func formattedScheduleDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Bill Details
struct BillDetailsView: View {
    @ObservedObject var orderManager: OrderManager
    @ObservedObject var controller: CartViewController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bill Details")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.darkGray)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // Bill breakdown
            VStack(spacing: 12) {
                // Item total
                HStack {
                    Text("Item Total")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.darkGray)
                    
                    Spacer()
                    
                    Text("₹\(String(format: "%.2f", orderManager.getCartTotal()))")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.darkGray)
                }
                
                // Convenience fee
                HStack {
                    Text("Convenience Fee (4%)")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.darkGray)
                    
                    Spacer()
                    
                    Text("₹\(String(format: "%.2f", controller.getConvenienceFee()))")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.darkGray)
                }
                
                Divider()
                
                // To Pay (Total)
                HStack {
                    Text("To Pay")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.darkGray)
                    
                    Spacer()
                    
                    Text("₹\(String(format: "%.2f", controller.getTotalAmount()))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primaryGreen)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct SchedulePickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedDate: Date
    @Binding var isScheduled: Bool
    var onConfirm: () -> Void
    
    @State private var selectedDay: String = "Today"
    @State private var selectedTime: String = "12:00 PM"
    
    let dayOptions = ["Today", "Tomorrow"]
    let timeOptions = ["12:00 PM", "12:30 PM", "1:00 PM", "1:30 PM", "2:00 PM", "2:30 PM", "3:00 PM", "3:30 PM", "4:00 PM", "4:30 PM", "5:00 PM", "5:30 PM", "6:00 PM"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with icon and title
            HStack {
                Spacer()
                
                HStack {
                    Image(systemName: "clock.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 22))
                    
                    Text("Schedule Order")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.darkGray)
                }
                
                Spacer()
                
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.black)
                        .font(.system(size: 18))
                        .padding(8)
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Divider()
            
            // Day selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Day")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.darkGray)
                
                HStack(spacing: 12) {
                    ForEach(dayOptions, id: \.self) { day in
                        let isSelected = selectedDay == day
                        
                        Button {
                            selectedDay = day
                            
                            // Update date based on selection
                            let calendar = Calendar.current
                            if day == "Today" {
                                selectedDate = Date()
                            } else {
                                selectedDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                            }
                        } label: {
                            VStack {
                                Text(day)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(isSelected ? .green : AppColors.darkGray)
                                
                                // Use DateFormatter for the date display
                                Text(formattedDateString(for: day))
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.mediumGray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSelected ? Color.green.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Time selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Time")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.darkGray)
                
                // Time options as a grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(visibleTimeOptions, id: \.self) { time in
                        let isSelected = selectedTime == time
                        
                        Button {
                            selectedTime = time
                            updateSelectedDate(with: time)
                        } label: {
                            Text(time)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isSelected ? .green : AppColors.darkGray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSelected ? Color.green.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Confirm button
            Button {
                isScheduled = true
                onConfirm()
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Confirm")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.primaryGreen)
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 40)
        }
        .frame(height: 550)
        .background(Color.white)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .padding(.top, 16)
    }
    
    // Computed property for time options based on day
    private var visibleTimeOptions: [String] {
        if selectedDay == "Today" {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: Date())
            
            // If current hour is before 11 AM, show all options
            if hour < 11 {
                return timeOptions
            }
            
            // If current hour is after 6 PM, show no options for today
            if hour >= 18 {
                return []
            }
            
            // Otherwise show times that are at least 1 hour from now
            return timeOptions.filter { time in
                let timeHour = hourFromTimeString(time)
                return timeHour > hour + 1 && timeHour <= 18
            }
        } else {
            // For tomorrow, show all allowed times (11 AM to 6 PM)
            return timeOptions
        }
    }
    
    // Helper to get formatted date string
    private func formattedDateString(for option: String) -> String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM"
        
        if option == "Today" {
            return dateFormatter.string(from: Date())
        } else {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            return dateFormatter.string(from: tomorrow)
        }
    }
    
    // Helper to parse hour from time string
    private func hourFromTimeString(_ time: String) -> Int {
        let components = time.components(separatedBy: ":")
        if components.count > 0 {
            if let hourString = components.first, let hour = Int(hourString) {
                return time.contains("PM") && hour != 12 ? hour + 12 : hour
            }
        }
        return 0
    }
    
    // Update selected date with the chosen time
    private func updateSelectedDate(with timeString: String) {
        let calendar = Calendar.current
        
        // Extract hour and minute from the time string
        let hourString = timeString.split(separator: ":").first!
        let minuteString = timeString.split(separator: ":").last!.split(separator: " ").first!
        
        var hour = Int(hourString) ?? 12
        let minute = Int(minuteString) ?? 0
        
        // Adjust for PM
        if timeString.contains("PM") && hour != 12 {
            hour += 12
        } else if timeString.contains("AM") && hour == 12 {
            hour = 0
        }
        
        // Set the components
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = hour
        components.minute = minute
        
        if let date = calendar.date(from: components) {
            selectedDate = date
        }
    }
}

// Helper extension for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    // Add custom hideTabBar modifier
    func hideTabBar(_ hidden: Bool) -> some View {
        return self.modifier(HideTabBarModifier(hidden: hidden))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Custom modifier to hide tab bar
struct HideTabBarModifier: ViewModifier {
    let hidden: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if hidden {
                    hideTabBar()
                }
            }
            .onDisappear {
                if hidden {
                    showTabBar()
                }
            }
    }
    
    private func hideTabBar() {
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes
            let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
            
            for windowScene in windowScenes {
                for window in windowScene.windows {
                    if let tabBarController = window.rootViewController as? UITabBarController {
                        // Hide the tab bar
                        tabBarController.tabBar.isHidden = true
                        
                        // Make it transparent
                        tabBarController.tabBar.isTranslucent = true
                        tabBarController.tabBar.backgroundColor = .clear
                        tabBarController.tabBar.barTintColor = .clear
                        
                        // Move it off screen
                        tabBarController.tabBar.frame.origin.y = UIScreen.main.bounds.height + 200
                    }
                    
                    // Check if the tab bar controller is nested
                    if let tabBarController = window.rootViewController?.tabBarController {
                        tabBarController.tabBar.isHidden = true
                        tabBarController.tabBar.isTranslucent = true
                        tabBarController.tabBar.backgroundColor = .clear
                        tabBarController.tabBar.barTintColor = .clear
                        tabBarController.tabBar.frame.origin.y = UIScreen.main.bounds.height + 200
                    }
                }
            }
        }
    }
    
    private func showTabBar() {
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes
            let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
            
            for windowScene in windowScenes {
                for window in windowScene.windows {
                    if let tabBarController = window.rootViewController as? UITabBarController {
                        // Show the tab bar
                        tabBarController.tabBar.isHidden = false
                        
                        // Reset properties
                        tabBarController.tabBar.isTranslucent = false
                        tabBarController.tabBar.backgroundColor = nil
                        tabBarController.tabBar.barTintColor = nil
                        
                        // Move it back to normal position
                        tabBarController.tabBar.frame.origin.y = UIScreen.main.bounds.height - tabBarController.tabBar.frame.height
                    }
                    
                    // Check if the tab bar controller is nested
                    if let tabBarController = window.rootViewController?.tabBarController {
                        tabBarController.tabBar.isHidden = false
                        tabBarController.tabBar.isTranslucent = false
                        tabBarController.tabBar.backgroundColor = nil
                        tabBarController.tabBar.barTintColor = nil
                        tabBarController.tabBar.frame.origin.y = UIScreen.main.bounds.height - tabBarController.tabBar.frame.height
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        CartView()
            .environmentObject(OrderManager.shared)
    }
} 
