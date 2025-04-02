# QSkipper Setup Instructions

After cloning this repository, follow these steps to properly run the project:

## Opening the Project

1. Open the project in Xcode by double-clicking the `QSkipper.xcodeproj` file
2. Wait for Xcode to process and index the files

## Fix Common Issues

If you encounter issues with the project not running in the simulator or errors related to missing files:

### Option 1: Create a New Scheme

1. In Xcode, go to Product > Scheme > Edit Scheme
2. If no scheme is available, click the "+" button to create a new one
3. Select "QSkipper" as the target
4. Make sure "Debug" is selected for the Run configuration
5. Close the scheme editor

### Option 2: Regenerate Project.pbxproj (If still having issues)

This project uses Xcode's File System Synchronization feature, which may cause issues on some setups.

1. Create a new Swift project in Xcode
2. Copy all the source files from QSkipper into the new project
3. Make sure to include:
   - All Swift files
   - Assets.xcassets
   - Info.plist
   - Any other resources

### Option 3: Fix Deployment Target

If you get errors about iOS deployment target being too new:

1. Open QSkipper.xcodeproj/project.pbxproj
2. Find IPHONEOS_DEPLOYMENT_TARGET and change it to match your Xcode's minimum supported version
3. Alternatively, in Xcode navigate to the project settings and adjust the iOS Deployment Target

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