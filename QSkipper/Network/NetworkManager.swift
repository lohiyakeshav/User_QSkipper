//
//  NetworkManager.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 28/03/25.
//

import Foundation
import UIKit

// Using a unique name to avoid conflicts with NetworkUtils.swift
enum SimpleNetworkError: Error {
    case invalidURL
    case invalidResponse
    case requestFailed(Error)
    case decodingFailed(Error)
    case serverError(Int, Data?)
    
    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let statusCode, _):
            return "Server error: \(statusCode)"
        }
    }
}

// Using the existing NetworkManager from NetworkUtils.swift
// This class just provides a simplified interface to that manager
class SimpleNetworkManager {
    static let shared = SimpleNetworkManager()
    private let imageCache = ImageCache.shared
    
    private init() {}
    
    func makeRequest<T: Decodable>(url: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: url) else {
            throw SimpleNetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SimpleNetworkError.invalidResponse
            }
            
            if httpResponse.statusCode >= 400 {
                throw SimpleNetworkError.serverError(httpResponse.statusCode, data)
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                throw SimpleNetworkError.decodingFailed(error)
            }
        } catch {
            if let networkError = error as? SimpleNetworkError {
                throw networkError
            } else {
                throw SimpleNetworkError.requestFailed(error)
            }
        }
    }
    
    func loadImage(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw SimpleNetworkError.invalidURL
        }
        
        // Check if image is in cache
        if let cachedImage = imageCache.getImage(forKey: urlString) {
            // Convert cached UIImage to Data
            if let imageData = cachedImage.jpegData(compressionQuality: 1.0) {
                print("Using cached image for URL: \(urlString)")
                return imageData
            }
        }
        
        print("Loading image from URL: \(urlString)")
        
        // Add retry logic for network resilience
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🔄 Image fetch attempt \(attempt)/\(maxRetries) for URL: \(urlString)")
                
                // Create a request with timeout settings
                var request = URLRequest(url: url)
                request.timeoutInterval = 15 // Shorter timeout (15 seconds instead of default 60)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SimpleNetworkError.invalidResponse
                }
                
                if httpResponse.statusCode >= 400 {
                    throw SimpleNetworkError.serverError(httpResponse.statusCode, data)
                }
                
                // Cache the image for future use
                if let image = UIImage(data: data) {
                    imageCache.setImage(image, forKey: urlString)
                }
                
                print("✅ Successfully loaded image from URL: \(urlString)")
                return data
                
            } catch {
                lastError = error
                print("❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Wait before retrying (exponential backoff)
                if attempt < maxRetries {
                    let delay = Double(attempt) * 0.5 // 0.5s, 1s, 1.5s
                    print("⏱️ Waiting \(delay)s before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // Try fallback URL if original fails (remove /admin/ if present)
        if urlString.contains("/admin/") {
            let fallbackUrlString = urlString.replacingOccurrences(of: "/admin/", with: "/")
            print("🔄 Trying fallback URL: \(fallbackUrlString)")
            
            guard let fallbackUrl = URL(string: fallbackUrlString) else {
                throw lastError ?? SimpleNetworkError.invalidURL
            }
            
            do {
                var request = URLRequest(url: fallbackUrl)
                request.timeoutInterval = 15
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SimpleNetworkError.invalidResponse
                }
                
                if httpResponse.statusCode >= 400 {
                    throw SimpleNetworkError.serverError(httpResponse.statusCode, data)
                }
                
                // Cache the image for future use
                if let image = UIImage(data: data) {
                    imageCache.setImage(image, forKey: urlString) // Cache with original key
                }
                
                print("✅ Successfully loaded image from fallback URL")
                return data
            } catch {
                print("❌ Fallback URL also failed: \(error.localizedDescription)")
                throw lastError ?? error
            }
        }
        
        // If we get here, all attempts failed
        throw lastError ?? SimpleNetworkError.requestFailed(NSError(domain: "Unknown", code: -1))
    }
} 