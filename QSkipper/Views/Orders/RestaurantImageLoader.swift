//
//  RestaurantImageLoader.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 01/04/25.
//

import SwiftUI

struct RestaurantImageLoader: View {
    let restaurantId: String
    @State private var restaurantImage: UIImage?
    @State private var isLoading = false
    @State private var restaurant: Restaurant?
    
    var body: some View {
        Group {
            if let image = restaurantImage {
                // We have an image loaded from the API
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
                    .clipped()
            } else if isLoading {
                // Loading indicator
                ProgressView()
                    .frame(width: 48, height: 48)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                // Fallback to placeholder or static images
                let imageName = getImageName(for: restaurantId)
                
                if !imageName.isEmpty, let uiImage = UIImage(named: imageName) {
                    // Local image
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    // Default placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "fork.knife")
                            .foregroundColor(.gray)
                            .font(.system(size: 22))
                    }
                }
            }
        }
        .onAppear {
            loadRestaurant()
        }
    }
    
    private func loadRestaurant() {
        // Only start loading if we don't already have an image
        guard restaurantImage == nil, !isLoading else { return }
        
        isLoading = true
        print("📸 Loading restaurant details for ID: \(restaurantId)")
        
        // Use NetworkUtils to get restaurant details and image with user-initiated priority
        Task(priority: .userInitiated) {
            do {
                let fetchedRestaurant = try await NetworkUtils.shared.fetchRestaurant(with: restaurantId)
                await MainActor.run {
                    self.restaurant = fetchedRestaurant
                    print("✅ Successfully loaded restaurant: \(fetchedRestaurant.name)")
                    
                    // If we have a photo ID, load the image
                    if let photoId = fetchedRestaurant.photoId {
                        loadImageFromPhotoId(photoId)
                    } else {
                        // If no photoId, try using the restaurant ID
                        loadImageFromPhotoId(restaurantId)
                    }
                }
            } catch {
                print("❌ Error fetching restaurant data: \(error)")
                
                // As a fallback, try loading image directly using the restaurant ID
                await MainActor.run {
                    loadImageFromPhotoId(restaurantId)
                }
            }
        }
    }
    
    private func loadImageFromPhotoId(_ photoId: String) {
        print("📸 Loading restaurant image with photo ID: \(photoId)")
        
        // Use NetworkUtils to get restaurant image with user-initiated priority
        Task(priority: .userInitiated) {
            do {
                let image = try await NetworkUtils.shared.fetchRestaurantImage(photoId: photoId)
                await MainActor.run {
                    self.restaurantImage = image
                    self.isLoading = false
                    print("✅ Successfully loaded restaurant image for photo ID: \(photoId)")
                }
            } catch {
                print("❌ Error loading restaurant image: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getImageName(for id: String) -> String {
        // Return local image name based on restaurant ID
        switch id {
        case "6661a3534d1e0d993a73e66a":
            return "waffle_co"
        case "6661a3894d1e0d993a73e66c":
            return "burger_king"
        default:
            return "wendys"
        }
    }
    
    private func getImageURL(for id: String) -> URL? {
        // Fallback URLs if local images aren't available
        switch id {
        case "6661a3534d1e0d993a73e66a":
            return URL(string: "https://example.com/waffle_co.jpg")
        case "6661a3894d1e0d993a73e66c":
            return URL(string: "https://example.com/burger_king.jpg")
        default:
            return URL(string: "https://example.com/wendys.jpg")
        }
    }
}

// Remote image loader component
struct RemoteImage: View {
    let url: URL?
    @State private var image: UIImage? = nil
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
            } else {
                // Fallback if image fails to load
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            isLoading = false
            return
        }
        
        // Use Task with appropriate priority to handle image loading
        Task(priority: .userInitiated) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let loadedImage = UIImage(data: data) {
                    await MainActor.run {
                        self.image = loadedImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                print("❌ Error loading remote image: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    HStack {
        RestaurantImageLoader(restaurantId: "6661a3534d1e0d993a73e66a")
        RestaurantImageLoader(restaurantId: "6661a3894d1e0d993a73e66c")
        RestaurantImageLoader(restaurantId: "unknown_id")
    }
    .padding()
} 