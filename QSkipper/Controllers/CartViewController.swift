import Foundation
import SwiftUI
import Razorpay

class CartViewController: ObservableObject, RazorpayPaymentCompletionProtocol {
    // Strong reference to ensure delegate retention
    private weak var razorpayWeak: RazorpayCheckout?
    private let orderManager: OrderManager
    private var razorpay: RazorpayCheckout? {
        didSet {
            razorpayWeak = razorpay
            print("🔄 Razorpay instance updated, delegate: \(String(describing: self))")
        }
    }
    @Published var isProcessing = false
    @Published var showOrderSuccess = false
    @Published var showOrderFail = false
    @Published var showPaymentView = false
    @Published var isSchedulingOrder = false
    @Published var scheduledDate = Date().addingTimeInterval(3600)
    @Published var showSchedulePicker = false
    @Published var selectedTipAmount: Int = 18
    @Published var currentOrderRequest: PlaceOrderRequest?
    @Published var orderId: String?
    @Published var packMyOrder: Bool = false
    let tipOptions = [12, 18, 25]
    @Published var restaurant: Restaurant?
    
    init(orderManager: OrderManager = OrderManager.shared) {
        self.orderManager = orderManager
        
        // First set up non-UI properties
        NotificationCenter.default.addObserver(self, selector: #selector(cartDidChange), name: NSNotification.Name("CartDidChange"), object: nil)
        
        // Then initialize UI properties
        ThreadUtility.ensureMainThread { [self] in
            self.loadRestaurantDetails()
            // Initialize Razorpay on the main thread
            self.razorpay = RazorpayCheckout.initWithKey("rzp_test_UrdIK5FKWhLES5", andDelegate: self)
            print("✅ Razorpay initialized with key: rzp_test_UrdIK5FKWhLES5, delegate: \(String(describing: self))")
        }
    }
    
    deinit {
        print("🗑️ CartViewController deallocated")
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func cartDidChange() {
        loadRestaurantDetails()
    }
    
    func loadRestaurantDetails() {
        if !orderManager.currentCart.isEmpty, let firstProduct = orderManager.currentCart.first {
            let restaurantId = firstProduct.product.restaurantId
            self.restaurant = RestaurantManager.shared.getRestaurant(by: restaurantId)
            
            if self.restaurant == nil {
                print("Restaurant not found in RestaurantManager for ID: \(restaurantId), attempting to fetch")
                if RestaurantManager.shared.restaurants.isEmpty {
                    Task {
                        try? await RestaurantManager.shared.fetchAllRestaurants()
                        await MainActor.run {
                            self.restaurant = RestaurantManager.shared.getRestaurant(by: restaurantId)
                            if self.restaurant == nil {
                                print("Still could not find restaurant, creating default")
                                self.restaurant = Restaurant(
                                    id: restaurantId,
                                    name: "Restaurant",
                                    estimatedTime: "30-40",
                                    cuisine: nil,
                                    photoId: nil,
                                    rating: 4.0,
                                    location: "Campus Area"
                                )
                            } else {
                                print("Found restaurant after fetching: \(String(describing: self.restaurant?.name))")
                            }
                        }
                    }
                } else {
                    print("Creating default restaurant for ID: \(restaurantId)")
                    self.restaurant = Restaurant(
                        id: restaurantId,
                        name: "Restaurant",
                        estimatedTime: "30-40",
                        cuisine: nil,
                        photoId: nil,
                        rating: 4.0,
                        location: "Campus Area"
                    )
                }
            } else {
                print("Restaurant found: \(String(describing: self.restaurant?.name))")
            }
        } else {
            print("Cart is empty or no products found")
        }
    }
    
    func placeOrder() {
        Task { @MainActor in
            print("🔄 CartViewController: Starting place order process...")
            self.isProcessing = true
            
            guard let userId = UserDefaultsManager.shared.getUserId() else {
                print("❌ CartViewController: Failed to get user ID for order")
                print("📱 Current UserDefaults state:")
                print("   - User ID: \(UserDefaultsManager.shared.getUserId() ?? "nil")")
                print("   - User Email: \(UserDefaultsManager.shared.getUserEmail() ?? "nil")")
                print("   - User Name: \(UserDefaultsManager.shared.getUserName() ?? "nil")")
                print("   - Is Logged In: \(UserDefaultsManager.shared.isUserLoggedIn())")
                self.isProcessing = false
                return
            }
            print("✅ CartViewController: User ID found: \(userId)")
            
            guard let firstItem = orderManager.currentCart.first else {
                print("❌ CartViewController: Error: Cart is empty")
                self.isProcessing = false
                return
            }
            
            let restaurantId = firstItem.product.restaurantId
            print("✅ CartViewController: Restaurant ID from first item: \(restaurantId)")
            
            let orderRequest = PlaceOrderRequest(
                userId: userId,
                restaurantId: restaurantId,
                items: orderManager.currentCart.map { cartItem in
                    OrderItem(
                        productId: cartItem.productId,
                        quantity: cartItem.quantity,
                        price: cartItem.product.price,
                        productName: cartItem.product.name
                    )
                },
                totalAmount: getTotalAmount(),
                orderType: orderManager.selectedOrderType,
                scheduledTime: isSchedulingOrder ? scheduledDate : nil,
                specialInstructions: nil
            )
            
            print("📤 CartViewController: Order Request Details:")
            print("   - User ID: \(orderRequest.userId)")
            print("   - Restaurant ID: \(orderRequest.restaurantId)")
            print("   - Total Amount: \(orderRequest.totalAmount)")
            print("   - Number of Items: \(orderRequest.items.count)")
            print("   - Order Type: \(orderRequest.orderType)")
            if let scheduledTime = orderRequest.scheduledTime {
                print("   - Scheduled Time: \(scheduledTime)")
            }
            
            self.currentOrderRequest = orderRequest
            print("✅ CartViewController: Order request set")
            
            do {
                try await submitOrderToAPI(orderRequest: orderRequest)
            } catch {
                print("❌ CartViewController: Order submission failed: \(error.localizedDescription)")
                self.isProcessing = false
            }
        }
    }
    
    private func submitOrderToAPI(orderRequest: PlaceOrderRequest) async throws {
        let priceString = String(format: "%.0f", getTotalAmount())
        let apiEndpoint = isSchedulingOrder ? "/schedule-order-placed" : "/order-placed"
        
        print("📤 CartViewController: Submitting order to \(isSchedulingOrder ? "schedule-order-placed" : "order-placed") API")
        
        // Set takeAway value based on conditions
        let takeAway: Bool
        if isSchedulingOrder {
            // Backend requires scheduled orders to have takeAway=true
            takeAway = true
            print("📝 CartViewController: Setting takeAway to true for scheduled orders (backend requirement)")
        } else {
            // For regular orders, use the packMyOrder value
            takeAway = packMyOrder
            print("📝 CartViewController: Setting takeAway to: \(takeAway) (type: Bool)")
        }
        
        var jsonDict: [String: Any] = [
            "restaurantId": orderRequest.restaurantId,
            "userId": orderRequest.userId,
            "items": orderRequest.items.map { item in
                [
                    "productId": item.productId,
                    "name": item.productName ?? "Unknown",
                    "quantity": item.quantity,
                    "price": Int(item.price)
                ]
            },
            "price": priceString,
            "takeAway": takeAway
        ]
        
        if isSchedulingOrder {
            let dateFormatter = ISO8601DateFormatter()
            let scheduleDateString = dateFormatter.string(from: scheduledDate)
            jsonDict["scheduleDate"] = scheduleDateString
        }
        
        let requestData = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
        if let jsonString = String(data: requestData, encoding: .utf8) {
            print("📄 CartViewController: Request payload:")
            print(jsonString)
        }
        
        do {
            let orderId: String
            if isSchedulingOrder {
                orderId = try await OrderAPIService.shared.placeScheduledOrder(jsonDict: jsonDict)
            } else {
                orderId = try await OrderAPIService.shared.placeOrder(jsonDict: jsonDict)
            }
            
            print("✅ CartViewController: Order API call successful!")
            print("   - Order ID: \(orderId)")
            
            await MainActor.run {
                self.orderId = orderId
                self.showPaymentView = true
                self.initiateRazorpayPayment(orderId: orderId, amount: getTotalAmount())
            }
        } catch {
            print("❌ CartViewController: Order API Error: \(error.localizedDescription)")
            await MainActor.run {
                self.isProcessing = false
            }
            throw error
        }
    }
    
    func initiateRazorpayPayment(orderId: String, amount: Double) {
        print("✅ Entering initiateRazorpayPayment with orderId: \(orderId)")
        
        ThreadUtility.ensureMainThread { [weak self] in
            guard let self = self, let razorpay = self.razorpay else {
                print("❌ CartViewController: Razorpay not initialized")
                self?.showPaymentView = false
                self?.isProcessing = false
                
                // Show payment failed view if Razorpay can't initialize
                self?.showOrderFail = true
                return
            }
            
            let amountInPaise = Int(amount * 100)
            let options: [String: Any] = [
                "amount": amountInPaise,
                "currency": "INR",
                "order_id": orderId,
                "name": self.restaurant?.name ?? "QSkipper",
                "description": "Order #\(orderId)",
                "prefill": [
                    "contact": UserDefaultsManager.shared.getUserPhone() ?? "",
                    "email": UserDefaultsManager.shared.getUserEmail() ?? ""
                ],
                "theme": [
                    "color": "#F37254"
                ],
                // Handle cancellation by setting these options
                "modal": [
                    "escape": false,
                    "confirm_close": true
                ]
            ]
            
            print("📤 CartViewController: Initiating Razorpay payment with options: \(options)")
            razorpay.open(options)
            print("✅ Razorpay payment popup opened")
        }
    }
    
    func getConvenienceFee() -> Double {
        return orderManager.getCartTotal() * 0.04
    }
    
    func getTotalAmount() -> Double {
        return orderManager.getCartTotal() * (1 + 0.04)
    }
    
    // MARK: - Razorpay Payment Completion Protocol

    func onPaymentSuccess(_ paymentId: String, andData data: [String: Any]) {
        print("✅ CartViewController: Razorpay Payment Success!")
        print("   - Payment ID: \(paymentId)")
        print("   - Full Payment Data: \(data)")
        
        Task { @MainActor in
            // Verify order with backend
            guard let orderId = self.orderId else {
                print("❌ CartViewController: No orderId available for verification")
                self.showPaymentView = false
                self.isProcessing = false
                return
            }
            
            print("📝 CartViewController: Starting order verification for orderId: \(orderId)")
            
            do {
                // Use the APIClient's verifyOrder method which has built-in retries and fallback
                _ = try await APIClient.shared.verifyOrder(orderId: orderId)
                print("✅ CartViewController: Order verification successful")
            } catch {
                print("⚠️ CartViewController: Order verification failed: \(error.localizedDescription)")
                // Continue with order success despite verification failure
                // The payment was successful even if verification failed
            }
            
            // Always proceed with success flow 
            ThreadUtility.ensureMainThread { [weak self] in
                guard let self = self else { return }
                self.showOrderSuccess = true
                self.showPaymentView = false
                self.isProcessing = false
                self.orderManager.clearCart()
                
                // Dispatch to ensure tab bar has time to update after order success UI appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Make sure tab bar shows up for navigation
                    Task { @MainActor in
                        if let tabBarController = UIApplication.keyWindow?.rootViewController as? UITabBarController {
                            tabBarController.tabBar.isHidden = false
                        }
                    }
                }
                
                print("✅ CartViewController: Order confirmed and cart cleared")
            }
        }
    }

    func onPaymentSuccess(_ paymentId: String) {
        print("⚠️ CartViewController: Legacy onPaymentSuccess called with payment_id: \(paymentId)")
        
        Task { @MainActor in
            guard let orderId = self.orderId else {
                print("❌ CartViewController: No orderId available for verification (legacy)")
                self.showPaymentView = false
                self.isProcessing = false
                return
            }
            
            print("📝 CartViewController: Starting order verification for orderId: \(orderId) (legacy)")
            
            do {
                // Use the APIClient's verifyOrder method which has built-in retries and fallback
                _ = try await APIClient.shared.verifyOrder(orderId: orderId)
                print("✅ CartViewController: Order verification successful (legacy)")
            } catch {
                print("⚠️ CartViewController: Order verification failed (legacy): \(error.localizedDescription)")
                // Continue with order success despite verification failure
                // The payment was successful even if verification failed
            }
            
            // Always proceed with success flow
            ThreadUtility.ensureMainThread { [weak self] in
                guard let self = self else { return }
                self.showOrderSuccess = true
                self.showPaymentView = false
                self.isProcessing = false
                self.orderManager.clearCart()
                
                // Dispatch to ensure tab bar has time to update after order success UI appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Make sure tab bar shows up for navigation
                    Task { @MainActor in
                        if let tabBarController = UIApplication.keyWindow?.rootViewController as? UITabBarController {
                            tabBarController.tabBar.isHidden = false
                        }
                    }
                }
                
                print("✅ CartViewController: Order confirmed and cart cleared (legacy callback)")
            }
        }
    }
    
    func onPaymentError(_ code: Int32, description: String) {
        print("❌ CartViewController: Razorpay Payment Failed!")
        print("   - Error Code: \(code)")
        print("   - Description: \(description)")
        
        // Check if we have an orderId, need to cancel the order on backend
        if let orderId = self.orderId {
            print("🔄 CartViewController: Attempting to cancel order \(orderId) after payment failure")
            
            // Attempt to cancel the order in the backend
            Task {
                do {
                    // Try to cancel the order, but don't block the UI flow
                    // This is a best effort to clean up the backend
                    try await APIClient.shared.cancelOrder(orderId: orderId)
                    print("✅ CartViewController: Order \(orderId) cancelled successfully after payment failure")
                } catch {
                    // Even if this fails, we still want to show the failure UI
                    print("⚠️ CartViewController: Failed to cancel order after payment failure: \(error.localizedDescription)")
                }
                
                // Show the failure UI regardless of backend cancellation result
                await MainActor.run {
                    self.showPaymentView = false
                    self.isProcessing = false
                    self.showOrderFail = true
                    
                    // Dispatch to ensure tab bar has time to update after order fail UI appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Make sure tab bar shows up for navigation
                        Task { @MainActor in
                            if let tabBarController = UIApplication.keyWindow?.rootViewController as? UITabBarController {
                                tabBarController.tabBar.isHidden = false
                            }
                        }
                    }
                    
                    print("⚠️ CartViewController: Setting showOrderFail to true")
                }
            }
        } else {
            // If no orderId, just update UI immediately
            ThreadUtility.ensureMainThread { [weak self] in
                guard let self = self else { return }
                self.showPaymentView = false
                self.isProcessing = false
                self.showOrderFail = true
                
                // Dispatch to ensure tab bar has time to update after order fail UI appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Make sure tab bar shows up for navigation
                    Task { @MainActor in
                        if let tabBarController = UIApplication.keyWindow?.rootViewController as? UITabBarController {
                            tabBarController.tabBar.isHidden = false
                        }
                    }
                }
                
                print("⚠️ CartViewController: Setting showOrderFail to true (no orderId to cancel)")
            }
        }
    }
}
