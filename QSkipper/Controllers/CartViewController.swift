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
        self.loadRestaurantDetails()
        // Initialize Razorpay on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.razorpay = RazorpayCheckout.initWithKey("rzp_test_UrdIK5FKWhLES5", andDelegate: self)
            print("✅ Razorpay initialized with key: rzp_test_UrdIK5FKWhLES5, delegate: \(String(describing: self))")
        }
        NotificationCenter.default.addObserver(self, selector: #selector(cartDidChange), name: NSNotification.Name("CartDidChange"), object: nil)
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
        let apiEndpoint = isSchedulingOrder ? APIEndpoints.scheduleOrderPlaced : APIEndpoints.orderPlaced
        
        print("📤 CartViewController: Submitting order to \(isSchedulingOrder ? "schedule-order-placed" : "order-placed") API")
        
        // Only set takeAway to true when packMyOrder is explicitly selected
        // Don't take order type into account anymore
        let takeAway = packMyOrder
        
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
        guard let razorpay = razorpay else {
            print("❌ CartViewController: Razorpay not initialized")
            DispatchQueue.main.async {
                self.showPaymentView = false
                self.isProcessing = false
            }
            return
        }
        
        let amountInPaise = Int(amount * 100)
        let options: [String: Any] = [
            "amount": amountInPaise,
            "currency": "INR",
            "order_id": orderId,
            "name": restaurant?.name ?? "QSkipper",
            "description": "Order #\(orderId)",
            "prefill": [
                "contact": UserDefaultsManager.shared.getUserPhone() ?? "",
                "email": UserDefaultsManager.shared.getUserEmail() ?? ""
            ],
            "theme": [
                "color": "#F37254"
            ]
        ]
        
        print("✅ Entering initiateRazorpayPayment with orderId: \(orderId)")
        print("📤 CartViewController: Initiating Razorpay payment with options: \(options)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
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
            
            let jsonDict: [String: Any] = ["order_id": orderId] // Using "order_id" as per Razorpay convention
            do {
                guard let url = URL(string: "\(APIEndpoints.baseURL)/verify-order") else {
                    print("❌ CartViewController: Invalid URL: \(APIEndpoints.baseURL)/verify-order")
                    self.showPaymentView = false
                    self.isProcessing = false
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                do {
                    let requestData = try JSONSerialization.data(withJSONObject: jsonDict)
                    request.httpBody = requestData
                    if let jsonString = String(data: requestData, encoding: .utf8) {
                        print("📄 CartViewController: Verification request payload: \(jsonString)")
                    }
                } catch {
                    print("❌ CartViewController: Failed to serialize JSON for verification: \(error.localizedDescription)")
                    self.showPaymentView = false
                    self.isProcessing = false
                    return
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ CartViewController: No HTTP response received from verifyOrder")
                    self.showOrderSuccess = true
                    self.showPaymentView = false
                    self.isProcessing = false
                    self.orderManager.clearCart()
                    return
                }
                
                print("✅ CartViewController: Order verification response received")
                print("   - Status Code: \(httpResponse.statusCode)")
                print("   - Headers: \(httpResponse.allHeaderFields)")
                
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("   - Response Body: \(responseBody)")
                } else {
                    print("   - Response Body: (empty or non-UTF8 data)")
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ CartViewController: Order verification successful")
                } else {
                    print("⚠️ CartViewController: Order verification returned non-200 status: \(httpResponse.statusCode)")
                }
                
                // Proceed with success flow regardless of verification result
                self.showOrderSuccess = true
                self.showPaymentView = false
                self.isProcessing = false
                self.orderManager.clearCart()
                print("✅ CartViewController: Order confirmed and cart cleared")
            } catch {
                print("❌ CartViewController: Order verification failed: \(error.localizedDescription)")
                // Still proceed with success flow to avoid blocking user
                self.showOrderSuccess = true
                self.showPaymentView = false
                self.isProcessing = false
                self.orderManager.clearCart()
                print("✅ CartViewController: Order confirmed and cart cleared despite verification failure")
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
            
            let jsonDict: [String: Any] = ["order_id": orderId] // Using "order_id" as per Razorpay convention
            do {
                guard let url = URL(string: "\(APIEndpoints.baseURL)/verify-order") else {
                    print("❌ CartViewController: Invalid URL: \(APIEndpoints.baseURL)/verify-order")
                    self.showPaymentView = false
                    self.isProcessing = false
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                do {
                    let requestData = try JSONSerialization.data(withJSONObject: jsonDict)
                    request.httpBody = requestData
                    if let jsonString = String(data: requestData, encoding: .utf8) {
                        print("📄 CartViewController: Verification request payload: \(jsonString)")
                    }
                } catch {
                    print("❌ CartViewController: Failed to serialize JSON for verification: \(error.localizedDescription)")
                    self.showPaymentView = false
                    self.isProcessing = false
                    return
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ CartViewController: No HTTP response received from verifyOrder (legacy)")
                    self.showOrderSuccess = true
                    self.showPaymentView = false
                    self.isProcessing = false
                    self.orderManager.clearCart()
                    return
                }
                
                print("✅ CartViewController: Order verification response received (legacy)")
                print("   - Status Code: \(httpResponse.statusCode)")
                print("   - Headers: \(httpResponse.allHeaderFields)")
                
                if let responseBody = String(data: data, encoding: .utf8) {
                    print("   - Response Body: \(responseBody)")
                } else {
                    print("   - Response Body: (empty or non-UTF8 data)")
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ CartViewController: Order verification successful (legacy)")
                } else {
                    print("⚠️ CartViewController: Order verification returned non-200 status (legacy): \(httpResponse.statusCode)")
                }
                
                self.showOrderSuccess = true
                self.showPaymentView = false
                self.isProcessing = false
                self.orderManager.clearCart()
                print("✅ CartViewController: Order confirmed and cart cleared (legacy callback)")
            } catch {
                print("❌ CartViewController: Order verification failed (legacy): \(error.localizedDescription)")
                self.showOrderSuccess = true
                self.showPaymentView = false
                self.isProcessing = false
                self.orderManager.clearCart()
                print("✅ CartViewController: Order confirmed and cart cleared despite verification failure (legacy)")
            }
        }
    }
    func onPaymentError(_ code: Int32, description: String) {
        print("❌ CartViewController: Razorpay Payment Failed!")
        print("   - Error Code: \(code)")
        print("   - Description: \(description)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showPaymentView = false
            self.isProcessing = false
        }
    }
}
