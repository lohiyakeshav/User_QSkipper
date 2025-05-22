import Foundation

/// Central configuration for all server URLs used throughout the app
public struct ServerConfig {
    // Primary server URL (render.com)
    static let renderBaseURL = "https://qskipper-server-2ul5.onrender.com"
    
    // Secondary/backup server URL (railway.app)
    static let railwayBaseURL = "https://qskipperserver-production.up.railway.app"
    
    // Default URL to use (can be switched between render and railway)
    static let primaryBaseURL = renderBaseURL
    
    // URLs with trailing slash for different usage patterns
    static let renderBaseURLWithSlash = "\(renderBaseURL)/"
    static let railwayBaseURLWithSlash = "\(railwayBaseURL)/"
    static let primaryBaseURLWithSlash = "\(primaryBaseURL)/"
    
    // Helper to create full URLs with endpoints
    static func renderURL(for endpoint: String) -> URL {
        let path = endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)"
        return URL(string: "\(renderBaseURL)\(path)")!
    }
    
    static func railwayURL(for endpoint: String) -> URL {
        let path = endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)"
        return URL(string: "\(railwayBaseURL)\(path)")!
    }
    
    static func primaryURL(for endpoint: String) -> URL {
        let path = endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)"
        return URL(string: "\(primaryBaseURL)\(path)")!
    }
} 