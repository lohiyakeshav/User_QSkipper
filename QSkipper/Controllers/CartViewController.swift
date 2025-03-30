//
//  CartViewController.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 30/03/25.
//

import SwiftUI

// Controller for handling cart view logic
class CartViewController: ObservableObject {
    private let orderManager: OrderManager
    @Published var isProcessing = false
    @Published var showOrderSuccess = false
    @Published var showPaymentConfirmation = false
    @Published var isSchedulingOrder = false
    @Published var scheduledDate = Date().addingTimeInterval(24 * 60 * 60) // Tomorrow
    @Published var showSchedulePicker = false
    @Published var selectedTipAmount: Int = 18
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
        self.isProcessing = true
        
        // Process the payment (would connect to payment API in production)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Complete order processing
            self.isProcessing = false
            
            // Show success message
            withAnimation(.easeInOut) {
                self.showOrderSuccess = true
            }
            
            // Clear the cart
            self.orderManager.clearCart()
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