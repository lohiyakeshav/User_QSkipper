import Foundation

// Models for API requests
struct OrderPlacementRequest: Codable {
    let restaurantId: String
    let userId: String
    let items: [OrderItemRequest]
    let price: String
    let takeAway: Bool
    
    // Add CodingKeys to ensure field names match exactly what the API expects
    enum CodingKeys: String, CodingKey {
        case restaurantId
        case userId
        case items
        case price
        case takeAway
    }
}

struct ScheduleOrderRequest: Codable {
    let restaurantId: String
    let userId: String
    let items: [OrderItemRequest]
    let price: String
    let scheduleDate: String
    let takeAway: Bool
    
    // Add CodingKeys to ensure the JSON field names match exactly what the API expects
    enum CodingKeys: String, CodingKey {
        case restaurantId
        case userId
        case items
        case price
        case scheduleDate
        case takeAway
    }
}

struct OrderItemRequest: Codable {
    let productId: String
    let name: String
    let quantity: Int
    let price: Int
    
    // Add CodingKeys to ensure the JSON field names match exactly what the API expects
    enum CodingKeys: String, CodingKey {
        case productId
        case name
        case quantity
        case price
    }
}

struct APIResponse: Codable {
    let success: Bool
    let message: String?
    let data: OrderData?
    
    // Add CodingKeys to ensure field names match the API response
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case data
    }
}

struct OrderData: Codable {
    let orderId: String?
    
    // Add CodingKeys to ensure field names match the API response
    enum CodingKeys: String, CodingKey {
        case orderId
    }
}


enum OrderAPIError: Error {
    case networkError(String)
    case serverError(String)
    case invalidData(responseData: Data)
    case timeout
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .networkError(let message): return "Network error: \(message)"
        case .serverError(let message): return "Server error: \(message)"
        case .invalidData: return "Invalid response data"
        case .timeout: return "Request timed out"
        case .unknown: return "Unknown error"
        }
    }
}

class OrderAPIService {
    static let shared = OrderAPIService()
    
    private init() {}
    
    func placeOrder(jsonDict: [String: Any]) async throws -> String {
        print("📡 OrderAPIService: Delegating placeOrder to APIClient")
        return try await APIClient.shared.placeOrder(orderData: jsonDict)
    }
    
    // for verifying payment
    func verifyOrder(jsonDict: [String: Any]) async throws -> HTTPURLResponse {
        print("📡 OrderAPIService: Delegating verifyOrder to APIClient")
        
        do {
            // Serialize the data
            let requestData = try JSONSerialization.data(withJSONObject: jsonDict)
            
            // Send the request through APIClient
            let data = try await APIClient.shared.request(
                path: "/verify-order",
                method: "POST",
                body: requestData,
                headers: ["Content-Type": "application/json"]
            )
            
            // Create a mock HTTPURLResponse since we can't construct it directly
            // This is needed for backward compatibility
            let response = HTTPURLResponse(
                url: URL(string: "https://qskipperbackend.onrender.com/verify-order")!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📩 OrderAPIService: Response body: \(jsonString)")
            }
            
            return response
        } catch let error as APIClient.APIError {
            print("❌ OrderAPIService: API error: \(error.localizedDescription)")
            let statusCode = 500
            
            if case .serverError(let code, _) = error {
                let response = HTTPURLResponse(
                    url: URL(string: "https://qskipperbackend.onrender.com/verify-order")!,
                    statusCode: code,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!
                
                throw NSError(
                    domain: "VerifyOrder",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(code)"]
                )
            }
            
            throw NSError(
                domain: "VerifyOrder",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        } catch {
            print("❌ OrderAPIService: Request failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func placeScheduledOrder(jsonDict: [String: Any]) async throws -> String {
        print("📡 OrderAPIService: Delegating placeScheduledOrder to APIClient")
        
        // Validate and ensure required fields for scheduled orders
        var modifiedJsonDict = jsonDict
        
        // IMPORTANT: Set takeAway to true for scheduled orders regardless of what was passed
        // This is required by the backend API which returns 400 if takeAway is false
        modifiedJsonDict["takeAway"] = true
        
        // Print the exact JSON and values before sending
        if let takeAwayValue = modifiedJsonDict["takeAway"] {
            print("📝 OrderAPIService: takeAway value type: \(type(of: takeAwayValue)), value: \(takeAwayValue)")
        }
        
        do {
            // Serialize request body
            let requestData = try JSONSerialization.data(withJSONObject: modifiedJsonDict)
            
            // Send the request through APIClient
            let data = try await APIClient.shared.request(
                path: "/schedule-order-placed",
                method: "POST",
                body: requestData,
                headers: ["Content-Type": "application/json"]
            )
            
            // Parse the response to get the order ID using the same logic as sendRequest
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Check for "id" field (direct objectId)
                if let orderId = json["id"] as? String {
                    return orderId
                }
                
                // Check for {"success": true, "data": {"orderId": "..."}} structure
                if let success = json["success"] as? Bool,
                   success,
                   let dataObj = json["data"] as? [String: Any],
                   let orderId = dataObj["orderId"] as? String {
                    return orderId
                }
            }
            
            // Check if the response is a plain string (ObjectId)
            if let responseText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: ""),
               responseText.count == 24, 
               responseText.range(of: "^[0-9a-f]+$", options: .regularExpression) != nil {
                return responseText
            }
            
            throw OrderAPIError.invalidData(responseData: data)
        } catch let error as APIClient.APIError {
            print("❌ OrderAPIService: API error: \(error.localizedDescription)")
            switch error {
            case .invalidURL:
                throw OrderAPIError.networkError("Invalid URL")
            case .serverError(let code, _):
                throw OrderAPIError.serverError("Status \(code)")
            case .rateLimited:
                throw OrderAPIError.networkError("Rate limited")
            default:
                throw OrderAPIError.networkError(error.localizedDescription)
            }
        } catch {
            throw OrderAPIError.networkError(error.localizedDescription)
        }
    }
    
    // Helper to validate ISO8601 date format
    func isValidISO8601Date(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString) != nil
    }
}

