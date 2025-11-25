import SwiftUI
import RevenueCat

@main
struct NoteWallApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var showOnboarding = false
    
    private let onboardingVersion = 3

    init() {
        // Initialize crash reporting
        setupCrashReporting()
        HomeScreenImageManager.prepareStorageStructure()
        configureRevenueCat()
        
        // Check onboarding status on init (only show for first launch)
        let shouldShow = !hasCompletedSetup
        _showOnboarding = State(initialValue: shouldShow)
        
        // Reset paywall data if this is a fresh install
        if !hasCompletedSetup {
            PaywallManager.shared.resetForFreshInstall()
        }
    }

    private func configureRevenueCat() {
        let configuration = Configuration
            .builder(withAPIKey: "test_QBXaIedOSkNmQggXGvcPsQQBIZl")
            .with(entitlementVerificationMode: .informational)
            .build()

        Purchases.configure(with: configuration)
        Purchases.logLevel = .debug
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
            MainTabView()
                .preferredColorScheme(.dark)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(
                        isPresented: $showOnboarding,
                        onboardingVersion: onboardingVersion
                    )
                }
                .onAppear {
                    // Show onboarding only for users who haven't completed setup yet
                    showOnboarding = !hasCompletedSetup
                }
                .onChange(of: hasCompletedSetup) { newValue in
                    showOnboarding = !newValue
                }
                .onOpenURL { url in
                    // Handle URL scheme when app is opened via notewall://
                    // This allows the shortcut to redirect back to the app
                    print("Opened via URL: \(url)")
                    if url.scheme?.lowercased() == "notewall" {
                        let lowerHost = url.host?.lowercased()
                        let lowerPath = url.path.lowercased()
                        if lowerHost == "wallpaper-updated" || lowerPath.contains("wallpaper-updated") {
                            NotificationCenter.default.post(name: .shortcutWallpaperApplied, object: nil)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .onboardingReplayRequested)) { _ in
                    showOnboarding = true
                }
                // MARK: - TESTING ONLY: Listen for reset request
                // TODO: Remove this before production release
                .onReceive(NotificationCenter.default.publisher(for: .requestAppReset)) { _ in
                    resetAppToFreshInstall()
                }
        }
        .commands {
            // MARK: - TESTING ONLY: Reset App Commands
            // TODO: Remove this entire .commands block before production release
            // Multiple shortcuts for easy testing: Cmd+Shift+K, Cmd+B, or Cmd+R
            CommandMenu("Testing") {
                Button("Reset to Fresh Install (Cmd+Shift+K)") {
                    resetAppToFreshInstall()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                
                Button("Reset to Fresh Install (Cmd+B)") {
                    resetAppToFreshInstall()
                }
                .keyboardShortcut("b", modifiers: [.command])
                
                Button("Reset to Fresh Install (Cmd+R)") {
                    resetAppToFreshInstall()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
    
    // MARK: - TESTING ONLY: Reset App Function
    // TODO: Remove this before production release
    private func resetAppToFreshInstall() {
        print("🔄 TESTING: RESETTING APP TO FRESH INSTALL STATE")
        
        // Reset all AppStorage values to defaults (setting to defaults works better than removeObject with @AppStorage)
        UserDefaults.standard.set(Data(), forKey: "savedNotes")
        UserDefaults.standard.removeObject(forKey: "lastLockScreenIdentifier")
        UserDefaults.standard.set(false, forKey: "skipDeletingOldWallpaper")
        UserDefaults.standard.set("", forKey: "autoUpdateWallpaperAfterDeletion")
        UserDefaults.standard.set(false, forKey: "hasShownAutoUpdatePrompt")
        UserDefaults.standard.set("", forKey: "lockScreenBackground")
        UserDefaults.standard.set("", forKey: "lockScreenBackgroundMode")
        UserDefaults.standard.set(Data(), forKey: "lockScreenBackgroundPhotoData")
        UserDefaults.standard.set("", forKey: "homeScreenPresetSelection")
        UserDefaults.standard.set(false, forKey: "hasCompletedInitialWallpaperSetup")
        UserDefaults.standard.set(false, forKey: "hasCompletedSetup")
        UserDefaults.standard.set(0, forKey: "completedOnboardingVersion")
        UserDefaults.standard.set(false, forKey: "homeScreenUsesCustomPhoto")
        UserDefaults.standard.set(false, forKey: "shouldShowTroubleshootingBanner")
        
        // Reset all PaywallManager AppStorage keys to defaults
        UserDefaults.standard.set(0, forKey: "wallpaperExportCount")
        UserDefaults.standard.set(false, forKey: "hasPremiumAccess")
        UserDefaults.standard.set(false, forKey: "hasLifetimeAccess")
        UserDefaults.standard.set(0.0, forKey: "subscriptionExpiryDate")
        UserDefaults.standard.set(false, forKey: "hasSeenPaywall")
        UserDefaults.standard.set(0, forKey: "paywallDismissCount")
        
        // Reset paywall manager state (this also clears the @AppStorage properties)
        PaywallManager.shared.resetForFreshInstall()
        
        // Reset shortcut setup completion flag
        ShortcutVerificationService.resetSetupCompletion()
        
        // Delete all files from Documents/NoteWall directory
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let noteWallURL = documentsURL.appendingPathComponent("NoteWall", isDirectory: true)
            
            if FileManager.default.fileExists(atPath: noteWallURL.path) {
                do {
                    try FileManager.default.removeItem(at: noteWallURL)
                    print("✅ Deleted all wallpaper files")
                } catch {
                    print("❌ Error deleting files: \(error)")
                }
            }
        }
        
        // Force synchronize UserDefaults to ensure all changes are saved
        UserDefaults.standard.synchronize()
        
        print("✅ All data cleared and synchronized")
        print("🎉 Reset complete! App will restart as fresh install.")
        
        // Force app restart by triggering onboarding
        // Set hasCompletedSetup to false and trigger onboarding
        DispatchQueue.main.async {
            // Update the @AppStorage property first - this will trigger onChange
            self.hasCompletedSetup = false
            
            // Post notification to force all views to reload
            NotificationCenter.default.post(name: .appResetToFreshInstall, object: nil)
            
            // Small delay to ensure state is updated, then trigger onboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("📱 Triggering onboarding...")
                NotificationCenter.default.post(name: .onboardingReplayRequested, object: nil)
            }
        }
    }
}
