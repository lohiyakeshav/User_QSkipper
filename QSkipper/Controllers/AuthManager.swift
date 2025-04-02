//
//  AuthManager.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import Foundation

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    private let networkManager = SimpleNetworkManager.shared
    private let userDefaultsManager = UserDefaultsManager.shared
    
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private init() {
        // Initialize with user's login status
        isLoggedIn = userDefaultsManager.isUserLoggedIn()
    }
    
    // Request OTP for login
    @MainActor
    func requestLoginOTP(email: String) async throws -> String {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let loginRequest = LoginRequest(email: email)
            let jsonData = try JSONEncoder().encode(loginRequest)
            
            print("Sending login request to \(APIEndpoints.login) with data: \(String(data: jsonData, encoding: .utf8) ?? "")")
            
            let response: OTPResponse = try await networkManager.makeRequest(
                url: APIEndpoints.login,
                method: "POST",
                body: jsonData
            )
            
            print("Login response received: \(response)")
            
            // Check status
            if !response.status {
                self.error = response.message
                throw SimpleNetworkError.serverError(400, nil)
            }
            
            // Store username and ID if available
            if let username = response.username, let id = response.id {
                print("Storing user information - ID: \(id), Email: \(email), Username: \(username)")
                userDefaultsManager.savePartialUser(id: id, email: email, username: username)
            } else if let id = response.id {
                // If username is not provided but ID is available
                print("Storing user information - ID: \(id), Email: \(email)")
                userDefaultsManager.savePartialUser(id: id, email: email, username: "User")
            }
            
            // For development, we'll return the OTP received directly
            if let otp = response.otp {
                return otp
            } else {
                return "" // Return empty string instead of hardcoded OTP
            }
        } catch {
            print("Login error: \(error)")
            if let networkError = error as? SimpleNetworkError {
                self.error = networkError.message
            } else {
                self.error = error.localizedDescription
            }
            throw error
        }
    }
    
    // Verify login OTP
    @MainActor
    func verifyLoginOTP(email: String, otp: String) async throws -> Bool {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let verificationRequest = OTPVerificationRequest(email: email, otp: otp)
            let jsonData = try JSONEncoder().encode(verificationRequest)
            
            let response: AuthResponse = try await networkManager.makeRequest(
                url: APIEndpoints.verifyLogin,
                method: "POST",
                body: jsonData
            )
            
            // Check if response is successful using the computed property
            if !response.isSuccess {
                self.error = response.message ?? "Verification failed"
                return false
            }
            
            // Get username from various sources with priority
            let username: String
            if let responseUsername = response.username, !responseUsername.isEmpty {
                username = responseUsername
            } else if let user = response.user, let userName = user.name, !userName.isEmpty {
                username = userName
            } else {
                // Use the name we saved during login OTP request
                username = userDefaultsManager.getUserName() ?? "User"
            }
            
            // Check if response has user data or just an ID
            if let user = response.user {
                // Create a new user with our determined username
                let updatedUser = User(
                    id: user.id, 
                    email: user.email, 
                    name: username,  // Use our determined username
                    phone: user.phone, 
                    token: user.token ?? response.token
                )
                
                // Save user data
                userDefaultsManager.saveUser(updatedUser)
                
                // Update login status
                self.isLoggedIn = true
                
                return true
            } else if let id = response.id {
                // If we only got an ID, create minimal user data
                let user = User(
                    id: id, 
                    email: email, 
                    name: username,  // Use our determined username
                    phone: nil, 
                    token: response.token
                )
                userDefaultsManager.saveUser(user)
                
                // Update login status
                self.isLoggedIn = true
                
                return true
            } else {
                self.error = response.message ?? "No user data or ID received"
                return false
            }
        } catch {
            if let networkError = error as? SimpleNetworkError {
                self.error = networkError.message
            } else {
                self.error = error.localizedDescription
            }
            throw error
        }
    }
    
    // Register a new user
    @MainActor
    func registerUser(email: String, name: String, phone: String) async throws -> String {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let registerRequest = RegisterRequest(email: email, name: name, phone: phone)
            let jsonData = try JSONEncoder().encode(registerRequest)
            
            print("Sending register request to \(APIEndpoints.register) with data: \(String(data: jsonData, encoding: .utf8) ?? "")")
            
            let response: OTPResponse = try await networkManager.makeRequest(
                url: APIEndpoints.register,
                method: "POST",
                body: jsonData
            )
            
            print("Register response received: \(response)")
            
            // For development, we'll return the OTP received directly
            if let otp = response.otp {
                return otp
            } else {
                return "" // Return empty string instead of hardcoded OTP
            }
        } catch {
            print("Register error: \(error)")
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // Verify register OTP
    @MainActor
    func verifyRegisterOTP(email: String, otp: String) async throws -> Bool {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let verificationRequest = OTPVerificationRequest(email: email, otp: otp)
            let jsonData = try JSONEncoder().encode(verificationRequest)
            
            print("Sending verify register request to \(APIEndpoints.verifyRegister) with data: \(String(data: jsonData, encoding: .utf8) ?? "")")
            
            let response: AuthResponse = try await networkManager.makeRequest(
                url: APIEndpoints.verifyRegister,
                method: "POST",
                body: jsonData
            )
            
            print("Verify register response received: \(response)")
            
            // Check if response is successful using the computed property
            if !response.isSuccess {
                self.error = response.message ?? "Verification failed"
                return false
            }
            
            // Check if response has user data or just an ID
            if let user = response.user {
                // Save user data
                userDefaultsManager.saveUser(user)
                
                // Update login status
                self.isLoggedIn = true
                
                return true
            } else if let id = response.id {
                // If we only got an ID, create minimal user data
                let user = User(id: id, email: email, name: nil, phone: nil, token: response.token)
                userDefaultsManager.saveUser(user)
                
                // Update login status
                self.isLoggedIn = true
                
                return true
            } else {
                self.error = response.message ?? "No user data or ID received"
                return false
            }
        } catch {
            print("Verify register error: \(error)")
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // Logout user
    @MainActor
    func logout() {
        userDefaultsManager.clearUserData()
        isLoggedIn = false
    }
    
    // Check if user is logged in
    func checkLoginStatus() -> Bool {
        return userDefaultsManager.isUserLoggedIn()
    }
    
    // Get current user ID
    func getCurrentUserId() -> String? {
        return userDefaultsManager.getUserId()
    }
    
    // Get current user email
    func getCurrentUserEmail() -> String? {
        return userDefaultsManager.getUserEmail()
    }
    
    // Get current user name
    func getCurrentUserName() -> String? {
        let name = userDefaultsManager.getUserName()
        print("🔍 AuthManager.getCurrentUserName() called, returning: \(name ?? "nil")")
        return name
    }
    
    // Resend OTP (works for both login and registration)
    @MainActor
    func resendOTP(email: String, isRegistration: Bool = false) async throws -> String {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            if isRegistration {
                // Get existing user data if available
                let name = userDefaultsManager.getUserName() ?? ""
                let phone = userDefaultsManager.getUserPhone() ?? ""
                
                // Use the register endpoint to resend OTP
                return try await registerUser(email: email, name: name, phone: phone)
            } else {
                // Use the login endpoint to resend OTP
                return try await requestLoginOTP(email: email)
            }
        } catch {
            print("Resend OTP error: \(error)")
            if let networkError = error as? SimpleNetworkError {
                self.error = networkError.message
            } else {
                self.error = error.localizedDescription
            }
            throw error
        }
    }
} 