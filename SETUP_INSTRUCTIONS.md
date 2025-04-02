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