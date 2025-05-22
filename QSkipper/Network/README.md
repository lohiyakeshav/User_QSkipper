# QSkipper Networking Layer

This directory contains the networking components for the QSkipper app, which have been refactored to provide a more robust, maintainable, and resilient networking architecture.

## Key Components

### 1. APIClient

The `APIClient` is a singleton that handles all network requests in the app. It provides:

- **Centralized request handling**: All API requests go through a single client
- **Fallback mechanism**: If the primary server (Render) returns a 503 error, the client automatically retries the request to the secondary server (Railway)
- **Rate limiting**: Prevents excessive API calls by limiting requests to once every 30 seconds per endpoint
- **Robust error handling**: Provides detailed error information and standardized error types
- **Request retries**: Automatically retries failed network requests with exponential backoff
- **Image loading and caching**: Handles loading and caching of images with multiple fallback options

### 2. APIEndpoints

Contains all API endpoint paths in one place for easy reference and maintenance.

### 3. NetworkUtils, SimpleNetworkManager, and OrderAPIService

Legacy network classes that have been updated to delegate to the APIClient, ensuring backward compatibility while taking advantage of the new architecture.

### 4. NetworkDiagnostics

Provides tools for diagnosing network connectivity issues, updated to use the APIClient.

## How to Use

### Making API Requests

```swift
// Basic request
do {
    let data = try await APIClient.shared.request(
        path: "/get_All_Restaurant",
        method: "GET"
    )
    // Process the data
} catch let error as APIClient.APIError {
    // Handle the error
}

// POST request with body
let orderData: [String: Any] = [
    "userId": userId,
    "restaurantId": restaurantId,
    "items": items,
    // ...
]

do {
    let orderId = try await APIClient.shared.placeOrder(orderData: orderData)
    // Use the order ID
} catch {
    // Handle error
}
```

### Loading Images

```swift
// Load an image with caching and automatic fallback
let imageURL = "\(baseURL)/get_restaurant_photo/\(photoId)"
do {
    let image = try await APIClient.shared.loadImage(from: imageURL)
    // Use the image
} catch {
    // Handle error or use placeholder
}
```

## Architecture Benefits

1. **Reduced redundancy**: Common networking code is now in one place
2. **Improved resilience**: Automatic fallback between servers when one is down
3. **Server cost optimization**: Free Render server is tried first, Railway (paid) is only used when necessary
4. **Rate limiting**: Prevents accidental API spamming and reduces server load
5. **Better maintainability**: Centralized request handling makes it easier to add logging, monitoring, or change the API behavior

## Implementation Details

- Primary server: `https://qskipper-server-2ul5.onrender.com`
- Secondary server: `https://qskipperserver-production.up.railway.app`
- Rate limit: Maximum 1 request per endpoint every 30 seconds
- Retry mechanism: Exponential backoff (1s, 2s, 4s, 8s) with up to 3 retries
- Fallback triggers: HTTP 503 Service Unavailable errors 