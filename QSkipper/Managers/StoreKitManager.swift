import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    // MARK: - Published Properties
    @Published private(set) var availableProducts: [StoreKit.Product] = []
    @Published private(set) var purchasedProductIdentifiers = Set<String>()
    
    // MARK: - Constants
    private let orderPaymentProductID = "com.queueskipper.orderpayment"
    private let walletTopUpProductID = "com.queueskipper.wallet.10000"
    private var hasLoadedProducts = false
    private var updateListenerTask: Task<Void, Error>? = nil
    
    // MARK: - Initialization
    private init() {
        startStoreKitListener()
        Task {
            await loadStoreProducts()
            await updatePurchaseHistory()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    func loadStoreProducts() async {
        guard !hasLoadedProducts else { 
            print("📦 StoreKitManager: Products already loaded, skipping")
            return 
        }
        
        print("📦 StoreKitManager: Starting to load products")
        print("📦 StoreKitManager: Will request products with IDs: \(orderPaymentProductID), \(walletTopUpProductID)")
        
        do {
            // Configure the product identifiers based on the order amount
            let productIds = Set([orderPaymentProductID, walletTopUpProductID])
            print("📦 StoreKitManager: Calling StoreKit.Product.products(for: \(productIds))")
            let storeProducts = try await StoreKit.Product.products(for: productIds)
            print("✅ StoreKitManager: Successfully loaded \(storeProducts.count) products")
            
            if storeProducts.isEmpty {
                print("⚠️ StoreKitManager: Warning - No products were returned by StoreKit")
            }
            
            for product in storeProducts {
                print("📦 StoreKitManager: Product Details:")
                print("   ID: \(product.id)")
                print("   Display Name: \(product.displayName)")
                print("   Description: \(product.description)")
                print("   Price: \(product.displayPrice)")
                print("   Type: \(product.type)")
            }
            
            await MainActor.run {
                self.availableProducts = storeProducts
                self.hasLoadedProducts = true
                print("📦 StoreKitManager: Products set in state, count: \(self.availableProducts.count)")
            }
        } catch {
            print("❌ StoreKitManager: Failed to load store products: \(error)")
            print("❌ StoreKitManager: Error description: \(error.localizedDescription)")
        }
    }
    
    func processPayment(for product: StoreKit.Product) async throws {
        print("🛍️ StoreKitManager: Starting payment process for product: \(product.id)")
        print("🛍️ StoreKitManager: Product details - type: \(product.type), price: \(product.displayPrice)")
        print("🛍️ StoreKitManager: The StoreKit purchase sheet should appear now...")
        
        do {
            print("🛍️ StoreKitManager: Calling product.purchase() - StoreKit UI should appear")
            // Request payment using StoreKit's native payment sheet
            let result = try await product.purchase()
            
            print("🛍️ StoreKitManager: Purchase() returned with result: \(result)")
            
            switch result {
            case .success(let verificationResult):
                print("🛍️ StoreKitManager: Purchase successful, verifying transaction")
                switch verificationResult {
                case .verified(let transaction):
                    print("✅ StoreKitManager: Payment verified for: \(transaction.productID)")
                    print("✅ StoreKitManager: Transaction ID: \(transaction.id)")
                    print("✅ StoreKitManager: Purchase date: \(transaction.purchaseDate)")
                    
                    // Finish the transaction to inform StoreKit that delivery was completed
                    // This is crucial for consumable purchases to be purchasable again
                    await transaction.finish()
                    print("✅ StoreKitManager: Transaction marked as finished")
                    
                    await updatePurchaseHistory()
                    print("✅ StoreKitManager: Transaction finished and purchase history updated")
                case .unverified(_, let verificationError):
                    print("❌ StoreKitManager: Payment verification failed: \(verificationError.localizedDescription)")
                    throw StoreKitError.verificationFailed
                }
            case .pending:
                print("⏳ StoreKitManager: Payment awaiting authorization")
                throw StoreKitError.paymentPending
            case .userCancelled:
                print("❌ StoreKitManager: Payment cancelled by user")
                throw StoreKitError.userCancelled
            @unknown default:
                print("❌ StoreKitManager: Unknown payment result")
                throw StoreKitError.unknown
            }
        } catch {
            print("❌ StoreKitManager: Payment processing error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Get product by ID
    func getProduct(byID productID: String) -> StoreKit.Product? {
        return availableProducts.first { $0.id == productID }
    }
    
    // MARK: - Private Methods
    private func startStoreKitListener() {
        updateListenerTask = listenForTransactions()
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchaseHistory()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    private func updatePurchaseHistory() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            await MainActor.run {
                if transaction.revocationDate == nil {
                    purchasedProductIdentifiers.insert(transaction.productID)
                    print("✅ Valid purchase found: \(transaction.productID)")
                } else {
                    purchasedProductIdentifiers.remove(transaction.productID)
                    print("❌ Revoked purchase found: \(transaction.productID)")
                }
            }
        }
    }
    
    // MARK: - Debug Helper Methods
    func debugStoreKitConfiguration() async {
        print("🔍 STOREKIT DEBUG INFO:")
        print("----------------------------------------------------")
        print("📱 Device information: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        print("📱 App sandbox environment: \(Bundle.main.appStoreReceiptURL?.lastPathComponent ?? "Unknown")")
        
        // Check product ID configuration
        print("📦 Configured product ID: \(orderPaymentProductID)")
        
        // Check if StoreKit configuration file exists
        if let storeKitConfigPath = Bundle.main.path(forResource: "QSkipper_StoreKit", ofType: "storekit") {
            print("✅ StoreKit configuration file found at: \(storeKitConfigPath)")
        } else {
            print("❌ StoreKit configuration file not found in the bundle!")
        }
        
        // Check loaded products
        print("📊 Products loaded: \(availableProducts.count)")
        if availableProducts.isEmpty {
            print("⚠️ No products loaded! This might indicate a configuration issue.")
            
            // Attempt to load products again
            print("🔄 Attempting to load products again...")
            await loadStoreProducts()
        }
        
        #if DEBUG
        print("⚙️ App is running in DEBUG mode - StoreKit will use the local configuration")
        #else
        print("⚙️ App is running in RELEASE mode - StoreKit will use App Store Connect configuration")
        #endif
        print("----------------------------------------------------")
    }
}

// MARK: - Error Handling
enum StoreKitError: LocalizedError {
    case purchaseFailed
    case verificationFailed
    case paymentPending
    case userCancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .purchaseFailed:
            return "Failed to process payment"
        case .verificationFailed:
            return "Payment verification failed"
        case .paymentPending:
            return "Payment is awaiting authorization"
        case .userCancelled:
            return "Payment was cancelled"
        case .unknown:
            return "An unexpected error occurred"
        }
    }
} 