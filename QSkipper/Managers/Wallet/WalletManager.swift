//
//  WalletManager.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 31/03/25.
//

import Foundation
import SwiftUI
import StoreKit

class WalletManager: ObservableObject {
    static let shared = WalletManager()
    
    // MARK: - Published Properties
    @Published private(set) var balance: Double = 0.0
    @Published private(set) var transactions: [WalletTransaction] = []
    @Published var isLoadingWallet: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Constants
    private let walletBalanceKey = "wallet_balance"
    private let walletTransactionsKey = "wallet_transactions"
    
    // StoreKit product IDs
    let walletProductID = "com.queueskipper.wallet.10000"
    
    // MARK: - Initialization
    private init() {
        loadWalletData()
    }
    
    // MARK: - Public Methods
    
    // Add funds to wallet
    func addFunds(amount: Double, type: TransactionType, description: String = "") {
        let transaction = WalletTransaction(
            id: UUID().uuidString,
            amount: amount,
            type: type,
            timestamp: Date(),
            description: description
        )
        
        balance += amount
        transactions.append(transaction)
        saveWalletData()
    }
    
    // Deduct funds from wallet
    func deductFunds(amount: Double, description: String = "") -> Bool {
        // Check if we have enough balance
        guard balance >= amount else {
            errorMessage = "Insufficient funds. Please add money to your wallet."
            showError = true
            return false
        }
        
        let transaction = WalletTransaction(
            id: UUID().uuidString,
            amount: -amount, // Negative amount for deduction
            type: .payment,
            timestamp: Date(),
            description: description
        )
        
        balance -= amount
        transactions.append(transaction)
        saveWalletData()
        return true
    }
    
    // Process wallet top-up with StoreKit
    func processWalletTopUp(product: StoreKit.Product) async throws {
        isLoadingWallet = true
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    // Add funds to wallet
                    if product.id == walletProductID {
                        await MainActor.run {
                            addFunds(
                                amount: 10000,
                                type: .topUp,
                                description: "Added ₹10,000 to wallet"
                            )
                        }
                    }
                    
                    // Finish the transaction
                    await transaction.finish()
                    
                case .unverified:
                    throw WalletError.verificationFailed
                }
            case .pending:
                throw WalletError.paymentPending
            case .userCancelled:
                throw WalletError.userCancelled
            @unknown default:
                throw WalletError.unknown
            }
        } catch {
            await MainActor.run {
                isLoadingWallet = false
            }
            throw error
        }
        
        // Set loading state to false when done
        await MainActor.run {
            isLoadingWallet = false
        }
    }
    
    // MARK: - Private Methods
    private func saveWalletData() {
        UserDefaults.standard.set(balance, forKey: walletBalanceKey)
        
        if let transactionsData = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(transactionsData, forKey: walletTransactionsKey)
        }
    }
    
    private func loadWalletData() {
        // Load balance
        balance = UserDefaults.standard.double(forKey: walletBalanceKey)
        
        // Load transactions
        if let transactionsData = UserDefaults.standard.data(forKey: walletTransactionsKey),
           let decodedTransactions = try? JSONDecoder().decode([WalletTransaction].self, from: transactionsData) {
            transactions = decodedTransactions
        }
        
        // For testing, add some initial balance if empty
        #if DEBUG
        if balance == 0 && transactions.isEmpty {
            balance = 1000
            let transaction = WalletTransaction(
                id: UUID().uuidString,
                amount: 1000,
                type: .topUp,
                timestamp: Date(),
                description: "Initial test balance"
            )
            transactions.append(transaction)
            saveWalletData()
        }
        #endif
    }
    
    // Reset wallet data (for testing)
    func resetWallet() {
        balance = 0
        transactions = []
        saveWalletData()
    }
}

// MARK: - Transaction Models
struct WalletTransaction: Identifiable, Codable {
    let id: String
    let amount: Double // Positive for deposits, negative for payments
    let type: TransactionType
    let timestamp: Date
    let description: String
    
    var formattedAmount: String {
        return "₹\(String(format: "%.2f", abs(amount)))"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter.string(from: timestamp)
    }
}

enum TransactionType: String, Codable {
    case topUp = "Top-up"
    case payment = "Payment"
    case refund = "Refund"
    
    var icon: String {
        switch self {
        case .topUp:
            return "arrow.down.circle.fill"
        case .payment:
            return "arrow.up.circle.fill"
        case .refund:
            return "arrow.uturn.down.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .topUp, .refund:
            return .green
        case .payment:
            return .red
        }
    }
}

// MARK: - Errors
enum WalletError: LocalizedError {
    case insufficientFunds
    case transactionFailed
    case verificationFailed
    case paymentPending
    case userCancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .insufficientFunds:
            return "Insufficient funds in wallet"
        case .transactionFailed:
            return "Transaction failed"
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