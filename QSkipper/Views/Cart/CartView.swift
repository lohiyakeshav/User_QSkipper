//
//  CartView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct CartView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var orderManager: OrderManager
    @State private var specialInstructions: String = ""
    @State private var isPlacingOrder = false
    @State private var orderPlaced = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                if orderManager.currentCart.isEmpty {
                    emptyCartView
                } else {
                    cartContentView
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
                            .foregroundColor(.black)
                    }
                }
            }
            .alert(isPresented: .constant(errorMessage != nil)) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An error occurred"),
                    dismissButton: .default(Text("OK")) {
                        errorMessage = nil
                    }
                )
            }
            .overlay {
                if isPlacingOrder {
                    LoadingView(message: "Placing your order...")
                }
                
                if orderPlaced {
                    OrderSuccessView {
                        orderManager.clearCart()
                        orderPlaced = false
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // Empty cart view
    private var emptyCartView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            AnimationView()
                .frame(height: 200)
            
            Text("Your cart is empty")
                .font(AppFonts.title)
                .foregroundColor(AppColors.darkGray)
            
            Text("Add items to your cart to continue")
                .font(AppFonts.body)
                .foregroundColor(AppColors.mediumGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Browse Menu")
                    .font(AppFonts.buttonText)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(AppColors.primaryGreen)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    // Cart content view
    private var cartContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Cart items section
                VStack(alignment: .leading) {
                    Text("Order Items")
                        .font(AppFonts.sectionTitle)
                        .padding(.horizontal, 20)
                    
                    ForEach(orderManager.currentCart) { item in
                        CartItemRow(item: item)
                    }
                }
                .padding(.top, 10)
                
                // Special instructions
                VStack(alignment: .leading) {
                    Text("Special Instructions")
                        .font(AppFonts.sectionTitle)
                        .padding(.horizontal, 20)
                    
                    TextField("Add notes for your order (optional)", text: $specialInstructions)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                }
                
                // Order summary
                VStack(alignment: .leading, spacing: 10) {
                    Text("Order Summary")
                        .font(AppFonts.sectionTitle)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 10) {
                        HStack {
                            Text("Item Total")
                                .foregroundColor(AppColors.mediumGray)
                            Spacer()
                            Text("₹\(String(format: "%.2f", orderManager.getTotalPrice()))")
                                .foregroundColor(AppColors.darkGray)
                        }
                        
                        HStack {
                            Text("Delivery Fee")
                                .foregroundColor(AppColors.mediumGray)
                            Spacer()
                            Text("₹40.00")
                                .foregroundColor(AppColors.darkGray)
                        }
                        
                        HStack {
                            Text("Platform Fee")
                                .foregroundColor(AppColors.mediumGray)
                            Spacer()
                            Text("₹10.00")
                                .foregroundColor(AppColors.darkGray)
                        }
                        
                        Divider()
                            .padding(.vertical, 5)
                        
                        HStack {
                            Text("Total")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text("₹\(String(format: "%.2f", orderManager.getTotalPrice() + 50.0))")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.primaryGreen)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal, 20)
                }
                
                // Checkout button
                Button {
                    placeOrder()
                } label: {
                    HStack {
                        Spacer()
                        Text("Proceed to Payment")
                            .font(AppFonts.buttonText)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(AppColors.primaryGreen)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                
                // Spacer at the bottom to allow scrolling
                Color.clear.frame(height: 30)
            }
        }
    }
    
    // Place order function
    private func placeOrder() {
        // Demo order placement
        isPlacingOrder = true
        orderManager.specialInstructions = specialInstructions
        
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isPlacingOrder = false
            orderPlaced = true
        }
    }
}

// Cart item row
struct CartItemRow: View {
    @EnvironmentObject var orderManager: OrderManager
    let item: CartItem
    
    var body: some View {
        HStack(spacing: 15) {
            // Product image
            ProductImageView(photoId: item.product.photoId, name: item.product.name, category: item.product.category)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            // Product info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.darkGray)
                
                Text("₹\(String(format: "%.2f", item.product.price)) x \(item.quantity)")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.mediumGray)
                    .padding(.top, 2)
                
                HStack {
                   
                    
                    // Quantity controls
                    Spacer()
                    
                    Button {
                        if item.quantity > 1 {
                            orderManager.updateCartItemQuantity(productId: item.productId, quantity: item.quantity - 1)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(AppColors.primaryGreen)
                    }
                    
                    Text("\(item.quantity)")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 30)
                    
                    Button {
                        orderManager.updateCartItemQuantity(productId: item.productId, quantity: item.quantity + 1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(AppColors.primaryGreen)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Remove button
            Button {
                orderManager.removeFromCart(productId: item.productId)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .opacity(0.7)
            }
            .padding(.horizontal, 5)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}

// Order success view
struct OrderSuccessView: View {
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                AnimationView()
                    .frame(height: 150)
                
                Text("Order Placed Successfully!")
                    .font(AppFonts.title)
                    .foregroundColor(AppColors.darkGray)
                
                Text("Your order has been placed successfully. You can track your order in the orders section.")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.mediumGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Button {
                    onDismiss()
                } label: {
                    Text("Continue Shopping")
                        .font(AppFonts.buttonText)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(AppColors.primaryGreen)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            .padding(30)
            .background(Color.white)
            .cornerRadius(20)
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    CartView()
        .environmentObject(OrderManager.shared)
} 
