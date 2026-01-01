# RevenueCat Integration Guide for FaithWall

This guide documents the complete RevenueCat SDK integration for the FaithWall app.

## ✅ Completed Integration

### 1. SDK Installation
- ✅ RevenueCat SDK is installed via Swift Package Manager
- ✅ Package: `https://github.com/RevenueCat/purchases-ios-spm.git`
- ✅ Version: 5.49.0 (as of latest update)

### 2. Configuration
- ✅ API Key: `test_cAcCMUiEpxcTKyHXVvsZAeGWjxu` (test key configured)
- ✅ Entitlement: `Faithwall Unlimited`
- ✅ Entitlement Verification Mode: Informational

### 3. Products Configured
- ✅ Monthly Subscription: `monthly`
- ✅ Lifetime Purchase: `lifetime`

### 4. Features Implemented

#### PaywallManager (`PaywallManager.swift`)
- ✅ RevenueCat connection and initialization
- ✅ Customer info retrieval and caching
- ✅ Offerings loading
- ✅ Purchase handling
- ✅ Restore purchases
- ✅ Entitlement checking for "Faithwall Unlimited"
- ✅ Subscription status tracking
- ✅ Trial period detection
- ✅ Error handling

#### RevenueCat Paywalls UI (`RevenueCatPaywallView.swift`)
- ✅ Native RevenueCat Paywalls UI integration
- ✅ Purchase completion handling
- ✅ Restore purchases support
- ✅ Error handling with user feedback
- ✅ Fallback to custom paywall if RevenueCat UI unavailable

#### Customer Center (`RevenueCatCustomerCenterView`)
- ✅ RevenueCat Customer Center integration
- ✅ Subscription management
- ✅ Fallback to App Store settings if unavailable

## 📋 Setup Instructions

### Step 1: Configure RevenueCat Dashboard

1. **Create/Login to RevenueCat Account**
   - Go to https://app.revenuecat.com
   - Create account or login

2. **Create a New App**
   - Click "Add App"
   - Enter app name: "FaithWall"
   - Select platform: iOS
   - Enter Bundle ID: `com.app.faithwall` (check your Info.plist)

3. **Configure Products**
   - Go to Products section
   - Add products:
     - **Monthly**: Product ID `monthly`, Type: Subscription
     - **Lifetime**: Product ID `lifetime`, Type: Non-Consumable

4. **Create Entitlement**
   - Go to Entitlements section
   - Create entitlement: `Faithwall Unlimited`
   - Attach products:
     - `monthly` → `Faithwall Unlimited`
     - `lifetime` → `Faithwall Unlimited`

5. **Create Offerings**
   - Go to Offerings section
   - Create a default offering (e.g., "default")
   - Add packages:
     - Monthly package with `monthly` product
     - Lifetime package with `lifetime` product

### Step 2: Update API Key for Production

When ready for production, update the API key in `FaithWallApp.swift`:

```swift
private func configureRevenueCat() {
    let configuration = Configuration
        .builder(withAPIKey: "YOUR_PRODUCTION_API_KEY") // Replace with production key
        .with(entitlementVerificationMode: .informational)
        .build()
    
    Purchases.configure(with: configuration)
    Purchases.shared.delegate = PaywallManager.shared
    PaywallManager.shared.connectRevenueCat()
}
```

**Important**: 
- Test key starts with `test_`
- Production key starts with `appl_`
- Never commit production keys to version control

### Step 3: Test the Integration

1. **Test Purchases**
   - Use RevenueCat's test mode
   - Test with sandbox accounts
   - Verify entitlement activation

2. **Test Restore**
   - Test restore purchases functionality
   - Verify customer info updates

3. **Test Customer Center**
   - Open Settings → Premium section
   - Tap on active subscription
   - Verify Customer Center opens

## 🔧 Usage Examples

### Showing RevenueCat Paywall

```swift
import SwiftUI

struct MyView: View {
    @State private var showPaywall = false
    
    var body: some View {
        Button("Upgrade") {
            showPaywall = true
        }
        .sheet(isPresented: $showPaywall) {
            if #available(iOS 15.0, *) {
                RevenueCatPaywallView(
                    displayCloseButton: true,
                    onDismiss: {
                        // Handle dismissal
                    }
                )
            }
        }
    }
}
```

### Checking Premium Status

```swift
let paywallManager = PaywallManager.shared

if paywallManager.isPremium {
    // User has active subscription or lifetime
    print("User is premium!")
}

// Check specific entitlement
if paywallManager.hasActiveRevenueCatEntitlement {
    print("User has 'Faithwall Unlimited' entitlement")
}
```

### Opening Customer Center

```swift
// In SettingsView, this is already implemented
if paywallManager.canPresentCustomerCenter {
    showCustomerCenter = true
}
```

### Making a Purchase

```swift
Task {
    guard let package = paywallManager.monthlyPackage else { return }
    
    do {
        try await paywallManager.purchase(package: package)
        print("Purchase successful!")
    } catch {
        print("Purchase failed: \(error.localizedDescription)")
    }
}
```

### Restoring Purchases

```swift
Task {
    await paywallManager.restoreRevenueCatPurchases()
    // Customer info will be updated automatically
}
```

## 📱 Best Practices

### 1. Always Check Entitlements
```swift
// ✅ Good: Check entitlement status
if paywallManager.hasActiveRevenueCatEntitlement {
    // Grant access
}

// ❌ Bad: Don't rely on local flags alone
if paywallManager.hasPremiumAccess {
    // This might be stale
}
```

### 2. Handle Errors Gracefully
```swift
do {
    try await paywallManager.purchase(package: package)
} catch {
    if let rcError = error as? ErrorCode {
        switch rcError {
        case .purchaseCancelledError:
            // User cancelled - don't show error
            break
        default:
            // Show error to user
            showError(error.localizedDescription)
        }
    }
}
```

### 3. Refresh Customer Info Regularly
```swift
// Refresh on app launch
Task {
    await paywallManager.refreshCustomerInfo()
}

// Refresh after purchase
// This is handled automatically by PurchasesDelegate
```

### 4. Use RevenueCat Paywalls When Possible
```swift
// ✅ Good: Use native RevenueCat UI
RevenueCatPaywallView()

// ⚠️ Fallback: Use custom paywall if needed
PaywallView(triggerReason: .manual)
```

## 🔍 Debugging

### Enable Debug Logging

Add to `FaithWallApp.swift`:

```swift
private func configureRevenueCat() {
    let configuration = Configuration
        .builder(withAPIKey: "test_cAcCMUiEpxcTKyHXVvsZAeGWjxu")
        .with(entitlementVerificationMode: .informational)
        .with(usesStoreKit2: true) // Use StoreKit 2 if available
        .with(observerMode: false) // Set to true if using observer mode
        .build()
    
    Purchases.logLevel = .debug // Enable debug logging
    Purchases.configure(with: configuration)
    // ...
}
```

### Check Customer Info

```swift
Task {
    let customerInfo = try await Purchases.shared.customerInfo()
    print("Active Entitlements: \(customerInfo.entitlements.active)")
    print("All Entitlements: \(customerInfo.entitlements.all)")
    print("Active Subscriptions: \(customerInfo.activeSubscriptions)")
}
```

## 🚨 Common Issues

### Issue: Entitlement Not Activating
**Solution**: 
1. Verify entitlement name matches exactly: `Faithwall Unlimited`
2. Check product IDs match: `monthly`, `lifetime`
3. Verify products are attached to entitlement in RevenueCat dashboard

### Issue: Products Not Loading
**Solution**:
1. Check API key is correct
2. Verify products exist in App Store Connect
3. Check offerings are configured in RevenueCat dashboard
4. Ensure products are approved in App Store Connect

### Issue: Customer Center Not Showing
**Solution**:
1. Ensure RevenueCatUI is imported: `#if canImport(RevenueCatUI)`
2. Check iOS version (requires iOS 15.0+)
3. Verify RevenueCat Paywalls package is included

## 📚 Additional Resources

- [RevenueCat iOS Documentation](https://www.revenuecat.com/docs/getting-started/installation/ios)
- [RevenueCat Paywalls Documentation](https://www.revenuecat.com/docs/tools/paywalls)
- [Customer Center Documentation](https://www.revenuecat.com/docs/tools/customer-center)
- [RevenueCat iOS SDK Reference](https://www.revenuecat.com/docs/ios)

## 🔐 Security Notes

1. **API Keys**: Never commit production API keys to version control
2. **Entitlement Verification**: Consider using `.enforced` mode in production
3. **Server-Side Validation**: For critical features, validate on your backend
4. **Test Mode**: Always test with sandbox accounts before production

## ✅ Checklist Before Production

- [ ] Replace test API key with production key
- [ ] Verify all products are configured in App Store Connect
- [ ] Test purchases with sandbox accounts
- [ ] Test restore purchases
- [ ] Verify entitlement activation
- [ ] Test Customer Center functionality
- [ ] Enable entitlement verification (consider `.enforced` mode)
- [ ] Test error handling
- [ ] Verify analytics events are firing
- [ ] Test on multiple devices
- [ ] Test subscription renewal flow

---

**Last Updated**: December 2024
**SDK Version**: 5.49.0
**Entitlement**: Faithwall Unlimited




