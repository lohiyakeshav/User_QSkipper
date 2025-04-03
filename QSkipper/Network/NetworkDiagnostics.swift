import Foundation

/// Utility class for diagnosing network connectivity issues
class NetworkDiagnostics {
    static let shared = NetworkDiagnostics()
    private init() {}
    
    /// Tests the connectivity to the backend API with a simple ping
    func testAPIConnectivity() async -> (isReachable: Bool, responseTime: TimeInterval, error: Error?) {
        let startTime = Date()
        let url = URL(string: "https://qskipperbackend.onrender.com/ping")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        
        do {
            print("🔍 NetworkDiagnostics: Testing connectivity to API...")
            let (_, response) = try await URLSession.shared.data(for: request)
            let endTime = Date()
            let responseTime = endTime.timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, 0, NSError(domain: "NetworkDiagnostics", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
            }
            
            print("✅ NetworkDiagnostics: API responded with status \(httpResponse.statusCode) in \(String(format: "%.2f", responseTime)) seconds")
            return (httpResponse.statusCode == 200, responseTime, nil)
        } catch {
            let endTime = Date()
            let responseTime = endTime.timeIntervalSince(startTime)
            
            print("❌ NetworkDiagnostics: API connectivity test failed: \(error.localizedDescription)")
            return (false, responseTime, error)
        }
    }
    
    /// Tests all major API endpoints for connectivity
    func testAllEndpoints() async -> [String: Bool] {
        let endpoints = [
            "Base": "/ping",
            "Restaurants": "/get_All_Restaurant",
            "Order": "/order-placed",
            "Schedule": "/schedule-order-placed"
        ]
        
        var results = [String: Bool]()
        
        for (name, path) in endpoints {
            let url = URL(string: "https://qskipperbackend.onrender.com\(path)")!
            var request = URLRequest(url: url)
            request.httpMethod = path == "/order-placed" || path == "/schedule-order-placed" ? "OPTIONS" : "GET"
            request.timeoutInterval = 10
            
            print("🔍 Testing endpoint: \(name) (\(path))")
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    results[name] = false
                    continue
                }
                
                // For OPTIONS request, we just care that the server responds, not the status code
                if request.httpMethod == "OPTIONS" {
                    results[name] = true
                    print("✅ Endpoint \(name) is reachable (OPTIONS request)")
                } else {
                    results[name] = (200...299).contains(httpResponse.statusCode)
                    print("✅ Endpoint \(name) returned status \(httpResponse.statusCode)")
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