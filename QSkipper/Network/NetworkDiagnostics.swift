import Foundation

/// Utility class for diagnosing network connectivity issues
class NetworkDiagnostics {
    static let shared = NetworkDiagnostics()
    private init() {}
    
    /// Quick check for network connectivity, returns true if connected
    func checkConnectivity() async -> Bool {
        // First try our API server - this is most important
        let (apiReachable, _, _) = await testAPIConnectivity()
        
        // If our API server is reachable, we're definitely connected
        if apiReachable {
            return true
        }
        
        // If our API server is not reachable, check general internet
        // to distinguish between API server down vs. no internet
        return await checkInternetConnectivity()
    }
    
    /// Tests the connectivity to the backend API with a simple ping
    func testAPIConnectivity() async -> (isReachable: Bool, responseTime: TimeInterval, error: Error?) {
        let startTime = Date()
        
        do {
            print("🔍 NetworkDiagnostics: Testing connectivity to API using APIClient...")
            
            // Use APIClient to test connectivity
            let responseData: Data = try await APIClient.shared.request(path: APIEndpoints.ping, forceRequest: true)
            
            // Verify the response is "hi home page"
            if let responseString = String(data: responseData, encoding: .utf8),
               responseString.contains("hi home page") {
                print("✅ NetworkDiagnostics: Received expected home page response")
            } else {
                print("⚠️ NetworkDiagnostics: Connected but unexpected response format")
            }
            
            let endTime = Date()
            let responseTime = endTime.timeIntervalSince(startTime)
            
            print("✅ NetworkDiagnostics: API responded successfully in \(String(format: "%.2f", responseTime)) seconds")
            return (true, responseTime, nil)
        } catch let error as APIClient.APIError {
            let endTime = Date()
            let responseTime = endTime.timeIntervalSince(startTime)
            
            print("❌ NetworkDiagnostics: API connectivity test failed: \(error.localizedDescription)")
            return (false, responseTime, error)
        } catch {
            let endTime = Date()
            let responseTime = endTime.timeIntervalSince(startTime)
            
            print("❌ NetworkDiagnostics: API connectivity test failed with unexpected error: \(error.localizedDescription)")
            return (false, responseTime, error)
        }
    }
    
    /// Tests all major API endpoints for connectivity
    func testAllEndpoints() async -> [String: Bool] {
        let endpoints = [
            "Base": APIEndpoints.ping,
            "Restaurants": APIEndpoints.getAllRestaurants,
            "Order": APIEndpoints.orderPlaced,
            "Schedule": APIEndpoints.scheduleOrderPlaced
        ]
        
        var results = [String: Bool]()
        
        for (name, path) in endpoints {
            print("🔍 Testing endpoint: \(name) (\(path))")
            
            do {
                // For POST endpoints, use OPTIONS method
                let method = path == APIEndpoints.orderPlaced || path == APIEndpoints.scheduleOrderPlaced ? "OPTIONS" : "GET"
                
                // Use APIClient for the request, forcing it to bypass rate limiting
                let responseData: Data = try await APIClient.shared.request(path: path, method: method, forceRequest: true)
                
                // For the base endpoint, verify it contains the expected response
                if name == "Base", let responseString = String(data: responseData, encoding: .utf8) {
                    if responseString.contains("hi home page") {
                        results[name] = true
                        print("✅ Endpoint \(name) is reachable with expected response")
                    } else {
                        print("⚠️ Endpoint \(name) response format unexpected: \(responseString)")
                        results[name] = true // Still count as reachable even if format is unexpected
                    }
                } else {
                    results[name] = true
                    print("✅ Endpoint \(name) is reachable")
                }
            } catch {
                results[name] = false
                print("❌ Endpoint \(name) test failed: \(error.localizedDescription)")
            }
        }
        
        return results
    }
    
    /// Checks internet connection by hitting multiple endpoints
    func checkInternetConnectivity() async -> Bool {
        let testSites = [
            "Google": "https://www.google.com",
            "Apple": "https://www.apple.com",
            "Cloudflare": "https://1.1.1.1"
        ]
        
        var successCount = 0
        print("🔍 Checking general internet connectivity...")
        
        for (name, urlString) in testSites {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD" // Just get headers, not full content
            request.timeoutInterval = 5
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { continue }
                
                if (200...299).contains(httpResponse.statusCode) {
                    successCount += 1
                    print("✅ Connected to \(name)")
                }
            } catch {
                print("❌ Failed to connect to \(name): \(error.localizedDescription)")
            }
        }
        
        let hasConnection = successCount > 0
        print("📊 Internet connectivity test result: \(hasConnection ? "Connected" : "Not connected")")
        return hasConnection
    }
    
    /// Run all diagnostic tests and return a report
    func runFullDiagnostics() async -> [String: Any] {
        print("🔬 Running full network diagnostics...")
        
        // Test general internet connectivity
        let hasInternet = await checkInternetConnectivity()
        
        // Test API connectivity
        let apiTest = await testAPIConnectivity()
        
        // Test all endpoints if API is reachable
        var endpointResults: [String: Bool] = [:]
        if apiTest.isReachable {
            endpointResults = await testAllEndpoints()
        }
        
        // Create diagnostic report
        let report: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "internetConnectivity": hasInternet,
            "apiReachable": apiTest.isReachable,
            "apiResponseTime": apiTest.responseTime,
            "apiError": apiTest.error?.localizedDescription ?? "None",
            "endpointTests": endpointResults
        ]
        
        print("📋 Diagnostic report:")
        print("   - Internet: \(hasInternet ? "Connected" : "Not connected")")
        print("   - API: \(apiTest.isReachable ? "Reachable" : "Not reachable") (Response time: \(String(format: "%.2f", apiTest.responseTime))s)")
        if let error = apiTest.error {
            print("   - API Error: \(error.localizedDescription)")
        }
        print("   - Endpoint tests: \(endpointResults.count) tested")
        for (endpoint, result) in endpointResults {
            print("     - \(endpoint): \(result ? "Success" : "Failed")")
        }
        
        return report
    }
} 