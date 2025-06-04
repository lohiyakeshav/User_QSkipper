//
//  NetworkManager.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 28/03/25.
//

import Foundation
import UIKit

// Using a unique name to avoid conflicts with NetworkUtils.swift
enum SimpleNetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(Error)
    case decodingFailed(Error)
    case serverError(Int, Data?)
    case serverErrorWithMessage(Int, String)
    case unknown
    
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
        case .serverErrorWithMessage(let statusCode, let message):
            return message.isEmpty ? "Server error: \(statusCode)" : message
        case .unknown:
            return "An unknown error occurred"
        }
    }
    
    // Implementing LocalizedError to make sure our custom message is used
    var errorDescription: String? {
        return message
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
        
        print("🔄 SimpleNetworkManager: Delegating \(method) request to APIClient: \(url.absoluteString)")
        
        // Extract path from URL to delegate to APIClient
        let path: String
        
        if url.path.isEmpty {
            path = "/"
        } else {
            path = url.path
        }
        
        do {
            let data = try await APIClient.shared.request(
                path: path,
                method: method,
                body: body,
                headers: method != "GET" ? ["Content-Type": "application/json"] : nil
            )
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                print("❌ SimpleNetworkManager: Decoding error: \(error)")
                throw SimpleNetworkError.decodingFailed(error)
            }
        } catch let error as APIClient.APIError {
            print("❌ SimpleNetworkManager: APIClient error: \(error.localizedDescription)")
            switch error {
            case .invalidURL:
                throw SimpleNetworkError.invalidURL
            case .invalidResponse:
                throw SimpleNetworkError.invalidResponse
            case .serverError(let code, let data):
                // Try to extract error message from server response
                if let data = data, let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw SimpleNetworkError.serverErrorWithMessage(code, errorResponse.message)
                } else if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    throw SimpleNetworkError.serverErrorWithMessage(code, errorString)
                } else {
                    throw SimpleNetworkError.serverError(code, data)
                }
            case .networkError(let err):
                throw SimpleNetworkError.requestFailed(err)
            case .decodingFailed(let err):
                throw SimpleNetworkError.decodingFailed(err)
            case .rateLimited:
                throw SimpleNetworkError.requestFailed(NSError(domain: "SimpleNetworkManager", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limited"]))
            case .noData:
                throw SimpleNetworkError.invalidResponse
            case .requestQueueFull:
                throw SimpleNetworkError.requestFailed(NSError(domain: "SimpleNetworkManager", code: 429, userInfo: [NSLocalizedDescriptionKey: "Request queue is full"]))
            }
        } catch {
            print("❌ SimpleNetworkManager: Unexpected error: \(error.localizedDescription)")
            throw SimpleNetworkError.requestFailed(error)
        }
    }
    
    func loadImage(from urlString: String) async throws -> Data {
        print("🔄 SimpleNetworkManager: Delegating image loading to APIClient: \(urlString)")
        
        do {
            let image = try await APIClient.shared.loadImage(from: urlString)
            
            // Convert UIImage to Data
            if let imageData = image.jpegData(compressionQuality: 1.0) {
                return imageData
            } else {
                throw SimpleNetworkError.invalidResponse
            }
        } catch let error as APIClient.APIError {
            print("❌ SimpleNetworkManager: APIClient image loading error: \(error.localizedDescription)")
            switch error {
            case .invalidURL:
                throw SimpleNetworkError.invalidURL
            case .serverError(let code, let data):
                // Try to extract error message from server response
                if let data = data, let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw SimpleNetworkError.serverErrorWithMessage(code, errorResponse.message)
                } else {
                    throw SimpleNetworkError.serverError(code, data)
                }
            default:
                throw SimpleNetworkError.requestFailed(error)
            }
        } catch {
            throw SimpleNetworkError.requestFailed(error)
        }
    }
}

// Error response structure matching the server's JSON error format
struct ErrorResponse: Decodable {
    let success: Bool
    let message: String
} 