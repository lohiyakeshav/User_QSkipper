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
            } else {
                // Use a placeholder with gradient instead of a loading indicator
                placeholderView
            }
        }
        .onAppear {
            loadRestaurant()
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            // Generate a consistent gradient based on restaurant ID
            let colors = gradientColors(for: restaurantId)
            
            LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 48, height: 48)
            .cornerRadius(8)
            
            // Show first letter if we have restaurant name
            if let restaurant = restaurant, restaurant.name != "Restaurant" {
                Text(String(restaurant.name.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
        }
    }
    
    private func gradientColors(for id: String) -> [Color] {
        // Generate consistent colors based on the restaurant ID
        let hash = abs(id.hashValue)
        let colorSets: [[Color]] = [
            [Color(hex: "#FF5F6D"), Color(hex: "#FFC371")],
            [Color(hex: "#11998e"), Color(hex: "#38ef7d")],
            [Color(hex: "#FC5C7D"), Color(hex: "#6A82FB")],
            [Color(hex: "#FFAFBD"), Color(hex: "#ffc3a0")],
            [Color(hex: "#2193b0"), Color(hex: "#6dd5ed")],
            [Color(hex: "#C33764"), Color(hex: "#1D2671")]
        ]
        
        return colorSets[hash % colorSets.count]
    }
    
    private func loadRestaurant() {
        // Only start loading if we don't already have an image
        guard restaurantImage == nil, !isLoading else { return }
        
        isLoading = true
        
        // Use NetworkUtils to get restaurant details and image with user-initiated priority
        Task(priority: .userInitiated) {
            do {
                let fetchedRestaurant = try await NetworkUtils.shared.fetchRestaurant(with: restaurantId)
                await MainActor.run {
                    self.restaurant = fetchedRestaurant
                    
                    // If we have a photo ID, load the image
                    if let photoId = fetchedRestaurant.photoId {
                        loadImageFromPhotoId(photoId)
                    } else {
                        // If no photoId, try using the restaurant ID
                        loadImageFromPhotoId(restaurantId)
                    }
                }
            } catch {
                // As a fallback, try loading image directly using the restaurant ID
                await MainActor.run {
                    loadImageFromPhotoId(restaurantId)
                }
            }
        }
    }
    
    private func loadImageFromPhotoId(_ photoId: String) {
        Task {
            do {
                let image = try await NetworkUtils.shared.fetchRestaurantImage(photoId: photoId)
                await MainActor.run {
                    self.restaurantImage = image
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
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