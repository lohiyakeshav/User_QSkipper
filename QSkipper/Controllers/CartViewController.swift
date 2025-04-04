//
//  CartViewController.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 30/03/25.
//

import Foundation
import SwiftUI
import StoreKit

// Controller for handling cart view logic
class CartViewController: ObservableObject {
    private let orderManager: OrderManager
    @Published var isProcessing = false
    
    @Published var showOrderSuccess = false
    @Published var showPaymentConfirmation = false
    @Published var isSchedulingOrder = false
    @Published var scheduledDate = Date().addingTimeInterval(3600) // Default to 1 hour from now
    @Published var showSchedulePicker = false
    @Published var selectedTipAmount: Int = 18
    @Published var showPaymentView = false
    @Published var currentOrderRequest: PlaceOrderRequest?
    @Published var orderId: String? = nil
    let tipOptions = [12, 18, 25]
    
    @Published var restaurant: Restaurant?
    
    init(orderManager: OrderManager = OrderManager.shared) {
        self.orderManager = orderManager
        self.loadRestaurantDetails()
        
        // Observe cart changes to update restaurant details
        NotificationCenter.default.addObserver(self, selector: #selector(cartDidChange), name: NSNotification.Name("CartDidChange"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func cartDidChange() {
        loadRestaurantDetails()
    }
    
    // Load restaurant details for current cart items
    func loadRestaurantDetails() {
        if !orderManager.currentCart.isEmpty, let firstProduct = orderManager.currentCart.first {
            let restaurantId = firstProduct.product.restaurantId
            
            // Get restaurant from RestaurantManager
            self.restaurant = RestaurantManager.shared.getRestaurant(by: restaurantId)
            
            // If no restaurant found from manager, try to fetch it or create a default
            if self.restaurant == nil {
                print("Restaurant not found in RestaurantManager for ID: \(restaurantId), attempting to fetch")
                
                // Try to fetch restaurant data if RestaurantManager doesn't have it yet
                if RestaurantManager.shared.restaurants.isEmpty {
                    Task {
                        try? await RestaurantManager.shared.fetchAllRestaurants()
                        
                        // Try one more time after fetching
                        await MainActor.run {
                            self.restaurant = RestaurantManager.shared.getRestaurant(by: restaurantId)
                            
                            // If still not found, create a default
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
                    // Create a default restaurant
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
    
    // Process order payment
    func placeOrder() {
        Task { @MainActor in
            print("🔄 CartViewController: Starting place order process...")
            self.isProcessing = true
            
            // Get user ID using UserDefaultsManager
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
            
            // Get restaurant ID from first cart item
            guard let firstItem = orderManager.currentCart.first else {
                print("❌ CartViewController: Error: Cart is empty")
                self.isProcessing = false
                return
            }
            
            let restaurantId = firstItem.product.restaurantId
            print("✅ CartViewController: Restaurant ID from first item: \(restaurantId)")
            
            // Create order request
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
            
            // Log request details
            print("📤 CartViewController: Order Request Details:")
            print("   - User ID: \(orderRequest.userId)")
            print("   - Restaurant ID: \(orderRequest.restaurantId)")
            print("   - Total Amount: \(orderRequest.totalAmount)")
            print("   - Number of Items: \(orderRequest.items.count)")
            print("   - Order Type: \(orderRequest.orderType)")
            if let scheduledTime = orderRequest.scheduledTime {
                print("   - Scheduled Time: \(scheduledTime)")
            }
            
            // Save the order request
            self.currentOrderRequest = orderRequest
            print("✅ CartViewController: Order request set")
            
            // Process with StoreKit directly
            // Use the order payment product which should be configured as a consumable
            if let orderProduct = StoreKitManager.shared.getProduct(byID: "com.qskipper.orderpayment") {
                print("✅ CartViewController: Found StoreKit product for payment")
                
                do {
                    print("🔄 CartViewController: Initiating StoreKit purchase...")
                    try await StoreKitManager.shared.processPayment(for: orderProduct)
                    
                    print("✅ CartViewController: Payment successful!")
                    
                    do {
                        // Submit the order to the appropriate API endpoint
                        try await submitOrderToAPI(orderRequest: orderRequest)
                        
                        // Success is already handled in submitOrderToAPI
                    } catch let apiError as OrderAPIError {
                        print("❌ CartViewController: Order API error: \(apiError.message)")
                        
                        // Check if we have response data we can recover from
                        if case .invalidData(let responseData) = apiError,
                           let responseString = String(data: responseData, encoding: .utf8) {
                            
                            let cleanedText = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                                                          .replacingOccurrences(of: "\"", with: "")
                            
                            // If it looks like a MongoDB ObjectId (24 hex characters), treat as success
                            if cleanedText.count == 24 && cleanedText.range(of: "^[0-9a-f]+$", options: .regularExpression) != nil {
                                print("✅ CartViewController: Found valid order ID in error response: \(cleanedText)")
                                
                                // Show success message
                                self.orderId = cleanedText
                                showOrderSuccess = true
                                isProcessing = false
                                
                                // Clear the cart
                                orderManager.clearCart()
                                return
                            }
                        }
                        
                        // If we couldn't recover, show error
                        isProcessing = false
                    } catch {
                        print("❌ CartViewController: Order submission failed: \(error.localizedDescription)")
                        isProcessing = false
                    }
                } catch StoreKitError.userCancelled {
                    print("❌ CartViewController: Payment cancelled by user")
                    isProcessing = false
                } catch {
                    print("❌ CartViewController: Payment failed: \(error.localizedDescription)")
                    isProcessing = false
                }
            } else {
                print("❌ CartViewController: StoreKit product not found")
                isProcessing = false
                showPaymentView = true // Fallback to the original flow
            }
        }
    }
    
    // Submit order to the appropriate API endpoint
    private func submitOrderToAPI(orderRequest: PlaceOrderRequest) async throws {
        let networkManager = SimpleNetworkManager.shared
        
        // Format the price as a string
        let priceString = String(format: "%.0f", getTotalAmount())
        
        // Determine which API endpoint to use based on scheduling
        let apiEndpoint = isSchedulingOrder ? 
            APIEndpoints.scheduleOrderPlaced : 
            APIEndpoints.orderPlaced
        
        print("📤 CartViewController: Submitting order to \(isSchedulingOrder ? "schedule-order-placed" : "order-placed") API")
        
        // Create the correct payload structure based on order type
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
            "takeAway": true
        ]
        
        // Add scheduleDate only for scheduled orders
        if isSchedulingOrder {
            let dateFormatter = ISO8601DateFormatter()
            let scheduleDateString = dateFormatter.string(from: scheduledDate)
            jsonDict["scheduleDate"] = scheduleDateString
        }
        
        // Convert dictionary to JSON data
        let requestData = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
        
        // Print the request for debugging
        if let jsonString = String(data: requestData, encoding: .utf8) {
            print("📄 CartViewController: Request payload:")
            print(jsonString)
        }
        
        do {
            // Use OrderAPIService to submit the order
            let orderId: String
            if isSchedulingOrder {
                orderId = try await OrderAPIService.shared.placeScheduledOrder(jsonDict: jsonDict)
            } else {
                orderId = try await OrderAPIService.shared.placeOrder(jsonDict: jsonDict)
            }
            
            print("✅ CartViewController: Order API call successful!")
            print("   - Order ID: \(orderId)")
            
            // Show success message
            await MainActor.run {
                self.orderId = orderId
                showOrderSuccess = true
                isProcessing = false
                
                // Clear the cart
                orderManager.clearCart()
            }
            
            // If we reach here, the order was successful
            return
        } catch {
            print("❌ CartViewController: Order API Error: \(error.localizedDescription)")
            
            // If the API returns a 200 status code with an order ID but we failed to parse it,
            // we should still treat it as a success
            if let responseData = (error as NSError).userInfo["responseData"] as? Data,
               let responseString = String(data: responseData, encoding: .utf8) {
                
                let cleanedText = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                                               .replacingOccurrences(of: "\"", with: "")
                
                // If it looks like a MongoDB ObjectId (24 hex characters), treat as success
                if cleanedText.count == 24 && cleanedText.range(of: "^[0-9a-f]+$", options: .regularExpression) != nil {
                    print("✅ CartViewController: Found valid order ID in error response: \(cleanedText)")
                    
                    await MainActor.run {
                        self.orderId = cleanedText
                        showOrderSuccess = true
                        isProcessing = false
                        
                        // Clear the cart
                        orderManager.clearCart()
                    }
                    
                    return
                }
            }
            
            // Re-throw the error if we couldn't recover
            throw error
        }
    }
    
    // Calculate convenience fee (4% of cart total)
    func getConvenienceFee() -> Double {
        return orderManager.getCartTotal() * 0.04
    }
    
    // Calculate total amount to pay with all fees
    func getTotalAmount() -> Double {
        return orderManager.getCartTotal() * (1 + 0.04)
    }
} 