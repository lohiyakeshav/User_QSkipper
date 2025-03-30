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
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SimpleNetworkError.invalidResponse
            }
            
            if httpResponse.statusCode >= 400 {
                throw SimpleNetworkError.serverError(httpResponse.statusCode, data)
            }
            
            return data
        } catch {
            if let networkError = error as? SimpleNetworkError {
                throw networkError
            } else {
                throw SimpleNetworkError.requestFailed(error)
            }
        }
    }
} 