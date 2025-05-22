# QSkipper

QSkipper is a cutting-edge food ordering application for iOS designed specifically for university campuses. It allows students and faculty to seamlessly order food from campus cafeterias and nearby restaurants, skipping long queues and saving valuable time.

![QSkipper](https://github.com/yourusername/QSkipper/blob/main/QSkipper/Assets.xcassets/AppIcon.appiconset/1024.png)

## Features

- **Campus Restaurant Discovery**: Browse restaurants on and around campus
- **Menu Exploration**: View detailed menus with high-quality food images
- **Smart Ordering**: Place orders with customization options
- **Real-time Tracking**: Monitor order status from preparation to delivery 
- **Order History**: Access past orders for quick reordering
- **Favorites**: Save preferred restaurants and dishes for quick access
- **Location Services**: Find nearby food options and delivery locations
- **Integrated Payments**: Secure checkout with multiple payment options
- **User Profiles**: Manage personal information and preferences

## Technology Stack

QSkipper is built using modern iOS development practices:

- **SwiftUI**: For a beautiful and responsive UI
- **MVVM Architecture**: Clean separation of concerns
- **Combine Framework**: Reactive programming for asynchronous operations
- **CoreLocation**: For location-based services
- **StoreKit**: For in-app purchases and payments

## Setup Instructions

### Prerequisites
- Xcode 14.0 or later
- iOS 15.0+ Simulator or device
- Swift 5.9+

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/QSkipper.git
   cd QSkipper
   ```

2. **Open the project in Xcode**
   ```bash
   open QSkipper.xcodeproj
   ```

3. **Resolve Package Dependencies**
   - After opening the project in Xcode, wait for Swift Package Manager to fetch and resolve dependencies.
   - If dependencies are not resolving automatically, go to `File > Packages > Resolve Package Versions`.

4. **Setup Signing & Capabilities**
   - Select the `QSkipper` target in Xcode
   - Go to the Signing & Capabilities tab
   - Select your Team and update the Bundle Identifier if needed

5. **Build Configuration**
   - Make sure the active scheme is set to `QSkipper`
   - Select your preferred simulator or device

6. **Run the Application**
   - Press Command+R or click the Run button

### Troubleshooting

If the app builds but doesn't run after cloning:

1. **Check Xcode Version**:
   - This project requires Xcode 14.0 or later

2. **Clean Build Folder**:
   - Select `Product > Clean Build Folder` in Xcode
   - Then try building and running again

3. **Regenerate Project Files**:
   - Close Xcode
   - Delete `.build` and `DerivedData` folders
   - Reopen the project and try again

4. **Reset iOS Simulator**:
   - Go to `iOS Simulator > Device > Erase All Content and Settings`
   - Try running the app again

5. **StoreKit Configuration**:
   - For in-app purchases testing, refer to the [STOREKIT_TESTING.md](STOREKIT_TESTING.md) guide
   - The configuration file should exist at `QSkipper/Configuration/QSkipper_StoreKit.storekit`

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## About the Team

QSkipper is the brainchild of Keshav Lohiya and his dedicated team, who poured their heart and soul into creating an application that transforms the campus dining experience. Their vision to eliminate long food queues and streamline the ordering process has resulted in this elegant, user-friendly solution.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 