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
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        Group {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
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
        guard let urlString = url, !urlString.isEmpty, imageData == nil else {
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let data = try await SimpleNetworkManager.shared.loadImage(from: urlString)
                
                DispatchQueue.main.async {
                    self.imageData = data
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
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
        guard let photoId = photoId, !photoId.isEmpty, image == nil else {
            useFallback = true
            
            if photoId == nil || photoId?.isEmpty == true {
                print("No photo ID provided for restaurant - using fallback image")
            }
            
            return
        }
        
        print("Loading restaurant image with ID: \(photoId)")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Direct call to the NetworkUtils to fetch restaurant image
                let loadedImage = try await networkUtils.fetchRestaurantImage(photoId: photoId)
                
                DispatchQueue.main.async {
                    self.image = loadedImage
                    self.isLoading = false
                    self.errorMessage = nil
                    self.useFallback = false
                    print("Successfully loaded restaurant image for ID: \(photoId)")
                }
            } catch {
                print("Error loading restaurant image for ID \(photoId): \(error)")
                
                DispatchQueue.main.async {
                    self.useFallback = true
                    self.isLoading = false
                    self.errorMessage = nil
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
    @State private var useFallback = true
    
    private let networkUtils = NetworkUtils.shared
    
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
                gradient: Gradient(colors: [Color(hex: "#76b852"), Color(hex: "#8DC26F")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: categoryIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 35, height: 35)
                        .foregroundColor(.white)
                    
                    if let name = name, !name.isEmpty {
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 24, weight: .bold))
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
    
    private var categoryIcon: String {
        guard let category = category?.lowercased() else {
            return "fork.knife"
        }
        
        if category.contains("veg") || category.contains("vegetable") {
            return "leaf.fill"
        } else if category.contains("dessert") || category.contains("sweet") {
            return "birthday.cake.fill"
        } else if category.contains("drink") || category.contains("juice") || category.contains("beverage") {
            return "cup.and.saucer.fill"
        } else if category.contains("rice") {
            return "sparkles"
        } else if category.contains("fast food") {
            return "flame.fill"
        } else if category.contains("south indian") {
            return "rectangle.grid.2x2.fill"
        } else if category.contains("north india") {
            return "circle.grid.2x2.fill"
        }
        
        return "fork.knife"
    }
    
    private func loadImage() {
        guard let photoId = photoId, !photoId.isEmpty, image == nil else {
            useFallback = true
            
            if photoId == nil || photoId?.isEmpty == true {
                print("No photo ID provided for product - using fallback image")
            }
            
            return
        }
        
        print("Loading product image with ID: \(photoId)")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Direct call to the NetworkUtils to fetch product image
                let loadedImage = try await networkUtils.fetchProductImage(photoId: photoId)
                
                DispatchQueue.main.async {
                    self.image = loadedImage
                    self.useFallback = false
                    self.isLoading = false
                    self.errorMessage = nil
                    print("Successfully loaded product image for ID: \(photoId)")
                }
            } catch {
                print("Error loading product image for ID \(photoId): \(error)")
                
                DispatchQueue.main.async {
                    self.useFallback = true
                    self.isLoading = false
                    self.errorMessage = nil
                }
            }
        }
    }
} 