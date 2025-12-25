import SwiftUI
import RevenueCat
import TelemetryDeck

@main
struct FaithWallApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("hasCompletedBibleLanguageSetup") private var hasCompletedBibleSetup = false
    @State private var showOnboarding = false
    @State private var showBibleSetup = false
    
    private let onboardingVersion = 3
    
    // Quick Actions integration
    @StateObject private var quickActionsManager = QuickActionsManager.shared
    
    // AppDelegate for handling Quick Actions
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Initialize crash reporting
        setupCrashReporting()
        HomeScreenImageManager.prepareStorageStructure()
        configureRevenueCat()
        
        // Initialize TelemetryDeck for analytics
        let telemetryConfig = TelemetryDeck.Config(appID: "F406962D-0C75-41A0-82DB-01AC06B8E21A")
        TelemetryDeck.initialize(config: telemetryConfig)
        
        // Check onboarding status on init (only show for first launch)
        let shouldShowOnboarding = !hasCompletedSetup
        _showOnboarding = State(initialValue: shouldShowOnboarding)
        
        // Check if Bible setup needs to be shown (after onboarding)
        let shouldShowBible = hasCompletedSetup && !hasCompletedBibleSetup
        _showBibleSetup = State(initialValue: shouldShowBible)
        
        // Reset paywall data if this is a fresh install
        if !hasCompletedSetup {
            PaywallManager.shared.resetForFreshInstall()
        }
        
        // Register Quick Actions for exit-intercept strategy
        QuickActionsManager.shared.registerQuickActions()
    }

    private func configureRevenueCat() {
        // Configure RevenueCat with test API key
        // For production, replace with your production API key
        let configuration = Configuration
            .builder(withAPIKey: "test_cAcCMUiEpxcTKyHXVvsZAeGWjxu")
            .with(entitlementVerificationMode: .informational)
            .build()

        Purchases.configure(with: configuration)
        Purchases.shared.delegate = PaywallManager.shared
        
        // Connect to RevenueCat and load initial data
        PaywallManager.shared.connectRevenueCat()
    }
    
    private func setupCrashReporting() {
        // Enable crash reporting in production
        CrashReporter.isEnabled = true
        
        // Set app version for crash reports
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            CrashReporter.setCustomKey("app_version", value: "\(version) (\(build))")
        }
        
        // Set device info
        CrashReporter.setCustomKey("device_model", value: UIDevice.current.model)
        CrashReporter.setCustomKey("ios_version", value: UIDevice.current.systemVersion)
        
        CrashReporter.logMessage("App launched", level: .info)
        
        // To enable Firebase Crashlytics, uncomment below and add Firebase SDK:
        /*
        import FirebaseCore
        import FirebaseCrashlytics
        
        FirebaseApp.configure()
        
        // Enable Crashlytics collection
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        */
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    // Show onboarding directly for first-time users (no flash of empty homepage)
                    OnboardingView(
                        isPresented: $showOnboarding,
                        onboardingVersion: onboardingVersion
                    )
                } else if showBibleSetup {
                    // Show Bible language selection after onboarding
                    FirstLaunchBibleSetupView(hasCompletedBibleSetup: $hasCompletedBibleSetup)
                } else {
                    // Show main app for users who have completed setup
                    MainTabView()
                        .onAppear {
                            // Handle Quick Action if app was launched via one
                            if let triggeredAction = quickActionsManager.triggeredAction {
                                print("🎬 FaithWallApp: App launched with Quick Action - \(triggeredAction.title)")
                                
                                // Post notification after a longer delay to ensure MainTabView is ready
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    print("📤 FaithWallApp: Posting quick action notification")
                                    NotificationCenter.default.post(
                                        name: .quickActionTriggered,
                                        object: triggeredAction
                                    )
                                }
                            }
                        }
                        .onOpenURL { url in
                            // Handle URL scheme when app is opened via faithwall://
                            // This allows the shortcut to redirect back to the app
                            print("🔗 FaithWallApp: Opened via URL: \(url)")
                            print("🔗 Scheme: \(url.scheme ?? "nil"), Host: \(url.host ?? "nil"), Path: \(url.path)")
                            
                            if url.scheme?.lowercased() == "faithwall" {
                                let lowerHost = url.host?.lowercased()
                                let lowerPath = url.path.lowercased()
                                if lowerHost == "wallpaper-updated" || lowerPath.contains("wallpaper-updated") {
                                    print("✅ FaithWallApp: Posting .shortcutWallpaperApplied notification")
                                    NotificationCenter.default.post(name: .shortcutWallpaperApplied, object: nil)
                                } else {
                                    print("⚠️ FaithWallApp: URL doesn't match wallpaper-updated pattern")
                                }
                            }
                        }
                }
            }
            .onAppear {
                // Lock orientation to portrait on app launch
                // Note: Orientation locking is primarily handled by Info.plist and AppDelegate
                // This onAppear is a backup attempt, but the main control is in AppDelegate.supportedInterfaceOrientationsFor
                if #available(iOS 16.0, *) {
                    // iOS 16+ - orientation is controlled by Info.plist, AppDelegate, and SceneDelegate
                    // The requestGeometryUpdate API may not be available or may have different signature
                    // Rely on AppDelegate and SceneDelegate methods instead
                } else {
                    // iOS 15 and below - orientation is controlled by Info.plist and AppDelegate
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                }
            }
            .onChange(of: hasCompletedSetup) { newValue in
                // Update onboarding state when setup completion changes
                if newValue {
                    showOnboarding = false
                    // After onboarding, show Bible setup if not done
                    if !hasCompletedBibleSetup {
                        showBibleSetup = true
                    }
                } else {
                    showOnboarding = true
                }
            }
            .onChange(of: hasCompletedBibleSetup) { newValue in
                // Hide Bible setup when completed
                if newValue {
                    showBibleSetup = false
                }
            }
            .onChange(of: PaywallManager.shared.isPremium) { _ in
                // Update Quick Actions when premium status changes
                QuickActionsManager.shared.refreshQuickActions()
            }
            .onReceive(NotificationCenter.default.publisher(for: .onboardingReplayRequested)) { _ in
                // Allow replaying onboarding from settings
                showOnboarding = true
            }
        }
    }
}
