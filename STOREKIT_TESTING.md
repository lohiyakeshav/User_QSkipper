# QSkipper In-App Purchase Testing Guide

This guide provides quick steps to set up and test in-app purchases in QSkipper.

## Understanding StoreKit Testing Limitations

**Important:** Apple's StoreKit testing environment has limitations regarding dynamic pricing:

1. The StoreKit payment sheet can **only display a fixed price** from the configuration file
2. It cannot dynamically change the displayed price based on your cart total
3. However, our app will still **process the correct payment amount** (your cart total)
4. This is only a limitation in the testing environment - in production, the correct amount will be used

## Quick Start

### Automated Setup

Run the following command in Terminal:

```bash
# Navigate to the QSkipper project directory
cd /path/to/QSkipper

# Run the setup script
./setup_storekit.sh
```

The script will configure everything needed for local StoreKit testing.

### Setting Up Dynamic Pricing for Testing

To make the StoreKit testing UI show a price matching your expected cart amount:

```bash
# Set the default testing price to match your cart amount
./setup_dynamic_pricing.sh 30.00
```

Where `30.00` is the amount you want to display in the StoreKit payment sheet.

### Testing In-App Purchases

1. Open QSkipper.xcodeproj in Xcode
2. Run the app on a simulator or device
3. Navigate to the order flow
4. Complete an order to reach the payment screen
5. Tap "Pay with Apple Pay" or "Simulate Payment" (in debug builds)
6. You'll see a note explaining that the payment sheet will show ₹30.00 (or your configured price)
7. The payment will actually use your cart total, not the displayed price
8. Complete the purchase in the StoreKit testing interface

## How Dynamic Pricing Really Works

Even though the StoreKit testing UI shows a fixed price, the app handles dynamic pricing through this process:

1. The app stores your cart total internally
2. When you tap to pay, it passes this amount to the payment system
3. The payment processor uses this amount, not the one displayed in the UI
4. The API that would allow changing the displayed price (`Product.LocalizedPrice.override`) doesn't exist in this version of StoreKit
5. This is only a display limitation - the actual payment amount will be correct

## Troubleshooting Dynamic Pricing

If you want to test with a different price:
1. Run `./setup_dynamic_pricing.sh <amount>` with your desired test amount
2. Restart the app completely (delete from simulator and rebuild)
3. Add products to your cart
4. Proceed to checkout
5. The payment sheet will show your configured price
6. But the actual payment will use your cart total

## Testing Scenarios

### Local Testing (Default)

When running the app from Xcode, it will use the local StoreKit configuration:
- Purchase transactions are simulated
- No real money is involved
- All transactions will succeed (unless you configure errors in the StoreKit configuration)
- The payment amount will be your cart total, despite what's shown in the UI

### Sandbox Testing (App Store Connect)

For more realistic testing:
1. Create sandbox tester accounts in App Store Connect
2. Create your products in App Store Connect exactly matching the IDs in the app
3. Run a build on a real device (either direct or via TestFlight)
4. Sign out of your normal Apple ID on the test device
5. Make a purchase in the app
6. Sign in with your sandbox tester account when prompted
7. The payment will use your actual cart total

## Troubleshooting

- **No products appear:** Verify the team ID is set correctly and the StoreKit configuration is enabled in the scheme
- **Product IDs don't match:** Ensure product IDs in the app match exactly with App Store Connect
- **Transactions don't complete:** Try resetting the StoreKit environment using the terminal command: `defaults delete com.apple.storeagent`
- **Wrong amount shown:** This is normal - the StoreKit testing UI can only show a fixed price. Use `./setup_dynamic_pricing.sh` to update it.

## Next Steps

For detailed configuration steps and advanced topics, see the full [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) document. 