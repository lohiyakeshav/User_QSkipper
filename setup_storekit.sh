#!/bin/bash

# Script to set up StoreKit testing in QSkipper

echo "🔄 Setting up StoreKit for Testing..."
echo "------------------------------------"

# Variables
STOREKIT_CONFIG_PATH="QSkipper/Configuration/QSkipper_StoreKit.storekit"
SCHEME_PATH="QSkipper.xcodeproj/xcshareddata/xcschemes/QSkipper.xcscheme"
TEAM_ID="team.qskipper@gmail.com"

# Check if the StoreKit configuration file exists
if [ ! -f "$STOREKIT_CONFIG_PATH" ]; then
    echo "❌ StoreKit configuration file not found at: $STOREKIT_CONFIG_PATH"
    exit 1
fi

# 1. Update the team ID in the StoreKit configuration file
echo "📝 Updating team ID in StoreKit configuration file..."
sed -i '' "s/\"_developerTeamID\" : \"[^\"]*\"/\"_developerTeamID\" : \"$TEAM_ID\"/" "$STOREKIT_CONFIG_PATH"
echo "✅ Team ID updated to: $TEAM_ID"

# 2. Check if the scheme already has StoreKit configuration
if grep -q "StoreKitConfigurationFileReference" "$SCHEME_PATH"; then
    echo "✅ StoreKit configuration is already set up in the Xcode scheme"
else
    echo "❌ StoreKit configuration is not set up in the Xcode scheme"
    echo "🔧 You need to manually configure it:"
    echo "   1. Open Xcode"
    echo "   2. Go to Product > Scheme > Edit Scheme"
    echo "   3. Select 'Run' and then the 'Options' tab"
    echo "   4. Check the 'StoreKit Configuration' checkbox"
    echo "   5. Select '$STOREKIT_CONFIG_PATH' from the dropdown"
fi

# 3. Verify bundle identifier
BUNDLE_ID=$(grep -A 1 "PRODUCT_BUNDLE_IDENTIFIER" QSkipper.xcodeproj/project.pbxproj | head -1 | sed 's/.*= \(.*\);/\1/')
echo "📱 Current bundle identifier: $BUNDLE_ID"
echo "   ⚠️ Make sure this matches your App Store Connect configuration"

# 4. Done!
echo "------------------------------------"
echo "✅ StoreKit setup complete!"
echo "   📱 Run the app in Xcode to test in-app purchases in the sandbox environment"
echo "   💡 Remember to create sandbox test accounts in App Store Connect" 