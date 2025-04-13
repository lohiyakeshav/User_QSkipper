//
//  CartView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

import SwiftUI

struct CartView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var orderManager: OrderManager
    @StateObject private var controller = CartViewController()
    @Environment(\.dismiss) private var dismiss
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
                    showPaymentView: .constant(false), // No longer needed, but kept for compatibility
                    showCancelAlert: $showCancelAlert,
                    showPaymentError: $showPaymentError,
                    errorMessage: $errorMessage,
                    currentUserId: currentUserId,
                    presentationMode: presentationMode
                )
                
                // Place Order Button moved to CartContentView
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
                    .transition(.opacity)
                    .animation(.easeInOut)
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
        .onAppear {
            controller.loadRestaurantDetails()
            hideTabBar(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hideTabBar(true)
            }
        }
        .onDisappear {
            hideTabBar(false)
        }
        .ignoresSafeArea(.keyboard)
        .hideTabBar(true)
    }
    
    // Assuming these helper methods exist elsewhere or need to be added
    
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
                            
                            // Place Order Button inside the ScrollView's VStack
                            if !orderManager.currentCart.isEmpty {
                                Button(action: {
                                    controller.placeOrder()
                                }) {
                                    Text(controller.isSchedulingOrder ? "Schedule Order" : "Place Order")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(AppColors.primaryGreen)
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .padding(.bottom, 80) // Increased bottom padding to 80
                                .disabled(controller.isProcessing || orderManager.currentCart.isEmpty)
                            }
                        }
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
    @Environment(\.presentationMode) var presentationMode
    
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
                
                // Dismiss the cart view to return to main UI
                presentationMode.wrappedValue.dismiss()
                
                // Post a notification to ensure tab change is recognized by the app
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                }
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
        .onAppear {
            print("👁️ EmptyCartView appeared")
        }
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
            Text("Order Options")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.darkGray)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            HStack(spacing: 10) {
                // Now option
                Button {
                    controller.isSchedulingOrder = false
                    // Reset scheduled date to default (1 hour from now)
                    controller.scheduledDate = Date().addingTimeInterval(3600)
                    print("📅 Reset to 'Now' option. scheduledDate reset to 1 hour from now")
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(controller.isSchedulingOrder ? AppColors.darkGray : AppColors.primaryGreen)
                        
                        Text("Average time: \(controller.restaurant?.estimatedTime ?? "30-40") mins")
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
                    print("📅 Opened schedule picker. Current date: \(controller.scheduledDate)")
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
                    
                    // Restaurant details - only name
                    Text(restaurant.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.darkGray)
                    
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
                                    print("📅 Change button pressed. Current scheduled date: \(controller.scheduledDate)")
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
    
    // Initialize with proper values based on selectedDate
    init(selectedDate: Binding<Date>, isScheduled: Binding<Bool>, onConfirm: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self._isScheduled = isScheduled
        self.onConfirm = onConfirm
        
        // Determine if the current selectedDate is today or tomorrow
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let selectedDay = calendar.startOfDay(for: selectedDate.wrappedValue)
        
        // Set initial values for selectedDay
        let isTomorrow = calendar.isDate(selectedDay, inSameDayAs: tomorrow)
        _selectedDay = State(initialValue: isTomorrow ? "Tomorrow" : "Today")
        
        // Set initial time value
        let hour = calendar.component(.hour, from: selectedDate.wrappedValue)
        let minute = calendar.component(.minute, from: selectedDate.wrappedValue)
        
        let isPM = hour >= 12
        let displayHour = isPM ? (hour > 12 ? hour - 12 : 12) : (hour == 0 ? 12 : hour)
        let timeString = String(format: "%d:%02d %@", displayHour, minute, isPM ? "PM" : "AM")
        
        // Find closest match in timeOptions
        if let matchingTime = timeOptions.first(where: { $0 == timeString }) {
            _selectedTime = State(initialValue: matchingTime)
        } else {
            // Find closest option
            for option in timeOptions {
                let optionHour = hourFromTimeString(option)
                if optionHour >= hour {
                    _selectedTime = State(initialValue: option)
                    break
                }
            }
        }
    }
    
    // Static helper to parse hour from time string used in init
    private static func hourFromTimeString(_ time: String) -> Int {
        let components = time.components(separatedBy: ":")
        if components.count > 0 {
            if let hourString = components.first, let hour = Int(hourString) {
                return time.contains("PM") && hour != 12 ? hour + 12 : hour
            }
        }
        return 0
    }
    
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
                    // Reset to "Now" option when dismissing with X button
                    isScheduled = false
                    // Reset scheduled date to default (1 hour from now)
                    selectedDate = Date().addingTimeInterval(3600)
                    print("📅 Dismissed schedule picker with X. Reset to 'Now' option.")
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
                            
                            // Update date based on selection and RESET the time to default for that day
                            let calendar = Calendar.current
                            
                            if day == "Today" {
                                // Reset to today with current time + 1 hour (or next available slot)
                                let now = Date()
                                let currentHour = calendar.component(.hour, from: now)
                                
                                // Create a date for today but preserve the selected time
                                var components = calendar.dateComponents([.year, .month, .day], from: now)
                                
                                // If before 11 AM, set to first time slot
                                if currentHour < 11 {
                                    // Set to first available time
                                    if !timeOptions.isEmpty {
                                        selectedTime = timeOptions[0]
                                        updateSelectedDate(with: timeOptions[0])
                                    }
                                }
                                // If after 6 PM, shouldn't be here (no options for today)
                                else if currentHour >= 18 {
                                    // Fallback to tomorrow's first slot
                                    selectedDay = "Tomorrow"
                                    selectedDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                                    if !timeOptions.isEmpty {
                                        selectedTime = timeOptions[0]
                                        updateSelectedDate(with: timeOptions[0])
                                    }
                                }
                                // Otherwise find appropriate time slot
                                else {
                                    let appropriateOptions = visibleTimeOptions
                                    if !appropriateOptions.isEmpty {
                                        selectedTime = appropriateOptions[0]
                                        // Create today's date with selected time
                                        updateSelectedDate(with: selectedTime)
                                    }
                                }
                            } else {
                                // For Tomorrow: Set to tomorrow with first available time slot
                                selectedDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                                if !timeOptions.isEmpty {
                                    selectedTime = timeOptions[0]
                                    updateSelectedDate(with: timeOptions[0])
                                }
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
            let now = Date()
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            
            // If current hour is after 6 PM, show no options for today
            if hour >= 18 {
                print("🕒 Current hour (\(hour)) is after 6 PM. No today options available")
                return []
            }
            
            // If current hour is before 11 AM, show all options
            if hour < 11 {
                print("🕒 Current hour (\(hour)) is before 11 AM. All options available")
                return timeOptions
            }
            
            // Otherwise show times that are at least 1 hour from now
            return timeOptions.filter { time in
                let timeHour = hourFromTimeString(time)
                
                // If the hour is more than current hour + 1, it's available
                if timeHour > hour + 1 {
                    return true
                }
                
                // If the hour is exactly current hour + 1, check minutes
                if timeHour == hour + 1 {
                    // Parse minutes from the time string
                    if let minuteStr = time.split(separator: ":").last?.split(separator: " ").first,
                       let timeMinute = Int(minuteStr) {
                        // Available if the minute in time option is greater than current minute
                        return timeMinute >= minute
                    }
                }
                
                return false
            }
        } else {
            // For tomorrow, show all allowed times (12 PM to 6 PM)
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
        
        // Get the appropriate date components based on selectedDay
        let now = Date()
        var baseDate: Date
        
        if selectedDay == "Today" {
            // Use today's date
            baseDate = now
        } else {
            // Use tomorrow's date
            baseDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        }
        
        // Get the year, month, and day from the appropriate base date
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        
        // Set the hour and minute from the time string
        components.hour = hour
        components.minute = minute
        
        // Create the final date
        if let date = calendar.date(from: components) {
            selectedDate = date
            print("📅 Date updated to: \(date)")
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
