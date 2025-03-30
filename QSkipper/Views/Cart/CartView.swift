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
    @StateObject private var viewModel = CartViewModel()
    @State private var showOrderSuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.05).edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Cart items
                    if orderManager.currentCart.isEmpty {
                        // Empty state
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
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                Text("Continue Shopping")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(AppColors.primaryGreen)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 15)
                            
                            Spacer()
                        }
                        .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                // Restaurant info
                                if let restaurant = viewModel.restaurant {
                                    HStack(spacing: 12) {
                                        // Restaurant image
                                        RestaurantImageView(photoId: restaurant.photoId, name: restaurant.name)
                                            .frame(width: 50, height: 50)
                                            .cornerRadius(8)
                                        
                                        // Restaurant info
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(restaurant.name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(AppColors.darkGray)
                                            
                                            Text(restaurant.location)
                                                .font(.system(size: 12))
                                                .foregroundColor(AppColors.mediumGray)
                                        }
                                        
                                        Spacer()
                                        
                                        // Restaurant rating
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                                .font(.system(size: 12))
                                            
                                            Text(String(format: "%.1f", restaurant.rating))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(AppColors.darkGray)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 15)
                                    .background(Color.white)
                                }
                                
                                // Section Title
                                HStack {
                                    Text("YOUR ORDER")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppColors.mediumGray)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                    
                                    Spacer()
                                    
                                    Button {
                                        withAnimation {
                                            orderManager.clearCart()
                                        }
                                    } label: {
                                        Text("Clear Cart")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppColors.errorRed)
                                            .padding(.horizontal, 20)
                                    }
                                }
                                .background(Color.gray.opacity(0.05))
                                
                                // Cart items
                                ForEach(orderManager.currentCart.indices, id: \.self) { index in
                                    let item = orderManager.currentCart[index]
                                    CartItemRow(
                                        item: item,
                                        onIncrement: {
                                            orderManager.incrementItem(at: index)
                                        },
                                        onDecrement: {
                                            orderManager.decrementItem(at: index)
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    
                                    if index < orderManager.currentCart.count - 1 {
                                        Divider()
                                            .padding(.leading, 80)
                                            .padding(.trailing, 20)
                                    }
                                }
                                
                                // Section Title
                                HStack {
                                    Text("BILL DETAILS")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppColors.mediumGray)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                    
                                    Spacer()
                                }
                                .background(Color.gray.opacity(0.05))
                                
                                // Bill details
                                VStack(spacing: 15) {
                                    // Item total
                                    HStack {
                                        Text("Item Total")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.darkGray)
                                        
                                        Spacer()
                                        
                                        Text("₹\(String(format: "%.0f", orderManager.getCartTotal()))")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.darkGray)
                                    }
                                    
                                    // Delivery fee
                                    HStack {
                                        Text("Delivery Fee")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.darkGray)
                                        
                                        Spacer()
                                        
                                        Text("₹\(String(format: "%.0f", viewModel.getDeliveryFee()))")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.darkGray)
                                    }
                                    
                                    // Platform fee
                                    HStack {
                                        Text("Platform Fee")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.darkGray)
                                        
                                        Spacer()
                                        
                                        Text("₹\(String(format: "%.0f", viewModel.getPlatformFee()))")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.darkGray)
                                    }
                                    
                                    // Taxes
                                    HStack {
                                        Text("GST and Restaurant Charges")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.darkGray)
                                        
                                        Spacer()
                                        
                                        Text("₹\(String(format: "%.0f", viewModel.getTaxes()))")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.darkGray)
                                    }
                                    
                                    Divider()
                                        .padding(.vertical, 5)
                                    
                                    // Total
                                    HStack {
                                        Text("Total")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppColors.darkGray)
                                        
                                        Spacer()
                                        
                                        Text("₹\(String(format: "%.0f", viewModel.getTotalAmount()))")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppColors.primaryGreen)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 15)
                                .background(Color.white)
                                
                                // Special instructions
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Special Instructions")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.darkGray)
                                    
                                    TextEditor(text: $viewModel.specialInstructions)
                                        .font(.system(size: 14))
                                        .foregroundColor(.black)
                                        .padding(10)
                                        .frame(height: 100)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 15)
                                .background(Color.white)
                                
                                // Bottom padding
                                Color.clear
                                    .frame(height: 100)
                            }
                        }
                        
                        // Checkout button
                        VStack {
                            Button {
                                viewModel.isProcessingOrder = true
                                
                                // Simulate order processing
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    viewModel.isProcessingOrder = false
                                    showOrderSuccess = true
                                }
                            } label: {
                                HStack {
                                    Text("Proceed to Pay")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("₹\(String(format: "%.0f", viewModel.getTotalAmount()))")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 15)
                                .background(AppColors.primaryGreen)
                                .cornerRadius(8)
                            }
                            .disabled(viewModel.isProcessingOrder)
                            .opacity(viewModel.isProcessingOrder ? 0.7 : 1)
                            .overlay(
                                Group {
                                    if viewModel.isProcessingOrder {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    }
                                }
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                        }
                    }
                }
                
                if showOrderSuccess {
                    OrderSuccessView {
                        self.orderManager.clearCart()
                        self.showOrderSuccess = false
                        self.presentationMode.wrappedValue.dismiss()
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: showOrderSuccess)
                }
            }
            .navigationTitle("Your Cart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.darkGray)
                    }
                }
            }
            .onAppear {
                viewModel.setupCart(with: orderManager.currentCart)
            }
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Veg/Non-veg indicator
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(item.product.isVeg ? Color.green : Color.red, lineWidth: 1)
                    .frame(width: 16, height: 16)
                
                Circle()
                    .fill(item.product.isVeg ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            
            // Product image
            ProductImageView(photoId: item.product.photoId, name: item.product.name, category: item.product.category)
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            
            // Product details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.darkGray)
                
                Text("₹\(String(format: "%.0f", item.product.price))")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.primaryGreen)
            }
            
            Spacer()
            
            // Quantity controls
            HStack(spacing: 0) {
                Button {
                    onDecrement()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(item.quantity > 1 ? AppColors.primaryGreen : Color.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .disabled(item.quantity <= 1)
                
                Text("\(item.quantity)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.darkGray)
                    .frame(width: 30)
                
                Button {
                    onIncrement()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.primaryGreen)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

struct OrderSuccessView: View {
    let onDone: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.primaryGreen)
                    .padding(.top, 30)
                
                Text("Order Placed!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.darkGray)
                
                Text("Your order has been placed successfully.\nYou can track your order status in the Orders section.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.mediumGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(AppColors.primaryGreen)
                        .cornerRadius(8)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 40)
        }
    }
}

class CartViewModel: ObservableObject {
    @Published var restaurant: Restaurant?
    @Published var specialInstructions: String = ""
    @Published var isProcessingOrder: Bool = false
    
    private let restaurantManager = RestaurantManager.shared
    
    func setupCart(with items: [CartItem]) {
        if let firstItem = items.first {
            self.restaurant = restaurantManager.getRestaurant(by: firstItem.product.restaurantId)
        }
    }
    
    func getDeliveryFee() -> Double {
        return 40.0 // Fixed delivery fee
    }
    
    func getPlatformFee() -> Double {
        return 20.0 // Fixed platform fee
    }
    
    func getTaxes() -> Double {
        // Assume 5% tax on item total
        return OrderManager.shared.getCartTotal() * 0.05
    }
    
    func getTotalAmount() -> Double {
        let itemTotal = OrderManager.shared.getCartTotal()
        return itemTotal + getDeliveryFee() + getPlatformFee() + getTaxes()
    }
}

#Preview {
    CartView()
        .environmentObject(OrderManager.shared)
} 
