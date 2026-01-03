import SwiftUI
import PhotosUI
import Photos
import UIKit
import QuartzCore
import AVKit
import AVFoundation
import AudioToolbox
import StoreKit
import UserNotifications

// Only log in debug builds to reduce console noise
#if DEBUG
private func debugLog(_ message: String) {
    print(message)
}
#else
private func debugLog(_ message: String) {
    // No-op in release builds
}
#endif

// MARK: - Video URL Helper
/// Gets video URL from Config (remote) or bundle (fallback)
/// This allows videos to be hosted online to reduce app bundle size
private func getVideoURL(for resourceName: String, withExtension ext: String = "mp4") -> URL? {
    // Try remote URL first from Config
    if let remoteURLString = Config.videoURLs[resourceName],
       let remoteURL = URL(string: remoteURLString),
       remoteURLString != "https://your-cdn-url.com/videos/\(resourceName).mp4" { // Check if placeholder URL
        debugLog("🌐 Using remote video URL for \(resourceName): \(remoteURLString)")
        return remoteURL
    }
    
    // Fallback to bundle if enabled or if remote URL is placeholder
    if Config.useBundleVideosAsFallback {
        if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: ext) {
            debugLog("📦 Using bundle video for \(resourceName) (fallback mode)")
            return bundleURL
        }
    }
    
    // If remote URL is placeholder, try bundle as last resort
    if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: ext) {
        debugLog("📦 Using bundle video for \(resourceName) (remote URL not configured)")
        return bundleURL
    }
    
    debugLog("❌ Video not found: \(resourceName).\(ext)")
    return nil
}

// MARK: - Video Player Without Controls (for Step 6)
struct VideoPlayerNoControlsView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(player: player)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No update needed - player is managed externally
    }
    
    class PlayerUIView: UIView {
        private var playerLayer: AVPlayerLayer
        
        init(player: AVPlayer) {
            playerLayer = AVPlayerLayer(player: player)
            super.init(frame: .zero)
            
            playerLayer.videoGravity = .resizeAspect
            layer.addSublayer(playerLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

// MARK: - Video Player With Controls and Top Crop
struct CroppedVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let topCrop: CGFloat
    
    func makeUIViewController(context: Context) -> UIViewController {
        let containerVC = ContainerViewController()
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true
        // Use resizeAspect to show full width of video (no side cropping)
        // Container will clip top/bottom to remove black bar
        playerVC.videoGravity = .resizeAspect
        
        containerVC.addChild(playerVC)
        containerVC.view.addSubview(playerVC.view)
        containerVC.playerViewController = playerVC
        containerVC.topCrop = topCrop
        containerVC.player = player
        // Enable clipping to ensure overflow is discarded
        containerVC.view.clipsToBounds = true
        
        return containerVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let containerVC = uiViewController as? ContainerViewController {
            containerVC.topCrop = topCrop
            containerVC.view.setNeedsLayout()
        }
    }
    
    class ContainerViewController: UIViewController {
        var playerViewController: AVPlayerViewController?
        var topCrop: CGFloat = 0
        var player: AVPlayer?
        private var hasStartedPlayback = false
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Auto-play video when view appears
            if !hasStartedPlayback, let player = player {
                player.seek(to: .zero)
                player.play()
                hasStartedPlayback = true
                debugLog("▶️ CroppedVideoPlayerView: Auto-started playback")
            }
        }
        
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            
            guard let playerVC = playerViewController else { return }
            
            // With resizeAspect, the video shows full width and fits within container
            // Shift the video upward by topCrop to push the black bar outside visible bounds
            let containerHeight = view.bounds.height
            let containerWidth = view.bounds.width
            
            // Make the player view taller than container to accommodate the upward shift
            // The video will fit within this frame with aspect-fit (showing full width), and the container will clip the excess
            let expandedHeight = containerHeight + topCrop
            
            // Position player view shifted upward - this pushes the top black bar outside visible area
            // Bottom excess will also be clipped by the container
            playerVC.view.frame = CGRect(
                x: 0,
                y: -topCrop, // Negative offset shifts video up, pushing black bar outside container
                width: containerWidth,
                height: expandedHeight
            )
            
            // Force layout update
            playerVC.view.setNeedsLayout()
            playerVC.view.layoutIfNeeded()
        }
    }
}

private enum OnboardingPage: Int, CaseIterable, Hashable {
    // Phase 1: Welcome & Quiz Introduction
    case preOnboardingHook      // Step 0: Mockup preview
    case quizIntro              // "Let's personalize your experience" transition
    
    // Phase 2: Assessment Quiz
    case quizForgetMost         // What do you struggle with?
    case quizPhoneChecks        // How often do you check your phone?
    case quizDistraction        // What distracts you most?
    
    // Phase 3: Analysis & Results
    case personalizationLoading // Analyzing your answers...
    case resultsPreview         // Your personalized profile
    
    // Phase 4: Education & Symptoms
    case symptoms               // Pain points they relate to
    case howAppHelps            // Position FaithWall as the solution
    
    // Phase 5: Social Proof & Features
    case socialProof            // Reviews & user count
    
    // Phase 6: Custom Plan & Setup Introduction
    case setupIntro             // Preview technical setup steps
    case pipelineChoice         // Choose between Full Screen or Widget
    
    // Phase 7a: Widget Setup (alternative path)
    case widgetOnboarding       // Widget setup flow
    
    // Phase 7b: Technical Setup - Full Screen (keep existing)
    case videoIntroduction
    case installShortcut
    case shortcutSuccess
    case addNotes
    case chooseWallpapers
    case allowPermissions
    
    // Phase 8: Completion
    case setupComplete
    case overview
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onboardingVersion: Int
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0
    @AppStorage("shouldShowTroubleshootingBanner") private var shouldShowTroubleshootingBanner = false
    @AppStorage("lockScreenBackground") private var lockScreenBackgroundRaw = LockScreenBackgroundOption.default.rawValue
    @AppStorage("lockScreenBackgroundMode") private var lockScreenBackgroundModeRaw = LockScreenBackgroundMode.default.rawValue
    @AppStorage("lockScreenBackgroundPhotoData") private var lockScreenBackgroundPhotoData: Data = Data()

    @AppStorage("homeScreenPresetSelection") private var homeScreenPresetSelectionRaw = ""
    @AppStorage("homeScreenUsesCustomPhoto") private var homeScreenUsesCustomPhoto = false
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("saveWallpapersToPhotos") private var saveWallpapersToPhotos = false
    @AppStorage("autoUpdateWallpaperAfterDeletion") private var autoUpdateWallpaperAfterDeletionRaw: String = ""
    @AppStorage("hasShownAutoUpdatePrompt") private var hasShownAutoUpdatePrompt = false
    @AppStorage("hasRequestedAppReview") private var hasRequestedAppReview = false
    @AppStorage("hasLockScreenWidgets") private var hasLockScreenWidgets = true
    @AppStorage("selectedOnboardingPipeline") private var selectedOnboardingPipeline = "" // "fullscreen" or "widget"
    
    // DEBUG: Set to true to skip directly to Choose Your Setup
    private let debugSkipToChooseSetup = true
    
    @State private var didOpenShortcut = false
    @State private var shouldAdvanceToInstallStep = false
    @State private var advanceToInstallStepTimer: Timer?
    @State private var isInstallingShortcut = false
    @State private var isSavingHomeScreenPhoto = false
    @State private var homeScreenStatusMessage: String?
    @State private var homeScreenStatusColor: Color = .gray
    @State private var isSavingLockScreenBackground = false
    @State private var lockScreenBackgroundStatusMessage: String?
    @State private var lockScreenBackgroundStatusColor: Color = .gray

    @State private var currentPage: OnboardingPage = .preOnboardingHook
    @State private var isLaunchingShortcut = false
    @State private var shortcutLaunchFallback: DispatchWorkItem?
    @State private var wallpaperVerificationTask: Task<Void, Never>?
    @State private var didTriggerShortcutRun = false
    @State private var isLoadingWallpaperStep = false
    @State private var demoVideoPlayer: AVQueuePlayer?
    @State private var demoVideoLooper: AVPlayerLooper?
    @State private var notificationsVideoPlayer: AVQueuePlayer?
    @State private var notificationsVideoLooper: AVPlayerLooper?
    @State private var notificationsVideoAspectRatio: CGFloat?
    @State private var welcomeVideoPlayer: AVQueuePlayer?
    @State private var welcomeVideoLooper: AVPlayerLooper?
    @State private var isWelcomeVideoMuted: Bool = false
    @State private var isWelcomeVideoPaused: Bool = false
    @State private var welcomeVideoProgress: Double = 0.0
    @State private var welcomeVideoDuration: Double = 0.0
    @State private var welcomeVideoProgressTimer: Timer?
    @State private var stuckGuideVideoPlayer: AVQueuePlayer?
    @State private var stuckGuideVideoLooper: AVPlayerLooper?
    @State private var isStuckVideoMuted: Bool = false
    @State private var isStuckVideoPaused: Bool = false
    @State private var stuckVideoProgress: Double = 0.0
    @State private var stuckVideoDuration: Double = 0.0
    @State private var stuckVideoProgressTimer: Timer?
    @StateObject private var pipVideoPlayerManager = PIPVideoPlayerManager()
    @State private var shouldStartPiP = false
    private let demoVideoPlaybackRate: Float = 1.5
    private let stuckVideoResourceName = "how-to-fix-guide"
    
    // Post-onboarding troubleshooting
    @State private var showTroubleshooting = false
    @State private var shouldRestartOnboarding = false
    
    // Widget onboarding sheet
    @State private var showWidgetOnboarding = false
    
    // Notes management for onboarding
    @State private var onboardingNotes: [Note] = []
    @State private var currentNoteText = ""
    @FocusState private var isNoteFieldFocused: Bool
    
    // Widget selection tracking
    @State private var hasSelectedWidgetOption = false
    
    // Post-onboarding paywall
    @State private var showPostOnboardingPaywall = false
    @StateObject private var paywallManager = PaywallManager.shared
    
    // Final step mockup preview
    @State private var showMockupPreview = false
    @State private var loadedWallpaperImage: UIImage?
    @State private var useLightMockup: Bool = true
    @State private var audioPlayer: AVAudioPlayer?
    
    // Transition animation from step 6 to step 7
    @State private var showTransitionScreen = false
    @State private var countdownNumber: Int = 3
    @State private var showConfetti = false
    @State private var confettiTrigger: Int = 0
    @State private var hideProgressIndicator = false
    @State private var transitionTextOpacity: Double = 0
    @State private var countdownOpacity: Double = 0
    
    // Enhanced transition animation states
    @State private var word1Visible = false
    @State private var word2Visible = false
    @State private var word3Visible = false
    @State private var word4Visible = false
    @State private var ringProgress: CGFloat = 0
    @State private var countdownGlow: CGFloat = 0
    @State private var particleBurst: Bool = false
    @State private var gradientRotation: Double = 0
    
    // Help button and support
    @State private var showHelpSheet = false
    @State private var improvementText = ""
    @State private var showImprovementSuccess = false
    @State private var showImprovementForm = false
    @State private var showHelpAlert = false
    @State private var helpAlertMessage = ""
    @State private var isSendingImprovement = false
    @FocusState private var isImprovementFieldFocused: Bool
    
    // Safari availability check
    @State private var showShortcutsCheckAlert = false
    @State private var isTransitioningBetweenPopups = false
    @State private var hasCheckedSafariOnStep2 = false
    @State private var hasCompletedShortcutsCheck = false
    @State private var hasCompletedSafariCheck = false
    @State private var wentToAppStoreForShortcuts = false
    
    // Pre-onboarding hook animation states
    @State private var firstNoteOpacity: Double = 0
    @State private var firstNoteScale: CGFloat = 0.8
    @State private var firstNoteOffset: CGFloat = 0
    @State private var firstNoteXOffset: CGFloat = -300 // Start off-screen left (left to right)
    @State private var firstNoteRotation: Double = -15 // Start rotated
    @State private var notesOpacity: [Double] = [0, 0, 0]
    @State private var notesOffset: [CGFloat] = [0, 0, 0]
    // Alternate directions: [right-to-left, left-to-right, right-to-left]
    @State private var notesXOffset: [CGFloat] = [300, -300, 300] // Alternate: right, left, right
    @State private var notesScale: [CGFloat] = [0.8, 0.8, 0.8] // Start smaller
    @State private var notesRotation: [Double] = [15, -15, 15] // Alternate rotation directions
    @State private var mockupOpacity: Double = 0
    @State private var mockupScale: CGFloat = 0.95
    @State private var mockupRotation: Double = 0
    @State private var taglineOpacity: Double = 0
    
    // 3-to-1 Animation States
    @State private var bubble1Offset: CGSize = .zero
    @State private var bubble2Offset: CGSize = .zero
    @State private var bubble3Offset: CGSize = .zero
    @State private var bubble1Opacity: Double = 0
    @State private var bubble2Opacity: Double = 0
    @State private var bubble3Opacity: Double = 0
    @State private var mergedBubbleOpacity: Double = 0
    @State private var mergedBubbleScale: CGFloat = 0.5
    @State private var showFinalContent: Bool = false
    @State private var continueButtonOpacity: Double = 0
    @State private var overallScale: CGFloat = 1.0
    @State private var overallOffset: CGFloat = 100 // Start lower on screen
    @State private var hasStartedPreOnboardingAnimation = false
    
    // Typewriter animation states for Bible verse
    @State private var typewriterText: String = ""
    @State private var typewriterReference: String = ""
    @State private var typewriterIndex: Int = 0
    @State private var typewriterRefIndex: Int = 0
    @State private var isTyping: Bool = false
    @State private var isTypingReference: Bool = false
    @State private var showVerseOnMockup: Bool = false
    @State private var containerOpacity: Double = 0
    @State private var verseOpacity: Double = 0
    @State private var textOffsetY: CGFloat = 0
    @State private var textFontSize: CGFloat = 28
    @State private var isMovingToMockup: Bool = false
    
    // Background transition animation states - Red-Orange like appAccent
    @State private var backgroundColorStart = Color(red: 0.95, green: 0.4, blue: 0.2)
    @State private var backgroundColorEnd = Color(red: 1.0, green: 0.5, blue: 0.1)
    @State private var showMockupBelow: Bool = false
    
    private var bibleVerse: String {
        "Be strong and courageous. Do not be afraid or terrified because of them, for the LORD your God goes with you; he will never leave you nor forsake you."
    }
    
    private var bibleReference: String {
        "— Deuteronomy 31:6"
    }

    private let shortcutURL = "https://www.icloud.com/shortcuts/4735a1723f8a4cc28c12d07092c66a35"
    private let whatsappNumber = "421907758852" // Replace with your actual WhatsApp number
    private let supportEmail = "iosfaithwall@gmail.com" // Replace with your actual support email

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                navigationStackOnboarding
            } else {
                navigationViewOnboarding
            }
        }
        .interactiveDismissDisabled()
        .task {
            HomeScreenImageManager.prepareStorageStructure()
        }
        .onAppear {
            // DEBUG: Skip to Choose Your Setup if flag is enabled
            if debugSkipToChooseSetup {
                currentPage = .pipelineChoice
            }
            
            // CRITICAL: Reset shortcut launch state when onboarding appears
            // This prevents shortcuts from running automatically when onboarding first opens
            // (e.g., when user clicks "Reinstall Shortcut" button)
            debugLog("📱 Onboarding: View appeared, resetting shortcut launch state")
            isLaunchingShortcut = false
            didTriggerShortcutRun = false
            shortcutLaunchFallback?.cancel()
            shortcutLaunchFallback = nil
            wallpaperVerificationTask?.cancel()
            wallpaperVerificationTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutWallpaperApplied)) { _ in
            completeShortcutLaunch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperGenerationFinished)) { _ in
            handleWallpaperGenerationFinished()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToShortcutsPipeline"))) { _ in
            // Switch back to pipeline choice
            withAnimation(.easeInOut) {
                currentPage = .pipelineChoice
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: currentPage) { page in
            if page == .chooseWallpapers {
                HomeScreenImageManager.prepareStorageStructure()
            }
            
            // Pause video when leaving video introduction step
            if page != .videoIntroduction {
                if let player = welcomeVideoPlayer, player.rate > 0 {
                    player.pause()
                    isWelcomeVideoPaused = true
                    debugLog("⏸️ Welcome video paused (page changed away from step 2)")
                }
            }
            
            // Resume video when entering video introduction step
            if page == .videoIntroduction {
                if let player = welcomeVideoPlayer, player.rate == 0 {
                    player.play()
                    isWelcomeVideoPaused = false
                    debugLog("▶️ Welcome video resumed (entering step 2)")
                }
                // Always restart progress tracking when entering step 2
                startWelcomeVideoProgressTracking()
            }
            
            // Auto-play notifications video when entering step 6
            if page == .allowPermissions {
                prepareNotificationsVideoPlayerIfNeeded()
                
                // Start playback with multiple retry attempts
                func startVideoPlayback() {
                    if let player = self.notificationsVideoPlayer {
                        // Ensure looper is active for continuous looping
                        if let looper = self.notificationsVideoLooper {
                            if looper.status == .failed, let item = player.currentItem {
                                // Recreate looper if needed
                                let newLooper = AVPlayerLooper(player: player, templateItem: item)
                                self.notificationsVideoLooper = newLooper
                                debugLog("🔄 Recreated video looper in onChange")
                            }
                        } else if let item = player.currentItem {
                            // Create looper if it doesn't exist
                            let newLooper = AVPlayerLooper(player: player, templateItem: item)
                            self.notificationsVideoLooper = newLooper
                            debugLog("🔄 Created video looper in onChange")
                        }
                        
                        player.seek(to: .zero)
                        player.play()
                        
                        // Verify playback started
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if player.rate == 0 {
                                player.seek(to: .zero)
                                player.play()
                                debugLog("▶️ Notifications video retry (entering step 6)")
                            } else {
                                debugLog("▶️ Notifications video playing and looping (entering step 6)")
                            }
                        }
                    } else {
                        // Player not ready, try again
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            startVideoPlayback()
                        }
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    startVideoPlayback()
                }
            }
        }
        .onChange(of: shouldRestartOnboarding) { shouldRestart in
            if shouldRestart {
                // Reset to first page and restart onboarding
                withAnimation {
                    currentPage = .preOnboardingHook
                }
                shouldRestartOnboarding = false
            }
        }
        .onChange(of: showShortcutsCheckAlert) { isShowing in
            if isShowing {
                // Pause video when Requirements check appears
                if let player = welcomeVideoPlayer {
                    player.pause()
                    isWelcomeVideoPaused = true
                    debugLog("⏸️ Welcome video paused (Requirements check appearing)")
                }
            } else if currentPage == .videoIntroduction {
                // Resume video when dismissed (if still on step 2 and no other popup showing AND not transitioning)
                let noOtherPopup = !showInstallSheet
                if noOtherPopup && !isTransitioningBetweenPopups, let player = welcomeVideoPlayer, player.rate == 0 {
                    player.play()
                    isWelcomeVideoPaused = false
                    debugLog("▶️ Welcome video resumed (Requirements check dismissed)")
                }
            }
        }
        .onChange(of: showInstallSheet) { isShowing in
            if isShowing {
                // Pause video when Install sheet appears
                if let player = welcomeVideoPlayer {
                    player.pause()
                    isWelcomeVideoPaused = true
                    debugLog("⏸️ Welcome video paused (Install sheet appearing)")
                }
            } else if currentPage == .videoIntroduction {
                // Resume video when dismissed (if still on step 2 and no other popup showing AND not transitioning)
                let noOtherPopup = !showShortcutsCheckAlert
                if noOtherPopup && !isTransitioningBetweenPopups, let player = welcomeVideoPlayer, player.rate == 0 {
                    player.play()
                    isWelcomeVideoPaused = false
                    debugLog("▶️ Welcome video resumed (Install sheet dismissed)")
                }
            }
            // Reset flag after a short delay
            if !isShowing && isInstallingShortcut {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInstallingShortcut = false
                }
            }
        }
        .sheet(isPresented: $showInstallSheet) {
            installSheetView()
        }
        .sheet(isPresented: $showTroubleshooting) {
            troubleshootingModalView
        }
        .sheet(isPresented: $showPostOnboardingPaywall) {
            PaywallView(triggerReason: .firstWallpaperCreated, allowDismiss: false)
                .onDisappear {
                    // Mark onboarding as complete when paywall is dismissed
                    hasCompletedSetup = true
                    completedOnboardingVersion = onboardingVersion

                    // Track analytics
                    OnboardingQuizState.shared.paywallShown = true
                    OnboardingAnalytics.trackPaywallShown(totalSetupTime: OnboardingQuizState.shared.totalSetupTime)

                    debugLog("✅ Onboarding completed - User dismissed paywall, now in main app")
                    
                    // Request app review after paywall is dismissed (either paid or canceled)
                    requestAppReviewIfNeeded()
                }
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func installSheetView() -> some View {
        if #available(iOS 16.0, *) {
            installSheetContent()
                .presentationDetents([.medium])
        } else {
            installSheetContent()
        }
    }

    private func installSheetContent() -> some View {
        ZStack(alignment: .topTrailing) {
            // Black background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(.appAccent)
                    .padding(.top, 40)
                
                Text("Install Shortcut")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    Text("We'll open the Shortcuts app now.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "pip")
                            .font(.body)
                            .foregroundColor(.appAccent)
                        Text("A video guide will appear")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.appAccent)
                    }
                    
                    Text("Follow the guide step-by-step - it will show you exactly what to do!")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                
                Spacer(minLength: 0)
                
                Button(action: {
                    // Medium haptic for important installation action
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Set flag to prevent video from auto-resuming
                    isInstallingShortcut = true
                    showInstallSheet = false
                    // Set flag to advance to step 3 when app backgrounds
                    shouldAdvanceToInstallStep = true
                    // Set up fallback timer in case app doesn't background (e.g., iPad split screen)
                    advanceToInstallStepTimer?.invalidate()
                    advanceToInstallStepTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                        if self.shouldAdvanceToInstallStep {
                            debugLog("📱 Onboarding: Fallback timer triggered, advancing to installShortcut step")
                            withAnimation(.easeInOut) {
                                self.currentPage = .installShortcut
                            }
                            self.shouldAdvanceToInstallStep = false
                        }
                    }
                    // Launch installation - this will open Shortcuts app
                    // Step 3 will be shown automatically when app backgrounds
                    installShortcut()
                }) {
                    Text("Install & Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showInstallSheet = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.05))
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                    )
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
            .zIndex(1000)
        }
    }

    @ViewBuilder
    private var navigationViewOnboarding: some View {
        NavigationView {
            onboardingPager(includePhotoPicker: false)
        }
    }

    @available(iOS 16.0, *)
    private var navigationStackOnboarding: some View {
        NavigationStack {
            onboardingPager(includePhotoPicker: true)
        }
    }

    private func onboardingPager(includePhotoPicker: Bool) -> some View {
        ZStack {
            // Dark gradient background for new emotional pages and video introduction
            // These pages have their own dark backgrounds
            let needsDarkBackground = [
                OnboardingPage.quizForgetMost, .quizPhoneChecks, .quizDistraction,
                .personalizationLoading, .resultsPreview, .socialProof, .setupIntro, .pipelineChoice, .widgetOnboarding, .videoIntroduction,
                .shortcutSuccess, .setupComplete
            ].contains(currentPage)
            
            if needsDarkBackground {
                LinearGradient(
                    colors: [Color(red: 0.99, green: 0.98, blue: 0.97), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            } else {
                Color(.systemBackground)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Progress indicator - only shown on technical setup steps
                if !hideProgressIndicator && !showTransitionScreen && currentPage.showsProgressIndicator {
                    onboardingProgressIndicatorCompact
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                        // Transparent background for dark pages
                        .background(
                            needsDarkBackground ? Color.clear : Color(.systemBackground)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ZStack {
                    // Transparent background for dark pages to show continuous gradient
                    if needsDarkBackground {
                        Color.clear
                            .ignoresSafeArea()
                    } else {
                    // Solid background to prevent seeing underlying content during transitions
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    }
                    
                    Group {
                        switch currentPage {
                        case .preOnboardingHook:
                            preOnboardingHookStep()
                        case .quizIntro:
                            MotivationalTransitionView {
                                advanceStep()
                            }
                        case .quizForgetMost:
                            QuizQuestionView(
                                question: "What do you struggle with most in your walk with God?",
                                subtitle: "Select the biggest one",
                                options: QuizData.forgetMostOptions
                            ) { answer in
                                OnboardingQuizState.shared.forgetMostList = [answer]
                                advanceStep()
                            }
                        case .quizPhoneChecks:
                            PhoneUsageSliderQuestionView { answer in
                                OnboardingQuizState.shared.phoneChecks = answer
                                advanceStep()
                            }
                        case .quizDistraction:
                            QuizQuestionView(
                                question: "What distracts you most from your faith?",
                                subtitle: "Select the biggest one",
                                options: QuizData.distractionOptions
                            ) { answer in
                                OnboardingQuizState.shared.biggestDistractionList = [answer]
                                advanceStep()
                            }
                        case .personalizationLoading:
                            PersonalizationLoadingView {
                                advanceStep()
                            }
                        case .resultsPreview:
                            ResultsPreviewView {
                                advanceStep()
                            }
                        case .symptoms:
                            SymptomsView {
                                advanceStep()
                            }
                        case .howAppHelps:
                            HowAppHelpsView {
                                advanceStep()
                            }
                        case .socialProof:
                            SocialProofView {
                                advanceStep()
                            }
                        case .setupIntro:
                            SetupIntroView(
                                title: "Let's Get You Set Up",
                                subtitle: "We'll guide you through each step",
                                icon: "gearshape.2.fill",
                                steps: QuizData.setupSteps,
                                timeEstimate: "Takes about 3-4 minutes",
                                ctaText: "Choose Your Setup"
                            ) {
                                advanceStep()
                            }
                        case .pipelineChoice:
                            PipelineChoiceView(
                                onSelectFullScreen: {
                                    selectedOnboardingPipeline = "fullscreen"
                                    // Skip widget onboarding and go to video introduction
                                    withAnimation(.easeInOut) {
                                        currentPage = .videoIntroduction
                                    }
                                },
                                onSelectWidget: {
                                    selectedOnboardingPipeline = "widget"
                                    // Show widget onboarding
                                    withAnimation(.easeInOut) {
                                        currentPage = .widgetOnboarding
                                    }
                                }
                            )
                        case .widgetOnboarding:
                            WidgetOnboardingView(isPresented: $showWidgetOnboarding) {
                                // Widget onboarding complete - go directly to paywall
                                completeOnboarding()
                            }
                        case .videoIntroduction:
                            videoIntroductionStep()
                        case .installShortcut:
                            installShortcutStep()
                        case .shortcutSuccess:
                            CelebrationView(
                                title: "Shortcut Installed!",
                                subtitle: "Great job! Now let's personalize your experience",
                                encouragement: "You're doing great!",
                                nextStepPreview: "Next: Add your first notes"
                            ) {
                                advanceStep()
                            }
                        case .addNotes:
                            addNotesStep()
                        case .chooseWallpapers:
                            chooseWallpapersStep(includePhotoPicker: includePhotoPicker)
                        case .allowPermissions:
                            allowPermissionsStep()
                        case .setupComplete:
                            SetupCompleteView {
                                // Trigger countdown transition after setup complete
                                startTransitionCountdown()
                            }
                        case .overview:
                            overviewStep()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .id(currentPage)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                .animation(.easeInOut(duration: 0.25), value: currentPage)
                .gesture(
                    DragGesture()
                        .onEnded { gesture in
                            handleSwipeGesture(gesture)
                        }
                )

                // Hide button during transition and on pages with their own buttons
                // New emotional hook pages (painPoint, quiz, results, socialProof, setupIntro, celebrations) have built-in buttons
                if !showTransitionScreen && currentPage.showsProgressIndicator {
                    primaryButtonSection
                }
            }
            .opacity(showTransitionScreen ? 0 : 1)
            
            // Transition screen overlay
            if showTransitionScreen {
                transitionCountdownView
                    .transition(.opacity)
            }
            
            // Confetti overlay (uses ConfettiView from OnboardingEnhanced.swift)
            if showConfetti {
                ConfettiView(trigger: $confettiTrigger)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            
            // Help button - visible only on technical setup steps
            // Different positioning for overview step (smaller, in grey corner)
            // Hidden on chooseWallpapers step as it's now integrated into the content
            if currentPage.showsProgressIndicator && currentPage != .chooseWallpapers {
                VStack {
                    HStack {
                        Spacer()
                        if currentPage == .overview {
                            // Smaller help button for overview step
                            compactHelpButton
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                        } else {
                            helpButton
                                .padding(.top, 100)
                                .padding(.trailing, 16)
                        }
                    }
                    Spacer()
                }
                .allowsHitTesting(true)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: showHelpSheet) { isShowing in
            if !isShowing && currentPage == .videoIntroduction {
                // Resume video if help sheet is dismissed and we're still on step 2
                if let player = welcomeVideoPlayer, player.rate == 0 {
                    player.play()
                    isWelcomeVideoPaused = false
                    debugLog("▶️ Welcome video resumed (help sheet dismissed)")
                }
            }
        }
        .sheet(isPresented: $showHelpSheet) {
            helpOptionsSheet
        }
        .sheet(isPresented: $showImprovementForm) {
            improvementFormSheet
        }
        .alert(isPresented: $showHelpAlert) {
            Alert(
                title: Text("Notice"),
                message: Text(helpAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .animation(.easeInOut(duration: 0.4), value: hideProgressIndicator)
        .animation(.easeInOut(duration: 0.3), value: showTransitionScreen)
    }

    private var onboardingProgressIndicatorCompact: some View {
        let technicalSteps: [OnboardingPage] = [.videoIntroduction, .installShortcut, .addNotes, .chooseWallpapers, .allowPermissions]
        
        return HStack(alignment: .center, spacing: 12) {
            ForEach(technicalSteps, id: \.self) { page in
                Button(action: {
                    // Only allow navigation to previous steps (not future ones)
                    if page.rawValue < currentPage.rawValue {
                        // Light haptic for navigation
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage = page
                        }
                    }
                }) {
                    progressIndicatorItem(for: page, displayMode: .compact)
                }
                .buttonStyle(.plain)
                .disabled(page.rawValue >= currentPage.rawValue) // Disable future steps
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(currentPage.accessibilityLabel) of 6")
    }

    private var primaryButtonSection: some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let buttonHeight: CGFloat = isCompact ? 48 : 56
        let buttonIconSize: CGFloat = isCompact ? 18 : 20
        let horizontalPadding: CGFloat = isCompact ? 16 : 24
        let topPadding: CGFloat = isCompact ? 12 : 18
        let bottomPadding: CGFloat = isCompact ? 16 : 22
        
        return VStack(spacing: isCompact ? 8 : 12) {
            // Hide primary button for installShortcut and overview steps as they have custom buttons
            if currentPage != .installShortcut && currentPage != .overview {
            Button(action: handlePrimaryButton) {
                HStack(spacing: 12) {
                    if currentPage == .chooseWallpapers && isLaunchingShortcut {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(.white)
                    } else if let iconName = primaryButtonIconName {
                        Image(systemName: iconName)
                            .font(.system(size: buttonIconSize, weight: .semibold))
                    }

                    Text(primaryButtonTitle)
                        .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(height: buttonHeight)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: primaryButtonEnabled))
            .disabled(!primaryButtonEnabled)
            }
            
            // Switch pipeline button for video introduction step
            if currentPage == .videoIntroduction {
                Button(action: {
                    // Switch back to pipeline choice
                    withAnimation(.easeInOut) {
                        currentPage = .pipelineChoice
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Change Setup Choice")
                            .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
                    }
                    .foregroundColor(.appAccent)
                    .frame(height: buttonHeight - 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: isCompact ? 14 : 20, style: .continuous)
                            .fill(Color.appAccent.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 14 : 20, style: .continuous)
                            .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1.5)
                    )
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .background(
            currentPage == .videoIntroduction 
                ? Color.clear.ignoresSafeArea(edges: .bottom)
                : Color(.systemBackground).ignoresSafeArea(edges: .bottom)
        )
    }

    private func preOnboardingHookStep() -> some View {
        GeometryReader { geometry in
            ZStack {
                // Background: Orange -> White transition
                LinearGradient(
                    colors: [backgroundColorStart, backgroundColorEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Phase 1: Typewriter on orange background (stays visible during transition)
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.25)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Verse text with invisible characters to prevent word jumping
                        ZStack(alignment: .topLeading) {
                            // Invisible full text for layout
                            Text(bibleVerse)
                                .font(.system(size: 22, weight: .semibold, design: .serif))
                                .foregroundColor(.clear)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                            
                            // Visible typed text
                            Text(typewriterText)
                                .font(.system(size: 22, weight: .semibold, design: .serif))
                                .foregroundColor(.white)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                        
                        // Reference text (smaller)
                        if !typewriterReference.isEmpty || typewriterIndex >= bibleVerse.count {
                            ZStack(alignment: .topLeading) {
                                // Invisible full text for layout
                                Text(bibleReference)
                                    .font(.system(size: 16, weight: .medium, design: .serif))
                                    .foregroundColor(.clear)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                
                                // Visible typed text
                                Text(typewriterReference)
                                    .font(.system(size: 16, weight: .medium, design: .serif))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                        }
                    }
                    .frame(maxWidth: geometry.size.width * 0.55, alignment: .leading)
                    .offset(x: 10) // Shift right to visually center
                    .frame(maxWidth: .infinity)
                    .opacity(showVerseOnMockup ? 0 : containerOpacity)
                    
                    Spacer()
                }
                
                // Phase 2: Mockup with verse on white background
                if showVerseOnMockup {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: geometry.size.height * 0.02)
                        
                        preOnboardingMockupView(geometry: geometry)
                        
                        Spacer()
                    }
                }
                
                // Continue button
                VStack {
                    Spacer()
                    
                    // Title
                    Text("FaithWall")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .opacity(taglineOpacity)
                         .padding(.bottom, 2)
                    
                    // Subtitle
                    Text("Your Daily Spiritual Companion")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.secondary)
                        .opacity(taglineOpacity)
                        .padding(.top, 0)
                        .padding(.bottom, 20)
                    
                    Button(action: {
                        OnboardingQuizState.shared.startTime = Date()
                        advanceStep()
                    }) {
                        HStack(spacing: 12) {
                            Text("Get Started")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .background(Color.appAccent)
                        .foregroundColor(.white)
                        .cornerRadius(ScreenDimensions.isCompactDevice ? 14 : 20)
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .opacity(continueButtonOpacity)
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, 0)
                }
            }
        }
        .onAppear {
            if !hasStartedPreOnboardingAnimation {
                hasStartedPreOnboardingAnimation = true
                startPreOnboardingAnimation()
            }
        }
    }
    
    @ViewBuilder
    private func preOnboardingMockupView(geometry: GeometryProxy) -> some View {
        // Calculate mockup dimensions
        let availableHeight = geometry.size.height * 0.75
        let availableWidth = geometry.size.width
        let mockupAspectRatio: CGFloat = 1892.0 / 4300.0
        let maxMockupHeight = availableHeight
        let maxMockupWidth = availableWidth * 0.9
        
        let mockupWidth = min(maxMockupHeight * mockupAspectRatio, maxMockupWidth)
        let mockupHeight = mockupWidth / mockupAspectRatio
        
        let screenInsetTop: CGFloat = mockupHeight * 0.012
        let screenInsetBottom: CGFloat = mockupHeight * 0.012
        let screenInsetHorizontal: CGFloat = mockupWidth * 0.042
        
        let screenWidth = mockupWidth - (screenInsetHorizontal * 2)
        let screenHeight = mockupHeight - screenInsetTop - screenInsetBottom
        let screenCornerRadius = mockupWidth * 0.115
        
        ZStack {
            // iPhone mockup overlay
            Image("step0_mockup")
                .resizable()
                .aspectRatio(mockupAspectRatio, contentMode: .fit)
                .frame(width: mockupWidth, height: mockupHeight)
                .opacity(mockupOpacity)
                .scaleEffect(mockupScale)
                .rotation3DEffect(
                    .degrees(mockupRotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
                .zIndex(1)
            
            // Lock screen text content overlaid on mockup
            preOnboardingNotesView(
                screenWidth: screenWidth,
                screenHeight: screenHeight
            )
            .frame(width: screenWidth, height: screenHeight)
            .clipped()
            .mask(
                RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous)
            )
            .offset(
                x: screenInsetHorizontal - mockupWidth/2 + screenWidth/2,
                y: screenInsetTop - mockupHeight/2 + screenHeight/2
            )
            .zIndex(2)
        }
        .frame(width: mockupWidth, height: mockupHeight, alignment: .center)
    }
    
    @ViewBuilder
    private func preOnboardingNotesView(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        let topSpacing: CGFloat = screenHeight * 0.23 + 64
        let availableWidthForNotes = screenWidth - 64
        
        VStack(spacing: 0) {
            Spacer()
                .frame(height: topSpacing)
            
            VStack(alignment: .leading, spacing: 8) {
                // Verse text - smaller to fit on mockup
                Text(bibleVerse)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(Color.white)
                    .opacity(verseOpacity)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 2)
                
                // Reference text - smaller to match
                Text(bibleReference)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundColor(Color.white.opacity(0.95))
                    .opacity(verseOpacity)
                    .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 2)
            }
            .frame(maxWidth: availableWidthForNotes, alignment: .leading)
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Language Selection Step
    
    /// Language selection step - shown immediately after the mockup preview
    /// This allows users to choose their preferred language before seeing any other localized content
    private func languageSelectionStep() -> some View {
        BibleLanguageSelectionView(
            showContinueButton: true,
            isOnboarding: true
        ) { selectedTranslation in
            // Language was selected and downloaded, advance to next step
            debugLog("🌍 Onboarding: Language selected - \(selectedTranslation.displayName)")
            advanceStep()
        }
    }
    
    /// Calculates adaptive font size for notes (similar to WallpaperRenderer)
    /// Returns font size that fits all notes without truncation
    private func calculateAdaptiveFontSize(
        for notes: [String],
        availableHeight: CGFloat,
        availableWidth: CGFloat
    ) -> CGFloat {
        let minFontSize: CGFloat = 20 // Half of 40
        let maxFontSize: CGFloat = 50 // Half of 100
        let fontWeight = UIFont.Weight.heavy
        
        guard !notes.isEmpty else { return maxFontSize }
        
        // Check if all notes fit at max font size
        if doNotesFit(notes, atFontSize: maxFontSize, availableHeight: availableHeight, availableWidth: availableWidth, fontWeight: fontWeight) {
            return maxFontSize
        }
        
        // Binary search to find optimal size
        var low = minFontSize
        var high = maxFontSize
        var bestFit = minFontSize
        
        while low <= high {
            let mid = (low + high) / 2
            if doNotesFit(notes, atFontSize: mid, availableHeight: availableHeight, availableWidth: availableWidth, fontWeight: fontWeight) {
                bestFit = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        return bestFit
    }
    
    /// Checks if all notes fit at given font size
    private func doNotesFit(
        _ notes: [String],
        atFontSize fontSize: CGFloat,
        availableHeight: CGFloat,
        availableWidth: CGFloat,
        fontWeight: UIFont.Weight
    ) -> Bool {
        let lineSpacing = fontSize * 0.15 // Same as WallpaperRenderer
        let separatorHeight = fontSize * 0.45 // Same as WallpaperRenderer
        
        let font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        var totalHeight: CGFloat = 0
        
        for (index, note) in notes.enumerated() {
            let attributedString = NSAttributedString(string: note, attributes: attributes)
            let textSize = attributedString.boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            let noteHeight = textSize.height + (index > 0 ? separatorHeight : 0)
            totalHeight += noteHeight
            
            if totalHeight > availableHeight {
                return false
            }
        }
        
        return true
    }
    
    private func startPreOnboardingAnimation() {
        // Reset to orange background
        backgroundColorStart = Color(red: 0.95, green: 0.4, blue: 0.2)
        backgroundColorEnd = Color(red: 1.0, green: 0.5, blue: 0.1)
        
        // Initial state
        typewriterText = ""
        typewriterReference = ""
        typewriterIndex = 0
        typewriterRefIndex = 0
        containerOpacity = 1
        showVerseOnMockup = false
        mockupOpacity = 0
        mockupScale = 0.95
        verseOpacity = 1
        continueButtonOpacity = 0
        
        // Phase 1: Start typing on orange background (0.5s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startTypewriterAnimation()
        }
    }
    
    private func startTypewriterAnimation() {
        let verseCharacters = Array(bibleVerse)
        let refCharacters = Array(bibleReference)
        
        // Haptic generator for typewriter effect
        let hapticGenerator = UIImpactFeedbackGenerator(style: .soft)
        hapticGenerator.prepare()
        
        func typingSpeed(for character: Character) -> TimeInterval {
            if character == " " {
                return 0.04
            } else if character == "." || character == "," || character == ";" || character == ":" {
                return 0.15
            } else {
                return 0.06
            }
        }
        
        func typeNextVerseCharacter() {
            guard typewriterIndex < verseCharacters.count else {
                // Verse complete, start reference
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    typeNextReferenceCharacter()
                }
                return
            }
            
            // Trigger haptic feedback
            hapticGenerator.impactOccurred(intensity: 0.4)
            
            withAnimation(.easeIn(duration: 0.08)) {
                typewriterText += String(verseCharacters[typewriterIndex])
            }
            typewriterIndex += 1
            
            if typewriterIndex < verseCharacters.count {
                let delay = typingSpeed(for: verseCharacters[typewriterIndex - 1])
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    typeNextVerseCharacter()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    typeNextReferenceCharacter()
                }
            }
        }
        
        func typeNextReferenceCharacter() {
            guard typewriterRefIndex < refCharacters.count else {
                // Typing complete - transition to mockup
                transitionToMockup()
                return
            }
            
            // Trigger haptic feedback
            hapticGenerator.impactOccurred(intensity: 0.4)
            
            withAnimation(.easeIn(duration: 0.08)) {
                typewriterReference += String(refCharacters[typewriterRefIndex])
            }
            typewriterRefIndex += 1
            
            if typewriterRefIndex < refCharacters.count {
                let delay = typingSpeed(for: refCharacters[typewriterRefIndex - 1])
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    typeNextReferenceCharacter()
                }
            } else {
                transitionToMockup()
            }
        }
        
        typeNextVerseCharacter()
    }
    
    private func playTransitionAudio() {
        // Configure audio session to ensure sound plays
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }

        // Try to find the audio file in the bundle
        if let url = Bundle.main.url(forResource: "transition-audio", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch {
                print("Could not play audio: \(error)")
            }
        } else {
            print("Audio file not found in bundle. Please add 'transition-audio.mp3' to your Xcode project targets.")
        }
    }
    
    private func transitionToMockup() {
        // Delay everything slightly to let the last character settle
        let startDelay = 0.3
        
        // Play audio transition (1s before background fade)
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
            playTransitionAudio()
        }
        
        // Step 1: Fade out typewriter text
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 0.8) {
            withAnimation(.easeOut(duration: 0.4)) {
                containerOpacity = 0
            }
        }
        
        // Step 2: Transition background to white
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 1.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                backgroundColorStart = .white
                backgroundColorEnd = .white
            }
        }
        
        // Step 3: Show mockup
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 1.5) {
            showVerseOnMockup = true
            
            withAnimation(.easeOut(duration: 0.8)) {
                mockupOpacity = 1.0
                mockupScale = 1.0
            }
            
            // Fade in title and subtitle
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                taglineOpacity = 1.0
            }
        }
        
        // Step 4: Show button (0.5s after mockup)
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 2.0) {
            withAnimation(.easeIn(duration: 0.5)) {
                continueButtonOpacity = 1.0
            }
        }
    }
    
    // Calculate font size for Bible verse text
    private func calculateFontSizeForText(
        text: String,
        availableHeight: CGFloat,
        availableWidth: CGFloat
    ) -> CGFloat {
        let minFontSize: CGFloat = 18
        let maxFontSize: CGFloat = 36
        let fontWeight = UIFont.Weight.heavy
        
        // Binary search to find optimal size
        var low = minFontSize
        var high = maxFontSize
        var bestFit = minFontSize
        
        while low <= high {
            let mid = (low + high) / 2
            if doesTextFit(text: text, atFontSize: mid, availableHeight: availableHeight, availableWidth: availableWidth, fontWeight: fontWeight) {
                bestFit = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        return bestFit
    }
    
    // Check if text fits at given font size
    private func doesTextFit(
        text: String,
        atFontSize fontSize: CGFloat,
        availableHeight: CGFloat,
        availableWidth: CGFloat,
        fontWeight: UIFont.Weight
    ) -> Bool {
        let lineSpacing = fontSize * 0.15
        let font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        return textSize.height <= availableHeight
    }
    
    @State private var showTextVersion = false
    @State private var showInstallSheet = false
    @State private var userWentToSettings = false

    private func videoIntroductionStep() -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let sectionSpacing: CGFloat = isCompact ? 16 : 24
        let horizontalPadding: CGFloat = isCompact ? 16 : 24
        let topPadding: CGFloat = isCompact ? 12 : 20
        let videoWidthRatio: CGFloat = isCompact ? 0.65 : 0.7
        let titleFontSize: CGFloat = isCompact ? 26 : 32
        let cardTitleFontSize: CGFloat = isCompact ? 17 : 20
        let cardBodyFontSize: CGFloat = isCompact ? 14 : 16
        let cardIconSize: CGFloat = isCompact ? 20 : 24
        let cardSpacing: CGFloat = isCompact ? 14 : 20
        let heroHeight: CGFloat = isCompact ? 120 : 180
        
        return ZStack {
            // Background is now handled by the parent container for continuous gradient
            // No separate background needed here
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: sectionSpacing) {
                    // Text Version / Back Button - Improved Design
                    HStack {
                    if showTextVersion {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showTextVersion = false
                            }
                            // Resume video playback
                            if let player = welcomeVideoPlayer, player.rate == 0 {
                                player.play()
                                isWelcomeVideoPaused = false
                                debugLog("▶️ Welcome video resumed")
                            }
                        }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("← Back to Video")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.appAccent)
                                )
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        } else {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    showTextVersion = true
                                }
                                // Pause video playback
                                if let player = welcomeVideoPlayer, player.rate > 0 {
                                    player.pause()
                                    isWelcomeVideoPaused = true
                                    debugLog("⏸️ Welcome video paused")
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "text.alignleft")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Prefer text instructions?")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.appAccent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.appAccent.opacity(0.15))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)
                    
                    if showTextVersion {
                        // Text Version Content - Brand Identity Design
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: isCompact ? 20 : 32) {
                                // Hero Icon with floating animation
                                Step3HeroIcon()
                                    .frame(height: heroHeight)
                                    .padding(.top, isCompact ? 12 : 20)
                                
                                // Title Section
                                VStack(spacing: isCompact ? 8 : 12) {
                                    Text("Important Setup Information")
                                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("Before you install the shortcut...")
                                        .font(.system(size: isCompact ? 14 : 16))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, horizontalPadding)
                                
                                // Content Cards
                                VStack(spacing: cardSpacing) {
                                    // Introduction Card
                                    BrandCard {
                                        VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: cardIconSize))
                                                    .foregroundColor(.appAccent)
                                                Text("Quick Heads Up")
                                                    .font(.system(size: cardTitleFontSize, weight: .bold))
                                                    .foregroundColor(.primary)
                                            }
                                            
                                            Text("When you tap 'Install Shortcut', you'll see some prompts. Here's what to expect:")
                                                .font(.system(size: cardBodyFontSize))
                                                .foregroundColor(.white.opacity(0.9))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    
                                    // Main Explanation Card
                                    BrandCard {
                                        VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: cardIconSize))
                                                    .foregroundColor(.appAccent)
                                                Text("Apple's Security Feature")
                                                    .font(.system(size: cardTitleFontSize, weight: .bold))
                                                    .foregroundColor(.primary)
                                            }
                                            
                                            Text("Due to Apple's security requirements, you'll need to allow several permissions for FaithWall to work.")
                                                .font(.system(size: cardBodyFontSize))
                                                .foregroundColor(.white.opacity(0.9))
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            Divider()
                                                .background(Color.black.opacity(0.05))
                                            
                                            Text("Don't worry, this is normal!")
                                                .font(.system(size: cardBodyFontSize, weight: .semibold))
                                                .foregroundColor(.appAccent)
                                            
                                            Text("Every permission request is necessary for creating your wallpapers. Just tap 'Allow' on each one.")
                                                .font(.system(size: cardBodyFontSize))
                                                .foregroundColor(.white.opacity(0.9))
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            // Highlight box
                                            HStack(alignment: .top, spacing: isCompact ? 10 : 12) {
                                                Image(systemName: "info.circle.fill")
                                                    .font(.system(size: isCompact ? 16 : 18))
                                                    .foregroundColor(.appAccent)
                                                    .padding(.top, 2)
                                                
                                                Text("We take your privacy seriously - we never access or share your personal data.")
                                                    .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                                                    .foregroundColor(.appAccent)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .padding(isCompact ? 12 : 16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.appAccent.opacity(0.15))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                        }
                                    }
                                    
                                    // What Happens Card
                                    BrandCard {
                                        VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "questionmark.circle.fill")
                                                    .font(.system(size: cardIconSize))
                                                    .foregroundColor(.appAccent)
                                                Text("What Happens Next?")
                                                    .font(.system(size: cardTitleFontSize, weight: .bold))
                                                    .foregroundColor(.primary)
                                            }
                                            
                                            Text("After tapping 'Install Shortcut', the Shortcuts app will open and ask you to allow various permissions. Tap 'Allow' on all of them.")
                                                .font(.system(size: cardBodyFontSize))
                                                .foregroundColor(.white.opacity(0.9))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    
                                    // Solution Card
                                    BrandCard {
                                        VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.system(size: cardIconSize))
                                                    .foregroundColor(.appAccent)
                                                Text("Easy Fix")
                                                    .font(.system(size: cardTitleFontSize, weight: .bold))
                                                    .foregroundColor(.primary)
                                            }
                                            
                                            Text("If you accidentally tap 'Don't Allow', no problem!")
                                                .font(.system(size: cardBodyFontSize))
                                                .foregroundColor(.white.opacity(0.9))
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            Divider()
                                                .background(Color.black.opacity(0.05))
                                            
                                            Text("Just close the Shortcuts app and tap 'Install Shortcut' again to retry.")
                                                .font(.system(size: cardBodyFontSize))
                                                .foregroundColor(.white.opacity(0.9))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    
                                    // Call to Action Card
                                    BrandCard {
                                        VStack(spacing: isCompact ? 12 : 16) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "arrow.right.circle.fill")
                                                    .font(.system(size: cardIconSize))
                                                    .foregroundColor(.appAccent)
                                                Text("Ready? Let's do this!")
                                                    .font(.system(size: cardTitleFontSize, weight: .bold))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, horizontalPadding)
                                .padding(.bottom, AdaptiveLayout.bottomScrollPadding)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .animation(.easeInOut(duration: 0.4), value: showTextVersion)
                    } else {
                        // Video Content
                        // Welcome Video (Introduction) - Auto-playing, looping, with custom controls
                        ZStack {
                            // Original centered video layout
                            VStack(spacing: 0) {
                                if Bundle.main.url(forResource: "welcome-video", withExtension: "mp4") != nil {
                                    if let player = welcomeVideoPlayer {
                                        AutoPlayingLoopingVideoPlayer(player: player)
                                            .aspectRatio(9/16, contentMode: .fit)
                                            .frame(width: UIScreen.main.bounds.width * videoWidthRatio)
                                            .cornerRadius(isCompact ? 12 : 16)
                                            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                                            .transition(.asymmetric(
                                                insertion: .move(edge: .leading).combined(with: .opacity),
                                                removal: .move(edge: .trailing).combined(with: .opacity)
                                            ))
                                    } else {
                                        RoundedRectangle(cornerRadius: isCompact ? 12 : 16)
                                            .fill(Color.gray.opacity(0.2))
                                            .aspectRatio(9/16, contentMode: .fit)
                                            .frame(width: UIScreen.main.bounds.width * videoWidthRatio)
                                            .overlay(
                                                VStack(spacing: 8) {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    Text("Loading video...")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            )
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: isCompact ? 12 : 16)
                                        .fill(Color.gray.opacity(0.2))
                                        .aspectRatio(9/16, contentMode: .fit)
                                        .frame(width: UIScreen.main.bounds.width * videoWidthRatio)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: "video.slash")
                                                    .font(.largeTitle)
                                                    .foregroundColor(.secondary)
                                                Text("Video not available")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        )
                                }
                            }
                            
                            // Overlay buttons (positioned in black space outside video)
                            if welcomeVideoPlayer != nil {
                                let videoWidth = UIScreen.main.bounds.width * videoWidthRatio
                                let leftEdge = (UIScreen.main.bounds.width - videoWidth) / 2
                                let rightEdge = leftEdge + videoWidth
                                let leftSpace = leftEdge
                                let rightSpace = UIScreen.main.bounds.width - rightEdge
                                
                                VStack {
                                    Spacer()
                                    
                                    HStack(spacing: 0) {
                                        // Backward arrow button in left black space
                                        HStack {
                                            Spacer()
                                            VStack {
                                                Spacer()
                                                Button(action: {
                                                    seekVideo(by: -3.0)
                                                }) {
                                                    Image("skipBackward3s")
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)
                                                }
                                                .padding(.trailing, 8) // 8px from video edge
                                                Spacer()
                                            }
                                        }
                                        .frame(width: leftSpace)
                                        
                                        // Video area (spacer)
                                        Spacer()
                                            .frame(width: videoWidth)
                                        
                                        // Forward arrow button in right black space
                                        HStack {
                                            VStack {
                                                Spacer()
                                                Button(action: {
                                                    seekVideo(by: 3.0)
                                                }) {
                                                    Image("skipForward3s")
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)
                                                }
                                                .padding(.leading, 8) // 8px from video edge
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                        .frame(width: rightSpace)
                                    }
                                    .frame(width: UIScreen.main.bounds.width)
                                    
                                    Spacer()
                                }
                                .frame(width: UIScreen.main.bounds.width)
                                
                                // Progress bar (top of video, only spans video width, accounting for rounded corners)
                                VStack {
                                    HStack {
                                        Spacer()
                                            .frame(width: (UIScreen.main.bounds.width - UIScreen.main.bounds.width * videoWidthRatio) / 2)
                                        
                                        GeometryReader { geometry in
                                            let availableWidth = geometry.size.width - 22 // Subtract padding (12 left + 10 right)
                                            let progressWidth = availableWidth * CGFloat(welcomeVideoProgress)
                                            
                                            ZStack(alignment: .leading) {
                                                // Background bar
                                                Rectangle()
                                                    .fill(Color.white.opacity(0.2))
                                                    .frame(height: 3)
                                                
                                                // Progress bar (turquoise)
                                                Rectangle()
                                                    .fill(Color.appAccent)
                                                    .frame(width: progressWidth, height: 3)
                                            }
                                            .padding(.leading, 12) // Offset to account for rounded corners on left
                                            .padding(.trailing, 10) // Offset to account for rounded corners on right
                                        }
                                        .frame(width: UIScreen.main.bounds.width * videoWidthRatio, height: 3)
                                        
                                        Spacer()
                                            .frame(width: (UIScreen.main.bounds.width - UIScreen.main.bounds.width * videoWidthRatio) / 2)
                                    }
                                    .padding(.top, 0)
                                    
                                    Spacer()
                                }
                                
                                // Mute button (top-left corner of video, higher z-index)
                                VStack {
                                    HStack {
                                        Button(action: {
                                            toggleMute()
                                        }) {
                                            Image(systemName: isWelcomeVideoMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .frame(width: isCompact ? 32 : 36, height: isCompact ? 32 : 36)
                                                .background(
                                                    Circle()
                                                        .fill(Color.black.opacity(0.6))
                                                        .overlay(
                                                            Circle()
                                                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                                        )
                                                )
                                        }
                                        .padding(.leading, UIScreen.main.bounds.width * ((1 - videoWidthRatio) / 2) + 12)
                                        .padding(.top, 12)
                                        Spacer()
                                        
                                        // Pause/Play button (top-right corner of video)
                                        Button(action: {
                                            if let player = welcomeVideoPlayer {
                                                if player.rate > 0 {
                                                    player.pause()
                                                    isWelcomeVideoPaused = true
                                                    debugLog("⏸️ Welcome video paused (pause button tapped)")
                                                } else {
                                                    player.play()
                                                    isWelcomeVideoPaused = false
                                                    startWelcomeVideoProgressTracking()
                                                    debugLog("▶️ Welcome video resumed (play button tapped)")
                                                }
                                            }
                                        }) {
                                            Image(systemName: isWelcomeVideoPaused ? "play.fill" : "pause.fill")
                                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .frame(width: isCompact ? 32 : 36, height: isCompact ? 32 : 36)
                                                .background(
                                                    Circle()
                                                        .fill(Color.black.opacity(0.6))
                                                        .overlay(
                                                            Circle()
                                                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                                        )
                                                )
                                        }
                                        .padding(.trailing, UIScreen.main.bounds.width * ((1 - videoWidthRatio) / 2) + 12)
                                        .padding(.top, 12)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .animation(.easeInOut(duration: 0.4), value: showTextVersion)
                        .onAppear {
                            setupWelcomeVideoPlayer()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, isCompact ? 12 : 16)
                .padding(.bottom, AdaptiveLayout.bottomScrollPadding)
            }
        }
        .onAppear {
            // Ensure video is set up and playing when step appears
            setupWelcomeVideoPlayer()
            // Small delay to ensure view hierarchy is ready, then force play
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let player = self.welcomeVideoPlayer {
                    if player.rate == 0 && !self.isWelcomeVideoPaused {
                        player.play()
                        self.startWelcomeVideoProgressTracking()
                        debugLog("▶️ Welcome video force-started after appear delay")
                    }
                }
            }
        }
        .onDisappear {
            // Stop progress tracking when leaving the step
            stopWelcomeVideoProgressTracking()
        }
        .sheet(isPresented: $showShortcutsCheckAlert) {
            requirementsCheckView
        }
    }
    
    private func stepRowImproved(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.appAccent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\("Step") \(number)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.appAccent)
                    .textCase(.uppercase)
                
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var requirementsCheckView: some View {
        ZStack {
            // Brand identity dark gradient background
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.98, blue: 0.97), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    shortcutsSection
                    
                    if hasCompletedShortcutsCheck {
                        safariSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    if hasCompletedShortcutsCheck && hasCompletedSafariCheck {
                        requirementsCheckContinueButton
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 40)
                .padding(.horizontal, DS.Spacing.xl)
            }
        }
    }
    
    private var requirementsCheckContinueButton: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Close the combined sheet and show install sheet
            isTransitioningBetweenPopups = true
            showShortcutsCheckAlert = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showInstallSheet = true
                isTransitioningBetweenPopups = false
            }
        }) {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appAccent)
                )
                .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .padding(.top, 16)
    }
    
    private var shortcutsSection: some View {
        VStack(spacing: 24) {
            shortcutsLogo
            shortcutsTitleSection
            
            if !hasCompletedShortcutsCheck {
                shortcutsInfoCard
                shortcutsActionButtons
            } else {
                shortcutsCompletedState
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
        )
    }
    
    private var shortcutsCompletedState: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Shortcuts is ready")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.green)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, DS.Spacing.l)
        .background(Capsule().fill(Color.green.opacity(0.15)))
    }
    
    // Shortcuts section helpers
    private var shortcutsLogo: some View {
        Group {
            if let shortcutsImage = UIImage(named: "shortcuts-app-logo") {
                Image(uiImage: shortcutsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 15, x: 0, y: 8)
            } else {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.appAccent)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 15, x: 0, y: 8)
            }
        }
    }
    
    private var shortcutsTitleSection: some View {
        VStack(spacing: 8) {
            Text("FaithWall Needs Shortcuts")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("The Shortcuts app makes FaithWall work")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var shortcutsInfoCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.appAccent)
                    Text("Why do I need Shortcuts?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Text("FaithWall uses Apple's Shortcuts app to automatically update your wallpaper with your notes. It's quick, secure, and built into iOS.")
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.8))
            }
        }
    }
    
    private var shortcutsActionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                debugLog("✅ User confirmed Shortcuts is installed")
                withAnimation(.spring()) {
                    hasCompletedShortcutsCheck = true
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("I Have Shortcuts")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appAccent))
            }
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                if let url = URL(string: "https://apps.apple.com/app/id915249334") {
                    UIApplication.shared.open(url)
                    debugLog("🌐 Opening App Store to install Shortcuts")
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Download Shortcuts")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
                )
            }
        }
    }
    
    private var safariSection: some View {
        VStack(spacing: 24) {
            safariLogo
            safariTitleSection
            
            if !hasCompletedSafariCheck {
                safariInfoCard
                safariActionButtons
            } else {
                // Completed state
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Safari is ready!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, DS.Spacing.l)
                .background(Capsule().fill(Color.green.opacity(0.15)))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
        )
    }
    
    // Safari section helpers
    private var safariLogo: some View {
        Group {
            if let safariImage = UIImage(named: "safari-logo") {
                Image(uiImage: safariImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 15, x: 0, y: 8)
            } else {
                Image(systemName: "safari")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.appAccent)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 15, x: 0, y: 8)
            }
        }
    }
    
    private var safariTitleSection: some View {
        VStack(spacing: 8) {
            Text("Safari Browser Needed")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("We need Safari to install the shortcut")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var safariInfoCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.appAccent)
                    Text("Why Safari?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Text("Apple requires Shortcuts to be installed through Safari for security. Don't worry - it only takes a moment!")
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.8))
            }
        }
    }
    
    private var safariActionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                debugLog("✅ User confirmed Safari is installed")
                withAnimation(.spring()) {
                    hasCompletedSafariCheck = true
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("I Have Safari")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appAccent))
            }
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                if let url = URL(string: "https://apps.apple.com/app/id1146562112") {
                    UIApplication.shared.open(url)
                    debugLog("🌐 Opening App Store to install Safari")
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Download Safari")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
                )
            }
        }
    }
    
    @State private var showTroubleshootingTextVersion = false

    private var troubleshootingModalView: some View {
        ZStack {
            // Brand identity dark gradient background
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.98, blue: 0.97), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .onAppear {
                // Set up video player when modal appears - force setup
                debugLog("📱 Troubleshooting modal appeared - setting up video")
                setupStuckVideoPlayerIfNeeded()
                
                // If video player is still nil after a brief delay, try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.stuckGuideVideoPlayer == nil {
                        debugLog("⚠️ Video player still nil after 0.5s, retrying setup...")
                        self.setupStuckVideoPlayerIfNeeded()
                    } else {
                        // Force ensure playing after delay for returning visits
                        self.ensureStuckVideoPlaying()
                    }
                }
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Text Version / Back Button - Brand Identity Design (top left like step 2)
                    HStack {
                        if showTroubleshootingTextVersion {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    showTroubleshootingTextVersion = false
                                }
                                resumeStuckVideoIfNeeded()
                                // Ensure progress tracking restarts after a small delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.ensureStuckVideoPlaying()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("← Back to Video")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.appAccent)
                                )
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(.leading, 0) // Text version page: minimal padding
                        } else {
                            HStack(spacing: 12) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        showTroubleshootingTextVersion = true
                                    }
                                    pauseStuckVideo()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "text.alignleft")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Prefer text instructions?")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.appAccent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(height: 38) // Fixed height to match help button
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.appAccent.opacity(0.15))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                
                                // Help button next to Text version - same height as Text version
                                Button(action: {
                                    // Medium haptic feedback
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    pauseStuckVideo()
                                    showHelpSheet = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "headphones")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.appAccent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(height: 38) // Match Text version button height exactly
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.leading, 48) // Video page: more padding
                        }
                        Spacer()
                        
                        // X button with grey border (top right) - larger like paywall
                        Button(action: {
                            // Light haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            stopStuckVideoPlayback()
                            showTroubleshooting = false
                            showTroubleshootingTextVersion = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                        }
                        .padding(.trailing, showTroubleshootingTextVersion ? 0 : 48) // 8 for text version, 40 for video
                    }
                    .padding(.top, 20)
                    
                    if !showTroubleshootingTextVersion {
                        // Video Version - Brand Identity Design
                        VStack(spacing: 24) {
                            // Title Section (icon removed)
                            VStack(spacing: 12) {
                                Text("Quick Fix")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text("If the wallpaper didn't update...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.top, 20)
                            
                            // Video outside of card
                            VStack(spacing: 16) {
                                Text("Watch Quick Guide")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                ZStack {
                                    // Video player - always try to show video
                                    if let player = stuckGuideVideoPlayer {
                                        AutoPlayingLoopingVideoPlayer(player: player)
                                            .aspectRatio(9/16, contentMode: .fit)
                                            .frame(width: UIScreen.main.bounds.width * 0.7)
                                            .cornerRadius(16)
                                            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                                    } else {
                                        // Loading state while video is being set up
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.gray.opacity(0.2))
                                            .aspectRatio(9/16, contentMode: .fit)
                                            .frame(width: UIScreen.main.bounds.width * 0.7)
                                            .overlay(
                                                VStack(spacing: 8) {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    Text("Loading video...")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            )
                                    }
                                    
                                    // Overlay controls styled the same as the intro video
                                    let videoWidth = UIScreen.main.bounds.width * 0.7
                                    let leftEdge = (UIScreen.main.bounds.width - videoWidth) / 2
                                    let rightEdge = leftEdge + videoWidth
                                    let leftSpace = leftEdge
                                    let rightSpace = UIScreen.main.bounds.width - rightEdge
                                    
                                    VStack {
                                        Spacer()
                                        
                                        HStack(spacing: 0) {
                                            // Backward button
                                            HStack {
                                                Spacer()
                                                VStack {
                                                    Spacer()
                                                    Button(action: {
                                                        seekStuckVideo(by: -3.0)
                                                    }) {
                                                        Image("skipBackward3s")
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: 44, height: 44)
                                                            .opacity(stuckGuideVideoPlayer == nil ? 0.5 : 1)
                                                    }
                                                    .padding(.trailing, 8)
                                                    .disabled(stuckGuideVideoPlayer == nil)
                                                    Spacer()
                                                }
                                            }
                                            .frame(width: leftSpace)
                                            
                                            Spacer()
                                                .frame(width: videoWidth)
                                            
                                            // Forward button
                                            HStack {
                                                VStack {
                                                    Spacer()
                                                    Button(action: {
                                                        seekStuckVideo(by: 3.0)
                                                    }) {
                                                        Image("skipForward3s")
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: 44, height: 44)
                                                            .opacity(stuckGuideVideoPlayer == nil ? 0.5 : 1)
                                                    }
                                                    .padding(.leading, 8)
                                                    .disabled(stuckGuideVideoPlayer == nil)
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                            .frame(width: rightSpace)
                                        }
                                        .frame(width: UIScreen.main.bounds.width)
                                        
                                        Spacer()
                                    }
                                    .frame(width: UIScreen.main.bounds.width)
                                    
                                    // Progress bar
                                    VStack {
                                        HStack {
                                            Spacer()
                                                .frame(width: (UIScreen.main.bounds.width - UIScreen.main.bounds.width * 0.7) / 2)
                                            
                                            GeometryReader { geometry in
                                                let availableWidth = geometry.size.width - 22
                                                let progressWidth = availableWidth * CGFloat(stuckVideoProgress)
                                                
                                                ZStack(alignment: .leading) {
                                                    Rectangle()
                                                        .fill(Color.white.opacity(0.2))
                                                        .frame(height: 3)
                                                    
                                                    Rectangle()
                                                        .fill(Color.appAccent)
                                                        .frame(width: progressWidth, height: 3)
                                                }
                                                .padding(.leading, 12)
                                                .padding(.trailing, 10)
                                            }
                                            .frame(width: UIScreen.main.bounds.width * 0.7, height: 3)
                                            
                                            Spacer()
                                                .frame(width: (UIScreen.main.bounds.width - UIScreen.main.bounds.width * 0.7) / 2)
                                        }
                                        .padding(.top, 0)
                                        
                                        Spacer()
                                    }
                                    
                                    // Mute button (top-left) and Pause/Play button (top-right)
                                    VStack {
                                        HStack {
                                            Button(action: {
                                                toggleStuckVideoMute()
                                            }) {
                                                Image(systemName: isStuckVideoMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                    .frame(width: 36, height: 36)
                                                    .background(
                                                        Circle()
                                                            .fill(Color.black.opacity(0.6))
                                                            .overlay(
                                                                Circle()
                                                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                                            )
                                                    )
                                                    .opacity(stuckGuideVideoPlayer == nil ? 0.5 : 1)
                                            }
                                            .disabled(stuckGuideVideoPlayer == nil)
                                            .padding(.leading, UIScreen.main.bounds.width * 0.15 + 12)
                                            .padding(.top, 12)
                                            Spacer()
                                            
                                            // Pause/Play button (top-right corner of video)
                                            Button(action: {
                                                if let player = stuckGuideVideoPlayer {
                                                    if player.rate > 0 {
                                                        pauseStuckVideo()
                                                    } else {
                                                        resumeStuckVideoIfNeeded(forcePlay: true)
                                                    }
                                                }
                                            }) {
                                                Image(systemName: isStuckVideoPaused ? "play.fill" : "pause.fill")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                    .frame(width: 36, height: 36)
                                                    .background(
                                                        Circle()
                                                            .fill(Color.black.opacity(0.6))
                                                            .overlay(
                                                                Circle()
                                                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                                            )
                                                    )
                                                    .opacity(stuckGuideVideoPlayer == nil ? 0.5 : 1)
                                            }
                                            .disabled(stuckGuideVideoPlayer == nil)
                                            .padding(.trailing, UIScreen.main.bounds.width * 0.15 + 12)
                                            .padding(.top, 12)
                                        }
                                        Spacer()
                                    }
                                }
                                .onAppear {
                                    setupStuckVideoPlayerIfNeeded()
                                }
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                            
                            // Instruction wallpaper image
                            VStack(spacing: 12) {
                                Image("InstructionWallpaper")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width * 0.5)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                                
                                Text("Note: The image appears red in Photos, but looks normal on your lock screen")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, DS.Spacing.xl)
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.top, 8)
                            
                            // Primary CTA Button - Brand Style
            Button(action: {
                // Medium haptic for important action
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                stopStuckVideoPlayback()
                
                // Save instruction wallpaper to Photos first, then open Photos
                saveInstructionWallpaperToPhotos()
                
                // Small delay to ensure image is saved before opening Photos
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    openWallpaperSettings()
                }
            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 18, weight: .semibold))
                            Text("Open Photos App")
                                        .font(.system(size: 17, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.appAccent)
                                            .blur(radius: 12)
                                            .opacity(0.4)
                                            .offset(y: 4)
                                        
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.appAccent)
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .padding(.horizontal, 48)
                        
                            // Secondary Button
                        Button(action: {
                        stopStuckVideoPlayback()
                            showTroubleshooting = false
                        }) {
                            Text("I'll Do This Later")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        }
                    } else {
                        // Text Version - Brand Identity Design
                        troubleshootingTextGuide
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onDisappear {
            stopStuckVideoPlayback()
        }
        .onChange(of: showHelpSheet) { isShowing in
            if isShowing {
                pauseStuckVideo()
            }
        }
    }
    
    private var troubleshootingTextGuide: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Hero Icon
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.appAccent)
                }
                .padding(.top, 20)
                
                // Title Section
                VStack(spacing: 8) {
                    Text("Wallpaper Not Showing?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Don't worry, it's an easy fix.")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            
                // Content Cards
                VStack(spacing: 16) {
                    // Explanation Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.appAccent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("The Issue")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("iOS sometimes hides new wallpapers in Photos. The image IS created, but it might look like a solid RED square.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appAccent.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Steps Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Follow these steps:")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.bottom, 16)
                        
                        VStack(alignment: .leading, spacing: 24) {
                            troubleshootingStep(number: 1, title: "Open Photos", description: "Tap the button below to open the Photos app.")
                            troubleshootingStep(number: 2, title: "Find the Red Image", description: "Look for the most recent image. It will appear as a solid RED square.")
                            troubleshootingStep(number: 3, title: "Tap Share", description: "Tap the share button (box with arrow) on that red image.")
                            troubleshootingStep(number: 4, title: "Use as Wallpaper", description: "Scroll down and select 'Use as Wallpaper'.")
                            troubleshootingStep(number: 5, title: "Set Lock Screen", description: "Tap 'Add' then 'Set Lock Screen Pair' or just 'Set Lock Screen'.")
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
                .padding(.horizontal, 20)
            
                // Primary CTA Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    saveInstructionWallpaperToPhotos()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        openWallpaperSettings()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Open Photos App")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.appAccent)
                            .shadow(color: Color.appAccent.opacity(0.4), radius: 10, x: 0, y: 5)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            
                // Secondary Button
                Button(action: {
                    showTroubleshooting = false
                    showTroubleshootingTextVersion = false
                }) {
                    Text("I'll do this later")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func troubleshootingStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 32, height: 32)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text("\(number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }
    
    @ViewBuilder
    private func installShortcutStep() -> some View {
        if userWentToSettings {
            installShortcutRetryView()
        } else {
            installShortcutCheckView()
        }
    }
    
    private func installShortcutRetryView() -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let titleFontSize: CGFloat = isCompact ? 26 : 32
        let cardTitleFontSize: CGFloat = isCompact ? 16 : 18
        let cardBodyFontSize: CGFloat = isCompact ? 14 : 16
        let cardIconSize: CGFloat = isCompact ? 18 : 20
        let buttonIconSize: CGFloat = isCompact ? 18 : 20
        let buttonFontSize: CGFloat = isCompact ? 16 : 18
        let sectionSpacing: CGFloat = isCompact ? 20 : 32
        let horizontalPadding: CGFloat = isCompact ? 16 : 24
        let heroIconSize: CGFloat = isCompact ? 90 : 110
        let checkIconSize: CGFloat = isCompact ? 36 : 44
        let ringSize: CGFloat = isCompact ? 100 : 130
        let heroHeight: CGFloat = isCompact ? 130 : 160
        
        return ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isCompact ? 16 : 24) {
                    ZStack {
                        Color.white.ignoresSafeArea()
                        
                        VStack(spacing: sectionSpacing) {
                            ZStack {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                                        .frame(width: ringSize + CGFloat(i) * (isCompact ? 22 : 30), height: ringSize + CGFloat(i) * (isCompact ? 22 : 30))
                                        .scaleEffect(1.1)
                                        .opacity(0.4)
                                }
                                
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: heroIconSize, height: heroIconSize)
                                    
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: checkIconSize, weight: .medium))
                                        .foregroundColor(.appAccent)
                                        .shadow(color: Color.appAccent.opacity(0.5), radius: 10, x: 0, y: 5)
                                }
                            }
                            .frame(height: heroHeight)
                            .padding(.top, isCompact ? 12 : 20)
                            
                            VStack(spacing: isCompact ? 8 : 12) {
                                Text("Ready to try again?")
                                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, horizontalPadding)
                            
                            BrandCard {
                                VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: cardIconSize))
                                            .foregroundColor(.appAccent)
                                        Text("All Set!")
                                            .font(.system(size: cardTitleFontSize, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Text("Great! Your shortcut is installed and ready to go.")
                                        .font(.system(size: cardBodyFontSize))
                                        .foregroundColor(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Divider()
                                        .background(Color.black.opacity(0.05))
                                    
                                    Text("Note: If you need to reinstall later, you can find it in the app settings.")
                                        .font(.system(size: cardBodyFontSize, weight: .semibold))
                                        .foregroundColor(.appAccent)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                
                                pipVideoPlayerManager.stopPictureInPicture()
                                pipVideoPlayerManager.stop()
                                shouldStartPiP = false
                                
                                showInstallSheet = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: buttonIconSize, weight: .semibold))
                                    Text("Install Shortcut Again")
                                        .font(.system(size: buttonFontSize, weight: .semibold))
                                }
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isCompact ? 14 : 18)
                                .background(
                                    RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                        .fill(Color.appAccent)
                                )
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, isCompact ? 24 : 40)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, isCompact ? 20 : 36)
                .padding(.bottom, AdaptiveLayout.bottomScrollPadding)
            }
        }
        .scrollAlwaysBounceIfAvailable()
    }
    
    private func installShortcutCheckView() -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let titleFontSize: CGFloat = isCompact ? 26 : 32
        let subtitleFontSize: CGFloat = isCompact ? 17 : 20
        let cardTitleFontSize: CGFloat = isCompact ? 16 : 18
        let cardBodyFontSize: CGFloat = isCompact ? 14 : 16
        let cardIconSize: CGFloat = isCompact ? 18 : 20
        let buttonIconSize: CGFloat = isCompact ? 18 : 20
        let buttonFontSize: CGFloat = isCompact ? 16 : 18
        let sectionSpacing: CGFloat = isCompact ? 20 : 32
        let buttonSpacing: CGFloat = isCompact ? 12 : 16
        let horizontalPadding: CGFloat = isCompact ? 16 : 24
        
        return ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: isCompact ? 16 : 24) {
                    VStack(spacing: sectionSpacing) {
                        VStack(spacing: isCompact ? 8 : 12) {
                            Text("Installation Check")
                                .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("Did the shortcut install successfully?")
                                .font(.system(size: subtitleFontSize, weight: .semibold))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, isCompact ? 36 : 60)
                        
                        BrandCard {
                            VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: cardIconSize))
                                        .foregroundColor(.appAccent)
                                    Text("Quick Check")
                                        .font(.system(size: cardTitleFontSize, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                
                                Text("Were you able to tap 'Allow' on all the permission prompts in the Shortcuts app?")
                                    .font(.system(size: cardBodyFontSize))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        VStack(spacing: buttonSpacing) {
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                advanceStep()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: isCompact ? 20 : 24, weight: .semibold))
                                    Text("Yes, It Worked!")
                                        .font(.system(size: buttonFontSize, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isCompact ? 14 : 18)
                                .background(
                                    RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                        .fill(Color.appAccent)
                                )
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                            }
                            
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                showTroubleshooting = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .font(.system(size: buttonIconSize, weight: .semibold))
                                    Text("No, I Got Stuck")
                                        .font(.system(size: buttonFontSize, weight: .semibold))
                                }
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isCompact ? 14 : 18)
                                .background(
                                    RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                        .fill(Color.black.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5)
                                        )
                                )
                            }
                            
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                installShortcut()
                            }) {
                                VStack(spacing: 2) {
                                    Text("Accidentally cancelled?")
                                        .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                    if #available(iOS 15.0, *) {
                                        Text(createUnderlinedText("Replay the video"))
                                            .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                    } else {
                                        Text("Replay the video")
                                            .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                    }
                                }
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, isCompact ? 4 : 8)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, isCompact ? 24 : 40)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, isCompact ? 20 : 36)
                .padding(.bottom, AdaptiveLayout.bottomScrollPadding)
            }
        }
        .scrollAlwaysBounceIfAvailable()
    }
    
    private func installShortcutInfoCard(title: String, subtitle: String, icon: String, highlightedText: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.appAccent)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                
                if let highlightedText = highlightedText, subtitle.contains(highlightedText) {
                    // Create attributed text with highlighted portion
                    let parts = subtitle.components(separatedBy: highlightedText)
                    if parts.count == 2 {
                        (Text(parts[0])
                            .foregroundColor(.secondary) +
                         Text(highlightedText)
                            .foregroundColor(.appAccent)
                            .fontWeight(.bold) +
                         Text(parts[1])
                            .foregroundColor(.secondary))
                        .font(.body)
                    } else {
                        Text(subtitle)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func addNotesStep() -> some View {
        OnboardingVerseSelectionView { text, reference in
            // Add note and advance
            let newNote = Note(text: text, reference: reference)
            onboardingNotes.append(newNote)
            saveOnboardingNotes()
            
            // Light impact haptic
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            advanceStep()
        }
    }
    
    private func addCurrentNote(scrollProxy: ScrollViewProxy) {
        let trimmed = currentNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Light impact haptic for adding note during onboarding
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation {
            let newNote = Note(text: trimmed, isCompleted: false)
            onboardingNotes.append(newNote)
            currentNoteText = ""
            isNoteFieldFocused = true
            
            // Scroll to the newly added note with center anchor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollProxy.scrollTo(newNote.id, anchor: .center)
                }
            }
        }
    }
    
    private func removeNote(_ note: Note) {
        if let index = onboardingNotes.firstIndex(where: { $0.id == note.id }) {
            // Light impact haptic for removing note during onboarding
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onboardingNotes.remove(at: index)
        }
    }
    
    private func noteIndex(for note: Note) -> Int {
        return onboardingNotes.firstIndex(where: { $0.id ==
            note.id }) ?? 0
    }

    @State private var hasConfirmedPermissions: Bool = false // Simple checkbox state

    private func allowPermissionsStep() -> some View {
        // Use adaptive layout values based on device size
        let isCompact = ScreenDimensions.isCompactDevice
        let horizontalPadding = AdaptiveLayout.horizontalPadding
        let titleFontSize: CGFloat = isCompact ? 24 : 34
        let hintFontSize: CGFloat = isCompact ? 16 : 20
        let instructionFontSize: CGFloat = isCompact ? 15 : 18
        let arrowSize: CGFloat = isCompact ? 16 : 20
        let arrowSpacing: CGFloat = isCompact ? 12 : 20
        let topPadding: CGFloat = isCompact ? 12 : 24
        let sectionSpacing: CGFloat = isCompact ? 8 : 16
        
        return GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Title - adaptive font size
                    Text("Allow All Permissions")
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalPadding)
                    
                    // Arrows pointing up - compact on small devices
                    HStack(spacing: arrowSpacing) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(spacing: isCompact ? 2 : 4) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: arrowSize, weight: .bold))
                                Image(systemName: "chevron.up")
                                    .font(.system(size: arrowSize, weight: .bold))
                                    .opacity(0.5)
                            }
                            .foregroundColor(.appAccent)
                        }
                    }
                    .padding(.top, sectionSpacing)
                    .padding(.bottom, isCompact ? 4 : 8)
                    
                    // Hint text - adaptive font size
                    Text("You'll see several permission requests")
                        .font(.system(size: hintFontSize, weight: .semibold))
                        .foregroundColor(.appAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.bottom, isCompact ? 4 : 8)
                    
                    // Title below hint text
                    Text("Click 'Allow' on each one to continue")
                        .font(.system(size: instructionFontSize, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.bottom, sectionSpacing)
                    
                    // Video at adaptive size - CRITICAL: Scale down significantly on compact devices
                    if let player = notificationsVideoPlayer {
                        let availableWidth = proxy.size.width - (horizontalPadding * 2)
                        
                        // Scale down the mockup to prevent interference with subtitle and CTA
                        let mockupScale: CGFloat = 0.85
                        let scaledWidth = availableWidth * mockupScale
                        
                        // CRITICAL FIX: Use much smaller video height on compact devices
                        // to ensure confirmation button is visible without scrolling
                        let maxVideoHeight = AdaptiveLayout.maxVideoHeight
                        let aspectBasedHeight = scaledWidth * 0.6
                        let containerHeight = min(aspectBasedHeight, maxVideoHeight)
                        let topCrop: CGFloat = isCompact ? 5 : 10
                        
                        CroppedVideoPlayerView(
                            player: player,
                            topCrop: topCrop
                        )
                        .frame(width: scaledWidth, height: containerHeight)
                        .clipped()
                        .contentShape(Rectangle())
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, isCompact ? 8 : 20)
                        .padding(.bottom, isCompact ? 6 : 12)
                        .onAppear {
                            // Bulletproof video playback when view appears
                            func startPlayback(attempt: Int = 1) {
                                guard attempt <= 10 else {
                                    debugLog("❌ VideoPlayer max retry attempts reached")
                                    return
                                }
                                
                                // Check if player item is ready
                                if let item = player.currentItem {
                                    if item.status != .readyToPlay {
                                        debugLog("⚠️ VideoPlayer item not ready (status: \(item.status.rawValue), attempt \(attempt)), retrying in 0.2s")
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            startPlayback(attempt: attempt + 1)
                                        }
                                        return
                                    }
                                }
                                
                                // Ensure looper is active for continuous looping
                                if let looper = notificationsVideoLooper {
                                    if looper.status == .failed, let item = player.currentItem {
                                        let newLooper = AVPlayerLooper(player: player, templateItem: item)
                                        notificationsVideoLooper = newLooper
                                        debugLog("🔄 Recreated video looper in video view onAppear")
                                    }
                                } else if let item = player.currentItem {
                                    let newLooper = AVPlayerLooper(player: player, templateItem: item)
                                    notificationsVideoLooper = newLooper
                                    debugLog("🔄 Created video looper in video view onAppear")
                                }
                                
                                // Configure audio session
                                do {
                                    try AVAudioSession.sharedInstance().setActive(false)
                                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                                    try AVAudioSession.sharedInstance().setActive(true)
                                } catch {
                                    debugLog("⚠️ Failed to configure audio session in onAppear: \(error)")
                                }
                                
                                // Start playback
                                player.seek(to: .zero)
                                player.play()
                                debugLog("▶️ VideoPlayer onAppear: Started playback (attempt \(attempt), rate: \(player.rate))")
                                
                                // Verify it's playing, retry if needed
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if player.rate == 0 {
                                        debugLog("⚠️ VideoPlayer not playing, retrying...")
                                        startPlayback(attempt: attempt + 1)
                                    } else {
                                        debugLog("✅ VideoPlayer playing and looping")
                                    }
                                }
                            }
                            
                            DispatchQueue.main.async {
                                startPlayback()
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if player.rate == 0 {
                                    startPlayback(attempt: 5)
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if player.rate == 0 {
                                    debugLog("⚠️ VideoPlayer still not playing after 1.5s, final retry")
                                    startPlayback(attempt: 8)
                                }
                            }
                        }
                        .onDisappear {
                            debugLog("⚠️ VideoPlayer disappeared")
                        }
                    } else {
                        // Placeholder while loading - smaller on compact
                        VStack(spacing: isCompact ? 8 : 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 20 : 40)
                        .padding(.horizontal, horizontalPadding)
                        .onAppear {
                            prepareNotificationsVideoPlayerIfNeeded()
                        }
                    }
                    
                    // Text below video - adaptive font
                    Text("How it should look:")
                        .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.top, isCompact ? 6 : 12)
                    
                    // CRITICAL: Confirmation button - MUST be visible on all devices
                    // This is the primary fix - ensure this button is always reachable
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            hasConfirmedPermissions.toggle()
                        }
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }) {
                        HStack(alignment: .center, spacing: isCompact ? 10 : 12) {
                            Image(systemName: hasConfirmedPermissions ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: isCompact ? 18 : 20, weight: .medium))
                                .foregroundColor(hasConfirmedPermissions ? Color.appAccent : Color.white.opacity(0.4))
                            
                            // Single line on all devices
                            Text("I've Granted All Permissions")
                                .font(.system(size: isCompact ? 15 : 16, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            
                            Spacer()
                        }
                        .padding(.horizontal, isCompact ? 16 : 20)
                        .padding(.vertical, isCompact ? 12 : 16)
                        .background(
                            RoundedRectangle(cornerRadius: AdaptiveLayout.cornerRadius, style: .continuous)
                                .fill(hasConfirmedPermissions ? Color.appAccent.opacity(0.15) : Color.black.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AdaptiveLayout.cornerRadius, style: .continuous)
                                        .strokeBorder(hasConfirmedPermissions ? Color.appAccent.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, isCompact ? 10 : 16)
                    // CRITICAL: Add generous bottom padding to ensure visibility above sticky Continue button
                    .padding(.bottom, AdaptiveLayout.bottomScrollPadding)
                }
            }
        }
        .onAppear {
            debugLog("📱 Allow Permissions step appeared")
            hasConfirmedPermissions = false
            
            // CRITICAL: Configure audio session for notifications video playback
            // The PiP video player might have set it to a different mode
            do {
                try AVAudioSession.sharedInstance().setActive(false)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                debugLog("✅ Audio session configured for notifications video")
            } catch {
                debugLog("⚠️ Failed to configure audio session: \(error)")
            }
            
            prepareNotificationsVideoPlayerIfNeeded()
            
            // Ensure video starts playing automatically and loops - try multiple times to handle timing
            func startVideoPlayback() {
                if let player = self.notificationsVideoPlayer {
                    // Ensure looper is active for continuous looping
                    if let looper = self.notificationsVideoLooper {
                        if looper.status == .failed, let item = player.currentItem {
                            // Recreate looper if it failed
                            let newLooper = AVPlayerLooper(player: player, templateItem: item)
                            self.notificationsVideoLooper = newLooper
                            debugLog("🔄 Recreated video looper")
                        }
                    } else if let item = player.currentItem {
                        // Create looper if it doesn't exist
                        let newLooper = AVPlayerLooper(player: player, templateItem: item)
                        self.notificationsVideoLooper = newLooper
                        debugLog("🔄 Created video looper")
                    }
                    
                    // Start playback
                    player.seek(to: .zero)
                    player.play()
                    debugLog("▶️ Attempted to start notifications video (rate: \(player.rate))")
                    
                    // Verify playback started and retry if needed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if player.rate == 0 {
                            // Retry with audio session reconfiguration
                            do {
                                try AVAudioSession.sharedInstance().setActive(false)
                                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                                try AVAudioSession.sharedInstance().setActive(true)
                            } catch {
                                debugLog("⚠️ Failed to reconfigure audio session: \(error)")
                            }
                            player.seek(to: .zero)
                            player.play()
                            debugLog("✅ Retry: Started notifications video playback (rate: \(player.rate))")
                        } else {
                            debugLog("✅ Notifications video playing and looping (rate: \(player.rate))")
                        }
                    }
                } else {
                    // Player not created yet, wait and try again
                    debugLog("⚠️ Player not ready, retrying in 0.3s")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        startVideoPlayback()
                    }
                }
            }
            
            // Start playback attempt immediately and with delays
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startVideoPlayback()
            }
            
            // Also try after a longer delay to ensure it starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let player = self.notificationsVideoPlayer, player.rate == 0 {
                    debugLog("⚠️ Video still not playing after 0.5s, forcing restart")
                    startVideoPlayback()
                }
            }
            
            // Final retry after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let player = self.notificationsVideoPlayer, player.rate == 0 {
                    debugLog("⚠️ Video still not playing after 1.0s, final retry")
                    // Force audio session reset
                    do {
                        try AVAudioSession.sharedInstance().setActive(false)
                        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                        try AVAudioSession.sharedInstance().setActive(true)
                    } catch {
                        debugLog("⚠️ Failed to reset audio session: \(error)")
                    }
                    player.seek(to: .zero)
                    player.play()
                }
            }
        }
    }
    
    
    // Removed old permission tracking functions - now using simple checkbox confirmation
    
    /*
    private func handlePermissionAreaTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastPermissionTapTime)
        
        debugLog("🔵 Permission tap detected! Current count: \(permissionCount), Time since last: \(timeSinceLastTap)")
        
        // Increment permission count for each tap (0 → 1 → 2 → 3)
        if permissionCount < 3 {
            let newCount = permissionCount + 1
            debugLog("🔵 Incrementing permission count: \(permissionCount) → \(newCount)")
            
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                permissionCount = newCount
            }
            
            // If we've reached 3, set the flag and stop tracking
            if permissionCount >= 3 {
                debugLog("✅ Reached 3 permissions via taps, stopping tracking")
                hasManuallySetToThree = true
                stopPermissionTracking()
            }
        } else {
            debugLog("⚠️ Permission count already at 3, ignoring tap")
        }
        
        // Track tap timing for analytics (but don't use it for counting)
        if timeSinceLastTap < 3.0 {
            permissionTapCount += 1
        } else {
            permissionTapCount = 1
        }
        
        lastPermissionTapTime = now
        
        // Also check actual permissions after a short delay to catch real permission grants
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !self.hasManuallySetToThree {
                debugLog("🔵 Checking actual permissions after tap...")
            self.updatePermissionCount()
            }
        }
    }
    
    private func updatePermissionCount() {
        // Don't update if we've manually set to 3 based on taps
        guard !hasManuallySetToThree else {
            debugLog("⏭️ Skipping permission check - manually set to 3")
            return
        }
        
        debugLog("🔍 updatePermissionCount() called - checking all permissions...")
        var count = 0
        
        // Check 1: Home Screen folder access via marker file
        // The shortcut should create a marker file when it successfully runs with permission
        let homeScreenFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FaithWall", isDirectory: true)
            .appendingPathComponent("HomeScreen", isDirectory: true)
        
        var hasHomeScreenAccess = false
        if let homeURL = homeScreenFolderURL {
            // Check for marker files that indicate the shortcut successfully ran with permission
            // Look for any recent files created by the shortcut (within last 5 minutes)
            let markerFiles = [
                ".permission-granted",
                ".shortcut-success",
                "homescreen.jpg", // The actual wallpaper file the shortcut creates
                "home_preset_black.jpg",
                "home_preset_gray.jpg"
            ]
            
            for markerName in markerFiles {
                let markerFile = homeURL.appendingPathComponent(markerName)
                if FileManager.default.fileExists(atPath: markerFile.path) {
                    // Check if file was created recently (within last 5 minutes)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: markerFile.path),
                       let creationDate = attributes[.creationDate] as? Date,
                       Date().timeIntervalSince(creationDate) < 300 { // 5 minutes
                        hasHomeScreenAccess = true
                        debugLog("📁 Home Screen folder: ✅ accessible (found marker: \(markerName), created \(Int(Date().timeIntervalSince(creationDate)))s ago)")
                        break
                    } else if FileManager.default.fileExists(atPath: markerFile.path) {
                        // File exists but might be old - still count it as permission was granted at some point
                        hasHomeScreenAccess = true
                        debugLog("📁 Home Screen folder: ✅ accessible (found marker: \(markerName), may be older)")
                        break
                    }
                }
            }
            
            if !hasHomeScreenAccess {
                debugLog("📁 Home Screen folder: ❌ no marker files found")
            }
        }
        
        if hasHomeScreenAccess {
            count += 1
            debugLog("   ✅ Counting Home Screen folder (count now: \(count))")
        }
        
        // Check 2: Lock Screen folder access via marker file
        let lockScreenFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FaithWall", isDirectory: true)
            .appendingPathComponent("LockScreen", isDirectory: true)
        
        var hasLockScreenAccess = false
        if let lockURL = lockScreenFolderURL {
            let markerFiles = [
                ".permission-granted",
                ".shortcut-success",
                "lockscreen.jpg", // The actual wallpaper file the shortcut creates
                "lockscreen_background.jpg"
            ]
            
            for markerName in markerFiles {
                let markerFile = lockURL.appendingPathComponent(markerName)
                if FileManager.default.fileExists(atPath: markerFile.path) {
                    // Check if file was created recently (within last 5 minutes)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: markerFile.path),
                       let creationDate = attributes[.creationDate] as? Date,
                       Date().timeIntervalSince(creationDate) < 300 { // 5 minutes
                        hasLockScreenAccess = true
                        debugLog("📁 Lock Screen folder: ✅ accessible (found marker: \(markerName), created \(Int(Date().timeIntervalSince(creationDate)))s ago)")
                        break
                    } else if FileManager.default.fileExists(atPath: markerFile.path) {
                        // File exists but might be old - still count it as permission was granted at some point
                        hasLockScreenAccess = true
                        debugLog("📁 Lock Screen folder: ✅ accessible (found marker: \(markerName), may be older)")
                        break
                    }
                }
            }
            
            if !hasLockScreenAccess {
                debugLog("📁 Lock Screen folder: ❌ no marker files found")
            }
        }
        
        if hasLockScreenAccess {
            count += 1
            debugLog("   ✅ Counting Lock Screen folder (count now: \(count))")
        }
        
        // Check 3: Notification permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                // Don't update if we've manually set to 3 based on taps
                guard !self.hasManuallySetToThree else {
                    debugLog("⏭️ Skipping permission check (async) - manually set to 3")
                    return
                }
                
                var newCount = count
                let notificationAuthorized = settings.authorizationStatus == .authorized
                debugLog("🔔 Notifications: status=\(settings.authorizationStatus.rawValue) (\(notificationAuthorized ? "✅ granted" : "❌ not granted"))")
                
                if notificationAuthorized {
                    newCount += 1
                    debugLog("   ✅ Counting Notifications (count now: \(newCount))")
                }
                
                debugLog("📊 Permission check result: \(newCount)/3 (current displayed: \(self.permissionCount)/3)")
                
                // Always update if the new count is different (but only increase, never decrease)
                if newCount > self.permissionCount {
                    debugLog("✅ Updating permission count: \(self.permissionCount) → \(newCount)")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        self.permissionCount = newCount
                    }
                } else if newCount == self.permissionCount {
                    debugLog("➡️ Permission count unchanged: \(newCount)/3")
                } else {
                    debugLog("⚠️ Permission count would decrease (\(self.permissionCount) → \(newCount)), not updating")
                }
            }
        }
    }
    */

    @ViewBuilder
    private func chooseWallpapersStep(includePhotoPicker: Bool) -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let titleFontSize: CGFloat = isCompact ? 24 : 28
        let sectionSpacing: CGFloat = isCompact ? 16 : 24
        let horizontalPadding: CGFloat = isCompact ? 16 : 24
        let topPadding: CGFloat = isCompact ? 20 : 32
        let buttonSize: CGFloat = isCompact ? 32 : 36
        let buttonIconSize: CGFloat = isCompact ? 12 : 14
        
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                // Title row with help and edit buttons
                HStack(alignment: .top) {
                    Text("Choose Your Wallpapers")
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    
                    Spacer()
                    
                    // Buttons stacked vertically, aligned to the right
                    VStack(alignment: .trailing, spacing: isCompact ? 6 : 8) {
                        // Help button tile (squarish) - above Edit Notes
                        Button(action: {
                            // Medium haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            showHelpSheet = true
                        }) {
                            Image(systemName: "headphones")
                                .font(.system(size: buttonIconSize, weight: .semibold))
                                .foregroundColor(.appAccent)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.clear)
                                )
                        }
                        
                        // Edit Notes button
                        Button(action: {
                            // Light impact haptic for edit notes button
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage = .addNotes
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: buttonIconSize, weight: .semibold))
                                Text("Edit Notes")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                            }
                            .foregroundColor(.appAccent)
                            .padding(.horizontal, isCompact ? 10 : 12)
                            .padding(.vertical, isCompact ? 6 : 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.appAccent.opacity(0.1))
                            )
                        }
                    }
                }

                if includePhotoPicker {
                    if #available(iOS 16.0, *) {
                        if isLoadingWallpaperStep {
                            VStack(spacing: isCompact ? 12 : 16) {
                                LoadingPlaceholder()
                                LoadingPlaceholder()
                                LoadingPlaceholder()
                            }
                            .transition(.opacity)
                        } else {
                            VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
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

                                if let message = homeScreenStatusMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(homeScreenStatusColor)
                                }
                                
                                Divider()
                                    .padding(.vertical, isCompact ? 8 : 12)

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

                                if let message = lockScreenBackgroundStatusMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(lockScreenBackgroundStatusColor)
                                }
                                
                                // Lock Screen Widgets Section - clear card-based design
                                lockScreenWidgetsSection
                                    .padding(.top, isCompact ? 16 : 24)
                            }
                            .transition(.opacity)
                        }
                    }
                } else {
                        Text("⚠️ Lock screen customization requires iOS 16 or later")
                            .font(.caption)
                            .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, AdaptiveLayout.bottomScrollPadding)
        }
        .onAppear(perform: ensureCustomPhotoFlagIsAccurate)
        .scrollAlwaysBounceIfAvailable()
    }
    
    private var lockScreenWidgetsSection: some View {
        let isCompact = ScreenDimensions.isCompactDevice
        
        return VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
            // Clear heading
            VStack(alignment: .leading, spacing: 4) {
                Text("Do you use lock screen widgets?")
                    .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Add FaithWall widgets to see notes without unlocking")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray2))
            }
            
            // Option buttons
            HStack(spacing: isCompact ? 10 : 12) {
                // Yes button (white)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation {
                        hasLockScreenWidgets = true
                        hasSelectedWidgetOption = true
                    }
                }) {
                    Text("Yes")
                        .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 12 : 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(hasSelectedWidgetOption && hasLockScreenWidgets ? Color.appAccent : Color.clear, lineWidth: 2.5)
                                )
                        )
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
                
                // No button (white)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation {
                        hasLockScreenWidgets = false
                        hasSelectedWidgetOption = true
                    }
                }) {
                    Text("No")
                        .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 12 : 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(hasSelectedWidgetOption && !hasLockScreenWidgets ? Color.appAccent : Color.clear, lineWidth: 2.5)
                                )
                        )
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
            }
            
            // Settings note
            Text("You can change this anytime in Settings")
                .font(.caption)
                .foregroundColor(Color(.systemGray3))
        }
        .padding(isCompact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }

    private func overviewStep() -> some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let subtitleFontSize: CGFloat = isCompact ? 14 : 16
        let buttonFontSize: CGFloat = isCompact ? 16 : 18
        let topSpacing: CGFloat = isCompact ? 24 : 40
        let mockupSpacing: CGFloat = isCompact ? 16 : 24
        let horizontalPadding: CGFloat = isCompact ? 28 : 40
        let buttonBottomPadding: CGFloat = isCompact ? 24 : 40
        
        return ZStack {
            // Dark background
            Color.white.ignoresSafeArea()
            
            // Confetti overlay
            if showConfetti {
                ConfettiView(trigger: $confettiTrigger)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: topSpacing)
                
                // iPhone mockup preview - large and prominent
                iPhoneMockupPreview
                    .opacity(showMockupPreview ? 1 : 0)
                    .scaleEffect(showMockupPreview ? 1 : 0.95)
                    .animation(.easeOut(duration: 0.5), value: showMockupPreview)
                
                Spacer()
                    .frame(height: mockupSpacing)
                
                // Subtitle
                Text("See your notes every time you unlock your phone")
                    .font(.system(size: subtitleFontSize))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, horizontalPadding)
                    .opacity(showMockupPreview ? 1 : 0)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Complete onboarding immediately (show paywall)
                    completeOnboarding()
                }) {
                    Text("Continue")
                        .font(.system(size: buttonFontSize, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCompact ? 14 : 18)
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                .fill(Color.appAccent)
                        )
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .opacity(showMockupPreview ? 1 : 0)
                .padding(.horizontal, isCompact ? 16 : 24)
                .padding(.bottom, buttonBottomPadding)
            }
        }
        .onAppear {
            loadWallpaperForPreview()
            
            // Trigger confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showConfetti = true
                    confettiTrigger += 1
                }
            }
            
            // Fade in mockup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation {
                    showMockupPreview = true
                }
            }
            
            // Hide confetti after a few seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation {
                    showConfetti = false
                }
            }
        }
        .onDisappear {
            showMockupPreview = false
            showConfetti = false
        }
    }
    
    // MARK: - Transition Countdown View (Epic Version)
    
    private var transitionCountdownView: some View {
        let isCompact = ScreenDimensions.isCompactDevice
        let numberSize: CGFloat = isCompact ? 180 : 240
        
        return ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Big bold countdown number - center stage
                ZStack {
                    // Number
                    Text("\(countdownNumber)")
                        .font(.system(size: numberSize, weight: .bold))
                        .foregroundColor(Color.appAccent)
                        .scaleEffect(particleBurst ? 1.15 : 1.0)
                        .opacity(countdownOpacity)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: particleBurst)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: countdownNumber)
                }
                
                Spacer()
                
                // Simple message at bottom
                VStack(spacing: 8) {
                    Text("Let's go!")
                        .font(.system(size: isCompact ? 28 : 34, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Your faith journey begins now")
                        .font(.system(size: isCompact ? 15 : 17, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .opacity(word1Visible ? 1 : 0)
                .offset(y: word1Visible ? 0 : 20)
                .animation(.easeOut(duration: 0.5), value: word1Visible)
                .padding(.bottom, isCompact ? 80 : 120)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func startTransitionCountdown() {
        // Haptic for transition
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Reset states
        countdownNumber = 3
        countdownOpacity = 0
        showConfetti = false
        word1Visible = false
        particleBurst = false
        
        // Hide progress indicator
        withAnimation(.easeOut(duration: 0.3)) {
            hideProgressIndicator = true
        }
        
        // Show transition screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showTransitionScreen = true
            }
        }
        
        // Show bottom text immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                word1Visible = true
            }
        }
        
        // Start countdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                countdownOpacity = 1
            }
            startCountdown()
        }
    }
    
    private func startCountdown() {
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        
        // 3
        countdownNumber = 3
        heavyImpact.impactOccurred()
        triggerBurst()
        
        // 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            countdownNumber = 2
            heavyImpact.impactOccurred()
            triggerBurst()
        }
        
        // 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            countdownNumber = 1
            heavyImpact.impactOccurred()
            triggerBurst()
        }
        
        // GO!
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            
            // Confetti
            withAnimation(.easeOut(duration: 0.2)) {
                showConfetti = true
                confettiTrigger += 1
            }
            
            // Transition to next screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showTransitionScreen = false
                    currentPage = .overview
                }
            }
            
            // Hide confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showConfetti = false
                }
            }
        }
    }
    
    private func triggerBurst() {
        particleBurst = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            particleBurst = false
        }
    }
    
    private var iPhoneMockupPreview: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let availableWidth = geometry.size.width
            
            // ⚙️ MOCKUP SIZE CONTROLS ⚙️
            // Actual aspect ratio of mockup_light.png and mockup_dark.png (1x export): 946 x 2150 = 0.44 (1/2.27)
            // This matches the actual image dimensions to prevent cropping
            let mockupAspectRatio: CGFloat = 946.0 / 2150.0
            
            // 📏 HEIGHT MULTIPLIER: Controls mockup size (1.3 = 130% of screen height)
            //    - Increase (e.g., 1.5) = LARGER mockup (more zoom effect)
            //    - Decrease (e.g., 0.9) = SMALLER mockup (more space around it)
            let maxMockupHeight = availableHeight * 1.3
            
            // 📐 WIDTH MULTIPLIER: Controls horizontal fill (1.0 = 100% of screen width)
            //    - Increase (e.g., 1.1) = Mockup can extend beyond screen edges
            //    - Decrease (e.g., 0.8) = More padding on sides
            let mockupWidth = min(maxMockupHeight * mockupAspectRatio, availableWidth * 1.0)
            let mockupHeight = mockupWidth / mockupAspectRatio
            
            // Screen insets within the mockup frame (percentage-based)
            // These values must match the transparent screen window in the cropped mockup PNG
            // The mockup bezel is about 2.5% on each side horizontally, 1% top/bottom
            let screenInsetTop: CGFloat = mockupHeight * 0.012
            let screenInsetBottom: CGFloat = mockupHeight * 0.012
            let screenInsetHorizontal: CGFloat = mockupWidth * 0.042
            
            // Calculate screen dimensions - fits within the transparent window
            let screenWidth = mockupWidth - (screenInsetHorizontal * 2)
            let screenHeight = mockupHeight - screenInsetTop - screenInsetBottom
            
            // Corner radius that matches the mockup's screen corners (iPhone 14/15 style)
            let screenCornerRadius = mockupWidth * 0.115
            
            // ⚙️ WALLPAPER DISPLAY - 1:1 TRUE REPRESENTATION ⚙️
            // The wallpaper is shown exactly as it appears on real lock screen
            // 🔧 ADJUST ZOOM: Change .scaleEffect(0.77) below
            //    - 0.77 = Current (77% size - zoomed in slightly to eliminate black edges)
            //    - 1.0 = No zoom (100% - may crop edges)
            //    - 0.75 = More zoom out (75% - shows more but smaller, may show black edges)
            //    - 0.9 = Less zoom (90% - closer to edges)
            
            ZStack {
                // Wallpaper layer (behind the mockup) - TRUE 1:1 size, no cropping
                ZStack {
                    if let wallpaper = loadedWallpaperImage {
                        Image(uiImage: wallpaper)
                            .resizable()
                            .aspectRatio(contentMode: .fit) // ✅ Maintains aspect ratio, shows full image
                            .frame(maxWidth: screenWidth, maxHeight: screenHeight)
                            .scaleEffect(0.77) // 🔍 Zoomed in slightly to eliminate black edges and make it smoother
                    } else {
                        // Fallback gradient if wallpaper not loaded
                        RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.15), Color(white: 0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: screenWidth, height: screenHeight)
                    }
                }
                .frame(width: screenWidth, height: screenHeight)
                .clipped()
                .mask(
                    RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous)
                )
                
                // iPhone mockup overlay (transparent screen window)
                // Use aspectRatio modifier to preserve the full image without cropping
                Image(useLightMockup ? "mockup_light_new" : "mockup_dark_new")
                    .resizable()
                    .aspectRatio(mockupAspectRatio, contentMode: .fit)
                    .frame(maxWidth: mockupWidth, maxHeight: mockupHeight)
            }
            .frame(width: availableWidth, height: availableHeight)
            .shadow(color: Color.black.opacity(0.35), radius: 25, x: 0, y: 12)
            .offset(y: 0) // Center vertically in the available space
        }
    }
    
    private func loadWallpaperForPreview() {
        // Load the user's generated lock screen wallpaper
        if let url = HomeScreenImageManager.lockScreenWallpaperURL(),
           FileManager.default.fileExists(atPath: url.path),
           let image = UIImage(contentsOfFile: url.path) {
            loadedWallpaperImage = image
            // Determine which mockup to use based on wallpaper brightness
            // SYNCED with WallpaperRenderer.textColorForBackground() - same threshold & logic
            let brightness = averageBrightnessOfTextArea(image)
            // brightness < 0.55 = dark image = WHITE notes = use mockup_dark (has white UI)
            // brightness >= 0.55 = bright image = BLACK notes = use mockup_light (has black UI)
            // useLightMockup = true means use "mockup_light", false means use "mockup_dark"
            useLightMockup = brightness >= 0.55
            debugLog("✅ Onboarding: Loaded wallpaper for preview")
            debugLog("   📊 Text area brightness: \(String(format: "%.3f", brightness))")
            debugLog("   🎨 Notes are \(brightness < 0.55 ? "WHITE" : "BLACK")")
            debugLog("   📱 Using mockup_\(useLightMockup ? "light" : "dark")")
        } else {
            debugLog("⚠️ Onboarding: Could not load wallpaper for preview")
            loadedWallpaperImage = nil
            useLightMockup = false // Default to dark mockup (white UI) for dark fallback
        }
    }
    
    /// Calculates average brightness of the TEXT AREA of an image
    /// SYNCED with WallpaperRenderer.averageBrightness() - same sampling region & formula
    /// Returns brightness value 0.0 (black) to 1.0 (white)
    private func averageBrightnessOfTextArea(_ image: UIImage) -> CGFloat {
        let imageSize = image.size
        
        // Sample from the TEXT AREA (where notes appear on lock screen)
        // Same region as WallpaperRenderer: top 38% to bottom 85%, left 80%
        let textAreaRect = CGRect(
            x: 0,
            y: imageSize.height * 0.38,  // Start below clock/widgets area
            width: imageSize.width * 0.8, // Left portion where text is
            height: imageSize.height * 0.47 // Up to above flashlight area
        )
        
        // Crop to text area first
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: CGRect(
                x: textAreaRect.origin.x * CGFloat(cgImage.width) / imageSize.width,
                y: textAreaRect.origin.y * CGFloat(cgImage.height) / imageSize.height,
                width: textAreaRect.width * CGFloat(cgImage.width) / imageSize.width,
                height: textAreaRect.height * CGFloat(cgImage.height) / imageSize.height
              )) else {
            return averageBrightnessFullImage(of: image)
        }
        
        let croppedImage = UIImage(cgImage: croppedCGImage)
        return averageBrightnessFullImage(of: croppedImage)
        }
    
    /// Samples brightness from the entire image
    private func averageBrightnessFullImage(of image: UIImage) -> CGFloat {
        let sampleSize = CGSize(width: 12, height: 12)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: sampleSize, format: format)
        let downsampled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: sampleSize))
        }

        guard let cgImage = downsampled.cgImage,
              let data = cgImage.dataProvider?.data,
              let pointer = CFDataGetBytePtr(data) else {
            return 0.5
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        guard bytesPerPixel >= 3 else { return 0.5 }

        var total: CGFloat = 0
        let width = Int(sampleSize.width)
        let height = Int(sampleSize.height)

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * cgImage.bytesPerRow) + (x * bytesPerPixel)
                let r = CGFloat(pointer[index])
                let g = CGFloat(pointer[index + 1])
                let b = CGFloat(pointer[index + 2])
                // ITU-R BT.601 formula (same as WallpaperRenderer)
                total += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            }
        }

        return total / CGFloat(width * height)
    }

    private func demoVideoSection(minHeight: CGFloat) -> some View {
        Group {
            if let player = demoVideoPlayer {
                VideoPlayer(player: player)
                    .aspectRatio(9/16, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: minHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                    .allowsHitTesting(false)
                    .onAppear {
                        player.playImmediately(atRate: demoVideoPlaybackRate)
                    }
                    .onDisappear {
                        player.pause()
                        player.seek(to: .zero)
                    }
                    .accessibilityLabel("FaithWall demo video")
            } else {
                demoVideoPlaceholder(minHeight: minHeight)
            }
        }
        .onAppear(perform: prepareDemoVideoPlayerIfNeeded)
    }

    private func demoVideoPlaceholder(minHeight: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.systemGray6))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color.appAccent)
                    Text("Demo video coming soon")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )
            .frame(minHeight: minHeight)
            .accessibilityHidden(true)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            debugLog("📱 Onboarding: App became active, currentPage: \(currentPage), didOpenShortcut: \(didOpenShortcut)")
            // ALWAYS stop PiP when returning to app - be aggressive about it
            // This ensures PiP disappears when user returns from Shortcuts app
            debugLog("🛑 Onboarding: Stopping PiP video (app became active)")
            pipVideoPlayerManager.stopPictureInPicture()
            pipVideoPlayerManager.stop()
            shouldStartPiP = false
            
            // Double-check after a brief delay to ensure it's stopped
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.pipVideoPlayerManager.isPiPActive {
                    debugLog("⚠️ Onboarding: PiP still active after stop, forcing stop again")
                    self.pipVideoPlayerManager.stopPictureInPicture()
                    self.pipVideoPlayerManager.stop()
                }
            }
            
            // Handle return from App Store during step 2 setup
            if currentPage == .videoIntroduction && wentToAppStoreForShortcuts {
                debugLog("📱 Onboarding: Returned from App Store (Shortcuts download)")
                wentToAppStoreForShortcuts = false
                
                // Ensure Shortcuts check is marked complete so Safari section shows
                withAnimation {
                    hasCompletedShortcutsCheck = true
                }
                
                // Ensure the sheet is still showing
                if !showShortcutsCheckAlert {
                    showShortcutsCheckAlert = true
                }
                isTransitioningBetweenPopups = false
            }
            
            // Resume video if on step 2 and no popup is showing
            if currentPage == .videoIntroduction {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let noPopupShowing = !self.showShortcutsCheckAlert && !self.showInstallSheet
                    if noPopupShowing && !self.isTransitioningBetweenPopups, let player = self.welcomeVideoPlayer, player.rate == 0 {
                        player.play()
                        self.isWelcomeVideoPaused = false
                        debugLog("▶️ Welcome video resumed (no popup showing)")
                    }
                }
            }
            
            // Handle return from Shortcuts app after installing shortcut
            // DON'T auto-advance - let user stay on Step 3 to see "Did it work?" screen
            if currentPage == .installShortcut && didOpenShortcut {
                debugLog("📱 Onboarding: Detected return from Shortcuts app, staying on installShortcut step")
                // Reset the flag and hide "Ready to Try Again?" screen to show "Installation Check"
                self.didOpenShortcut = false
                self.userWentToSettings = false
                debugLog("✅ Onboarding: User can now interact with Step 3 - showing Installation Check screen")
            }
            // Only complete shortcut launch if we're on the chooseWallpapers step
            if currentPage == .chooseWallpapers {
                completeShortcutLaunch()
            }
        } else if newPhase == .background {
            // Advance to step 3 when app backgrounds after opening Shortcuts
            if shouldAdvanceToInstallStep {
                debugLog("📱 Onboarding: App went to background, advancing to installShortcut step")
                // Cancel fallback timer since app backgrounded successfully
                advanceToInstallStepTimer?.invalidate()
                advanceToInstallStepTimer = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut) {
                        self.currentPage = .installShortcut
                    }
                    self.shouldAdvanceToInstallStep = false
                }
            }
            
            // PiP should automatically take over the already-playing video
            // because we set canStartPictureInPictureAutomaticallyFromInline = true
            if shouldStartPiP && currentPage == .installShortcut {
                debugLog("🎬 Onboarding: App went to background")
                debugLog("   - Video should already be playing")
                debugLog("   - PiP should take over automatically")
                
                // If automatic PiP doesn't work, try manual start as fallback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !self.pipVideoPlayerManager.isPiPActive {
                        debugLog("⚠️ Onboarding: Automatic PiP didn't start, trying manual start")
                        if self.pipVideoPlayerManager.isReadyToPlay && self.pipVideoPlayerManager.isPiPControllerReady {
                            let success = self.pipVideoPlayerManager.startPictureInPicture()
                            if success {
                                debugLog("✅ Onboarding: PiP started manually")
                            } else {
                                debugLog("❌ Onboarding: Manual PiP start also failed")
                            }
                        }
                    } else {
                        debugLog("✅ Onboarding: Automatic PiP is active")
                    }
                }
            }
        }
    }

    private var primaryButtonTitle: String {
        switch currentPage {
        case .preOnboardingHook, .quizIntro, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .symptoms, .howAppHelps, .socialProof, .setupIntro, .pipelineChoice, .widgetOnboarding, .shortcutSuccess, .setupComplete:
            return "" // These pages have their own buttons
        case .videoIntroduction:
            return "Next"
        case .installShortcut:
            return didOpenShortcut ? "Next" : "Install Shortcut"
        case .addNotes:
            return "Continue"
        case .chooseWallpapers:
            return isLaunchingShortcut ? "Launching Shortcut..." : "Next"
        case .allowPermissions:
            return hasConfirmedPermissions ? "Continue" : "Grant Permissions First"
        case .overview:
            return "Start Using FaithWall"
        }
    }

    private var primaryButtonIconName: String? {
        switch currentPage {
        case .preOnboardingHook, .quizIntro, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .symptoms, .howAppHelps, .socialProof, .setupIntro, .pipelineChoice, .widgetOnboarding, .shortcutSuccess, .setupComplete:
            return nil // These pages have their own buttons
        case .videoIntroduction:
            return "bolt.fill"
        case .installShortcut:
            return "arrow.down.circle.fill"
        case .addNotes:
            return "arrow.right.circle.fill"
        case .chooseWallpapers:
            return isLaunchingShortcut ? nil : "paintbrush.pointed.fill"
        case .allowPermissions:
            return "checkmark.shield.fill"
        case .overview:
            return "checkmark.circle.fill"
        }
    }

    private var primaryButtonEnabled: Bool {
        switch currentPage {
        case .preOnboardingHook, .quizIntro, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .symptoms, .howAppHelps, .socialProof, .setupIntro, .pipelineChoice, .widgetOnboarding, .shortcutSuccess, .setupComplete:
            return false // These pages have their own buttons
        case .videoIntroduction:
            return true
        case .installShortcut:
            return true
        case .addNotes:
            return !onboardingNotes.isEmpty
        case .chooseWallpapers:
            let hasHomeSelection = homeScreenUsesCustomPhoto || !homeScreenPresetSelectionRaw.isEmpty
            let hasLockSelection: Bool
            if let mode = LockScreenBackgroundMode(rawValue: lockScreenBackgroundModeRaw) {
                if mode == .photo {
                    // Check if we have photo data in memory OR a saved background file (from preset or photo)
                    let hasBackgroundFile = HomeScreenImageManager.lockScreenBackgroundSourceURL().map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                    hasLockSelection = !lockScreenBackgroundPhotoData.isEmpty || hasBackgroundFile
                } else if mode == .notSelected {
                    hasLockSelection = false
                } else {
                    hasLockSelection = true
                }
            } else {
                hasLockSelection = false
            }
            let hasWidgetSelection = hasSelectedWidgetOption
            return hasHomeSelection && hasLockSelection && hasWidgetSelection && !isSavingHomeScreenPhoto && !isSavingLockScreenBackground && !isLaunchingShortcut
        case .allowPermissions:
            return hasConfirmedPermissions
        case .overview:
            return true
        }
    }

    private func handlePrimaryButton() {
        debugLog("🎯 Onboarding: Primary button tapped on page: \(currentPage.progressTitle)")
        
        // Light impact haptic for primary button tap
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Dismiss keyboard before any transition for smooth animation
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        switch currentPage {
        case .preOnboardingHook, .quizIntro, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .symptoms, .howAppHelps, .socialProof, .setupIntro, .pipelineChoice, .widgetOnboarding, .shortcutSuccess, .setupComplete:
            // These pages have their own buttons and handle navigation internally
            break
        case .videoIntroduction:
             // Pause video when showing Shortcuts check (video will continue in background)
             if let player = welcomeVideoPlayer, player.rate > 0 {
                 player.pause()
             }
              
             // Show Shortcuts check first
             showShortcutsCheckAlert = true
        case .installShortcut:
            // This is now handled by custom buttons in the view
             break
        case .addNotes:
            // Move directly to wallpapers
            withAnimation(.easeInOut(duration: 0.3)) {
                self.currentPage = .chooseWallpapers
            }
        case .chooseWallpapers:
            saveWallpaperAndContinue()
        case .allowPermissions:
            // Go to setup complete celebration
            withAnimation(.easeInOut(duration: 0.3)) {
                self.currentPage = .setupComplete
            }
        case .overview:
            completeOnboarding()
        }
    }

    private func advanceStep() {
        guard let next = OnboardingPage(rawValue: currentPage.rawValue + 1) else { 
            return 
        }
        
        var targetPage = next
        
        // Skip quizIntro step (Welcome! Let's personalize your experience)
        if targetPage == .quizIntro {
            targetPage = .quizForgetMost
        }
        
        // Pause video when leaving video introduction step
        if currentPage == .videoIntroduction {
            if let player = welcomeVideoPlayer, player.rate > 0 {
                player.pause()
                isWelcomeVideoPaused = true
                debugLog("⏸️ Welcome video paused (leaving step 2)")
            }
        }
        
        // Light impact haptic for page transition
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation(.easeInOut) {
            currentPage = targetPage
        }
    }
    
    private func goBackStep() {
        guard currentPage.rawValue > 0 else { return }
        guard let previous = OnboardingPage(rawValue: currentPage.rawValue - 1) else { return }
        
        var targetPage = previous
        
        // Skip quizIntro step when going back
        if targetPage == .quizIntro {
            targetPage = .preOnboardingHook
        }
        
        // Light impact haptic for going back
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Reset transition states when going back from overview
        if currentPage == .overview {
            hideProgressIndicator = false
            showConfetti = false
        }
        
        withAnimation(.easeInOut) {
            currentPage = targetPage
        }
        
        // Resume video when returning to video introduction step
        if targetPage == .videoIntroduction {
            if let player = welcomeVideoPlayer, player.rate == 0 {
                player.play()
                isWelcomeVideoPaused = false
                debugLog("▶️ Welcome video resumed (returning to step 2)")
            }
        }
    }
    
    private func handleSwipeGesture(_ gesture: DragGesture.Value) {
        let horizontalAmount = gesture.translation.width
        let verticalAmount = abs(gesture.translation.height)
        
        // Only handle horizontal swipes (not vertical)
        guard abs(horizontalAmount) > verticalAmount else { return }
        
        // Swipe right to go back
        if horizontalAmount > 50 {
            // Only allow going back from overview to chooseWallpapers
            if currentPage == .overview {
                goBackStep()
            }
        }
        // Swipe left to go forward (optional, can be removed if not desired)
        else if horizontalAmount < -50 {
            if currentPage == .videoIntroduction {
                advanceStep()
            } else if currentPage == .installShortcut && didOpenShortcut {
                advanceStep()
            } else if currentPage == .addNotes && primaryButtonEnabled {
                advanceStep()
            } else if currentPage == .chooseWallpapers && primaryButtonEnabled {
                saveWallpaperAndContinue()
            } else if currentPage == .allowPermissions {
                // Go to setup complete on swipe as well
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage = .setupComplete
                }
            }
        }
    }

    private func saveWallpaperAndContinue() {
        debugLog("✅ Onboarding: Saving wallpaper and running shortcut to apply it")
        
        HomeScreenImageManager.prepareStorageStructure()
        
        // Save notes BEFORE generating wallpaper so ContentView can read them
        saveOnboardingNotes()
        
        // Generate wallpaper and launch shortcut to apply it
        // This will trigger permission prompts automatically
        finalizeWallpaperSetup(shouldLaunchShortcut: true)
        
        // Advance to next step (Allow Permissions) - this happens after wallpaper is generated
        advanceStep()
    }

    private func installShortcut() {
        guard let url = URL(string: shortcutURL) else { return }
        
        // If user is on "Ready to Try Again" page (userWentToSettings == true),
        // we need to reload the video with the fix guide version
        // Otherwise, prepare PiP video if not already loaded
        if userWentToSettings {
            // Stop any active PiP and reload with the correct video for the fix flow
            pipVideoPlayerManager.stopPictureInPicture()
            pipVideoPlayerManager.stop()
            // Force reload by calling preparePiPVideo which will load the fix guide
            // preparePiPVideo checks userWentToSettings to determine which video to use
            preparePiPVideo()
        } else if !pipVideoPlayerManager.hasLoadedVideo {
            preparePiPVideo()
        }
        shouldStartPiP = true
        
        Task {
            // Brief wait for player to be ready (much shorter now!)
            var attempts = 0
            while !pipVideoPlayerManager.isReadyToPlay && attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                attempts += 1
            }
            
            // PiP controller should be ready immediately since 1x1 container is created in loadVideo()
            // But let's verify it's ready
            if !pipVideoPlayerManager.isPiPControllerReady {
                debugLog("⚠️ Onboarding: PiP controller not ready yet, waiting briefly...")
                attempts = 0
                while !pipVideoPlayerManager.isPiPControllerReady && attempts < 10 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    attempts += 1
                }
            }
            
            if pipVideoPlayerManager.isReadyToPlay && pipVideoPlayerManager.isPiPControllerReady {
                debugLog("✅ Onboarding: Player and PiP controller ready")
                
                // Make sure video is at the beginning
                await MainActor.run {
                    pipVideoPlayerManager.getPlayer()?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                }
                
                // CRITICAL: Start playing the video BEFORE opening Shortcuts
                // iOS requires the video to be actively playing before PiP can work
                _ = pipVideoPlayerManager.play()
                debugLog("✅ Onboarding: Started video playback")
                
                // VERIFY playback actually started - this is the key fix!
                // Wait a moment for playback to begin
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                // Check if video is actually playing
                var playbackAttempts = 0
                while !pipVideoPlayerManager.isPlaying && playbackAttempts < 10 {
                    debugLog("⚠️ Onboarding: Playback not started yet, retrying... (attempt \(playbackAttempts + 1))")
                    await MainActor.run {
                        // Force play again
                        pipVideoPlayerManager.getPlayer()?.playImmediately(atRate: 1.0)
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    playbackAttempts += 1
                }
                
                if pipVideoPlayerManager.isPlaying {
                    debugLog("✅ Onboarding: Verified video is playing (rate > 0)")
                } else {
                    debugLog("⚠️ Onboarding: Video may not be playing, but proceeding anyway")
                }
                
                
                // Open Shortcuts immediately - PiP will start AUTOMATICALLY when app backgrounds
                // Thanks to: canStartPictureInPictureAutomaticallyFromInline = true
                debugLog("🚀 Onboarding: Opening Shortcuts - PiP will start automatically when app backgrounds")
                
                // Pause the main video player (welcomeVideoPlayer) if it's playing
                await MainActor.run {
                    if let player = self.welcomeVideoPlayer, player.rate > 0 {
                        player.pause()
                        self.isWelcomeVideoPaused = true
                        debugLog("⏸️ Welcome video paused before opening Shortcuts")
                    }
                }
                
                await MainActor.run {
                    UIApplication.shared.open(url) { success in
                        DispatchQueue.main.async {
                            if success {
                                self.didOpenShortcut = true
                                debugLog("✅ Onboarding: Opened Shortcuts")
                            } else {
                                debugLog("⚠️ Onboarding: Shortcut URL open failed. This may be due to:")
                                debugLog("   - iCloud Drive connectivity issues")
                                debugLog("   - Pending iCloud terms acceptance")
                                debugLog("   - Network connectivity problems")
                                debugLog("   - Shortcuts app privacy settings")
                                self.shouldStartPiP = false
                                // Stop PiP and playback if Shortcuts didn't open
                                self.pipVideoPlayerManager.stopPictureInPicture()
                                self.pipVideoPlayerManager.stop()
                                // Still advance to step 3 even if Shortcuts didn't open
                                if self.shouldAdvanceToInstallStep {
                                    // Cancel fallback timer since we're handling it here
                                    self.advanceToInstallStepTimer?.invalidate()
                                    self.advanceToInstallStepTimer = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(.easeInOut) {
                                            self.currentPage = .installShortcut
                                        }
                                        self.shouldAdvanceToInstallStep = false
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                debugLog("❌ Onboarding: Cannot prepare PiP - Player ready: \(self.pipVideoPlayerManager.isReadyToPlay), Controller ready: \(self.pipVideoPlayerManager.isPiPControllerReady)")
                // Still open the Shortcuts URL even if PiP isn't ready
                await MainActor.run {
                    UIApplication.shared.open(url) { success in
                        DispatchQueue.main.async {
                            if success {
                                self.didOpenShortcut = true
                            } else {
                                // Still advance to step 3 even if Shortcuts didn't open
                                if self.shouldAdvanceToInstallStep {
                                    // Cancel fallback timer since we're handling it here
                                    self.advanceToInstallStepTimer?.invalidate()
                                    self.advanceToInstallStepTimer = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(.easeInOut) {
                                            self.currentPage = .installShortcut
                                        }
                                        self.shouldAdvanceToInstallStep = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func preparePiPVideo() {
        // Determine which video to use based on whether user went to Settings (fix flow)
        let videoResourceName = userWentToSettings ? "fix-guide-final-version" : "pip-guide-new"
        
        // If userWentToSettings is true, always reload (we're switching to fix guide)
        // Otherwise, only load if not already loaded
        let needsReload = userWentToSettings || !pipVideoPlayerManager.hasLoadedVideo
        
        if !needsReload {
            debugLog("✅ Onboarding: PiP video already loaded, skipping reload")
            return
        }
        
        guard let videoURL = getVideoURL(for: videoResourceName) else {
            debugLog("⚠️ Onboarding: PiP demo video not found for resource: \(videoResourceName)")
            return
        }
        
        debugLog("🎬 Onboarding: Preparing PiP video from: \(videoURL.absoluteString) (resource: \(videoResourceName))")
        
        // Load the video (this will call performCleanup() internally if needed)
        let loaded = pipVideoPlayerManager.loadVideo(url: videoURL)
        
        if loaded {
            debugLog("✅ Onboarding: Video loaded, waiting for player to be ready")
            
            // Wait for player to be ready, then set up the layer
            Task {
                var attempts = 0
                while !pipVideoPlayerManager.isReadyToPlay && attempts < 50 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    attempts += 1
                }
                
                if pipVideoPlayerManager.isReadyToPlay {
                    debugLog("✅ Onboarding: Player is ready")
                    
                    // Trigger a state update to make the view add the layer
                    await MainActor.run {
                        // Force update by touching a @Published property
                        _ = pipVideoPlayerManager.isReadyToPlay
                    }
                }
            }
        }
    }

    private func completeOnboarding() {
        // Save notes to AppStorage before completing
        saveOnboardingNotes()
        
        // Success notification haptic for completing onboarding
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // NOTE: hasCompletedSetup and completedOnboardingVersion are set AFTER paywall is dismissed
        // to prevent the onboarding from being dismissed before the paywall sheet can be shown.
        // See the .sheet(isPresented: $showPostOnboardingPaywall) onDisappear handler.
        
        shouldShowTroubleshootingBanner = true // Show troubleshooting banner on home screen
        hasShownAutoUpdatePrompt = true // No longer needed but keep for compatibility
        
        // Always use automatic wallpaper updates - this is the default app behavior
        autoUpdateWallpaperAfterDeletionRaw = "true"
        saveWallpapersToPhotos = false // Files only for clean experience
        
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
        
        // Show soft paywall after onboarding completion
        // hasCompletedSetup will be set after paywall is dismissed
        // Review popup will be shown after paywall is dismissed
        showPostOnboardingPaywall = true
    }

    

    private func prepareDemoVideoPlayerIfNeeded() {
        guard demoVideoPlayer == nil else { return }
        guard let bundleURL = Bundle.main.url(forResource: "pip-guide-new", withExtension: "mp4") else {
            debugLog("⚠️ Onboarding: Demo video not found in bundle")
            return
        }

        // Use bundle URL directly - bundle resources are always accessible to AVFoundation
        // and don't trigger sandbox extension warnings
        let item = AVPlayerItem(url: bundleURL)
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        queuePlayer.isMuted = true
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        queuePlayer.playImmediately(atRate: demoVideoPlaybackRate)

        demoVideoPlayer = queuePlayer
        demoVideoLooper = looper
    }
    
    private func notificationsVideoSection(minHeight: CGFloat) -> some View {
        Group {
            if let player = notificationsVideoPlayer {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .mask(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .padding(.vertical, 20)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                    .onAppear {
                        print("🎬 Video view appeared")
                        print("   - Player exists: true")
                        print("   - Current item: \(player.currentItem != nil)")
                        print("   - Item status: \(player.currentItem?.status.rawValue ?? -1)")
                        print("   - Current rate: \(player.rate)")
                        
                        // Small delay to ensure view hierarchy is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("▶️ Attempting to play...")
                            player.playImmediately(atRate: self.demoVideoPlaybackRate)
                            
                            // Check if playback actually started
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                let currentRate = player.rate
                                let currentTime = player.currentTime().seconds
                                print("📊 Playback status after 0.5s:")
                                print("   - Rate: \(currentRate) (target: \(self.demoVideoPlaybackRate))")
                                print("   - Current time: \(currentTime)s")
                                print("   - Time base rate: \(player.currentItem?.timebase?.rate ?? 0)")
                                
                                if currentRate == 0 {
                                    print("⚠️ WARNING: Player rate is 0 - video may not be playing!")
                                    print("   Trying alternative play method...")
                                    player.play()
                                    player.rate = self.demoVideoPlaybackRate
                                }
                            }
                        }
                    }
                    .onDisappear {
                        print("⏸️ Video view disappeared, pausing")
                        player.pause()
                        player.seek(to: .zero)
                    }
                    .accessibilityLabel("Notifications demo video")
            } else {
                notificationsVideoPlaceholder(minHeight: minHeight)
                    .onAppear {
                        print("⚠️ Video player is nil when view appeared!")
                        print("   Attempting to prepare player now...")
                        prepareNotificationsVideoPlayerIfNeeded()
                    }
            }
        }
    }
    
    private func notificationsVideoPlaceholder(minHeight: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.systemGray6))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color.appAccent)
                    Text("Loading notifications video...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )
            .frame(minHeight: minHeight)
            .accessibilityHidden(true)
    }
    
    private func prepareNotificationsVideoPlayerIfNeeded() {
        // If player already exists, ensure it's playing (don't skip)
        if let existingPlayer = notificationsVideoPlayer {
            print("⚠️ Video player already exists, ensuring playback")
            // Ensure audio session is configured for playback
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("⚠️ Failed to configure audio session: \(error)")
            }
            // Force playback if not playing
            if existingPlayer.rate == 0 {
                existingPlayer.seek(to: .zero)
                existingPlayer.play()
                print("▶️ Restarted existing notifications video player")
            }
            return
        }
        
        debugLog("🔍 Onboarding: Preparing notifications video player...")
        
        // Try to find the video file
        guard let bundleURL = Bundle.main.url(forResource: "notifications-of-permissions", withExtension: "mp4") else {
            print("❌ CRITICAL: notifications-of-permissions.mp4 not found in bundle!")
            print("📁 Bundle path: \(Bundle.main.bundlePath)")
            
            // List ALL video files in bundle for debugging
            if let files = try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath) {
                let videoFiles = files.filter { $0.hasSuffix(".mov") || $0.hasSuffix(".mp4") }
                print("📁 Video files in bundle: \(videoFiles)")
            }
            return
        }
        
        print("✅ Found notifications-of-permissions.mp4 at: \(bundleURL.path)")
        
        // Verify file is accessible and has content
        let fileManager = FileManager.default
        guard fileManager.isReadableFile(atPath: bundleURL.path) else {
            print("❌ File exists but is not readable!")
            return
        }
        
        if let attrs = try? fileManager.attributesOfItem(atPath: bundleURL.path),
           let size = attrs[.size] as? Int64 {
            print("📊 File size: \(size) bytes (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))")
            if size == 0 {
                print("❌ File is empty!")
                return
            }
        }
        
        // Create asset and check if it's playable
        let asset = AVAsset(url: bundleURL)
        
        // Log asset properties
        Task {
            let isPlayable = try? await asset.load(.isPlayable)
            let duration = try? await asset.load(.duration)
            let tracks = try? await asset.load(.tracks)
            
            await MainActor.run {
                print("📹 Asset properties:")
                print("   - Playable: \(isPlayable ?? false)")
                print("   - Duration: \(duration?.seconds ?? 0) seconds")
                print("   - Tracks: \(tracks?.count ?? 0)")
                
                if let videoTracks = tracks?.filter({ $0.mediaType == .video }) {
                    print("   - Video tracks: \(videoTracks.count)")
                }
            }
        }
        
        let item = AVPlayerItem(asset: asset)
        
        // Observe player item status with detailed logging
        _ = item.observe(\.status, options: [.new, .initial]) { playerItem, _ in
            DispatchQueue.main.async {
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ notifications-of-permissions.mp4 player item READY TO PLAY (Allow Permissions step)")
                    print("   - Duration: \(playerItem.duration.seconds) seconds")
                    if let videoTrack = playerItem.asset.tracks(withMediaType: .video).first {
                        let videoSize = videoTrack.naturalSize
                        let aspectRatio = videoSize.width / videoSize.height
                        self.notificationsVideoAspectRatio = aspectRatio
                        print("   - Natural size: \(videoSize)")
                        print("   - Aspect ratio: \(aspectRatio)")
                    }
                    // Auto-play when ready if we're on the allowPermissions step
                    if self.currentPage == .allowPermissions, let player = self.notificationsVideoPlayer {
                        player.seek(to: .zero)
                        player.play()
                        print("   - Auto-playing video (step 6 is active)")
                    }
                case .failed:
                    print("❌ Player item FAILED")
                    if let error = playerItem.error as NSError? {
                        print("   - Error: \(error.localizedDescription)")
                        print("   - Domain: \(error.domain)")
                        print("   - Code: \(error.code)")
                        print("   - UserInfo: \(error.userInfo)")
                    }
                case .unknown:
                    print("⚠️ Player item status UNKNOWN")
                @unknown default:
                    print("⚠️ Player item status @unknown default")
                }
            }
        }
        
        // Observe playback errors
        _ = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { notification in
            print("❌ Playback failed to play to end time")
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("   Error: \(error.localizedDescription)")
            }
        }
        
        // Configure audio session for notifications video playback
        // This ensures it works even after PiP video has been used
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured for notifications video")
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
        }
        
        // Create looping player
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        queuePlayer.isMuted = true
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        
        // Store everything
        notificationsVideoPlayer = queuePlayer
        notificationsVideoLooper = looper
        
        print("✅ Notifications video player created")
        print("   - Player ready: \(queuePlayer.currentItem != nil)")
        print("   - Looper status: \(looper.status.rawValue)")
        
        // IMPORTANT: Don't call play here - let the view's onAppear handle it
        // This prevents race conditions with the VideoPlayer view setup
    }
    
    private func setupWelcomeVideoPlayer() {
        guard welcomeVideoPlayer == nil else {
            // If player already exists, just ensure it's playing
            if let player = welcomeVideoPlayer, player.rate == 0 {
                player.play()
            }
            return
        }
        
        debugLog("🔍 Onboarding: Setting up welcome video player...")
        
        // Try to find the video file (remote URL or bundle fallback)
        guard let videoURL = getVideoURL(for: "welcome-video") else {
            debugLog("❌ welcome-video.mp4 not found!")
            return
        }
        
        debugLog("✅ Found welcome-video at: \(videoURL.absoluteString)")
        
        // Create asset and player item
        let asset = AVAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        
        // Create looping player
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        // Configure player for autoplay and looping
        queuePlayer.isMuted = isWelcomeVideoMuted // Sync with state
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        
        // Store everything
        welcomeVideoPlayer = queuePlayer
        welcomeVideoLooper = looper
        
        debugLog("✅ Welcome video player created")
        
        // Get video duration
        Task {
            let duration = try? await asset.load(.duration)
            await MainActor.run {
                if let duration = duration {
                    welcomeVideoDuration = duration.seconds
                    debugLog("📹 Welcome video duration: \(welcomeVideoDuration) seconds")
                }
            }
        }
        
        // Set up progress tracking timer
        startWelcomeVideoProgressTracking()
        
        // Start playing automatically
        queuePlayer.play()
        isWelcomeVideoPaused = false
        debugLog("▶️ Welcome video started playing")
    }
    
    private func startWelcomeVideoProgressTracking() {
        // Stop any existing timer
        welcomeVideoProgressTimer?.invalidate()
        
        // Create new timer to update progress
        welcomeVideoProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = self.welcomeVideoPlayer else { return }
            
            let currentTime = CMTimeGetSeconds(player.currentTime())
            let duration = self.welcomeVideoDuration > 0 ? self.welcomeVideoDuration : CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
            
            if duration > 0 {
                // Calculate progress, handling looping
                var progress = currentTime / duration
                
                // If video loops and we're past the duration, reset progress
                if progress >= 1.0 {
                    progress = 0.0
                }
                
                self.welcomeVideoProgress = min(max(progress, 0), 1)
            }
        }
    }
    
    private func stopWelcomeVideoProgressTracking() {
        welcomeVideoProgressTimer?.invalidate()
        welcomeVideoProgressTimer = nil
    }
    
    private func seekVideo(by seconds: Double) {
        guard let player = welcomeVideoPlayer else { return }
        
        // Get current time
        let currentTime = player.currentTime()
        let currentSeconds = CMTimeGetSeconds(currentTime)
        
        // Calculate new time
        let newSeconds = max(0, currentSeconds + seconds)
        let newTime = CMTime(seconds: newSeconds, preferredTimescale: currentTime.timescale)
        
        // Seek to new time
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
        
        debugLog("⏩ Video seeked by \(seconds) seconds to \(newSeconds)s")
    }
    
    private func toggleMute() {
        guard let player = welcomeVideoPlayer else { return }
        
        isWelcomeVideoMuted.toggle()
        player.isMuted = isWelcomeVideoMuted
        
        debugLog(isWelcomeVideoMuted ? "🔇 Welcome video muted" : "🔊 Welcome video unmuted")
    }
    
    // MARK: - Stuck/Troubleshooting Video Controls
    
    private func setupStuckVideoPlayerIfNeeded() {
        // If player already exists, just ensure it's playing and tracking
        if stuckGuideVideoPlayer != nil {
            debugLog("⚠️ Stuck guide video player already exists - ensuring playback")
            ensureStuckVideoPlaying()
            return
        }
        
        debugLog("🔍 Setting up stuck guide video player...")
        debugLog("   - Looking for resource: \(stuckVideoResourceName)")
        
        guard let url = Bundle.main.url(forResource: stuckVideoResourceName, withExtension: "mp4") ??
                        Bundle.main.url(forResource: stuckVideoResourceName, withExtension: "mov") else {
            debugLog("❌ Stuck guide video not found in bundle!")
            debugLog("   - Tried: \(stuckVideoResourceName).mp4")
            debugLog("   - Tried: \(stuckVideoResourceName).mov")
            debugLog("   - Bundle path: \(Bundle.main.bundlePath)")
            
            // List video files in bundle for debugging
            if let files = try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath) {
                let videoFiles = files.filter { $0.hasSuffix(".mp4") || $0.hasSuffix(".mov") }
                debugLog("   - Video files in bundle: \(videoFiles)")
            }
            
            debugLog("⚠️ Stuck guide video not found. Placeholder image will be shown.")
            return
        }
        
        debugLog("✅ Found stuck guide video at: \(url.path)")
        
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        queuePlayer.isMuted = isStuckVideoMuted
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        
        stuckGuideVideoPlayer = queuePlayer
        stuckGuideVideoLooper = looper
        
        debugLog("✅ Stuck guide video player created")
        
        Task {
            let duration = try? await asset.load(.duration)
            await MainActor.run {
                if let duration = duration {
                    stuckVideoDuration = duration.seconds
                    debugLog("📹 Stuck guide video duration: \(stuckVideoDuration) seconds")
                }
            }
        }
        
        startStuckVideoProgressTracking()
        queuePlayer.play()
        isStuckVideoPaused = false
        debugLog("▶️ Stuck guide video started")
    }
    
    private func startStuckVideoProgressTracking() {
        stuckVideoProgressTimer?.invalidate()
        stuckVideoProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = self.stuckGuideVideoPlayer else { return }
            let currentTime = CMTimeGetSeconds(player.currentTime())
            let duration = self.stuckVideoDuration > 0 ? self.stuckVideoDuration : CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
            
            if duration > 0 {
                var progress = currentTime / duration
                if progress >= 1.0 {
                    progress = 0.0
                }
                self.stuckVideoProgress = min(max(progress, 0), 1)
            }
        }
    }
    
    private func stopStuckVideoProgressTracking() {
        stuckVideoProgressTimer?.invalidate()
        stuckVideoProgressTimer = nil
    }
    
    private func seekStuckVideo(by seconds: Double) {
        guard let player = stuckGuideVideoPlayer else { return }
        
        let currentTime = player.currentTime()
        let currentSeconds = CMTimeGetSeconds(currentTime)
        let newSeconds = max(0, currentSeconds + seconds)
        let newTime = CMTime(seconds: newSeconds, preferredTimescale: currentTime.timescale)
        
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
        
        debugLog("⏩ Stuck guide seeked by \(seconds) seconds to \(newSeconds)s")
    }
    
    private func toggleStuckVideoMute() {
        guard let player = stuckGuideVideoPlayer else { return }
        isStuckVideoMuted.toggle()
        player.isMuted = isStuckVideoMuted
        debugLog(isStuckVideoMuted ? "🔇 Stuck guide muted" : "🔊 Stuck guide unmuted")
    }
    
    private func pauseStuckVideo() {
        guard let player = stuckGuideVideoPlayer else { return }
        player.pause()
        isStuckVideoPaused = true
        debugLog("⏸️ Stuck guide paused")
    }
    
    private func resumeStuckVideoIfNeeded(forcePlay: Bool = false) {
        guard let player = stuckGuideVideoPlayer else { return }
        guard forcePlay || !showTroubleshootingTextVersion else { return }
        player.play()
        isStuckVideoPaused = false
        // Ensure progress tracking is running
        if stuckVideoProgressTimer == nil || !stuckVideoProgressTimer!.isValid {
            startStuckVideoProgressTracking()
        }
        debugLog("▶️ Stuck guide resumed")
    }
    
    private func stopStuckVideoPlayback() {
        if let player = stuckGuideVideoPlayer {
            player.pause()
            player.seek(to: .zero)
        }
        isStuckVideoPaused = true
        stopStuckVideoProgressTracking()
    }
    
    /// Ensures the stuck video is playing and progress is being tracked.
    /// Call this when returning to the troubleshooting modal.
    private func ensureStuckVideoPlaying() {
        guard let player = stuckGuideVideoPlayer else { return }
        
        // Restart progress tracking if not running
        if stuckVideoProgressTimer == nil || !stuckVideoProgressTimer!.isValid {
            startStuckVideoProgressTracking()
            debugLog("📊 Stuck video progress tracking restarted")
        }
        
        // Ensure video is playing if not paused and not in text version
        if player.rate == 0 && !isStuckVideoPaused && !showTroubleshootingTextVersion {
            player.play()
            debugLog("▶️ Stuck video resumed (ensureStuckVideoPlaying)")
        }
    }
    
    private func saveOnboardingNotes() {
        guard !onboardingNotes.isEmpty else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(onboardingNotes)
            savedNotesData = data
            // Sync to widget
            WidgetDataSync.syncNotesToWidget(data)
            print("✅ Saved \(onboardingNotes.count) notes from onboarding")
        } catch {
            print("❌ Failed to save onboarding notes: \(error)")
        }
    }

    private func finalizeWallpaperSetup(shouldLaunchShortcut: Bool = false) {
        // Allow wallpaper generation if we are on chooseWallpapers step
        // We removed the isLaunchingShortcut guard because we want to save without launching now
        guard currentPage == .chooseWallpapers else {
            debugLog("⚠️ Onboarding: finalizeWallpaperSetup called but not in correct context")
            return
        }
        
        debugLog("✅ Onboarding: Finalizing wallpaper setup from step 5")
        
        // Generate wallpaper directly
        
        // 1. Resolve background color
        let backgroundOption = LockScreenBackgroundOption(rawValue: lockScreenBackgroundRaw) ?? .default
        let backgroundColor = backgroundOption.uiColor
        
        // 2. Resolve background image
        var backgroundImage: UIImage? = nil
        let backgroundMode = LockScreenBackgroundMode(rawValue: lockScreenBackgroundModeRaw) ?? .default
        
        if backgroundMode == .photo {
            if !lockScreenBackgroundPhotoData.isEmpty, let image = UIImage(data: lockScreenBackgroundPhotoData) {
                backgroundImage = image
            }
        }
        
        // 3. Generate wallpaper
        debugLog("🎨 Onboarding: Generating wallpaper with \(onboardingNotes.count) notes")
        let lockScreenImage = WallpaperRenderer.generateWallpaper(
            from: onboardingNotes,
            backgroundColor: backgroundColor,
            backgroundImage: backgroundImage,
            hasLockScreenWidgets: hasLockScreenWidgets
        )
        
        // 4. Save to file system
        do {
            try HomeScreenImageManager.saveLockScreenWallpaper(lockScreenImage)
            debugLog("✅ Onboarding: Saved generated wallpaper to file system")
            
            // 5. Trigger shortcut launch ONLY if requested
            if shouldLaunchShortcut {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.didTriggerShortcutRun = true
                self.openShortcutToApplyWallpaper()
                }
            }
        } catch {
            debugLog("❌ Onboarding: Failed to save generated wallpaper: \(error)")
            // Only show error if we were trying to launch
            if shouldLaunchShortcut {
            handleWallpaperVerificationFailure()
            }
        }
    }

    private func completeShortcutLaunch() {
        shortcutLaunchFallback?.cancel()
        shortcutLaunchFallback = nil
        wallpaperVerificationTask?.cancel()
        wallpaperVerificationTask = nil
        guard isLaunchingShortcut else { 
            return 
        }
        isLaunchingShortcut = false
        didTriggerShortcutRun = false
        if currentPage == .chooseWallpapers {
            currentPage = .videoIntroduction
        }
    }
    
    private func requestAppReviewIfNeeded() {
        // Review request has been moved to SocialProofView (onboarding step)
        // to appear before the paywall/completion.
        #if DEBUG
        print("🌟 requestAppReviewIfNeeded called but disabled (moved to SocialProofView)")
        #endif
    }

    private func handleWallpaperGenerationFinished() {
        guard isLaunchingShortcut, currentPage == .chooseWallpapers, !didTriggerShortcutRun else { 
            return 
        }
        didTriggerShortcutRun = true
        openShortcutToApplyWallpaper()
    }

    private func openShortcutToApplyWallpaper() {
        wallpaperVerificationTask?.cancel()
        wallpaperVerificationTask = Task {
            let filesReady = await waitForWallpaperFilesReady()
            
            if Task.isCancelled {
                return
            }
            
            if filesReady {
                launchShortcutAfterVerification()
            } else {
                handleWallpaperVerificationFailure()
            }
        }
    }

    private func waitForWallpaperFilesReady(maxWait: TimeInterval = 6.0, pollInterval: TimeInterval = 0.25) async -> Bool {
        let deadline = Date().addingTimeInterval(maxWait)
        while Date() < deadline {
            if Task.isCancelled {
                return false
            }

            if areWallpaperFilesReady() {
                return true
            }

            let jitter = Double.random(in: 0...0.05)
            let delay = pollInterval + jitter
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        return areWallpaperFilesReady()
    }

    private func areWallpaperFilesReady() -> Bool {
        guard
            let homeURL = HomeScreenImageManager.homeScreenImageURL(),
            let lockURL = HomeScreenImageManager.lockScreenWallpaperURL()
        else {
            return false
        }
        return isReadableNonZeroFile(at: homeURL) && isReadableNonZeroFile(at: lockURL)
    }

    private func isReadableNonZeroFile(at url: URL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path),
              fileManager.isReadableFile(atPath: url.path) else {
            return false
        }

        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber else {
            return false
        }
        return fileSize.intValue > 0
    }

    @MainActor
    private func handleWallpaperVerificationFailure() {
        debugLog("❌ Onboarding: Wallpaper file verification failed or timed out")
        wallpaperVerificationTask = nil
        didTriggerShortcutRun = false
        isLaunchingShortcut = false
        homeScreenStatusMessage = "Wallpaper verification failed"
        homeScreenStatusColor = .red
    }

    @MainActor
    private func launchShortcutAfterVerification() {
        wallpaperVerificationTask = nil

        guard areWallpaperFilesReady() else {
            handleWallpaperVerificationFailure()
            return
        }

        debugLog("✅ Onboarding: Wallpaper files verified, opening shortcut")

        let shortcutName = "FaithWall Automation"
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let urlString = "shortcuts://run-shortcut?name=\(encodedName)"
        guard let url = URL(string: urlString) else {
            debugLog("❌ Onboarding: Failed to create shortcut URL")
            handleWallpaperVerificationFailure()
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                debugLog("⚠️ Onboarding: Shortcut URL open returned false")
                DispatchQueue.main.async {
                    self.didTriggerShortcutRun = false
                    self.isLaunchingShortcut = false
                }
            }
        }
    }
    
    private func runShortcutForPermissions() {
        debugLog("🚀 Onboarding: Running shortcut for permissions step")
        
        let shortcutName = "FaithWall Automation"
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let urlString = "shortcuts://run-shortcut?name=\(encodedName)"
        guard let url = URL(string: urlString) else {
            debugLog("❌ Onboarding: Failed to create shortcut URL for permissions")
            return
        }
        
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                debugLog("✅ Onboarding: Successfully opened shortcut for permissions")
            } else {
                debugLog("⚠️ Onboarding: Failed to open shortcut for permissions")
            }
        }
    }
    
    private func saveInstructionWallpaperToPhotos() {
        debugLog("💾 Onboarding: Saving instruction wallpaper to Photos")
        
        guard let instructionImage = UIImage(named: "InstructionWallpaper") else {
            debugLog("❌ Onboarding: Failed to load instruction wallpaper image")
            return
        }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                debugLog("❌ Onboarding: Photos permission not granted")
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: instructionImage.jpegData(compressionQuality: 1.0)!, options: nil)
            }) { success, error in
                if success {
                    debugLog("✅ Onboarding: Instruction wallpaper saved to Photos")
                } else if let error = error {
                    debugLog("❌ Onboarding: Failed to save instruction wallpaper: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Help Button & Support
    
    /// Floating help button with glowy outline (performance optimized)
    private var helpButton: some View {
        Button(action: {
            // Pause video when showing help sheet (if on step 2)
            if currentPage == .videoIntroduction {
                if let player = welcomeVideoPlayer, player.rate > 0 {
                    player.pause()
                    isWelcomeVideoPaused = true
                    debugLog("⏸️ Welcome video paused (help sheet appearing)")
                }
            }
            // Medium haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            showHelpSheet = true
        }) {
            ZStack {
                // Simple pulsing ring (performance optimized)
                Circle()
                    .strokeBorder(
                        Color.appAccent.opacity(pulseAnimation ? 0.5 : 0.3),
                        lineWidth: pulseAnimation ? 2 : 1.5
                    )
                    .frame(width: 48, height: 48)
                    .shadow(
                        color: Color.appAccent.opacity(pulseAnimation ? 0.8 : 0.4),
                        radius: pulseAnimation ? 16 : 10,
                        x: 0,
                        y: 0
                    )
                
                // Icon
                Image(systemName: "headphones")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
        }
        .onAppear {
            // Simple pulsing glow animation
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    /// Compact help button for overview step (smaller, positioned in grey corner)
    private var compactHelpButton: some View {
        Button(action: {
            // Medium haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            showHelpSheet = true
        }) {
            ZStack {
                // Simple pulsing ring (performance optimized)
                Circle()
                    .strokeBorder(
                        Color.appAccent.opacity(pulseAnimation ? 0.5 : 0.3),
                        lineWidth: pulseAnimation ? 1.5 : 1
                    )
                    .frame(width: 36, height: 36)
                    .shadow(
                        color: Color.appAccent.opacity(pulseAnimation ? 0.7 : 0.4),
                        radius: pulseAnimation ? 10 : 6,
                        x: 0,
                        y: 0
                    )
                
                // Icon (smaller)
                Image(systemName: "headphones")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
        }
        .onAppear {
            // Simple pulsing glow animation
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    @State private var pulseAnimation = false
    
    /// Help options sheet with 3 support channels
    private var helpOptionsSheet: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.96),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Need Help?")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("We're here to help you succeed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // If on overview page, complete onboarding instead of just closing
                        if currentPage == .overview {
                            showHelpSheet = false
                            completeOnboarding()
                        } else {
                            showHelpSheet = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, 40)
                
                // Support options
                VStack(spacing: 16) {
                    // 1. WhatsApp (Primary)
                    supportOptionCard(
                        icon: "message.fill",
                        title: "Chat on WhatsApp",
                        subtitle: "Get instant help from our team",
                        accentColor: Color(red: 0.15, green: 0.78, blue: 0.40), // WhatsApp green
                        isPrimary: true
                    ) {
                        openWhatsApp()
                    }
                    
                    // 2. Email Feedback
                    supportOptionCard(
                        icon: "envelope.fill",
                        title: "Get Help via Email",
                        subtitle: "We'll respond within 24 hours",
                        accentColor: .blue
                    ) {
                        openEmailFeedback()
                    }
                    
                    // 3. In-app Improvement
                    supportOptionCard(
                        icon: "lightbulb.fill",
                        title: "Suggest Improvements",
                        subtitle: "Help us make FaithWall better",
                        accentColor: Color(red: 0.61, green: 0.35, blue: 0.71) // Purple
                    ) {
                        showHelpSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showImprovementForm = true
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                
                Spacer()
                
                // Footer note
                Text("Current Step" + " \(currentPageName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            }
        }
    }
    
    /// Support option card component
    private func supportOptionCard(
        icon: String,
        title: String,
        subtitle: String,
        accentColor: Color,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            // Light haptic
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isPrimary ? 0.08 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isPrimary ? accentColor.opacity(0.3) : Color.black.opacity(0.05),
                                lineWidth: isPrimary ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    /// In-app improvement suggestions form (redesigned for performance)
    private var improvementFormSheet: some View {
        NavigationView {
            ZStack {
                // Dark gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.96),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss keyboard smoothly when tapping background
                    if isImprovementFieldFocused {
                        withAnimation(.easeOut(duration: 0.25)) {
                            isImprovementFieldFocused = false
                        }
                    }
                }
                
                if showImprovementSuccess {
                    // Success state
                    VStack(spacing: 24) {
                        Group {
                            if #available(iOS 17.0, *) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(Color("AppAccent"))
                                    .symbolEffect(.bounce, value: showImprovementSuccess)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(Color("AppAccent"))
                            }
                        }
                        
                        Text("Thank You!")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Your suggestion has been sent")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Input form with ScrollView for better keyboard handling
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What could we improve?")
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Your feedback helps make FaithWall better for everyone")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                            
                            // Text editor container
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Suggestion")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                ZStack(alignment: .topLeading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.black.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(
                                                    isImprovementFieldFocused ? Color("AppAccent").opacity(0.5) : Color.black.opacity(0.05),
                                                    lineWidth: isImprovementFieldFocused ? 2 : 1
                                                )
                                        )
                                        .frame(height: 180)
                                    
                                    // Text editor
                                    if #available(iOS 16.0, *) {
                                        TextEditor(text: $improvementText)
                                            .focused($isImprovementFieldFocused)
                                            .scrollContentBackground(.hidden)
                                            .frame(height: 180)
                                            .padding(12)
                                            .foregroundColor(.primary)
                                            .font(.body)
                                    } else {
                                        TextEditor(text: $improvementText)
                                            .focused($isImprovementFieldFocused)
                                            .frame(height: 180)
                                            .padding(12)
                                            .foregroundColor(.primary)
                                            .font(.body)
                                            .background(Color.clear)
                                    }
                                    
                                    // Placeholder
                                    if improvementText.isEmpty {
                                        Text("Share your thoughts here...")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                            
                            // Character count (optional, for better UX)
                            HStack {
                                Spacer()
                                Text("\(improvementText.count) \("characters")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Send button
                            Button {
                                sendImprovementFeedback()
                            } label: {
                                HStack(spacing: 12) {
                                    if isSendingImprovement {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                    }
                                    Text(isSendingImprovement ? "Sending..." : "Send Suggestion")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            improvementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingImprovement
                                                ? Color.gray.opacity(0.3)
                                                : Color("AppAccent")
                                        )
                                )
                                .shadow(
                                    color: (improvementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingImprovement)
                                        ? .clear
                                        : Color("AppAccent").opacity(0.4),
                                    radius: 16,
                                    x: 0,
                                    y: 8
                                )
                            }
                            .disabled(improvementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingImprovement)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.vertical, 20)
                    }
                    .scrollDismissesKeyboardIfAvailable()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Dismiss keyboard smoothly when tapping outside text field
                        if isImprovementFieldFocused {
                            withAnimation(.easeOut(duration: 0.25)) {
                                isImprovementFieldFocused = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        // Dismiss keyboard first
                        isImprovementFieldFocused = false
                        // Then close after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showImprovementForm = false
                            improvementText = ""
                            showImprovementSuccess = false
                            isSendingImprovement = false
                        }
                    }
                    .foregroundColor(Color("AppAccent"))
                }
            }
        }
    }
    
    // MARK: - Support Actions
    
    /// Opens WhatsApp with pre-filled message
    private func openWhatsApp() {
        let message = """
        \("Hi! I need help with FaithWall.")
        
        \("I'm stuck on:") \(currentPageName)
        
        \(getDeviceInfo())
        """
        
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let whatsappURL = "https://wa.me/\(whatsappNumber)?text=\(encodedMessage)"
        
        guard let url = URL(string: whatsappURL) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                if !success {
                    // WhatsApp didn't open, show fallback
                    DispatchQueue.main.async {
                        helpAlertMessage = "Couldn't open WhatsApp"
                        showHelpAlert = true
                    }
                }
            }
            showHelpSheet = false
        } else {
            // WhatsApp not installed
            helpAlertMessage = "WhatsApp is not installed"
            showHelpAlert = true
        }
    }
    
    /// Opens email app with pre-filled feedback
    private func openEmailFeedback() {
        let subject = "\("FaithWall Help Needed") - \(currentPageName)"
        let body = """
        
        
        ---
        \("Current Step"): \(currentPageName)
        \(getDeviceInfo())
        ---
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let mailtoURL = "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        guard let url = URL(string: mailtoURL) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            showHelpSheet = false
        } else {
            // Email not configured
            helpAlertMessage = "Email is not configured on this device"
            showHelpAlert = true
        }
    }
    
    /// Sends improvement suggestion via email service
    private func sendImprovementFeedback() {
        guard !improvementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isSendingImprovement else { return }
        
        // Medium haptic for send action
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Show loading state immediately
        isSendingImprovement = true
        
        // Hide keyboard first with smooth animation
        withAnimation(.easeOut(duration: 0.25)) {
            isImprovementFieldFocused = false
        }
        
        // Wait for keyboard to fully dismiss before proceeding (keyboard animation takes ~0.5 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let details = """
            \("User Suggestion"):
            \(self.improvementText)
            
            ---
            \("Context"):
            \("Current Step"): \(self.currentPageName)
            \(self.getDeviceInfo())
            """
            
            // Use FeedbackService to send the suggestion
            FeedbackService.shared.sendFeedback(
                reason: "Onboarding Improvement Suggestion",
                details: details,
                isPremium: self.paywallManager.isPremium
            ) { success, error in
                DispatchQueue.main.async {
                    self.isSendingImprovement = false
                    
                    if success {
                        // Keyboard should be fully dismissed by now, show success animation
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            self.showImprovementSuccess = true
                        }
                        
                        // Success haptic
                        let notification = UINotificationFeedbackGenerator()
                        notification.notificationOccurred(.success)
                        
                        // Auto-dismiss after showing success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.showImprovementForm = false
                            self.improvementText = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.showImprovementSuccess = false
                            }
                        }
                    } else {
                        // Fallback to email if service fails
                        self.openEmailFeedback()
                        self.showImprovementForm = false
                    }
                }
            }
        }
    }
    
    /// Gets device and app information
    private func getDeviceInfo() -> String {
        let device = UIDevice.current.model
        let osVersion = UIDevice.current.systemVersion
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        return "\("Device"): \(device), iOS: \(osVersion), App: v\(appVersion)"
    }
    
    /// Creates underlined text compatible with all iOS versions
    @available(iOS 15.0, *)
    private func createUnderlinedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        attributedString.underlineStyle = .single
        return attributedString
    }
    
    /// Returns human-readable name for current onboarding page
    private var currentPageName: String {
        switch currentPage {
        case .preOnboardingHook:
            return "Welcome"
        case .quizIntro:
            return "Getting Started"
        case .quizForgetMost:
            return "Quick Quiz"
        case .quizPhoneChecks:
            return "Quick Quiz"
        case .quizDistraction:
            return "Quick Quiz"
        case .personalizationLoading:
            return "Customizing Experience"
        case .resultsPreview:
            return "Personalized Plan"
        case .symptoms:
            return "Symptoms"
        case .howAppHelps:
            return "How FaithWall Helps"
        case .socialProof:
            return "What Others Say"
        case .setupIntro:
            return "Setup Introduction"
        case .pipelineChoice:
            return "Choose Setup Method"
        case .widgetOnboarding:
            return "Widget Setup"
        case .videoIntroduction:
            return "Video Introduction"
        case .installShortcut:
            return "Install Shortcut"
        case .shortcutSuccess:
            return "Shortcut Installed"
        case .addNotes:
            return "Add Notes"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .allowPermissions:
            return "Allow Permissions"
        case .setupComplete:
            return "Setup Complete"
        case .overview:
            return "Overview"
        }
    }
    
    private func openWallpaperSettings() {
        debugLog("📱 Onboarding: Opening Photos app to Library tab")
        
        // iOS 18.1+ broke App-prefs:Wallpaper URL scheme - it no longer works.
        // Solution: Open Photos app to Library tab (all photos grid view) using reverse-engineered URL scheme.
        // The user's FaithWall wallpaper will be at the top (most recent) since it was just saved.
        
        // This opens Photos directly to Library tab showing all photos in grid view
        // NOT the Albums view - much better UX!
        if let photosURL = URL(string: "photos-navigation://contentmode?id=photos") {
            UIApplication.shared.open(photosURL) { success in
                if success {
                    debugLog("✅ Onboarding: Successfully opened Photos app to Library tab")
                    self.userWentToSettings = true
                    self.showTroubleshooting = false
                    self.showTroubleshootingTextVersion = false
                } else {
                    // Fallback: Try basic Photos redirect
                    debugLog("⚠️ Onboarding: contentmode URL failed, trying photos-redirect")
                    if let photosRedirectURL = URL(string: "photos-redirect://") {
                        UIApplication.shared.open(photosRedirectURL) { redirectSuccess in
                            if redirectSuccess {
                                debugLog("✅ Onboarding: Successfully opened Photos app")
                                self.userWentToSettings = true
                                self.showTroubleshooting = false
                                self.showTroubleshootingTextVersion = false
                            } else {
                                // Final fallback: Open Settings app
                                debugLog("⚠️ Onboarding: Photos app failed, opening Settings as fallback")
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL) { _ in
                                        self.userWentToSettings = true
                                        self.showTroubleshooting = false
                                        self.showTroubleshootingTextVersion = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Fallback: Open Settings app
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL) { _ in
                    self.userWentToSettings = true
                    self.showTroubleshooting = false
                    self.showTroubleshootingTextVersion = false
                }
            }
        }
    }

    @available(iOS 16.0, *)
    private func handlePickedHomeScreenData(_ data: Data) {
        debugLog("📸 Onboarding: Handling picked home screen data")
        debugLog("   Data size: \(data.count) bytes")
        isSavingHomeScreenPhoto = true
        homeScreenStatusMessage = "Saving photo..."
        homeScreenStatusColor = .gray

        Task {
            do {
                guard let image = UIImage(data: data) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }
                debugLog("   Image size: \(image.size)")
                try HomeScreenImageManager.saveHomeScreenImage(image)
                debugLog("✅ Onboarding: Saved custom home screen photo")
                if let url = HomeScreenImageManager.homeScreenImageURL() {
                    debugLog("   File path: \(url.path)")
                    debugLog("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
                }

                await MainActor.run {
                    homeScreenUsesCustomPhoto = true
                    homeScreenStatusMessage = nil
                    homeScreenStatusColor = .gray
                    homeScreenPresetSelectionRaw = ""
                    debugLog("   homeScreenUsesCustomPhoto set to: true")
                    debugLog("   homeScreenPresetSelectionRaw cleared")
                }
            } catch {
                debugLog("❌ Onboarding: Failed to save home screen photo: \(error)")
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
    
    // MARK: - Step 2 Text Version Helper Components
    
    private struct Step3HeroIcon: View {
        @State private var animateRings = false
        @State private var floatingOffset: CGFloat = 0
        
        var body: some View {
            ZStack {
                // Animated rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        .frame(width: 140 + CGFloat(i) * 35, height: 140 + CGFloat(i) * 35)
                        .scaleEffect(animateRings ? 1.1 : 1.0)
                        .opacity(animateRings ? 0.3 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                            value: animateRings
                        )
                }
                
                // Main icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.appAccent)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .offset(y: floatingOffset)
            }
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        animateRings = true
                    }
                    withAnimation(Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                        floatingOffset = -8
                    }
                }
            }
        }
    }
    
    private struct InstallationCheckHeroIcon: View {
        @State private var animateRings = false
        @State private var floatingOffset: CGFloat = 0
        
        var body: some View {
            ZStack {
                // Animated rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        .frame(width: 130 + CGFloat(i) * 30, height: 130 + CGFloat(i) * 30)
                        .scaleEffect(animateRings ? 1.1 : 1.0)
                        .opacity(animateRings ? 0.3 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                            value: animateRings
                        )
                }
                
                // Main icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.appAccent)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .offset(y: floatingOffset)
            }
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        animateRings = true
                    }
                    withAnimation(Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                        floatingOffset = -8
                    }
                }
            }
        }
    }
    
    private struct BrandCard<Content: View>: View {
        let content: Content
        
        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

private extension OnboardingView {
    enum ProgressIndicatorDisplayMode {
        case large
        case compact
    }

    @ViewBuilder
    func progressIndicatorItem(for page: OnboardingPage, displayMode: ProgressIndicatorDisplayMode) -> some View {
        // Get step number (1-6), excluding preOnboardingHook and overview
        if let position = page.stepNumber {
            // Compare using step numbers for proper ordering
            let currentStepNumber = currentPage.stepNumber ?? 0
            let pageStepNumber = page.stepNumber ?? 0
            let isCurrent = currentPage == page
            let isComplete = currentStepNumber > pageStepNumber
            let isClickable = pageStepNumber < currentStepNumber // Can navigate back to previous steps

            let circleFill: Color = {
                if isCurrent || isComplete {
                    return Color.appAccent  // Cyan for current and completed
                } else {
                    return Color(.systemGray5)  // Light gray for future steps
                }
            }()

            let circleTextColor: Color = isCurrent || isComplete ? .white : Color(.secondaryLabel)

            // Calculate values based on display mode (computed before ViewBuilder context)
            let (circleSize, circleShadowOpacity, circleStrokeOpacity, circleStrokeWidth, circleFontSize, circleFontDesign): (CGFloat, Double, Double, CGFloat, CGFloat, Font.Design) = {
                switch displayMode {
                case .large:
                    return (38, isCurrent ? 0.18 : 0.0, isCurrent ? 0.25 : 0.15, isCurrent ? 1.5 : 1, 16, .rounded)
                case .compact:
                    return (40, 0.0, isCurrent ? 0.28 : 0.18, 1, 18, .rounded)
                }
            }()

            ZStack {
                Circle()
                    .fill(circleFill)
                .frame(width: circleSize, height: circleSize)
                .shadow(color: Color.black.opacity(circleShadowOpacity), radius: isCurrent ? 10 : 0, x: 0, y: isCurrent ? 6 : 0)
                    .overlay(
                        Circle()
                        .strokeBorder(Color.white.opacity(circleStrokeOpacity), lineWidth: circleStrokeWidth)
                    )

                // Always show numbers (no checkmarks)
                Text("\(position)")
                    .font(.system(size: circleFontSize, weight: .semibold, design: circleFontDesign))
                    .foregroundColor(circleTextColor)
            }
            .opacity(isClickable ? 1.0 : 0.6) // Slightly dim future steps to show they're not clickable
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(position)")
            .accessibilityValue(isComplete ? "Complete, tap to go back" : (isCurrent ? "Current step" : "Not started"))
        } else {
            // Return empty view for preOnboardingHook and overview (they don't have step numbers)
            EmptyView()
        }
    }

    private var overviewHeroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.appAccent.opacity(0.28),
                            Color.appAccent.opacity(0.12),
                            Color(.systemBackground)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 16) {
                Text("Ready to Go")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You’ve got everything set up. Keep these quick highlights in mind as you start using FaithWall.")
                    .font(.callout)
                    .foregroundColor(.secondary)

                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(Color.appAccent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What’s next?")
                            .font(.headline)
                        Text("Add notes, update the wallpaper, and let FaithWall keep your lock screen awesome.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .accessibilityElement(children: .combine)
    }

    private func overviewInfoCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.appAccent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 8)
        )
    }

    private var overviewAutomationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Pro tip: make it automatic")
                    .font(.headline)
            } icon: {
                Image(systemName: "bolt.badge.clock")
                    .foregroundColor(Color.appAccent)
            }

            Text("Create a Shortcuts automation so FaithWall runs on your schedule, like at the start of a workday or when a Focus mode activates.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                overviewAutomationRow("Trigger it every morning before you leave for the day.")
                overviewAutomationRow("Pair it with a Focus mode to keep your lock screen current throughout the week.")
                overviewAutomationRow("Use a personal automation when you arrive at the office or start a commute.")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.10), lineWidth: 1)
        )
    }

    private func overviewAutomationRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption)
                .foregroundColor(Color.appAccent)
                .accessibilityHidden(true)

            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    private var cornerRadius: CGFloat {
        ScreenDimensions.isCompactDevice ? 14 : 20
    }

    func makeBody(configuration: Configuration) -> some View {
        let colors = buttonColors(isPressed: configuration.isPressed)

        return configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: colors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(isEnabled ? 0.08 : 0.04), lineWidth: 1)
            )
            .shadow(
                color: Color.appAccent.opacity(isEnabled ? (configuration.isPressed ? 0.16 : 0.28) : 0.08),
                radius: configuration.isPressed ? 8 : 16,
                x: 0,
                y: configuration.isPressed ? 4 : 12
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.75)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }

    private func buttonColors(isPressed: Bool) -> [Color] {
        if isEnabled {
            let top = Color.appAccent.opacity(isPressed ? 0.95 : 1.0)
            let bottom = Color.appAccent.opacity(isPressed ? 0.82 : 0.9)
            return [top, bottom]
        } else {
            return [
                Color(.systemGray4),
                Color(.systemGray5)
            ]
        }
    }
}

private extension OnboardingPage {
    var navigationTitle: String {
        switch self {
        case .preOnboardingHook:
            return ""
        case .quizIntro:
            return ""
        case .quizForgetMost, .quizPhoneChecks, .quizDistraction:
            return ""
        case .personalizationLoading:
            return ""
        case .resultsPreview:
            return ""
        case .symptoms:
            return ""
        case .howAppHelps:
            return ""
        case .socialProof:
            return ""
        case .setupIntro:
            return ""
        case .pipelineChoice:
            return ""
        case .widgetOnboarding:
            return ""
        case .addNotes:
            return "Add Notes"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .videoIntroduction:
            return "Introduction"
        case .installShortcut:
            return "Install Shortcut"
        case .shortcutSuccess:
            return ""
        case .allowPermissions:
            return "Allow Permissions"
        case .setupComplete:
            return ""
        case .overview:
            return "All Set"
        }
    }

    var progressTitle: String {
        switch self {
        case .preOnboardingHook:
            return "Pre-Onboarding Hook"
        case .quizIntro:
            return "Getting Started"
        case .quizForgetMost, .quizPhoneChecks, .quizDistraction:
            return "Personalization"
        case .personalizationLoading:
            return "Customizing"
        case .resultsPreview:
            return "Your Profile"
        case .symptoms:
            return "Symptoms"
        case .howAppHelps:
            return "Solution"
        case .socialProof:
            return "Community"
        case .setupIntro:
            return "Setup Preview"
        case .pipelineChoice:
            return "Choose Setup"
        case .widgetOnboarding:
            return "Widget Setup"
        case .addNotes:
            return "Add Notes"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .videoIntroduction:
            return "Introduction"
        case .installShortcut:
            return "Install Shortcut"
        case .shortcutSuccess:
            return "Success"
        case .allowPermissions:
            return "Allow Permissions"
        case .setupComplete:
            return "Complete"
        case .overview:
            return "All Set"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .preOnboardingHook:
            return "Pre-Onboarding"
        case .quizIntro:
            return "Getting Started"
        case .quizForgetMost:
            return "Quiz question 1"
        case .quizPhoneChecks:
            return "Quiz question 2"
        case .quizDistraction:
            return "Quiz question 3"
        case .personalizationLoading:
            return "Customizing your experience"
        case .resultsPreview:
            return "Your personalized results"
        case .symptoms:
            return "Understanding your struggles"
        case .howAppHelps:
            return "How FaithWall helps"
        case .socialProof:
            return "Community proof"
        case .setupIntro:
            return "Setup introduction"
        case .pipelineChoice:
            return "Choose your setup method"
        case .widgetOnboarding:
            return "Widget setup"
        case .videoIntroduction:
            return "Step 1"
        case .installShortcut:
            return "Step 2"
        case .shortcutSuccess:
            return "Shortcut installed"
        case .addNotes:
            return "Step 3"
        case .chooseWallpapers:
            return "Step 4"
        case .allowPermissions:
            return "Step 5"
        case .setupComplete:
            return "Setup complete"
        case .overview:
            return "All Set"
        }
    }
    
    // Returns the step number (1-6) for display in the step counter
    // Only technical setup steps show step numbers
    var stepNumber: Int? {
        switch self {
        case .preOnboardingHook, .quizIntro, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .symptoms, .howAppHelps, .socialProof, .setupIntro, .pipelineChoice, .widgetOnboarding, .shortcutSuccess, .setupComplete, .overview:
            return nil // These don't show step numbers
        case .videoIntroduction:
            return 1
        case .installShortcut:
            return 2
        case .addNotes:
            return 3
        case .chooseWallpapers:
            return 4
        case .allowPermissions:
            return 5
        }
    }
    
    // Phase for progress indicator
    var phase: String {
        switch self {
        case .preOnboardingHook, .quizIntro, .quizForgetMost, .quizPhoneChecks, .quizDistraction, .personalizationLoading, .resultsPreview, .symptoms, .howAppHelps:
            return "Getting to Know You"
        case .socialProof, .setupIntro, .pipelineChoice:
            return "Almost Ready"
        case .widgetOnboarding:
            return "Widget Setup"
        case .videoIntroduction, .installShortcut, .shortcutSuccess, .addNotes, .chooseWallpapers, .allowPermissions:
            return "Setup"
        case .setupComplete, .overview:
            return "Complete"
        }
    }
    
    // Whether this page shows the compact progress indicator
    var showsProgressIndicator: Bool {
        switch self {
        case .preOnboardingHook, .quizIntro, .quizForgetMost, .quizPhoneChecks, .quizDistraction,
             .personalizationLoading, .resultsPreview, .symptoms, .howAppHelps, .socialProof, .setupIntro, .pipelineChoice, .widgetOnboarding, .shortcutSuccess, .setupComplete, .overview:
            return false
        case .videoIntroduction, .installShortcut, .addNotes, .chooseWallpapers, .allowPermissions:
            return true
        }
    }
}

#if !os(macOS)
private extension View {
    @ViewBuilder
    func onboardingNavigationBarBackground() -> some View {
        if #available(iOS 16.0, *) {
            self
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarBackground(.hidden, for: .automatic)
        } else {
            self
        }
    }
}
#endif

#if !os(macOS)
private extension View {
    @ViewBuilder
    func scrollAlwaysBounceIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.always)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func scrollDismissesKeyboardIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}
#endif

// MARK: - Loading Placeholder

private struct LoadingPlaceholder: View {
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray5))
            .frame(height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 400 : -400)
            )
            .clipped()
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Looping Video Player View
private struct LoopingVideoPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer
    let playbackRate: Float
    
    func makeCoordinator() -> Coordinator {
        Coordinator(player: player, playbackRate: playbackRate)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = VideoPlayerContainerView()
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = view.bounds // Set initial frame
        view.playerLayer = playerLayer
        view.layer.addSublayer(playerLayer)
        
        // Store coordinator
        context.coordinator.containerView = view
        context.coordinator.playerLayer = playerLayer
        
        // Set up frame and playback
        DispatchQueue.main.async {
            playerLayer.frame = view.bounds
            
            // Check if item is already ready and play immediately
            if let currentItem = player.currentItem {
                if currentItem.status == .readyToPlay && player.rate == 0 {
                    // Item is ready, play immediately
                    player.playImmediately(atRate: playbackRate)
                    print("✅ LoopingVideoPlayerView: Started playing immediately (item already ready)")
                } else if currentItem.status != .readyToPlay {
                    // Item not ready yet, set up observer
                    let coordinator = context.coordinator
                    coordinator.statusObserver?.invalidate()
                    let statusObserver = currentItem.observe(\.status, options: [.new]) { [weak player, weak coordinator] item, _ in
                        guard let player = player, let coordinator = coordinator else { return }
                        DispatchQueue.main.async {
                            if item.status == .readyToPlay && player.rate == 0 {
                                if let containerView = coordinator.containerView,
                                   let layer = containerView.playerLayer {
                                    layer.frame = containerView.bounds
                                }
                                player.playImmediately(atRate: playbackRate)
                                print("✅ LoopingVideoPlayerView: Started playing after item became ready")
                            }
                        }
                    }
                    coordinator.statusObserver = statusObserver
                }
            } else {
                // No current item, try to play anyway (looper should handle it)
                if player.rate == 0 {
                    player.playImmediately(atRate: playbackRate)
                    print("✅ LoopingVideoPlayerView: Started playing (no item check)")
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let containerView = uiView as? VideoPlayerContainerView,
              let playerLayer = containerView.playerLayer else {
            return
        }
        
        // Only update frame - don't try to play here, let allowPermissionsStep handle playback
        let newFrame = uiView.bounds
        if playerLayer.frame != newFrame {
            playerLayer.frame = newFrame
        }
    }
    
    class Coordinator {
        let player: AVQueuePlayer
        let playbackRate: Float
        weak var containerView: VideoPlayerContainerView?
        weak var playerLayer: AVPlayerLayer?
        var statusObserver: NSKeyValueObservation?
        
        init(player: AVQueuePlayer, playbackRate: Float) {
            self.player = player
            self.playbackRate = playbackRate
        }
        
        deinit {
            statusObserver?.invalidate()
        }
    }
}

private class VideoPlayerContainerView: UIView {
    var playerLayer: AVPlayerLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure player layer frame matches bounds after layout
        if let playerLayer = playerLayer {
            let newFrame = bounds
            if playerLayer.frame != newFrame {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                playerLayer.frame = newFrame
                CATransaction.commit()
            }
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        // When view is added to window, ensure player layer frame is set
        if window != nil, let playerLayer = playerLayer {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                playerLayer.frame = self.bounds
            }
        }
    }
}

// MARK: - Non-Interactive Video Player View (no controls, no interactions)
private struct NonInteractiveVideoPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer
    let playbackRate: Float
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        
        // Store layer in coordinator for frame updates
        context.coordinator.playerLayer = playerLayer
        
        // Set up frame and playback
        DispatchQueue.main.async {
            playerLayer.frame = view.bounds
            
            // Start playback when ready
            if let currentItem = player.currentItem {
                if currentItem.status == .readyToPlay && player.rate == 0 {
                    player.playImmediately(atRate: playbackRate)
                } else if currentItem.status != .readyToPlay {
                    // Wait for item to be ready
                    let statusObserver = currentItem.observe(\.status, options: [.new]) { [weak player] item, _ in
                        guard let player = player else { return }
                        DispatchQueue.main.async {
                            if item.status == .readyToPlay && player.rate == 0 {
                                player.playImmediately(atRate: playbackRate)
                            }
                        }
                    }
                    context.coordinator.statusObserver = statusObserver
                }
            } else {
                if player.rate == 0 {
                    player.playImmediately(atRate: playbackRate)
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let playerLayer = context.coordinator.playerLayer else {
            return
        }
        
        // Update frame to match view bounds
        let newFrame = uiView.bounds
        if playerLayer.frame != newFrame {
            playerLayer.frame = newFrame
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
        var statusObserver: NSKeyValueObservation?
        
        deinit {
            statusObserver?.invalidate()
        }
    }
}

// MARK: - Animated Checkmark View
private struct AnimatedCheckmarkView: View {
    @State private var isAnimating = false
    @State private var showCheckmark = false
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.appAccent)
                .frame(width: 120, height: 120)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .shadow(color: Color.appAccent.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.primary)
                .opacity(showCheckmark ? 1 : 0)
                .scaleEffect(showCheckmark ? 1 : 0.3)
        }
        .onAppear {
            performAnimation()
        }
    }
    
    private func performAnimation() {
        // Play haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        
        // Play system sound (success sound)
        AudioServicesPlaySystemSound(1519) // Success sound
        
        // Animate the circle
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
            scale = 1.0
            rotation = 360
        }
        
        // Trigger haptic after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impactFeedback.impactOccurred()
        }
        
        // Show checkmark with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
            }
            
            // Second haptic for checkmark appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let lightFeedback = UIImpactFeedbackGenerator(style: .light)
                lightFeedback.impactOccurred()
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true), onboardingVersion: 2)
}

private extension OnboardingView {
    func ensureCustomPhotoFlagIsAccurate() {
        // During onboarding, don't auto-enable based on file existence
        // Only sync the flag in Settings view where it makes sense
        // This prevents pre-selection during first-time setup
        
        // If user hasn't completed setup yet, ensure flag starts as false
        if !hasCompletedSetup {
            homeScreenUsesCustomPhoto = false
            return
        }
        
        // After setup is complete, sync with actual file state
        let shouldBeEnabled = homeScreenPresetSelectionRaw.isEmpty && HomeScreenImageManager.homeScreenImageExists()
        if homeScreenUsesCustomPhoto != shouldBeEnabled {
            homeScreenUsesCustomPhoto = shouldBeEnabled
        }
    }

    private func advanceAfterShortcutInstallIfNeeded() {
        // This method is no longer needed - navigation is handled directly in onChange
        // Keeping it for backwards compatibility but it shouldn't be called
    }
}

// MARK: - Animated Word Component

struct AnimatedWord: View {
    let text: String
    let isVisible: Bool
    let delay: Double
    var isAccent: Bool = false
    
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 20
    
    var body: some View {
        Text(text)
            .foregroundStyle(
                isAccent ?
                LinearGradient(
                    colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                ) :
                LinearGradient(
                    colors: [.white.opacity(0.7), .white.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: isAccent ? Color.appAccent.opacity(0.5) : .clear, radius: 10, x: 0, y: 0)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: yOffset)
            .onChange(of: isVisible) { visible in
                if visible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            scale = 1.0
                            opacity = 1.0
                            yOffset = 0
                        }
                    }
                }
            }
    }
}

// MARK: - Floating Ambient Particles

struct FloatingParticlesView: View {
    @State private var particles: [FloatingParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [particle.color.opacity(0.6), particle.color.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: particle.size / 2
                            )
                        )
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: particle.blur)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                animateParticles(in: geometry.size)
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        particles = (0..<25).map { _ in
            FloatingParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 4...20),
                color: [Color.appAccent, .white, Color.appAccent.opacity(0.5)].randomElement()!,
                blur: CGFloat.random(in: 0...3),
                speed: Double.random(in: 3...8)
            )
        }
    }
    
    private func animateParticles(in size: CGSize) {
        for i in particles.indices {
            let particle = particles[i]
            withAnimation(
                .easeInOut(duration: particle.speed)
                .repeatForever(autoreverses: true)
            ) {
                particles[i].y = CGFloat.random(in: 0...size.height)
                particles[i].x = particle.x + CGFloat.random(in: -50...50)
            }
        }
    }
}

struct FloatingParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    let blur: CGFloat
    let speed: Double
}

// MARK: - Countdown Burst Effect

struct CountdownBurstView: View {
    @State private var particles: [BurstParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.offsetX, y: particle.offsetY)
                    .opacity(particle.opacity)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            createBurst()
        }
    }
    
    private func createBurst() {
        particles = (0..<16).map { i in
            let angle = Double(i) * (360.0 / 16.0) * .pi / 180.0
            return BurstParticle(
                angle: angle,
                size: CGFloat.random(in: 4...8),
                color: [Color.appAccent, .white, Color.appAccent.opacity(0.7)].randomElement()!
            )
        }
        
        // Animate burst outward
        for i in particles.indices {
            let angle = particles[i].angle
            let distance: CGFloat = CGFloat.random(in: 60...100)
            
            withAnimation(.easeOut(duration: 0.4)) {
                particles[i].offsetX = cos(angle) * distance
                particles[i].offsetY = sin(angle) * distance
                particles[i].opacity = 0
            }
        }
    }
}

struct BurstParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let size: CGFloat
    let color: Color
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var opacity: Double = 1
}

// (Duplicate ConfettiView removed; use ConfettiView in OnboardingEnhanced.swift)

// MARK: - Auto-Playing Looping Video Player

struct AutoPlayingLoopingVideoPlayer: UIViewRepresentable {
    let player: AVQueuePlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        
        // Store player layer in context for updates
        context.coordinator.playerLayer = playerLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = context.coordinator.playerLayer {
            // Update frame when view bounds change
            DispatchQueue.main.async {
                playerLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}
