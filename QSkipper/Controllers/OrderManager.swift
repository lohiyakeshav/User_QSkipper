//
//  OrderManager.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import Foundation
import SwiftUI
import Combine

// CartItem represents a product in the cart with its quantity
struct CartItem: Identifiable, Codable {
    let id = UUID()
    let productId: String
    let product: Product
    var quantity: Int
    
    // Total price for this cart item (quantity * product price)
    var totalPrice: Double {
        return Double(quantity) * product.price
    }
}

class OrderManager: ObservableObject {
    static let shared = OrderManager()
    
    private let networkManager = SimpleNetworkManager.shared
    private let networkUtils = NetworkUtils.shared
    private let userDefaultsManager = UserDefaultsManager.shared
    
    @Published var currentCart: [CartItem] = []
    @Published var currentRestaurantId: String? = nil
    @Published var orders: [Order] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    // Order configuration
    @Published var selectedOrderType: OrderType = .takeaway
    @Published var isScheduledOrder: Bool = false
    @Published var scheduledDate: Date = Date()
    @Published var specialInstructions: String = ""
    
    // Persistent cart key for UserDefaults
    private let cartKey = "current_cart"
    
    private init() {
        loadCart()
    }
    
    // MARK: - Cart Methods
    
    // Toggle order type between dine-in and takeaway
    func toggleOrderType() {
        selectedOrderType = selectedOrderType == .dineIn ? .takeaway : .dineIn
    }
    
    // Set scheduled time for order
    func setScheduledTime(date: Date) {
        scheduledDate = date
        isScheduledOrder = true
    }
    
    // Set order for immediate pickup/dine-in
    func setImmediateOrder() {
        isScheduledOrder = false
    }
    
    // Add item to cart
    func addToCart(product: Product, quantity: Int = 1) {
        // Check if we already have items from a different restaurant
        if let currentRestaurantId = currentRestaurantId, currentRestaurantId != product.restaurantId {
            // Clear cart if we're adding from a different restaurant
            clearCart()
        }
        
        // Set current restaurant
        self.currentRestaurantId = product.restaurantId
        
        // Check if the product is already in the cart
        if let index = currentCart.firstIndex(where: { $0.productId == product.id }) {
            // Update quantity
            currentCart[index].quantity += quantity
        } else {
            // Add new item
            let newItem = CartItem(productId: product.id, product: product, quantity: quantity)
            currentCart.append(newItem)
        }
        
        saveCart()
    }
    
    // Remove item from cart
    func removeFromCart(productId: String) {
        currentCart.removeAll { $0.productId == productId }
        
        // Reset restaurant ID if cart is empty
        if currentCart.isEmpty {
            currentRestaurantId = nil
        }
        
        saveCart()
    }
    
    // Update quantity of item in cart
    func updateCartItemQuantity(productId: String, quantity: Int) {
        if let index = currentCart.firstIndex(where: { $0.productId == productId }) {
            if quantity <= 0 {
                // Remove item if quantity is zero or negative
                currentCart.remove(at: index)
            } else {
                // Update quantity
                currentCart[index].quantity = quantity
            }
            saveCart()
        }
    }
    
    // Increment quantity of item at index
    func incrementItem(at index: Int) {
        guard index < currentCart.count else { return }
        currentCart[index].quantity += 1
        saveCart()
    }
    
    // Decrement quantity of item at index
    func decrementItem(at index: Int) {
        guard index < currentCart.count else { return }
        if currentCart[index].quantity > 1 {
            currentCart[index].quantity -= 1
        } else {
            // Remove item if quantity would be zero
            currentCart.remove(at: index)
        }
        saveCart()
    }
    
    // Clear cart
    func clearCart() {
        currentCart.removeAll()
        currentRestaurantId = nil
        specialInstructions = ""
        isScheduledOrder = false
        scheduledDate = Date()
        saveCart()
    }
    
    // Calculate total amount
    func getTotalAmount() -> Double {
        return currentCart.reduce(0) { $0 + ($1.totalPrice) }
    }
    
    // Get total number of items in cart (sum of quantities)
    func getTotalItems() -> Int {
        return currentCart.reduce(0) { $0 + $1.quantity }
    }
    
    // Get total price of all items in cart
    func getTotalPrice() -> Double {
        return currentCart.reduce(0) { $0 + $1.totalPrice }
    }
    
    // Get cart total - alias for getTotalPrice for better readability
    func getCartTotal() -> Double {
        return getTotalPrice()
    }
    
    // Get quantity of a product in cart
    func getQuantityInCart(productId: String) -> Int {
        if let item = currentCart.first(where: { $0.productId == productId }) {
            return item.quantity
        }
        return 0
    }
    
    // Save cart to UserDefaults
    private func saveCart() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(currentCart)
            UserDefaults.standard.set(data, forKey: cartKey)
        } catch {
            print("Error saving cart: \(error)")
        }
    }
    
    // Load cart from UserDefaults
    private func loadCart() {
        guard let data = UserDefaults.standard.data(forKey: cartKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            currentCart = try decoder.decode([CartItem].self, from: data)
        } catch {
            print("Error loading cart: \(error)")
        }
    }
    
    // MARK: - Order Methods
    
    // Place order
    func placeOrder() async throws -> Order? {
        guard let userId = userDefaultsManager.getUserId(), let restaurantId = currentRestaurantId else {
            error = "User not logged in or no restaurant selected"
            return nil
        }
        
        guard !currentCart.isEmpty else {
            error = "Cart is empty"
            return nil
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let scheduledTime = isScheduledOrder ? scheduledDate : nil
            let orderRequest = PlaceOrderRequest(
                userId: userId,
                restaurantId: restaurantId,
                items: currentCart.map { cartItem -> OrderItem in
                    return OrderItem(
                        productId: cartItem.productId,
                        quantity: cartItem.quantity,
                        price: cartItem.product.price,
                        productName: cartItem.product.name
                    )
                },
                totalAmount: getTotalAmount(),
                orderType: selectedOrderType,
                scheduledTime: scheduledTime,
                specialInstructions: specialInstructions.isEmpty ? nil : specialInstructions
            )
            
            let jsonData = try JSONEncoder().encode(orderRequest)
            
            let response: OrderResponse = try await networkManager.makeRequest(
                url: APIEndpoints.orderPlaced,
                method: "POST",
                body: jsonData
            )
            
            if response.status == "success", let order = response.order {
                // Clear cart after successful order
                await MainActor.run {
                    self.clearCart()
                    // Add order to order history
                    self.orders.append(order)
                }
                
                return order
            } else {
                await MainActor.run {
                    self.error = response.message
                }
                return nil
            }
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw error
        }
    }
    
    // Get order status
    func getOrderStatus(orderId: String) async throws -> OrderStatus? {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let response: OrderStatusResponse = try await networkManager.makeRequest(
                url: APIEndpoints.getOrderStatus(oid: orderId)
            )
            
            if response.status == "success", let orderStatus = response.orderStatus {
                // Update order status in local orders list
                if let index = orders.firstIndex(where: { $0.id == orderId }) {
                    var updatedOrder = orders[index]
                    DispatchQueue.main.async {
                        self.orders[index] = updatedOrder
                    }
                }
                
                return orderStatus
            } else {
                error = response.message
                return nil
            }
            
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // Get user orders
    func getUserOrders() async throws -> [Order] {
        guard let userId = userDefaultsManager.getUserId() else {
            error = "User not logged in"
            return []
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let response: OrdersResponse = try await networkManager.makeRequest(
                url: APIEndpoints.getUserOrders(uid: userId)
            )
            
            if response.status == "success", let orders = response.orders {
                await MainActor.run {
                    self.orders = orders.sorted { $0.createdAt > $1.createdAt }
                }
                return orders
            } else {
                await MainActor.run {
                    self.error = response.message
                }
                return []
            }
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw error
        }
    }
    
    // Get order by ID
    func getOrder(by id: String) -> Order? {
        return orders.first { $0.id == id }
    }
} 