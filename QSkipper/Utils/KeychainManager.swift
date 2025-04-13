//
//  KeychainManager.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import Foundation
import Security

/// A utility class for securely storing data in the keychain without triggering Apple ID verification
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    /// Save a string value securely in the keychain
    /// - Parameters:
    ///   - value: The string value to save
    ///   - key: The key to associate with the value
    /// - Returns: A boolean indicating success or failure
    func saveString(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return saveData(data, forKey: key)
    }
    
    /// Retrieve a string value from the keychain
    /// - Parameter key: The key associated with the value
    /// - Returns: The string value if found, nil otherwise
    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Save binary data securely in the keychain
    /// - Parameters:
    ///   - data: The data to save
    ///   - key: The key to associate with the data
    /// - Returns: A boolean indicating success or failure
    func saveData(_ data: Data, forKey key: String) -> Bool {
        // First, attempt to delete any existing item
        deleteItem(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            // This prevents iCloud sync and Apple ID verification
            kSecAttrSynchronizable as String: false
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve binary data from the keychain
    /// - Parameter key: The key associated with the data
    /// - Returns: The data if found, nil otherwise
    func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            // This prevents iCloud sync and Apple ID verification
            kSecAttrSynchronizable as String: false
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return data
    }
    
    /// Delete an item from the keychain
    /// - Parameter key: The key of the item to delete
    /// - Returns: A boolean indicating success or failure
    func deleteItem(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            // This prevents iCloud sync and Apple ID verification
            kSecAttrSynchronizable as String: false
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Clear all keychain items for the app
    /// - Returns: A boolean indicating success or failure
    func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
} 