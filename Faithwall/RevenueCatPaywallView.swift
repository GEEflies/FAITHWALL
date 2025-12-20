import SwiftUI
import RevenueCat
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

/// Modern RevenueCat Paywalls UI wrapper for FaithWall
/// This provides a native RevenueCat paywall experience with customization
@available(iOS 15.0, *)
struct RevenueCatPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paywallManager = PaywallManager.shared
    
    let displayCloseButton: Bool
    let onDismiss: (() -> Void)?
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(displayCloseButton: Bool = true, onDismiss: (() -> Void)? = nil) {
        self.displayCloseButton = displayCloseButton
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        #if canImport(RevenueCatUI)
        if #available(iOS 15.0, *) {
            PaywallView(
                displayCloseButton: displayCloseButton
            ) { customerInfo in
                // Purchase completed successfully
                handlePurchaseSuccess(customerInfo: customerInfo)
            } onRestore: { customerInfo in
                // Restore completed successfully
                handleRestoreSuccess(customerInfo: customerInfo)
            } onFailure: { error in
                // Purchase or restore failed
                handleError(error)
            }
            .onAppear {
                // Refresh offerings when paywall appears
                Task {
                    await paywallManager.loadOfferings(force: true)
                }
            }
        } else {
            fallbackPaywall
        }
        #else
        fallbackPaywall
        #endif
    }
    
    #if canImport(RevenueCatUI)
    @available(iOS 15.0, *)
    private var fallbackPaywall: some View {
        PaywallView(triggerReason: .manual)
    }
    #else
    private var fallbackPaywall: some View {
        PaywallView(triggerReason: .manual)
    }
    #endif
    
    private func handlePurchaseSuccess(customerInfo: CustomerInfo) {
        // Update customer info in PaywallManager
        paywallManager.handleCustomerInfoUpdate(customerInfo: customerInfo)
        
        // Dismiss paywall
        dismiss()
        onDismiss?()
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func handleRestoreSuccess(customerInfo: CustomerInfo) {
        // Update customer info in PaywallManager
        paywallManager.handleCustomerInfoUpdate(customerInfo: customerInfo)
        
        // Show success message
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

// MARK: - Customer Center View
@available(iOS 15.0, *)
struct RevenueCatCustomerCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paywallManager = PaywallManager.shared
    
    var body: some View {
        #if canImport(RevenueCatUI)
        if #available(iOS 15.0, *) {
            CustomerCenterView(
                displayCloseButton: true
            ) { customerInfo in
                // Customer info updated
                paywallManager.handleCustomerInfoUpdate(customerInfo: customerInfo)
            } onFailure: { error in
                // Error loading customer center
                print("❌ Customer Center Error: \(error.localizedDescription)")
            }
        } else {
            fallbackView
        }
        #else
        fallbackView
        #endif
    }
    
    private var fallbackView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.appAccent)
                
                Text("Manage Subscription")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("To manage your subscription, please visit the App Store settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Open App Store Settings") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - PaywallManager Extension for Customer Info Handling
extension PaywallManager {
    /// Handles customer info updates from RevenueCat Paywalls UI
    /// This is a convenience method that calls the main handle method
    func handleCustomerInfoUpdate(customerInfo: CustomerInfo) {
        handle(customerInfo: customerInfo)
    }
}

