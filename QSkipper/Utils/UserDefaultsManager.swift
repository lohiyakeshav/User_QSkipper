//
//  UserDefaultsManager.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import Foundation

class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let userDefaults = UserDefaults.standard
    private let keychainManager = KeychainManager.shared
    
    // Keys
    private let tokenKey = "user_token"
    private let userIdKey = "userID"
    private let userEmailKey = "user_email"
    private let userNameKey = "user_name"
    private let userPhoneKey = "user_phone"
    private let isLoggedInKey = "is_logged_in"
    
    private init() {}
    
    // MARK: - User Authentication
    
    func saveUserToken(_ token: String) {
        // Save token to keychain instead of UserDefaults for better security
        // without triggering Apple ID verification
        _ = keychainManager.saveString(token, forKey: tokenKey)
    }
    
    func getUserToken() -> String? {
        return keychainManager.getString(forKey: tokenKey)
    }
    
    func saveUserId(_ userId: String) {
        userDefaults.set(userId, forKey: userIdKey)
    }
    
    func getUserId() -> String? {
        return userDefaults.string(forKey: userIdKey)
    }
    
    func saveUserEmail(_ email: String) {
        userDefaults.set(email, forKey: userEmailKey)
    }
    
    func getUserEmail() -> String? {
        return userDefaults.string(forKey: userEmailKey)
    }
    
    func saveUserName(_ name: String) {
        print("📝 SAVING USERNAME: \(name) with key: \(userNameKey)")
        userDefaults.synchronize() // Make sure data is flushed before
        userDefaults.set(name, forKey: userNameKey)
        userDefaults.synchronize() // Force immediate write
        
        // Verify the save worked
        let savedName = userDefaults.string(forKey: userNameKey)
        print("📝 VERIFICATION - Saved username: \(savedName ?? "nil")")
    }
    
    func getUserName() -> String? {
        let name = userDefaults.string(forKey: userNameKey)
        print("📱 UserDefaultsManager.getUserName() called, key=\(userNameKey), value=\(name ?? "nil")")
        return name
    }
    
    func saveUserPhone(_ phone: String) {
        userDefaults.set(phone, forKey: userPhoneKey)
    }
    
    func getUserPhone() -> String? {
        return userDefaults.string(forKey: userPhoneKey)
    }
    
    func setUserLoggedIn(_ isLoggedIn: Bool) {
        userDefaults.set(isLoggedIn, forKey: isLoggedInKey)
    }
    
    func isUserLoggedIn() -> Bool {
        return userDefaults.bool(forKey: isLoggedInKey)
    }
    
    func saveUser(_ user: User) {
        saveUserId(user.id)
        saveUserEmail(user.email)
        if let name = user.name {
            saveUserName(name)
        }
        if let phone = user.phone {
            saveUserPhone(phone)
        }
        if let token = user.token {
            saveUserToken(token)
        }
        setUserLoggedIn(true)
    }
    
    func savePartialUser(id: String, email: String, username: String) {
        saveUserId(id)
        saveUserEmail(email)
        saveUserName(username)
        // Don't set logged in here - only after OTP is verified
    }
    
    // Clear all user-related data
    func clearUserData() {
        for key in [userIdKey, userEmailKey, userNameKey, userPhoneKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Remove token from keychain
        _ = keychainManager.deleteItem(forKey: tokenKey)
        
        setUserLoggedIn(false)
    }
} 