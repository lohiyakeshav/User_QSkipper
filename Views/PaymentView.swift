var body: some View {
    ZStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PaymentHeaderView(amount: totalAmount + tipAmount)
                
                // Payment Methods Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Payment Methods")
                        .font(.headline)
                        .padding(.leading)
                    
                    Button(action: {
                        selectedPaymentMethod = "Apple Pay"
                    }) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .foregroundColor(.black)
                            Text("Apple Pay")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedPaymentMethod == "Apple Pay" {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedPaymentMethod == "Apple Pay" ? Color.gray.opacity(0.2) : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        selectedPaymentMethod = "Credit Card"
                    }) {
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundColor(.blue)
                            Text("Credit Card")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedPaymentMethod == "Credit Card" {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedPaymentMethod == "Credit Card" ? Color.gray.opacity(0.2) : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Order Summary
                VStack(alignment: .leading, spacing: 10) {
                    Text("Order Summary")
                        .font(.headline)
                        .padding(.leading)
                    
                    VStack(spacing: 15) {
                        HStack {
                            Text("Restaurant")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(restaurantName)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Items")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(cartManager.currentCart.count) items")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Subtotal")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("$\(String(format: "%.2f", totalAmount))")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Tip")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("$\(String(format: "%.2f", tipAmount))")
                                .fontWeight(.medium)
                        }
                        
                        if isScheduledOrder, let time = scheduledTime {
                            HStack {
                                Text("Scheduled for")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(time, style: .time)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total")
                                .fontWeight(.bold)
                            Spacer()
                            Text("$\(String(format: "%.2f", totalAmount + tipAmount))")
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
                
                // Payment Button
                Button(action: {
                    isMakingPayment = true
                    processPayment()
                }) {
                    HStack {
                        Spacer()
                        if isMakingPayment {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Pay $\(String(format: "%.2f", totalAmount + tipAmount))")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(isMakingPayment)
                }
                .padding(.top)
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
        .toolbar(.hidden, for: .tabBar) // Hide tab bar for iOS 16+
        
        if paymentStatus == .success {
            PaymentSuccessView(cartManager: cartManager, amount: totalAmount + tipAmount)
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
}

private func processPayment() {
    // Simulate network request for payment
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        // Random success or failure for demonstration (90% success rate)
        if Double.random(in: 0...1) < 0.9 {
            self.simulateSuccessfulPayment()
        } else {
            self.alertMessage = "Your payment could not be processed. Please try again."
            self.showAlert = true
            self.isMakingPayment = false
        }
    }
}

private func simulateSuccessfulPayment() {
    // Simulate payment processing delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        self.paymentStatus = .success
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