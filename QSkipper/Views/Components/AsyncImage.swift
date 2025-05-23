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
    @State private var retryCount = 0
    
    private let networkUtils = NetworkUtils.shared
    private let imageCache = ImageCache.shared
    private let maxRetries = 2
    
    var body: some View {
        Group {
            if let image = image, !useFallback {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .allowsHitTesting(false)
            } else {
                fallbackView
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private var fallbackView: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: randomGradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if isLoading {
                // More subtle loading indicator that doesn't disrupt the UI
                VStack(spacing: 8) {
                    // Show restaurant initial or icon
                    if let name = name, !name.isEmpty && name != "Loading..." {
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "fork.knife")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                    }
                    
                    // Small loading indicator
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                    
                    if let name = name, !name.isEmpty && name != "Loading..." {
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Show retry button if loading failed
                    if useFallback && retryCount < maxRetries && !isLoading {
                        Button {
                            retryLoadImage()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.3)))
                        }
                        .padding(.top, 5)
                    }
                }
            }
        }
    }
    
    // Random gradient colors based on restaurant name for consistent fallback display
    private var randomGradientColors: [Color] {
        // Use restaurant name or ID as a seed for consistent gradient
        let seed = (name ?? photoId ?? "default").hash
        var random = Random(seed: UInt64(abs(seed)))
        
        // Predefined gradients for restaurants
        let gradients: [[Color]] = [
            [Color(hex: "#FF5F6D"), Color(hex: "#FFC371")],
            [Color(hex: "#11998e"), Color(hex: "#38ef7d")],
            [Color(hex: "#FC5C7D"), Color(hex: "#6A82FB")],
            [Color(hex: "#FFAFBD"), Color(hex: "#ffc3a0")],
            [Color(hex: "#2193b0"), Color(hex: "#6dd5ed")],
            [Color(hex: "#C33764"), Color(hex: "#1D2671")],
            [Color(hex: "#ee9ca7"), Color(hex: "#ffdde1")],
            [Color(hex: "#ED213A"), Color(hex: "#93291E")],
            [Color(hex: "#FFC837"), Color(hex: "#FF8008")],
            [Color(hex: "#4E65FF"), Color(hex: "#92EFFD")]
        ]
        
        let index = Int(random.next() % UInt64(gradients.count))
        return gradients[index]
    }
    
    private func retryLoadImage() {
        guard retryCount < maxRetries else { return }
        
        retryCount += 1
        isLoading = true
        
        Task {
            await Task.sleep(UInt64(0.5 * 1_000_000_000))
            await loadImage(forceRetry: true)
        }
    }
    
    private func loadImage(forceRetry: Bool = false) {
        guard let photoId = photoId, !photoId.isEmpty else {
            useFallback = true
            
            if photoId == nil || photoId?.isEmpty == true {
                print("No photo ID provided for restaurant - using fallback image")
            }
            
            return
        }
        
        // Check if image is in cache
        if !forceRetry, let cachedImage = imageCache.getImage(forKey: "restaurant_\(photoId)") {
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

// Simple pseudorandom generator for consistent random values when provided the same seed
struct Random {
    private var seed: UInt64
    
    init(seed: UInt64) {
        self.seed = seed
    }
    
    mutating func next() -> UInt64 {
        // XORShift algorithm for pseudorandom generation
        seed ^= seed << 13
        seed ^= seed >> 7
        seed ^= seed << 17
        return seed
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
    @State private var retryCount = 0
    
    private let networkUtils = NetworkUtils.shared
    private let imageCache = ImageCache.shared
    private let maxRetries = 2
    
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
            // Background gradient that varies by category
            categoryGradient
            
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
                
                // Show retry button if loading failed
                if useFallback && retryCount < maxRetries && !isLoading {
                    Button {
                        retryLoadImage()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    .padding(.top, 5)
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
        }
    }
    
    // Category-specific gradient for fallback
    private var categoryGradient: some View {
        let gradientColors: [Color]
        
        if let category = category?.lowercased() {
            switch true {
            case category.contains("pizza"):
                gradientColors = [Color(hex: "#FF5E62"), Color(hex: "#FF9966")]
            case category.contains("burger"):
                gradientColors = [Color(hex: "#FF9966"), Color(hex: "#FF5E62")]
            case category.contains("dessert"), category.contains("sweet"):
                gradientColors = [Color(hex: "#FF7080"), Color(hex: "#FFA8D4")]
            case category.contains("drink"), category.contains("beverage"):
                gradientColors = [Color(hex: "#4E65FF"), Color(hex: "#92EFFD")]
            case category.contains("breakfast"):
                gradientColors = [Color(hex: "#FFC837"), Color(hex: "#FF8008")]
            case category.contains("lunch"):
                gradientColors = [Color(hex: "#1D976C"), Color(hex: "#93F9B9")]
            case category.contains("veg"), category.contains("vegetarian"):
                gradientColors = [Color(hex: "#56AB2F"), Color(hex: "#A8E063")]
            case category.contains("non-veg"), category.contains("meat"):
                gradientColors = [Color(hex: "#CB356B"), Color(hex: "#BD3F32")]
            case category.contains("indian"), category.contains("north indian"):
                gradientColors = [Color(hex: "#FF7E5F"), Color(hex: "#FEB47B")]
            default:
                gradientColors = [Color(hex: "#4E65FF"), Color(hex: "#92EFFD")]
            }
        } else {
            gradientColors = [Color(hex: "#4E65FF"), Color(hex: "#92EFFD")]
        }
        
        return LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
    
    private func retryLoadImage() {
        guard retryCount < maxRetries else { return }
        
        retryCount += 1
        isLoading = true
        
        Task {
            await Task.sleep(UInt64(0.5 * 1_000_000_000))
            await loadImage(forceRetry: true)
        }
    }
    
    private func loadImage(forceRetry: Bool = false) {
        guard let photoId = photoId, !photoId.isEmpty else {
            useFallback = true
            
            if photoId == nil || photoId?.isEmpty == true {
                print("No photo ID provided for product - using fallback image")
            }
            
            return
        }
        
        // Check if image is in cache
        if !forceRetry, let cachedImage = imageCache.getImage(forKey: "product_\(photoId)") {
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