import SwiftUI
import StoreKit

// Payment Header View Component
struct PaymentHeaderView: View {
    let amount: Double
    
    var body: some View {
        HStack {
            Text("Payment Details")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text("$\(String(format: "%.2f", amount))")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
        )
        .padding(.horizontal)
    }
}

// Order Summary View Component
struct OrderSummaryView: View {
    let request: PlaceOrderRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.headline)
            
            Text("Total Amount: ₹\(String(format: "%.2f", request.totalAmount))")
                .font(.title3)
                .bold()
            
            Text("Number of Items: \(request.items.count)")
                .font(.subheadline)
            
            Text("Order Type: \(request.orderType.displayName)")
                .font(.subheadline)
            
            // Items List
            VStack(alignment: .leading, spacing: 8) {
                Text("Items:")
                    .font(.subheadline)
                    .bold()
                
                ForEach(request.items, id: \.id) { item in
                    HStack {
                        Text(item.productName ?? "Unknown Item")
                        Spacer()
                        Text("x\(item.quantity)")
                        Text("₹\(String(format: "%.2f", item.price))")
                    }
                    .font(.subheadline)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// Payment Options View Component
struct PaymentOptionsView: View {
    let product: StoreKit.Product?
    let isProcessing: Bool
    let onPayment: (StoreKit.Product) async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Method")
                .font(.headline)
            
            if let product = product {
                Button(action: {
                    Task {
                        await onPayment(product)
                    }
                }) {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.title2)
                        Text("Pay with Apple Pay")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
            }
            
            // Test Payment Button (for development)
            #if DEBUG
            Button(action: {
                Task {
                    if let product = product {
                        await onPayment(product)
                    }
                }
            }) {
                Text("Simulate Payment (Test)")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(isProcessing)
            #endif
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// Define PaymentStatus enum with pending case
enum PaymentStatus: Equatable {
    case pending
    case success
    case failed(String)
    
    static func == (lhs: PaymentStatus, rhs: PaymentStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending):
            return true
        case (.success, .success):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// Main Payment View
struct PaymentView: View {
    @StateObject private var storeKitManager = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabSelection: TabSelection
    @ObservedObject var cartManager: OrderManager
    @State private var isMakingPayment = false
    @State private var paymentStatus: PaymentStatus = .pending
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedPaymentMethod = "Apple Pay"
    
    let orderRequest: PlaceOrderRequest
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var paymentSuccessful = false
    
    // Order result state
    @State private var orderId: String? = nil
    
    var restaurantName: String
    var totalAmount: Double
    var tipAmount: Double
    var isScheduledOrder: Bool
    var scheduledTime: Date?
    
    // Initializer to explicitly define parameter order
    init(cartManager: OrderManager, orderRequest: PlaceOrderRequest, restaurantName: String, totalAmount: Double, tipAmount: Double, isScheduledOrder: Bool, scheduledTime: Date? = nil) {
        self.cartManager = cartManager
        self.orderRequest = orderRequest
        self.restaurantName = restaurantName
        self.totalAmount = totalAmount
        self.tipAmount = tipAmount
        self.isScheduledOrder = isScheduledOrder
        self.scheduledTime = scheduledTime
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PaymentHeaderView(amount: totalAmount + tipAmount)
                    
                    // Order Summary
                    OrderSummaryView(request: orderRequest)
                        .padding(.horizontal)
                    
                    // Payment Options
                    if let product = storeKitManager.getProduct(byID: "com.queueskipper.orderpayment") {
                        PaymentOptionsView(
                            product: product,
                            isProcessing: isProcessing,
                            onPayment: { product in
                                Task {
                                    await processPayment(product: product)
                                }
                            }
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isProcessing || paymentSuccessful)
            .toolbar {
                if !isProcessing && !paymentSuccessful {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(AppColors.primaryGreen)
                        }
                    }
                }
            }
            
            if paymentStatus == .success {
                // Present the OrderSuccessView as a full screen overlay
                Color.white
                    .ignoresSafeArea()
                    .overlay(
                        OrderSuccessView(
                            cartManager: cartManager,
                            orderId: orderId
                        )
                        .environmentObject(tabSelection)
                    )
                    .transition(.opacity)
                    .animation(.easeInOut)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Payment Failed"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .task {
            print("🔄 PaymentView: View appeared, running StoreKit diagnostic")
            
            // Run debug diagnostics first
            await storeKitManager.debugStoreKitConfiguration()
            
            // Load products
            print("🔄 PaymentView: Loading store products...")
            await storeKitManager.loadStoreProducts()
            
            print("✅ PaymentView: Store products loaded: \(storeKitManager.availableProducts.count)")
            
            if storeKitManager.availableProducts.isEmpty {
                print("⚠️ PaymentView: WARNING - No products available! StoreKit purchase UI won't appear.")
                print("⚠️ PaymentView: Check your StoreKit configuration file and product IDs")
                
                // Set error to show to the user
                errorMessage = "No payment products available. Please try again later."
                showError = true
            } else {
                for product in storeKitManager.availableProducts {
                    print("📦 PaymentView: Available product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
                }
            }
        }
        .onAppear {
            hideTabBar()
            
            // Ensure the tab bar stays hidden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                hideTabBar()
            }
        }
        .onDisappear {
            showTabBar()
        }
    }
    
    private func processPayment(product: StoreKit.Product) async {
        isProcessing = true
        
        do {
            print("🔄 PaymentView: Starting payment process for product: \(product.id)")
            try await storeKitManager.processPayment(for: product)
            
            print("✅ PaymentView: Payment successful!")
            
            // Update payment status
            await MainActor.run {
                isProcessing = true // Keep processing while making API call
            }
            
            // After successful payment, submit the order to API
            let orderResult = await submitOrderToAPI()
            
            // Update UI based on API result
            await MainActor.run {
                if orderResult.success {
                    paymentStatus = .success
                    paymentSuccessful = true
                    
                    // Clear the cart
                    cartManager.clearCart()
                    
                    // Navigate to Orders tab after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        tabSelection.selectedTab = .orders
                    }
                } else {
                    alertMessage = orderResult.errorMessage ?? "Failed to place order"
                    showAlert = true
                }
                isProcessing = false
            }
            
        } catch StoreKitError.userCancelled {
            print("❌ PaymentView: Payment cancelled by user")
            await MainActor.run {
                isProcessing = false
            }
        } catch {
            print("❌ PaymentView: Payment failed: \(error.localizedDescription)")
            await MainActor.run {
                alertMessage = error.localizedDescription
                showAlert = true
                isProcessing = false
            }
        }
    }
    
    // Helper struct for order submission result
    private struct OrderSubmissionResult {
        let success: Bool
        let orderId: String?
        let errorMessage: String?
    }
    
    // Submit order to the appropriate API endpoint
    private func submitOrderToAPI() async -> OrderSubmissionResult {
        // Run network diagnostics before making API call
        await runNetworkDiagnostics()
        
        do {
            // Get current user ID from the app's user manager
            let userId = "67e027be2a5929b05bbcc97a" // Use your actual user ID from auth system
            
            // Format the price as a string
            let priceString = String(format: "%.0f", totalAmount + tipAmount)
            
            print("🔄 PaymentView: Preparing to send order to API")
            print("📝 Order details:")
            print("   - Restaurant ID: \(orderRequest.restaurantId ?? "unknown")")
            print("   - Items count: \(orderRequest.items.count)")
            print("   - Total price: \(priceString)")
            print("   - Is scheduled: \(isScheduledOrder)")
            
            // Create items array for the request
            let itemsArray = orderRequest.items.map { item -> [String: Any] in
                return [
                    "productId": item.productId ?? "",
                    "name": item.productName ?? "Unknown",
                    "quantity": item.quantity,
                    "price": Int(item.price)
                ]
            }
            
            // Base payload structure
            var jsonDict: [String: Any] = [
                "restaurantId": orderRequest.restaurantId ?? "6661a3534d1e0d993a73e66a",
                "userId": userId,
                "items": itemsArray,
                "price": priceString,
                "takeAway": true
            ]
            
            if isScheduledOrder, let scheduledTime = scheduledTime {
                // Format the date for API
                let dateFormatter = ISO8601DateFormatter()
                let scheduleDateString = dateFormatter.string(from: scheduledTime)
                
                print("📅 Scheduled order for: \(scheduleDateString)")
                print("   - Format validation: \(scheduleDateString.contains("T") && scheduleDateString.contains("Z")) - should contain T and Z")
                
                // Double-check ISO8601 format - should be like: 2025-04-01T14:30:00Z
                if !scheduleDateString.contains("T") || !scheduleDateString.contains("Z") {
                    print("⚠️ PaymentView: Warning - Date format might not be correct ISO8601 format with T and Z")
                    // Force correct format if needed
                    let backupFormatter = DateFormatter()
                    backupFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    backupFormatter.timeZone = TimeZone(abbreviation: "UTC")
                    let backupDateString = backupFormatter.string(from: scheduledTime)
                    print("📅 PaymentView: Using backup date format: \(backupDateString)")
                    
                    // Use the backup date format
                    jsonDict["scheduleDate"] = backupDateString
                } else {
                    // Use the original ISO8601 format
                    jsonDict["scheduleDate"] = scheduleDateString
                }
                
                // Log and validate
                let requestData = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
                if let jsonString = String(data: requestData, encoding: .utf8) {
                    print("📤 PaymentView: Scheduled order JSON payload:")
                    print(jsonString)
                    
                    // Verify scheduleDate is properly included in the JSON
                    if !jsonString.contains("\"scheduleDate\"") {
                        print("⚠️ PaymentView: WARNING - scheduleDate field missing in JSON!")
                    }
                }
                
                print("📤 PaymentView: Sending scheduled order to API")
                
                // Call the API with this payload
                let orderId = try await OrderAPIService.shared.placeScheduledOrder(jsonDict: jsonDict)
                
                print("✅ PaymentView: Scheduled order API call successful!")
                print("   - Order ID: \(orderId)")
                
                // Store order ID for display
                await MainActor.run {
                    self.orderId = orderId
                }
                
                return OrderSubmissionResult(success: true, orderId: orderId, errorMessage: nil)
                
            } else {
                // For immediate orders
                let requestData = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
                if let jsonString = String(data: requestData, encoding: .utf8) {
                    print("📤 PaymentView: Immediate order JSON payload:")
                    print(jsonString)
                }
                
                print("📤 PaymentView: Sending immediate order to API")
                
                // Call the API with this payload
                let orderId = try await OrderAPIService.shared.placeOrder(jsonDict: jsonDict)
                
                print("✅ PaymentView: Immediate order API call successful!")
                print("   - Order ID: \(orderId)")
                
                // Store order ID for display
                await MainActor.run {
                    self.orderId = orderId
                }
                
                return OrderSubmissionResult(success: true, orderId: orderId, errorMessage: nil)
            }
        } catch let error as OrderAPIError {
            print("❌ PaymentView: API Error: \(error.message)")
            
            // Check if we have response data we can recover from
            if case .invalidData(let responseData) = error,
               let responseString = String(data: responseData, encoding: .utf8) {
                
                let cleanedText = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                                              .replacingOccurrences(of: "\"", with: "")
                
                // If it looks like a MongoDB ObjectId (24 hex characters), treat as success
                if cleanedText.count == 24 && cleanedText.range(of: "^[0-9a-f]+$", options: .regularExpression) != nil {
                    print("✅ PaymentView: Found valid order ID in error response: \(cleanedText)")
                    
                    // Store order ID for display
                    await MainActor.run {
                        self.orderId = cleanedText
                    }
                    
                    return OrderSubmissionResult(success: true, orderId: cleanedText, errorMessage: nil)
                }
            }
            
            // Handle specific API errors
            switch error {
            case .timeout:
                print("⏱️ PaymentView: API request timed out")
                return OrderSubmissionResult(
                    success: false, 
                    orderId: nil, 
                    errorMessage: "Your order has been paid for but we couldn't confirm it with the restaurant. Please check your Orders page or contact support."
                )
            default:
                return OrderSubmissionResult(success: false, orderId: nil, errorMessage: error.message)
            }
        } catch {
            print("❌ PaymentView: Unexpected error submitting order: \(error.localizedDescription)")
            return OrderSubmissionResult(
                success: false, 
                orderId: nil, 
                errorMessage: "An unexpected error occurred. Your payment has been processed, but order confirmation failed. Please check your Orders page."
            )
        }
    }
    
    // Helper method to run network diagnostics
    private func runNetworkDiagnostics() async {
        print("🔬 PaymentView: Running network diagnostics before submitting order...")
        
        // Test API connectivity first
        let apiTest = await NetworkDiagnostics.shared.testAPIConnectivity()
        if !apiTest.isReachable {
            print("⚠️ PaymentView: API is not reachable! Error: \(apiTest.error?.localizedDescription ?? "Unknown")")
            print("⚠️ PaymentView: Will attempt to make the API call anyway, but it may fail")
        } else {
            print("✅ PaymentView: API is reachable (response time: \(String(format: "%.2f", apiTest.responseTime))s)")
            
            // If API is reachable, test the specific endpoint we'll be using
            let endpoint = isScheduledOrder ? "/schedule-order-placed" : "/order-placed"
            print("🔍 PaymentView: Testing endpoint: \(endpoint)")
            
            let url = URL(string: "https://qskipperbackend.onrender.com\(endpoint)")!
            var request = URLRequest(url: url)
            request.httpMethod = "OPTIONS"  // Use OPTIONS to check if endpoint exists without sending data
            request.timeoutInterval = 10
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    print("✅ PaymentView: Endpoint \(endpoint) is reachable (status: \(httpResponse.statusCode))")
                }
            } catch {
                print("⚠️ PaymentView: Endpoint test failed: \(error.localizedDescription)")
                print("⚠️ PaymentView: Will attempt to make the API call anyway")
            }
        }
    }
    
    // Function to hide tab bar
    private func hideTabBar() {
        // Update UITabBar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = UIColor.clear
        tabBarAppearance.shadowColor = UIColor.clear
        
        // Make all colors transparent
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .clear
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .clear
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
        
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
                        rootViewController.tabBar.isHidden = true
                        rootViewController.tabBar.isTranslucent = true
                        
                        // Move tab bar off-screen if hidden
                        if true {
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
                        tabBarController.tabBar.isHidden = true
                        tabBarController.tabBar.isTranslucent = true
                        
                        if true {
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

class PaymentViewModel: ObservableObject {
    @Published var paymentStatus: PaymentStatus?
    
    func processPayment() {
        // Here you would integrate with actual payment processing
        // For now, we'll simulate a successful payment
        simulateSuccessfulPayment()
    }
    
    func simulateSuccessfulPayment() {
        // Simulate payment processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.paymentStatus = .success
        }
    }
} 