//
//  ImageCache.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 30/3/25.
//

import UIKit
import Foundation

// MARK: - ImageCache for caching downloaded images 
// A singleton class for caching images to improve performance and reduce network requests

public class ImageCache {
    public static let shared = ImageCache()
    
    // Memory cache
    private let memoryCache = NSCache<NSString, UIImage>()
    // Disk cache directory URL
    private let diskCacheURL: URL
    
    // Cache configuration
    private let memoryCacheLimit = 50 * 1024 * 1024 // 50 MB
    private let diskCacheLimit = 200 * 1024 * 1024 // 200 MB
    private let diskCacheMaxAgeDays = 7 // 7 days max age for disk cache
    
    // Tracking total disk cache size
    private var estimatedDiskCacheSize: UInt64 = 0
    
    // Queue for disk operations
    private let diskQueue = DispatchQueue(label: "com.qskipper.ImageCache.diskQueue", qos: .utility)
    
    private init() {
        // Configure memory cache
        memoryCache.countLimit = 100 // Maximum number of images to store
        memoryCache.totalCostLimit = memoryCacheLimit
        
        // Create disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("QSkipperImageCache", isDirectory: true)
        
        createDiskCacheDirectory()
        calculateDiskCacheSize()
        
        // Register for memory warning notifications to clear cache when needed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Setup periodic disk cache cleanup
        schedulePeriodicDiskCacheCleanup()
        
        print("ImageCache initialized with \(estimatedDiskCacheSize / 1024 / 1024)MB on disk")
    }
    
    // MARK: - Public methods
    
    public func setImage(_ image: UIImage, forKey key: String) {
        // Calculate a cost based on the image's size in bytes
        let cost = Int(image.size.width * image.size.height * 4) // 4 bytes per pixel (RGBA)
        
        // Store in memory cache
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
        
        // Store in disk cache
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            self.saveToDisk(image: image, key: key, cost: cost)
        }
        
        print("🖼️ CACHE: Stored image for key: \(key), size: \(image.size.width)x\(image.size.height), cost: \(cost) bytes")
    }
    
    public func getImage(forKey key: String) -> UIImage? {
        // First try memory cache
        if let image = memoryCache.object(forKey: key as NSString) {
            print("✅ CACHE HIT: Retrieved image for key: \(key) from memory cache, size: \(image.size.width)x\(image.size.height)")
            return image
        }
        
        // Check if image is currently being loaded
        let fileURL = fileURL(for: key)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Try to load from disk on the main thread if file exists
            // This is faster than waiting for the disk queue and avoids priority inversion
            if let data = try? Data(contentsOf: fileURL),
               let image = UIImage(data: data) {
                
                // Also cache this in memory for faster access next time
                let cost = Int(image.size.width * image.size.height * 4)
                self.memoryCache.setObject(image, forKey: key as NSString, cost: cost)
                
                print("✅ CACHE HIT: Retrieved image for key: \(key) from disk cache, size: \(image.size.width)x\(image.size.height)")
                return image
            }
        }
        
        // If we couldn't load it synchronously, trigger an async load but return nil for now
        // This avoids the thread priority inversion from semaphore.wait
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let image = self.loadFromDisk(key: key) {
                // Cache in memory for next time
                let cost = Int(image.size.width * image.size.height * 4)
                
                // Ensure we update the memory cache on the main thread
                DispatchQueue.main.async {
                    self.memoryCache.setObject(image, forKey: key as NSString, cost: cost)
                }
                
                print("✅ CACHE HIT (async): Retrieved image for key: \(key) from disk cache, size: \(image.size.width)x\(image.size.height)")
            } else {
                print("⛔️ CACHE MISS: No image found for key: \(key)")
            }
        }
        
        // Return nil immediately - the UI will update when the image loads asynchronously
        return nil
    }
    
    public func removeImage(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            
            let fileURL = self.fileURL(for: key)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    @objc public func removeAllImages() {
        clearMemoryCache()
        clearDiskCache()
    }
    
    // MARK: - Memory cache methods
    
    @objc public func clearMemoryCache() {
        memoryCache.removeAllObjects()
        print("Memory cache cleared")
    }
    
    // MARK: - Disk cache methods
    
    private func createDiskCacheDirectory() {
        if !FileManager.default.fileExists(atPath: diskCacheURL.path) {
            do {
                try FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
                print("Created disk cache directory at \(diskCacheURL.path)")
            } catch {
                print("Error creating disk cache directory: \(error)")
            }
        }
    }
    
    private func fileURL(for key: String) -> URL {
        // Create a filename by hashing the key
        let filename = key.hash.description
        return diskCacheURL.appendingPathComponent(filename)
    }
    
    private func saveToDisk(image: UIImage, key: String, cost: Int) {
        let fileURL = fileURL(for: key)
        
        // Convert image to JPEG data
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        do {
            try data.write(to: fileURL)
            estimatedDiskCacheSize += UInt64(data.count)
            
            // Check if we need to trim the cache
            if estimatedDiskCacheSize > UInt64(diskCacheLimit) {
                cleanupDiskCache()
            }
        } catch {
            print("Error writing image to disk: \(error)")
        }
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = fileURL(for: key)
        
        if let data = try? Data(contentsOf: fileURL) {
            return UIImage(data: data)
        }
        
        return nil
    }
    
    private func calculateDiskCacheSize() {
        let fileManager = FileManager.default
        
        guard let fileEnumerator = fileManager.enumerator(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }
        
        estimatedDiskCacheSize = 0
        
        for case let fileURL as URL in fileEnumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                if let fileSize = resourceValues.fileSize {
                    estimatedDiskCacheSize += UInt64(fileSize)
                }
            } catch {
                print("Error calculating size of file \(fileURL): \(error)")
            }
        }
        
        print("Disk cache size: \(estimatedDiskCacheSize / 1024 / 1024)MB")
    }
    
    private func cleanupDiskCache() {
        let fileManager = FileManager.default
        
        // Get all files sorted by creation date
        guard let fileEnumerator = fileManager.enumerator(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }
        
        var filesToDelete: [(url: URL, size: UInt64, date: Date)] = []
        let currentDate = Date()
        
        // Collect files with their properties
        for case let fileURL as URL in fileEnumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                if let fileSize = resourceValues.fileSize,
                   let creationDate = resourceValues.creationDate {
                    
                    // Check if file is too old
                    let age = currentDate.timeIntervalSince(creationDate)
                    if age > Double(diskCacheMaxAgeDays * 24 * 60 * 60) {
                        filesToDelete.append((fileURL, UInt64(fileSize), creationDate))
                    } else {
                        filesToDelete.append((fileURL, UInt64(fileSize), creationDate))
                    }
                }
            } catch {
                print("Error getting properties for file \(fileURL): \(error)")
            }
        }
        
        // Sort files by date (oldest first)
        filesToDelete.sort { $0.date < $1.date }
        
        // Delete oldest files until we're under the limit
        var deletedSize: UInt64 = 0
        let targetSize = estimatedDiskCacheSize - UInt64(diskCacheLimit / 2) // Delete until we're at half capacity
        
        print("Cleaning disk cache, need to remove \(targetSize / 1024 / 1024)MB")
        
        for fileInfo in filesToDelete {
            if deletedSize >= targetSize {
                break
            }
            
            do {
                try fileManager.removeItem(at: fileInfo.url)
                deletedSize += fileInfo.size
            } catch {
                print("Error deleting file \(fileInfo.url): \(error)")
            }
        }
        
        // Update estimated size
        estimatedDiskCacheSize -= deletedSize
        print("Removed \(deletedSize / 1024 / 1024)MB from disk cache")
    }
    
    private func clearDiskCache() {
        let fileManager = FileManager.default
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: diskCacheURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
            
            estimatedDiskCacheSize = 0
            print("Disk cache cleared")
        } catch {
            print("Error clearing disk cache: \(error)")
        }
    }
    
    private func schedulePeriodicDiskCacheCleanup() {
        // Run cleanup once a day
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 86400) { [weak self] in
            guard let self = self else { return }
            
            self.diskQueue.async {
                self.cleanupDiskCache()
                self.schedulePeriodicDiskCacheCleanup() // Schedule next cleanup
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 