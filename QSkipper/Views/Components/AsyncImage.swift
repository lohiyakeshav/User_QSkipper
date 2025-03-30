//
//  AsyncImage.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI

struct QAsyncImage: View {
    var url: String?
    var placeholder: Image
    
    @State private var imageData: Data? = nil
    @State private var image: UIImage? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    private let imageCache = ImageCache.shared
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                ZStack {
                    placeholder
                        .resizable()
                        .scaledToFill()
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryGreen))
                    }
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let urlString = url, !urlString.isEmpty, image == nil else {
            return
        }
        
        // Check if image is in cache
        if let cachedImage = imageCache.getImage(forKey: urlString) {
            print("Using cached image for URL: \(urlString)")
            self.image = cachedImage
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let data = try await SimpleNetworkManager.shared.loadImage(from: urlString)
                
                await MainActor.run {
                    if let uiImage = UIImage(data: data) {
                        self.image = uiImage
                        
                        // Cache the loaded image
                        self.imageCache.setImage(uiImage, forKey: urlString)
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = nil // Don't show errors to users
                    self.isLoading = false
                    print("Failed to load image from \(urlString): \(error.localizedDescription)")
                }
            }
        }
    }
}

struct RestaurantImageView: View {
    var photoId: String?
    var name: String?
    
    @State private var image: UIImage? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var useFallback = false
    
    private let networkUtils = NetworkUtils.shared
    private let imageCache = ImageCache.shared
    
    var body: some View {
        Group {
            if let image = image, !useFallback {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackView
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private var fallbackView: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#FF5F6D"), Color(hex: "#FFC371")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                    
                    if let name = name, !name.isEmpty {
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if let error = errorMessage, !useFallback {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .multilineTextAlignment(.center)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    private func loadImage() {
        guard let photoId = photoId, !photoId.isEmpty else {
            useFallback = true
            
            if photoId == nil || photoId?.isEmpty == true {
                print("No photo ID provided for restaurant - using fallback image")
            }
            
            return
        }
        
        // Check if image is in cache
        if let cachedImage = imageCache.getImage(forKey: "restaurant_\(photoId)") {
            print("Using cached restaurant image for ID: \(photoId)")
            self.image = cachedImage
            self.useFallback = false
            return
        }
        
        print("Loading restaurant image with ID: \(photoId)")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Direct call to the NetworkUtils to fetch restaurant image
                let loadedImage = try await networkUtils.fetchRestaurantImage(photoId: photoId)
                
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                    self.errorMessage = nil
                    self.useFallback = false
                    
                    // Cache the loaded image (though the network util already does this)
                    self.imageCache.setImage(loadedImage, forKey: "restaurant_\(photoId)")
                    
                    print("Successfully loaded restaurant image for ID: \(photoId)")
                }
            } catch {
                print("Error loading restaurant image for ID \(photoId): \(error)")
                
                await MainActor.run {
                    self.useFallback = true
                    self.isLoading = false
                    self.errorMessage = nil // Don't show errors to users
                }
            }
        }
    }
}

struct ProductImageView: View {
    var photoId: String?
    var name: String?
    var category: String?
    
    @State private var image: UIImage? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var useFallback = false
    
    private let networkUtils = NetworkUtils.shared
    private let imageCache = ImageCache.shared
    
    var body: some View {
        ZStack {
            if let image = image, !useFallback {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            } else {
                fallbackView
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private var fallbackView: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#4E65FF"), Color(hex: "#92EFFD")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                // Food icon based on category
                Image(systemName: categoryIcon)
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.9))
                
                // Product name if available
                if let name = name {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .lineLimit(2)
                }
            }
        }
    }
    
    // Returns a system icon name based on the food category
    private var categoryIcon: String {
        guard let category = category?.lowercased() else {
            return "fork.knife"
        }
        
        if category.contains("pizza") {
            return "circle.grid.2x1.fill"
        } else if category.contains("burger") {
            return "square.stack.fill"
        } else if category.contains("dessert") || category.contains("sweet") {
            return "birthday.cake.fill"
        } else if category.contains("drink") || category.contains("beverage") {
            return "cup.and.saucer.fill"
        } else if category.contains("soup") {
            return "bowl.fill"
        } else if category.contains("salad") {
            return "leaf.fill"
        } else if category.contains("breakfast") {
            return "sunrise.fill"
        } else {
            return "fork.knife"
        }
    }
    
    private func loadImage() {
        guard let photoId = photoId, !photoId.isEmpty else {
            useFallback = true
            
            if photoId == nil || photoId?.isEmpty == true {
                print("No photo ID provided for product - using fallback image")
            }
            
            return
        }
        
        // Check if image is in cache
        if let cachedImage = imageCache.getImage(forKey: "product_\(photoId)") {
            print("Using cached product image for ID: \(photoId)")
            self.image = cachedImage
            self.useFallback = false
            return
        }
        
        print("Loading product image with ID: \(photoId)")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Direct call to the NetworkUtils to fetch product image
                let loadedImage = try await networkUtils.fetchProductImage(photoId: photoId)
                
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                    self.errorMessage = nil
                    self.useFallback = false
                    
                    // Cache the loaded image (though the network util already does this)
                    self.imageCache.setImage(loadedImage, forKey: "product_\(photoId)")
                    
                    print("Successfully loaded product image for ID: \(photoId)")
                }
            } catch {
                print("Error loading product image for ID \(photoId): \(error)")
                
                await MainActor.run {
                    self.useFallback = true
                    self.isLoading = false
                    self.errorMessage = nil // Don't show errors to users
                }
            }
        }
    }
} 