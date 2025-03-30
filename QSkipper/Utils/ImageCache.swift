//
//  ImageCache.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 30/3/25.
//

import UIKit

// MARK: - ImageCache for caching downloaded images 
// A singleton class for caching images to improve performance and reduce network requests

public class ImageCache {
    public static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        // Set cache limits to prevent memory issues
        cache.countLimit = 100 // Maximum number of images to store
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB limit
        
        // Register for memory warning notifications to clear cache when needed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        print("ImageCache initialized")
    }
    
    public func setImage(_ image: UIImage, forKey key: String) {
        // Calculate a cost based on the image's size in bytes
        let cost = Int(image.size.width * image.size.height * 4) // 4 bytes per pixel (RGBA)
        cache.setObject(image, forKey: key as NSString, cost: cost)
        print("🖼️ CACHE: Stored image for key: \(key), size: \(image.size.width)x\(image.size.height), cost: \(cost) bytes")
    }
    
    public func getImage(forKey key: String) -> UIImage? {
        let image = cache.object(forKey: key as NSString)
        if let image = image {
            print("✅ CACHE HIT: Retrieved image for key: \(key), size: \(image.size.width)x\(image.size.height)")
            return image
        } else {
            print("⛔️ CACHE MISS: No image found for key: \(key)")
            return nil
        }
    }
    
    public func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    @objc public func removeAllImages() {
        cache.removeAllObjects()
    }
    
    @objc public func clearCache() {
        removeAllImages()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 