# QSkipper

QSkipper is a food ordering application for iOS.

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
   - If using in-app purchases for testing, ensure the StoreKit configuration is properly set up
   - Check that the StoreKit configuration file exists at `QSkipper/Configuration/QSkipper_StoreKit.storekit`

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 