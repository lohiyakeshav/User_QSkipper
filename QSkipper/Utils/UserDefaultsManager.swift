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
    
    // Keys
    private let tokenKey = "user_token"
    private let userIdKey = "user_id"
    private let userEmailKey = "user_email"
    private let userNameKey = "user_name"
    private let userPhoneKey = "user_phone"
    private let isLoggedInKey = "is_logged_in"
    
    private init() {}
    
    // MARK: - User Authentication
    
    func saveUserToken(_ token: String) {
        userDefaults.set(token, forKey: tokenKey)
    }
    
    func getUserToken() -> String? {
        return userDefaults.string(forKey: tokenKey)
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
        userDefaults.set(name, forKey: userNameKey)
    }
    
    func getUserName() -> String? {
        return userDefaults.string(forKey: userNameKey)
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
    
    func clearUserData() {
        userDefaults.removeObject(forKey: tokenKey)
        userDefaults.removeObject(forKey: userIdKey)
        userDefaults.removeObject(forKey: userEmailKey)
        userDefaults.removeObject(forKey: userNameKey)
        userDefaults.removeObject(forKey: userPhoneKey)
        setUserLoggedIn(false)
    }
} 