# QSkipper Setup Instructions

After cloning this repository, follow these steps to properly run the project:

## Requirements

- Xcode 15.0 or newer
- iOS 17.0 or newer (app uses iOS 17 features like ContentUnavailableView)
- macOS Sonoma 14.0 or newer recommended

## Opening the Project

1. Open the project in Xcode by double-clicking the `QSkipper.xcodeproj` file
   - Important: This is an Xcode project, NOT a Swift Package. Do not try to open Package.swift (which no longer exists).
2. Wait for Xcode to process and index the files

## Common Issues & Solutions

If you encounter issues with the project not running in the simulator or errors related to missing files:

### Option 1: Create a New Scheme

1. In Xcode, go to Product > Scheme > Edit Scheme
2. If no scheme is available, click the "+" button to create a new one
3. Select "QSkipper" as the target
4. Make sure "Debug" is selected for the Run configuration
5. Close the scheme editor

### Option 2: Check the Project Navigator

Make sure the project navigator shows all your files:

1. If files appear missing, try right-clicking in the Project Navigator
2. Select "Add Files to 'QSkipper'..."
3. Navigate to the QSkipper folder in your cloned repository
4. Select the files or folders that appear to be missing
5. Make sure "Create groups" is selected and click "Add"

### Option 3: Fix Deployment Target

If you get errors about iOS deployment target being too new:

1. Select the QSkipper project in the navigator
2. Go to the "Info" tab in the editor
3. Under "Deployment Info", adjust the iOS Deployment Target to match your Xcode's capabilities

## Signing & Capabilities

1. Select the QSkipper project in the Project Navigator
2. Go to the Signing & Capabilities tab
3. Choose your team from the dropdown
4. If you don't have a team, you can use "Personal Team" with your Apple ID

## Running the App

1. Select an iOS simulator from the device menu
2. Click the Run button (play icon)
3. If the app builds but doesn't launch in the simulator, try cleaning the build folder (Shift+Command+K) and building again

## Troubleshooting

If you continue to experience issues:
- Delete the derived data folder: ~/Library/Developer/Xcode/DerivedData
- Restart Xcode
- Try with a newer version of Xcode if available

# Setting Up and Testing In-App Purchases

This guide provides comprehensive instructions for configuring and testing in-app purchases for QSkipper using Apple's Sandbox environment.

## 1. Automated Setup Script (Recommended)

We've provided an automated script to simplify the StoreKit setup process:

1. Open Terminal
2. Navigate to the QSkipper project directory: `cd /path/to/QSkipper`
3. Run the setup script: `./setup_storekit.sh`
4. The script will:
   - Update the team ID in the StoreKit configuration file
   - Verify that StoreKit testing is configured in the Xcode scheme
   - Display the current bundle identifier for verification

## 2. Manual Configuration

### Update Team ID in StoreKit Configuration File
1. Open `/QSkipper/Configuration/QSkipper_StoreKit.storekit`
2. Replace `"_developerTeamID" : "REPLACE_WITH_YOUR_TEAM_ID"` with your actual Apple Developer Team ID
   - Team ID: `team.qskipper@gmail.com`

### Configure Xcode for StoreKit Testing
1. Open your project scheme: Product → Scheme → Edit Scheme
2. Select "Run" and then click on the "Options" tab
3. Check "StoreKit Configuration" and select `QSkipper_StoreKit.storekit`

## 3. App Store Connect Configuration

### Create Products in App Store Connect
1. Log into [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to "My Apps" → QSkipper → "In-App Purchases"
3. Click "+" to add a new IAP
4. Select "Consumable" for both products
5. Enter product details exactly matching your StoreKit file:
   - Product ID: `com.qskipper.orderpayment`
   - Reference Name: "Order Payment"
   - Display Name: "Order Payment"
   - Description: "Order payment for QSkipper" 
   - Price: 9.99
   
   And for the wallet top-up:
   - Product ID: `com.queueskipper.wallet.10000`
   - Reference Name: "Wallet Top-up ₹10,000"
   - Display Name: "₹10,000 Wallet Top-up"
   - Description: "Add ₹10,000 to your wallet"
   - Price: 100.00

## 4. Create Sandbox Tester Accounts

1. In App Store Connect, go to Users and Access → Sandbox → Testers
2. Click "+" to add a new tester
3. Fill in the required information:
   - First Name, Last Name
   - Email Address (use an email you control but haven't used for Apple ID)
   - Password (must meet Apple ID requirements)
   - Country or Region (India)
4. Click "Create"

## 5. Testing In-App Purchases

### 5.1. Local Testing (StoreKit Configuration File)
This uses Xcode's local StoreKit testing environment without requiring App Store Connect setup:

1. Run the app in Xcode with the StoreKit configuration enabled (see above)
2. Navigate to the payment flow
3. The payment sheet will appear but will use local testing instead of real StoreKit

### 5.2. Sandbox Testing (TestFlight or Development Build)
This tests the actual StoreKit integration with App Store's sandbox environment:

1. Ensure your app has the correct Bundle ID matching App Store Connect
2. Configure your Info.plist with the required StoreKit entitlements
3. Create a build for testing (either run on device or submit to TestFlight)
4. On your testing device, sign out of your normal Apple ID
5. Launch the app and initiate a payment
6. When prompted, sign in with your sandbox tester account
7. Complete the purchase flow

## 6. Troubleshooting

### Common Issues and Solutions

#### No Products Available
- Verify product IDs match exactly between code and App Store Connect
- Check that all required fields are completed in App Store Connect
- Products must be in "Ready to Submit" status
- Your app must have "Prepare for Submission" status minimum

#### Sandbox Account Issues
- Don't sign into the App Store with the sandbox account
- Only use the sandbox account when prompted during the purchase flow
- If a sandbox account gets stuck, create a new one

#### Transaction Issues
- If purchases aren't working in Sandbox, try: `defaults delete com.apple.storeagent` in Terminal
- For transaction history reset in simulator: `xcrun simctl privacy <simulator_id> grant com.apple.commerce.payment`

## 7. Receipt Validation

For production, implement proper receipt validation:
- The app sends the receipt to your server
- Your server validates the receipt with Apple's verification API
- Remember to use different endpoints for sandbox vs. production:
  - Sandbox: `https://sandbox.itunes.apple.com/verifyReceipt`
  - Production: `https://buy.itunes.apple.com/verifyReceipt`

## Support

If you encounter issues with the StoreKit integration, check the Xcode logs for detailed error messages and refer to Apple's StoreKit documentation for further guidance. 