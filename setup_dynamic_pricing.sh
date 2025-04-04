#!/bin/bash

# Dynamic pricing configuration script for QSkipper

echo "🔧 Configuring Dynamic Pricing for StoreKit Testing..."
echo "----------------------------------------------------"

# Variables
STOREKIT_CONFIG_PATH="QSkipper/Configuration/QSkipper_StoreKit.storekit"
TEST_PRICE=${1:-"30.00"}  # Default to 30.00 if no price provided

# Check if the StoreKit configuration file exists
if [ ! -f "$STOREKIT_CONFIG_PATH" ]; then
    echo "❌ StoreKit configuration file not found at: $STOREKIT_CONFIG_PATH"
    exit 1
fi

# 1. Update the product price in the StoreKit configuration file
echo "📝 Updating product price to ₹$TEST_PRICE in StoreKit configuration file..."
sed -i '' "s/\"displayPrice\" : \"[0-9]*\.[0-9]*\",/\"displayPrice\" : \"$TEST_PRICE\",/" "$STOREKIT_CONFIG_PATH"

# 2. Also update the product display name and description to reflect the new price
echo "📝 Updating product display name and description..."
sed -i '' "s/\"description\" : \"Pay for your order (₹[0-9]*\.[0-9]*)\"/\"description\" : \"Pay for your order (₹$TEST_PRICE)\"/" "$STOREKIT_CONFIG_PATH"
sed -i '' "s/\"displayName\" : \"Order Payment (₹[0-9]*\.[0-9]*)\"/\"displayName\" : \"Order Payment (₹$TEST_PRICE)\"/" "$STOREKIT_CONFIG_PATH"

echo "✅ Display price updated to: ₹$TEST_PRICE"

# 3. Make the script informative about the changes
echo "⚠️ IMPORTANT: StoreKit Testing UI Limitations"
echo "   - In the StoreKit testing environment, we can only display a fixed price"
echo "   - The payment sheet will show ₹$TEST_PRICE"
echo "   - However, the app will actually use your cart total for the payment amount"
echo "   - This is only a display limitation in the test environment"
echo "   - In production with real App Store, this will work correctly"

# 4. Instructions for testing
echo ""
echo "🧪 To test dynamic pricing:"
echo "   1. Delete the app from the simulator/device"
echo "   2. Clean build folder in Xcode (Shift+Command+K)"
echo "   3. Build and run the app"
echo "   4. Create a cart with any amount"
echo "   5. Go to checkout"
echo "   6. You'll see a note under the payment buttons explaining the price difference"
echo "   7. The payment sheet will show ₹$TEST_PRICE"
echo "   8. But the actual payment will use your cart total"

# 5. Extra information about StoreKit limitations
echo ""
echo "📚 Technical note: StoreKit Testing UI Constraints"
echo "   - Apple's StoreKit Testing API doesn't allow dynamic price display in the payment sheet"
echo "   - The Product.LocalizedPrice.override API doesn't exist in this version of StoreKit"
echo "   - Our solution: We show a fixed price in UI but process the correct amount"
echo "   - This script helps match the displayed price to what you expect to see"

echo "----------------------------------------------------"
echo "✅ Configuration complete!" 