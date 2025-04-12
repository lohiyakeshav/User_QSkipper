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
    
    private let baseURL = "https://qskipperbackend.onrender.com"
    private let maxRetries = 3
    
    private init() {}
    
    func placeOrder(jsonDict: [String: Any]) async throws -> String {
        return try await sendRequest(endpoint: "/order-placed", jsonDict: jsonDict)
    }
    
    // for verifying payment
    func verifyOrder(jsonDict: [String: Any]) async throws -> HTTPURLResponse {
        guard let url = URL(string: "\(APIEndpoints.baseURL)/verify-order") else {
            print("❌ OrderAPIService: Invalid URL: \(APIEndpoints.baseURL)/verify-order")
            throw URLError(.badURL)
        }
        
        print("🌐 OrderAPIService: Sending request to \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let requestData = try JSONSerialization.data(withJSONObject: jsonDict)
            if let jsonString = String(data: requestData, encoding: .utf8) {
                print("📄 OrderAPIService: Request payload: \(jsonString)")
            }
            request.httpBody = requestData
        } catch {
            print("❌ OrderAPIService: Failed to serialize JSON: \(error.localizedDescription)")
            throw error
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ OrderAPIService: No HTTP response received")
                throw NSError(domain: "VerifyOrder", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response received"])
            }
            
            if let bodyString = String(data: data, encoding: .utf8) {
                print("📩 OrderAPIService: Response body: \(bodyString)")
            } else {
                print("📩 OrderAPIService: No response body (empty or binary data)")
            }
            
            print("📊 OrderAPIService: Response status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                throw NSError(
                    domain: "VerifyOrder",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(httpResponse.statusCode)"]
                )
            }
            
            return httpResponse
        } catch {
            print("❌ OrderAPIService: Request failed: \(error.localizedDescription)")
            throw error
        }
    }

    
    
    func placeScheduledOrder(jsonDict: [String: Any]) async throws -> String {
        return try await sendRequest(endpoint: "/schedule-order-placed", jsonDict: jsonDict)
    }
    
    private func sendRequest(endpoint: String, jsonDict: [String: Any]) async throws -> String {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw OrderAPIError.networkError("Invalid URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
        urlRequest.httpBody = jsonData
        
        print("📤 OrderAPI: Sending request to \(endpoint):")
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🔄 OrderAPI: Attempt \(attempt)/\(maxRetries) for \(endpoint)")
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                
                print("📥 OrderAPI: Received response from \(endpoint):")
                if let responseString = String(data: data, encoding: .utf8) {
                    print(responseString)
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OrderAPIError.networkError("Invalid response")
                }
                
                print("📥 OrderAPI: HTTP Status Code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw OrderAPIError.serverError("Status \(httpResponse.statusCode): \(errorMessage)")
                }
                
                // Parse the response
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw OrderAPIError.invalidData(responseData: data)
                }
                
                // Check for "id" field (your backend's format)
                if let orderId = json["id"] as? String {
                    print("✅ OrderAPI: Successfully parsed order ID: \(orderId)")
                    return orderId
                }
                
                // Fallback to original logic for other formats
                if let success = json["success"] as? Bool {
                    if success, let dataObj = json["data"] as? [String: Any], let orderId = dataObj["orderId"] as? String {
                        print("✅ OrderAPI: Successfully parsed order ID from data: \(orderId)")
                        return orderId
                    } else {
                        let errorMsg = json["message"] as? String ?? "Unknown server error"
                        throw OrderAPIError.serverError(errorMsg)
                    }
                }
                
                // If no "id" or "success", check plain string response
                if let responseText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: ""),
                   responseText.count == 24, responseText.range(of: "^[0-9a-f]+$", options: .regularExpression) != nil {
                    print("✅ OrderAPI: Response is a valid MongoDB ObjectId: \(responseText)")
                    return responseText
                }
                
                print("❌ OrderAPI: No valid order ID found in response")
                throw OrderAPIError.invalidData(responseData: data)
                
            } catch {
                lastError = error
                print("❌ OrderAPI: Attempt \(attempt) failed: \(error.localizedDescription)")
                
                let shouldRetry = isRetryableError(error)
                if shouldRetry && attempt < maxRetries {
                    let delay = calculateRetryDelay(attempt)
                    print("⏱️ OrderAPI: Waiting \(delay) seconds before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    print("❌ OrderAPI: Non-retryable error, breaking retry loop")
                    throw error
                }
            }
        }
        
        throw lastError ?? OrderAPIError.unknown
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [.timedOut, .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost].contains(urlError.code)
        }
        return false
    }
    
    private func calculateRetryDelay(_ attempt: Int) -> Double {
        return min(pow(2.0, Double(attempt - 1)), 8) // 1, 2, 4, 8 seconds
    }
}
    
    // Helper to validate ISO8601 date format
    func isValidISO8601Date(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString) != nil
    }

