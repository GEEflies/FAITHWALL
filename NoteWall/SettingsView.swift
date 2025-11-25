import SwiftUI
import PhotosUI
import UIKit
import Combine

struct SettingsView: View {
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("skipDeletingOldWallpaper") private var skipDeletingOldWallpaper = false
    @AppStorage("autoUpdateWallpaperAfterDeletion") private var autoUpdateWallpaperAfterDeletionRaw: String = ""
    
    // Computed property for auto-update preference
    private var autoUpdateWallpaperAfterDeletion: Bool? {
        get {
            if autoUpdateWallpaperAfterDeletionRaw.isEmpty {
                return nil
            }
            return autoUpdateWallpaperAfterDeletionRaw == "true"
        }
        set {
            if let value = newValue {
                autoUpdateWallpaperAfterDeletionRaw = value ? "true" : "false"
            } else {
                autoUpdateWallpaperAfterDeletionRaw = ""
            }
        }
    }
    @AppStorage("lockScreenBackground") private var lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
    @AppStorage("lockScreenBackgroundMode") private var lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
    @AppStorage("lockScreenBackgroundPhotoData") private var lockScreenBackgroundPhotoData: Data = Data()
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0
    @AppStorage("homeScreenUsesCustomPhoto") private var homeScreenUsesCustomPhoto = false
    @StateObject private var paywallManager = PaywallManager.shared
    @State private var showDeleteAlert = false
    @State private var showResetAlert = false
    @State private var showPaywall = false
    @State private var showTroubleshooting = false
    @State private var shouldRestartOnboarding = false
    var selectedTab: Binding<Int>?

    private let shortcutURL = "https://www.icloud.com/shortcuts/5c43e6ec791e4a90b8172bda31243e5c"
    private let testFlightShortcutURL = "https://www.icloud.com/shortcuts/1c815657ac7c446a996d505032471cea"
    
    // Detect if running from TestFlight
    private var isTestFlightBuild: Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("sandboxReceipt")
    }
    
    // Get the appropriate shortcut URL based on build type
    private var currentShortcutURL: String {
        return isTestFlightBuild ? testFlightShortcutURL : shortcutURL
    }
    init(selectedTab: Binding<Int>? = nil) {
        self.selectedTab = selectedTab
    }

    @AppStorage("homeScreenPresetSelection") private var homeScreenPresetSelectionRaw = ""
    @State private var isSavingHomeScreenPhoto = false
    @State private var homeScreenStatusMessage: String?
    @State private var homeScreenStatusColor: Color = .gray
    @State private var isSavingLockScreenBackground = false
    @State private var lockScreenBackgroundStatusMessage: String?
    @State private var lockScreenBackgroundStatusColor: Color = .gray
    @State private var showLegalDocument = false
    @State private var selectedLegalDocument: LegalDocumentType = .termsOfService

    var body: some View {
        NavigationView {
            settingsList
                .listStyle(.insetGrouped)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .alert("Delete All Notes?", isPresented: $showDeleteAlert) {
                    Button("Cancel", role: .cancel) {
                        // Light impact haptic for alert dismissal
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                    Button("Delete", role: .destructive) {
                        deleteAllNotes()
                    }
                } message: {
                    Text("This action cannot be undone. All your notes will be permanently deleted.")
                }
                .alert("Reinstall Shortcut?", isPresented: $showResetAlert) {
                    Button("Cancel", role: .cancel) {
                        // Light impact haptic for alert dismissal
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                    Button("Reset & Reinstall", role: .destructive) {
                        resetToFreshInstall()
                    }
                } message: {
                    Text("This will reset the app to fresh install state and guide you through reinstalling the shortcut. All app data including notes, wallpapers, and settings will be deleted.")
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private var settingsList: some View {
        List {
            premiumSection
            homeScreenSection
            actionsSection
            wallpaperSettingsSection
            supportSection
        }
        .sheet(isPresented: $showPaywall) {
            if #available(iOS 15.0, *) {
                PaywallView(triggerReason: .settings, allowDismiss: true)
            }
        }
        .sheet(isPresented: $showTroubleshooting) {
            TroubleshootingView(
                isPresented: $showTroubleshooting,
                shouldRestartOnboarding: $shouldRestartOnboarding
            )
        }
        .sheet(isPresented: $showLegalDocument) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(getLegalDocumentContent())
                            .font(.system(.body, design: .default))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                }
                .navigationTitle(selectedLegalDocument.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showLegalDocument = false
                        }
                    }
                }
            }
        }
        .onChange(of: shouldRestartOnboarding) { shouldRestart in
            if shouldRestart {
                // Reset to fresh install state to force onboarding
                hasCompletedSetup = false
                completedOnboardingVersion = 0
                shouldRestartOnboarding = false
            }
        }
    }
    
    private var premiumSection: some View {
        Section {
            if paywallManager.isPremium {
                Button(action: openSubscriptionManagement) {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.appAccent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NoteWall+ Active")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(paywallManager.hasLifetimeAccess ? "Lifetime Access" : "Subscription Active")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.appAccent)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    paywallManager.resetPaywallData()
                    paywallManager.showPaywall(reason: .settings)
                }) {
                    HStack {
                        Text("Revert to Paywall (Test)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    // Light impact haptic for opening paywall
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    showPaywall = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(.appAccent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade to NoteWall+")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(paywallManager.remainingFreeExports) free wallpapers remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var wallpaperSettingsSection: some View {
        Section(header: Text("Wallpaper Settings")) {
            Toggle(isOn: Binding(
                get: { skipDeletingOldWallpaper },
                set: { newValue in
                    skipDeletingOldWallpaper = newValue
                    // Light impact haptic for toggle switch
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skip Deleting Old Wallpapers")
                    Text("When enabled, old wallpapers won't be deleted automatically. This avoids system permission popups.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if autoUpdateWallpaperAfterDeletion != nil {
                Toggle(isOn: Binding(
                    get: { autoUpdateWallpaperAfterDeletion ?? false },
                    set: { newValue in
                        autoUpdateWallpaperAfterDeletionRaw = newValue ? "true" : "false"
                        // Light impact haptic for toggle switch
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-Update After Deletion")
                        Text("When enabled, your lock screen wallpaper will automatically update when you delete notes.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var homeScreenSection: some View {
        if #available(iOS 16.0, *) {
            Section("Wallpapers") {
                HomeScreenPhotoPickerView(
                    isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                    homeScreenStatusMessage: $homeScreenStatusMessage,
                    homeScreenStatusColor: $homeScreenStatusColor,
                    homeScreenImageAvailable: Binding(
                        get: { homeScreenUsesCustomPhoto },
                        set: { homeScreenUsesCustomPhoto = $0 }
                    ),
                    handlePickedHomeScreenData: handlePickedHomeScreenData
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)

                HomeScreenQuickPresetsView(
                    isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                    homeScreenStatusMessage: $homeScreenStatusMessage,
                    homeScreenStatusColor: $homeScreenStatusColor,
                    homeScreenImageAvailable: Binding(
                        get: { homeScreenUsesCustomPhoto },
                        set: { homeScreenUsesCustomPhoto = $0 }
                    ),
                    handlePickedHomeScreenData: handlePickedHomeScreenData
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)

                LockScreenBackgroundPickerView(
                    isSavingBackground: $isSavingLockScreenBackground,
                    statusMessage: $lockScreenBackgroundStatusMessage,
                    statusColor: $lockScreenBackgroundStatusColor,
                    backgroundMode: Binding(
                        get: { LockScreenBackgroundMode(rawValue: lockScreenBackgroundModeRaw) ?? .default },
                        set: { lockScreenBackgroundModeRaw = $0.rawValue }
                    ),
                    backgroundOption: Binding(
                        get: { LockScreenBackgroundOption(rawValue: lockScreenBackgroundRaw) ?? .default },
                        set: { lockScreenBackgroundRaw = $0.rawValue }
                    ),
                    backgroundPhotoData: Binding(
                        get: { lockScreenBackgroundPhotoData },
                        set: { lockScreenBackgroundPhotoData = $0 }
                    ),
                    backgroundPhotoAvailable: !lockScreenBackgroundPhotoData.isEmpty
                )
                .listRowInsets(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)

                UpdateWallpaperButton()
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 20, leading: 0, bottom: 12, trailing: 0))
            }
            .onAppear(perform: ensureCustomHomePhotoFlagIsAccurate)
        } else {
            Section(header: Text("Wallpapers")) {
                Text("Save a home screen image requires iOS 16 or newer.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
            }
            .onAppear(perform: ensureCustomHomePhotoFlagIsAccurate)
        }
    }

    private var actionsSection: some View {
        Section(header: Text("Actions")) {
            Button(action: {
                // Medium impact haptic for destructive delete action
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showDeleteAlert = true
            }) {
                HStack {
                    Text("Delete All Notes")
                        .foregroundColor(.red)
                    Spacer()
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            Button(action: {
                // Medium impact haptic for destructive reset action
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                showResetAlert = true
            }) {
                HStack {
                    Text("Reinstall Shortcut")
                        .foregroundColor(.cyan)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.cyan)
                }
            }
            
            // MARK: - TESTING ONLY: Reset App Button
            // TODO: Remove this before production release
            #if DEBUG
            Button(action: {
                // Medium impact haptic
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                NotificationCenter.default.post(name: .requestAppReset, object: nil)
            }) {
                HStack {
                    Text("🧪 Reset to Fresh Install (Testing)")
                        .foregroundColor(.orange)
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.orange)
                }
            }
            #endif
            
            Button(action: {
                showTroubleshooting = true
            }) {
                HStack {
                    Text("Wallpaper Not Showing?")
                        .foregroundColor(.appAccent)
                    Spacer()
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(.appAccent)
                }
            }
        }
    }

    private var supportSection: some View {
        Section(header: Text("Support & Legal")) {
            Button(action: {
                if let url = URL(string: "mailto:iosnotewall@gmail.com") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Text("Contact Support")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "envelope")
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {
                selectedLegalDocument = .termsOfService
                showLegalDocument = true
            }) {
                HStack {
                    Text("Terms of Service")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {
                selectedLegalDocument = .privacyPolicy
                showLegalDocument = true
            }) {
                HStack {
                    Text("Privacy Policy")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "hand.raised")
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {
                shareApp()
            }) {
                HStack {
                    Text("Share NoteWall")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func deleteAllNotes() {
        // Medium impact haptic for destructive delete action (already triggered on button tap, but adding here for confirmation)
        savedNotesData = Data()
        // Switch back to Home tab after deleting notes
        if let selectedTab = selectedTab {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                selectedTab.wrappedValue = 0
            }
        }
    }

    
    private func resetToFreshInstall() {
        print("🔄 RESETTING APP TO FRESH INSTALL STATE")
        
        // 1. Clear all AppStorage values
        savedNotesData = Data()
        skipDeletingOldWallpaper = false
        lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
        lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
        lockScreenBackgroundPhotoData = Data()
        hasCompletedSetup = false
        completedOnboardingVersion = 0
        homeScreenUsesCustomPhoto = false
        homeScreenPresetSelectionRaw = ""
        
        // Clear other AppStorage keys that might exist
        UserDefaults.standard.removeObject(forKey: "lastLockScreenIdentifier")
        UserDefaults.standard.removeObject(forKey: "hasCompletedInitialWallpaperSetup")
        
        // Reset paywall data for fresh install
        PaywallManager.shared.resetForFreshInstall()
        
        // Reset shortcut setup completion flag
        ShortcutVerificationService.resetSetupCompletion()
        
        print("✅ Cleared all AppStorage data")
        
        // 2. Delete all files from Documents/NoteWall directory
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
        
        print("🎉 Reset complete! App is now in fresh install state.")
        print("   Triggering onboarding...")
        
        // 3. Trigger onboarding
        NotificationCenter.default.post(name: .onboardingReplayRequested, object: nil)
        
        // 4. Switch to Home tab
        if let selectedTab = selectedTab {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                selectedTab.wrappedValue = 0
            }
        }
    }

    @available(iOS 16.0, *)
    fileprivate func handlePickedHomeScreenData(_ data: Data) {
        // Light impact haptic for photo picker selection
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        isSavingHomeScreenPhoto = true
        homeScreenStatusMessage = "Saving photo…"
        homeScreenStatusColor = .gray

        Task {
            do {
                guard let image = UIImage(data: data) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }
                try HomeScreenImageManager.saveHomeScreenImage(image)

                await MainActor.run {
                    homeScreenUsesCustomPhoto = true
                    homeScreenStatusMessage = nil
                    homeScreenStatusColor = .gray
                    homeScreenPresetSelectionRaw = ""
                }
            } catch {
                await MainActor.run {
                    homeScreenStatusMessage = error.localizedDescription
                    homeScreenStatusColor = .red
                }
            }

            await MainActor.run {
                isSavingHomeScreenPhoto = false
                isSavingLockScreenBackground = false
            }
        }
    }
}

private struct UpdateWallpaperButton: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isGenerating = false

    var body: some View {
        Button(action: triggerUpdate) {
            HStack(spacing: 12) {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(isGenerating ? "Updating…" : "Update Wallpaper Now")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Color.appAccent)
            .foregroundColor(.white)
            .cornerRadius(12)
            .animation(.easeInOut(duration: 0.2), value: isGenerating)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
        .padding(.horizontal, 16)
        .onReceive(NotificationCenter.default.publisher(for: .requestWallpaperUpdate)) { _ in
            isGenerating = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperGenerationFinished)) { _ in
            isGenerating = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutWallpaperApplied)) { _ in
            isGenerating = false
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                isGenerating = false
            }
        }
    }

    private func triggerUpdate() {
        guard !isGenerating else { return }
        
        // Light impact haptic for update wallpaper button tap
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        isGenerating = true
        // Settings wallpaper changes do NOT count toward free limit
        let request = WallpaperUpdateRequest(skipDeletionPrompt: false, trackForPaywall: false)
        NotificationCenter.default.post(name: .requestWallpaperUpdate, object: request)
    }
}

#Preview {
    SettingsView()
}

private extension SettingsView {
    private func ensureCustomHomePhotoFlagIsAccurate() {
        let shouldBeEnabled = homeScreenPresetSelectionRaw.isEmpty && HomeScreenImageManager.homeScreenImageExists()
        if homeScreenUsesCustomPhoto != shouldBeEnabled {
            homeScreenUsesCustomPhoto = shouldBeEnabled
        }
    }
    
    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    @available(iOS 13.0, *)
    private func shareApp() {
        let shareText = """
        Just discovered NoteWall - it turns your lock screen into a productivity powerhouse! 🚀
        
        See your goals every time you unlock your phone. Game changer! 
        
        #ProductivityHack #NoteWall #LockScreen
        """
        
        let appURL = URL(string: "https://apps.apple.com/app/notewall")!
        let items = [shareText, appURL] as [Any]
        
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // For iPad support
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func getLegalDocumentContent() -> String {
        switch selectedLegalDocument {
        case .termsOfService:
            return """
            Terms of Service
            
            Last Updated: November 13, 2025
            
            1. Acceptance of Terms
            
            By downloading, installing, or using NoteWall ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.
            
            2. Description of Service
            
            NoteWall is a productivity application that allows users to create custom wallpapers with personal notes and reminders for their iOS devices.
            
            3. Subscription Terms
            
            • NoteWall+ Monthly: Monthly subscription with automatic renewal
            • NoteWall+ Lifetime: One-time payment for permanent access
            • Free trial periods may be offered for subscription plans
            • Subscriptions automatically renew unless cancelled 24 hours before renewal
            • Manage subscriptions in your Apple ID account settings
            
            4. User Obligations
            
            You agree to use the App only for lawful purposes and in accordance with these Terms.
            
            5. Privacy
            
            Your privacy is important to us. All notes and personal data are stored locally on your device and are not transmitted to our servers.
            
            6. Contact Information
            
            For questions or support, contact us at: iosnotewall@gmail.com
            
            Developer: NoteWall Team
            """
        case .privacyPolicy:
            return """
            Privacy Policy
            
            Last Updated: November 13, 2025
            
            1. Information We Collect
            
            • Notes and text you create (stored locally on your device only)
            • Photos you select for wallpapers (processed locally)
            • Device information for app compatibility
            • Anonymous performance data to improve the app
            
            2. How We Use Information
            
            • Provide wallpaper generation functionality
            • Process in-app purchases through Apple's App Store
            • Improve app performance and fix bugs
            • Provide customer support
            
            3. Data Storage
            
            • All personal content is stored locally on your device
            • We do not upload your personal content to external servers
            • Your data remains private and under your control
            
            4. Contact
            
            Email: iosnotewall@gmail.com
            Developer: NoteWall Team
            """
        case .termsAndPrivacy:
            return """
            TERMS OF SERVICE & PRIVACY POLICY
            
            Last Updated: November 13, 2025
            
            ═══════════════════════════════════════
            PART I: END-USER LICENSE AGREEMENT (EULA)
            ═══════════════════════════════════════
            
            1. ACKNOWLEDGEMENT
            
            This End-User License Agreement ("EULA") is a legal agreement between you ("End-User") and NoteWall Team ("Developer") for the NoteWall mobile application ("Licensed Application"). This EULA is concluded between you and the Developer only, and not with Apple Inc. ("Apple"). The Developer, not Apple, is solely responsible for the Licensed Application and its content. The EULA may not provide for usage rules for Licensed Applications that are in conflict with the Apple Media Services Terms and Conditions.
            
            2. SCOPE OF LICENSE
            
            The license granted to the End-User for the Licensed Application must be limited to a non-transferable license to use the Licensed Application on any Apple-branded Products that the End-User owns or controls and as permitted by the Usage Rules set forth in the Apple Media Services Terms and Conditions, except that such Licensed Application may be accessed and used by other accounts associated with the purchaser via Family Sharing or volume purchasing.
            
            3. MAINTENANCE AND SUPPORT
            
            You must be solely responsible for providing any maintenance and support services with respect to the Licensed Application, as specified in the EULA, or as required under applicable law. You and the End-User must acknowledge that Apple has no obligation whatsoever to furnish any maintenance and support services with respect to the Licensed Application.
            
            Contact for support: iosnotewall@gmail.com
            
            4. WARRANTY
            
            You must be solely responsible for any product warranties, whether express or implied by law, to the extent not effectively disclaimed. The EULA must provide that, in the event of any failure of the Licensed Application to conform to any applicable warranty, the End-User may notify Apple, and Apple will refund the purchase price for the Licensed Application to that End-User; and that, to the maximum extent permitted by applicable law, Apple will have no other warranty obligation whatsoever with respect to the Licensed Application, and any other claims, losses, liabilities, damages, costs or expenses attributable to any failure to conform to any warranty will be Your sole responsibility.
            
            5. PRODUCT CLAIMS
            
            You and the End-User must acknowledge that You, not Apple, are responsible for addressing any claims of the End-User or any third party relating to the Licensed Application or the end-user's possession and/or use of that Licensed Application, including, but not limited to: (i) product liability claims; (ii) any claim that the Licensed Application fails to conform to any applicable legal or regulatory requirement; and (iii) claims arising under consumer protection, privacy, or similar legislation, including in connection with Your Licensed Application's use of the HealthKit and HomeKit frameworks. The EULA may not limit Your liability to the End-User beyond what is permitted by applicable law.
            
            6. INTELLECTUAL PROPERTY RIGHTS
            
            You and the End-User must acknowledge that, in the event of any third party claim that the Licensed Application or the End-User's possession and use of that Licensed Application infringes that third party's intellectual property rights, You, not Apple, will be solely responsible for the investigation, defense, settlement and discharge of any such intellectual property infringement claim.
            
            7. LEGAL COMPLIANCE
            
            The End-User must represent and warrant that (i) he/she is not located in a country that is subject to a U.S. Government embargo, or that has been designated by the U.S. Government as a "terrorist supporting" country; and (ii) he/she is not listed on any U.S. Government list of prohibited or restricted parties.
            
            8. DEVELOPER NAME AND ADDRESS
            
            Developer Name: NoteWall Team
            Address: Slovakia
            Email: iosnotewall@gmail.com
            
            Contact information to which any End-User questions, complaints or claims with respect to the Licensed Application should be directed.
            
            9. THIRD PARTY TERMS OF AGREEMENT
            
            You must state in the EULA that the End-User must comply with applicable third party terms of agreement when using Your Application.
            
            10. THIRD PARTY BENEFICIARY
            
            You and the End-User must acknowledge and agree that Apple, and Apple's subsidiaries, are third party beneficiaries of the EULA, and that, upon the End-User's acceptance of the terms and conditions of the EULA, Apple will have the right (and will be deemed to have accepted the right) to enforce the EULA against the End-User as a third party beneficiary thereof.
            
            ═══════════════════════════════════════
            PART II: SUBSCRIPTION TERMS
            ═══════════════════════════════════════
            
            11. AUTO-RENEWABLE SUBSCRIPTIONS
            
            • Payment will be charged to your iTunes Account at confirmation of purchase
            • Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period
            • Account will be charged for renewal within 24-hours prior to the end of the current period, and identify the cost of the renewal
            • Subscriptions may be managed by the user and auto-renewal may be turned off by going to the user's Account Settings after purchase
            • Any unused portion of a free trial period, if offered, will be forfeited when the user purchases a subscription to that publication, where applicable
            
            12. FREE TRIAL TERMS
            
            • New users receive 3 free wallpaper exports to try the app
            • Premium subscriptions may include a free trial period (typically 5-7 days)
            • You will be charged at the end of the trial period unless you cancel before it ends
            • To cancel: Settings app → [Your Name] → Subscriptions → NoteWall → Cancel Subscription
            • Free trials are available to new subscribers only
            
            13. REFUND POLICY
            
            • All refund requests must be made through Apple's App Store
            • Contact Apple Support directly for refund assistance
            • Refunds are subject to Apple's refund policy
            • We cannot process refunds directly as all payments are handled by Apple
            
            14. PRICING AND AVAILABILITY
            
            • Prices are subject to change without notice
            • Subscription prices may vary by region and currency
            • Features and availability may vary by device and iOS version
            • We reserve the right to modify or discontinue features at any time
            
            ═══════════════════════════════════════
            PART III: PRIVACY POLICY
            ═══════════════════════════════════════
            
            15. INFORMATION WE COLLECT
            
            15.1 Personal Information You Provide:
            • Notes and Text: All notes you create are stored locally on your device only
            • Photos: Any photos you select for wallpaper backgrounds are processed locally on your device
            • No personal content is transmitted to our servers or third parties
            
            15.2 Automatically Collected Information:
            • Device Information: iOS version, device model (for app compatibility and optimization)
            • App Performance Data: Anonymous crash reports and performance metrics to improve the app
            • Purchase Information: Subscription status and transaction records (processed by Apple)
            • Usage Analytics: Anonymous data about app features used (no personal content)
            
            15.3 Information We Do NOT Collect:
            • We do not collect your name, email address, or contact information unless you contact us
            • We do not access your contacts, location, camera roll, or other personal data
            • We do not track your browsing habits or app usage patterns across other apps
            • We do not use cookies or similar tracking technologies
            
            16. HOW WE USE YOUR INFORMATION
            
            We use collected information to:
            • Provide the core wallpaper generation functionality
            • Process in-app purchases through Apple's App Store
            • Improve app performance and fix technical issues
            • Provide customer support when you contact us directly
            • Ensure app compatibility across different iOS versions and devices
            • Analyze app usage patterns to improve user experience (anonymized data only)
            
            17. DATA STORAGE AND SECURITY
            
            17.1 Local Storage:
            • All your notes and photos are stored exclusively on your device using iOS secure storage
            • We do not upload, sync, or backup your personal content to external servers
            • Your data remains completely private and under your control
            • Data is protected by iOS built-in security features including device encryption
            • When you delete the app, all your data is permanently removed
            
            17.2 Data Transmission:
            • No personal content (notes, photos) is transmitted over the internet
            • Only anonymous technical data may be sent for app improvement purposes
            • All purchase transactions are handled securely by Apple using industry-standard encryption
            • Any data transmission uses secure HTTPS protocols
            
            18. DATA SHARING AND DISCLOSURE
            
            We do not sell, trade, rent, or share your personal information with third parties, except in the following limited circumstances:
            
            18.1 Apple Inc.:
            • Purchase and subscription information is shared with Apple for payment processing
            • Anonymous crash reports may be shared through Apple's developer tools
            • App Store analytics data is processed by Apple according to their privacy policy
            
            18.2 Legal Requirements:
            • We may disclose information if required by law, court order, or government request
            • We may disclose information to protect our rights, property, or safety
            • We may disclose information to prevent fraud or illegal activities
            
            18.3 Business Transfers:
            • In the event of a merger, acquisition, or sale of assets, user information may be transferred
            • Users will be notified of any such transfer and their rights regarding their data
            
            19. YOUR PRIVACY RIGHTS
            
            19.1 European Union (GDPR) Rights:
            If you are located in the EU, you have the following rights:
            • Right of Access: Request information about data we process about you
            • Right of Rectification: Correct inaccurate personal data
            • Right of Erasure: Request deletion of your personal data
            • Right of Portability: Export your data in a readable format
            • Right to Object: Object to processing of your personal data
            • Right to Restrict Processing: Limit how we process your data
            • Right to Lodge a Complaint: File a complaint with your local data protection authority
            
            19.2 California Privacy Rights (CCPA):
            If you are a California resident, you have the right to:
            • Know what personal information is collected about you
            • Delete personal information we have collected
            • Opt-out of the sale of personal information (we do not sell personal information)
            • Non-discrimination for exercising your privacy rights
            
            19.3 Exercising Your Rights:
            To exercise any of these rights, contact us at: iosnotewall@gmail.com
            We will respond to your request within 30 days.
            
            20. DATA RETENTION
            
            • Notes: Stored locally on your device until you delete them or uninstall the app
            • App Settings: Stored locally until app is uninstalled
            • Purchase Records: Maintained by Apple according to their retention policies
            • Technical Data: Anonymous performance data may be retained for up to 2 years for app improvement
            • Support Communications: Retained for up to 3 years for customer service purposes
            
            21. CHILDREN'S PRIVACY
            
            NoteWall is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information immediately. Parents who believe their child has provided us with personal information should contact us at iosnotewall@gmail.com.
            
            22. INTERNATIONAL DATA TRANSFERS
            
            Since all personal data is processed locally on your device, there are no international data transfers of your personal content. Any anonymous technical data shared with us is processed in accordance with applicable data protection laws and may be transferred to countries with different data protection standards.
            
            23. CHANGES TO THIS PRIVACY POLICY
            
            We may update this Privacy Policy from time to time to reflect changes in our practices, technology, or applicable laws. We will notify you of any material changes by:
            • Posting the updated policy in the app
            • Updating the "Last Updated" date at the top of this policy
            • Sending a notification through the app if changes are significant
            
            Your continued use of the app after any changes constitutes acceptance of the updated policy.
            
            24. CONTACT INFORMATION
            
            If you have questions, concerns, or requests regarding this Privacy Policy or our privacy practices, please contact us:
            
            Email: iosnotewall@gmail.com
            Developer: NoteWall Team
            
            For EU residents: You also have the right to lodge a complaint with your local data protection authority.
            
            ═══════════════════════════════════════
            PART IV: GENERAL TERMS
            ═══════════════════════════════════════
            
            25. DISCLAIMER OF WARRANTIES
            
            THE LICENSED APPLICATION IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED OR ERROR-FREE.
            
            26. LIMITATION OF LIABILITY
            
            TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE DEVELOPER SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES, WHETHER INCURRED DIRECTLY OR INDIRECTLY, OR ANY LOSS OF DATA, USE, GOODWILL, OR OTHER INTANGIBLE LOSSES.
            
            27. TERMINATION
            
            This EULA is effective until terminated by you or the Developer. Your rights under this EULA will terminate automatically without notice if you fail to comply with any term(s) of this EULA. Upon termination, you must cease all use of the Licensed Application and delete all copies.
            
            28. GOVERNING LAW
            
            This EULA and Privacy Policy are governed by the laws of Slovakia, without regard to conflict of law principles. Any disputes will be resolved in the courts of Slovakia.
            
            29. SEVERABILITY
            
            If any provision of this EULA is held to be unenforceable or invalid, such provision will be changed and interpreted to accomplish the objectives of such provision to the greatest extent possible under applicable law, and the remaining provisions will continue in full force and effect.
            
            30. ENTIRE AGREEMENT
            
            This EULA, together with this Privacy Policy, constitutes the entire agreement between you and the Developer regarding the Licensed Application and supersedes all prior or contemporaneous understandings regarding such subject matter. No amendment to or modification of this EULA will be binding unless in writing and signed by the Developer.
            
            ═══════════════════════════════════════
            
            By using NoteWall, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and Privacy Policy.
            
            Thank you for using NoteWall!
            """
        }
    }
}
