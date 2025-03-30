//
//  AuthModels.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import Foundation

struct User: Codable {
    let id: String
    let email: String
    let name: String?
    let phone: String?
    let token: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "pid"
        case email
        case name
        case phone
        case token
    }
}

struct LoginRequest: Codable {
    let email: String
    
    enum CodingKeys: String, CodingKey {
        case email
    }
}

struct OTPVerificationRequest: Codable {
    let email: String
    let otp: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case otp
    }
}

struct RegisterRequest: Codable {
    let email: String
    let name: String
    let phone: String?  // Make phone optional
    
    enum CodingKeys: String, CodingKey {
        case email
        case name = "username" // Changed to match API
        case phone
    }
}

struct AuthResponse: Codable {
    let status: Bool?  // Make optional since some responses don't include it
    let message: String?  // Make optional for responses that don't include it
    let user: User?
    let token: String?
    let id: String? // Added to support both response formats
    let username: String? // Add username field from response
    
    enum CodingKeys: String, CodingKey {
        case status = "success" // Changed to match API
        case message
        case user
        case token
        case id
        case username
    }
    
    // Add computed property to determine if response is successful
    var isSuccess: Bool {
        // If status is provided, use it
        if let status = status {
            return status
        }
        // If id is provided but no status, consider it successful
        else if id != nil {
            return true
        }
        // Otherwise consider it failed
        return false
    }
}

struct OTPResponse: Codable {
    let status: Bool
    let message: String
    let otp: String?  // OTP returned by API for development/testing purposes
    let username: String? // Add username field from response
    let id: String? // Add ID field from response
    
    enum CodingKeys: String, CodingKey {
        case status = "success" // Changed to match API
        case message
        case otp
        case username
        case id
    }
} 