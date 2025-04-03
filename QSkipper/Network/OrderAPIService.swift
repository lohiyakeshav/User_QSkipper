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
    case unknown
    case timeout
    
    var message: String {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidData:
            return "Invalid data received from server"
        case .invalidData(responseData: _):
            return "Invalid data received from server"
        case .unknown:
            return "An unknown error occurred"
        case .timeout:
            return "Request timed out. Please check your internet connection and try again."
        }
    }
}

class OrderAPIService {
    static let shared = OrderAPIService()
    
    private let baseURL = "https://qskipperbackend.onrender.com"
    private let maxRetries = 3
    
    private init() {}
    
    // Place immediate order with retry logic
    func placeOrder(jsonDict: [String: Any]) async throws -> String {
        return try await sendRequest(endpoint: "/order-placed", jsonDict: jsonDict)
    }
    
    // Place scheduled order with retry logic
    func placeScheduledOrder(jsonDict: [String: Any]) async throws -> String {
        return try await sendRequest(endpoint: "/schedule-order-placed", jsonDict: jsonDict)
    }
    
    // Generic request function with retry logic using dictionary
    private func sendRequest(endpoint: String, jsonDict: [String: Any]) async throws -> String {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw OrderAPIError.networkError("Invalid URL")
        }
        
        // Configure URLRequest with longer timeout
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60 // Increase timeout to 60 seconds
        
        // Encode request
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
        urlRequest.httpBody = jsonData
        
        // Print request for debugging
        print("📤 OrderAPI: Sending request to \(endpoint):")
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
            
            // For scheduled orders, check schedule date
            if jsonString.contains("scheduleDate") {
                print("✅ OrderAPI: scheduleDate field found in payload")
                
                // Expected schedule order format:
                print("""
                Expected schedule order format:
                {
                    "restaurantId": "6661a3534d1e0d993a73e66a",
                    "userId": "67e027be2a5929b05bbcc97a",
                    "items": [
                        {
                            "productId": "6661a4304d1e0d993a73e672",
                            "name": "Pav Bhaji",
                            "quantity": 1,
                            "price": 80
                        }
                    ],
                    "price": "110",
                    "scheduleDate": "2025-04-01T14:30:00Z",
                    "takeAway": true
                }
                """)
            } else {
                // Expected immediate order format:
                print("""
                Expected immediate order format:
                {
                    "restaurantId": "6661a3534d1e0d993a73e66a",
                    "userId": "67e027be2a5929b05bbcc97a",
                    "items": [
                        {
                            "productId": "6661a4304d1e0d993a73e672",
                            "name": "Pav Bhaji",
                            "quantity": 1,
                            "price": 80
                        }
                    ],
                    "price": "110",
                    "takeAway": true
                }
                """)
            }
        }
        
        // Try up to maxRetries times
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🔄 OrderAPI: Attempt \(attempt)/\(maxRetries) for \(endpoint)")
                
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                
                // Print response for debugging
                print("📥 OrderAPI: Received response from \(endpoint):")
                if let responseString = String(data: data, encoding: .utf8) {
                    print(responseString)
                } else {
                    print("⚠️ OrderAPI: Could not convert response data to string")
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OrderAPIError.networkError("Invalid response")
                }
                
                // Print HTTP status code
                print("📥 OrderAPI: HTTP Status Code: \(httpResponse.statusCode)")
                
                // Handle HTTP errors
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    // Try to parse error message from response body
                    var errorMessage = "Server returned status code \(httpResponse.statusCode)"
                    if let responseString = String(data: data, encoding: .utf8) {
                        errorMessage += ": \(responseString)"
                    }
                    throw OrderAPIError.serverError(errorMessage)
                }
                
                // Try to parse the response using JSONSerialization
                do {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool {
                        if success {
                            // Successfully placed order
                            if let dataObj = json["data"] as? [String: Any],
                               let orderId = dataObj["orderId"] as? String {
                                print("✅ OrderAPI: Successfully received order ID: \(orderId)")
                                return orderId
                            } else {
                                print("⚠️ OrderAPI: Order successful but no order ID found in response")
                                return "unknown"
                            }
                        } else {
                            // API returned success=false
                            let errorMsg = json["message"] as? String ?? "Unknown server error"
                            print("❌ OrderAPI: Server returned success=false: \(errorMsg)")
                            throw OrderAPIError.serverError(errorMsg)
                        }
                    } else {
                        // Before giving up, check if the response is a plain string
                        if let responseText = String(data: data, encoding: .utf8) {
                            print("📄 OrderAPI: Response text: \(responseText)")
                            
                            // If the response is just a string and contains a valid ID format (no spaces, quotes removed)
                            let cleanedText = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                                                         .replacingOccurrences(of: "\"", with: "")
                            
                            // Check if it looks like a MongoDB ObjectId (24 hex characters)
                            if cleanedText.count == 24 && cleanedText.range(of: "^[0-9a-f]+$", options: .regularExpression) != nil {
                                print("✅ OrderAPI: Response appears to be a valid order ID: \(cleanedText)")
                                return cleanedText
                            }
                            
                            // Try to extract orderId directly if possible
                            if responseText.contains("orderId") || responseText.contains("order_id") {
                                print("🔍 OrderAPI: Found orderId mention in response, attempting manual extraction")
                                if let orderIdRange = responseText.range(of: "\"orderId\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression),
                                   let orderIdValueRange = responseText[orderIdRange].range(of: ":\"([^\"]+)\"", options: .regularExpression) {
                                    let orderIdValue = responseText[orderIdValueRange]
                                        .replacingOccurrences(of: ":\"", with: "")
                                        .replacingOccurrences(of: "\"", with: "")
                                    print("✅ OrderAPI: Manually extracted order ID: \(orderIdValue)")
                                    return orderIdValue
                                }
                            }
                        }
                        throw OrderAPIError.invalidData(responseData: data)
                    }
                } catch {
                    print("❌ OrderAPI: Error parsing response: \(error.localizedDescription)")
                    throw OrderAPIError.invalidData(responseData: data)
                }
            } catch {
                lastError = error
                print("❌ OrderAPI: Attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Check if we should retry based on error type
                let shouldRetry = isRetryableError(error)
                
                if shouldRetry && attempt < maxRetries {
                    let delay = calculateRetryDelay(attempt)
                    print("⏱️ OrderAPI: Waiting \(delay) seconds before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else if !shouldRetry {
                    print("❌ OrderAPI: Non-retryable error, breaking retry loop")
                    throw error
                }
            }
        }
        
        // If we get here, all attempts failed
        if let urlError = lastError as? URLError, urlError.code == .timedOut {
            throw OrderAPIError.timeout
        }
        throw lastError ?? OrderAPIError.unknown
    }
    
    // Determine if an error should be retried
    private func isRetryableError(_ error: Error) -> Bool {
        // Retry on network errors, but not server errors
        if let urlError = error as? URLError {
            return [.notConnectedToInternet, 
                    .networkConnectionLost, 
                    .timedOut, 
                    .cannotFindHost, 
                    .cannotConnectToHost].contains(urlError.code)
        }
        
        // Retry on our timeout error
        if let apiError = error as? OrderAPIError, case .timeout = apiError {
            return true
        }
        
        // Don't retry on other error types
        return false
    }
    
    // Calculate delay using exponential backoff
    private func calculateRetryDelay(_ attempt: Int) -> Double {
        return min(pow(2.0, Double(attempt - 1)), 8) // 1, 2, 4, 8 seconds
    }
    
    // Helper to validate ISO8601 date format
    func isValidISO8601Date(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString) != nil
    }
} 
