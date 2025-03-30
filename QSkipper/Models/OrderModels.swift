//
//  OrderModels.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import Foundation

enum OrderType: String, Codable {
    case dineIn = "dine_in"
    case takeaway = "takeaway"
    
    var displayName: String {
        switch self {
        case .dineIn:
            return "Dine In"
        case .takeaway:
            return "Pick Up"
        }
    }
}

enum OrderStatus: String, Codable {
    case pending = "pending"
    case preparing = "preparing"
    case readyForPickup = "ready_for_pickup"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .preparing:
            return "Preparing"
        case .readyForPickup:
            return "Ready for Pickup"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }
}

struct OrderItem: Codable, Identifiable {
    let id = UUID()
    let productId: String
    let quantity: Int
    let price: Double
    let productName: String?
    
    enum CodingKeys: String, CodingKey {
        case productId = "pid"
        case quantity
        case price
        case productName = "product_name"
    }
}

struct Order: Identifiable, Codable {
    let id: String
    let userId: String
    let restaurantId: String
    let items: [OrderItem]
    let totalAmount: Double
    let status: OrderStatus
    let orderType: OrderType
    let scheduledTime: Date?
    let createdAt: Date
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "oid"
        case userId = "uid"
        case restaurantId = "rid"
        case items
        case totalAmount = "total_amount"
        case status
        case orderType = "order_type"
        case scheduledTime = "scheduled_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PlaceOrderRequest: Codable {
    let userId: String
    let restaurantId: String
    let items: [OrderItem]
    let totalAmount: Double
    let orderType: OrderType
    let scheduledTime: Date?
    let specialInstructions: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "uid"
        case restaurantId = "rid"
        case items
        case totalAmount = "total_amount"
        case orderType = "order_type"
        case scheduledTime = "scheduled_time"
        case specialInstructions = "special_instructions"
    }
}

struct OrderResponse: Codable {
    let status: String
    let message: String
    let order: Order?
}

struct OrderStatusResponse: Codable {
    let status: String
    let message: String
    let orderStatus: OrderStatus?
    
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case orderStatus = "order_status"
    }
}

struct OrdersResponse: Codable {
    let status: String
    let message: String
    let orders: [Order]?
}

struct UserOrdersResponse: Codable {
    let status: String
    let message: String
    let orders: [Order]
} 