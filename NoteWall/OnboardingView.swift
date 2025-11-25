import SwiftUI
import PhotosUI
import UIKit
import QuartzCore
import AVKit
import AVFoundation
import AudioToolbox

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

private enum OnboardingPage: Int, CaseIterable, Hashable {
    case welcome
    case installShortcut
    case addNotes
    case chooseWallpapers
    case allowPermissions
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
    @State private var didOpenShortcut = false
    @State private var isSavingHomeScreenPhoto = false
    @State private var homeScreenStatusMessage: String?
    @State private var homeScreenStatusColor: Color = .gray
    @State private var isSavingLockScreenBackground = false
    @State private var lockScreenBackgroundStatusMessage: String?
    @State private var lockScreenBackgroundStatusColor: Color = .gray

    @State private var currentPage: OnboardingPage = .welcome
    @State private var isLaunchingShortcut = false
    @State private var shortcutLaunchFallback: DispatchWorkItem?
    @State private var wallpaperVerificationTask: Task<Void, Never>?
    @State private var didTriggerShortcutRun = false
    @State private var isLoadingWallpaperStep = false
    @State private var demoVideoPlayer: AVQueuePlayer?
    @State private var demoVideoLooper: AVPlayerLooper?
    @State private var notificationsVideoPlayer: AVQueuePlayer?
    @State private var notificationsVideoLooper: AVPlayerLooper?
    @StateObject private var pipVideoPlayerManager = PIPVideoPlayerManager()
    @State private var shouldStartPiP = false
    private let demoVideoPlaybackRate: Float = 1.5
    
    // Post-onboarding troubleshooting
    @State private var showTroubleshooting = false
    @State private var shouldRestartOnboarding = false
    
    // Notes management for onboarding
    @State private var onboardingNotes: [Note] = []
    @State private var currentNoteText = ""
    @FocusState private var isNoteFieldFocused: Bool

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

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                navigationStackOnboarding
            } else {
                navigationViewOnboarding
            }
        }
        .interactiveDismissDisabled()
        .overlay(
            // Player layer for PiP support - must be in view hierarchy
            // Keep it off-screen but with proper video dimensions
            HiddenPiPPlayerLayerView(playerManager: pipVideoPlayerManager)
                .frame(width: 320, height: 568) // Proper video dimensions
                .offset(x: -10000, y: 0) // Off-screen to the left
                .allowsHitTesting(false)
        )
        .task {
            HomeScreenImageManager.prepareStorageStructure()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shortcutWallpaperApplied)) { _ in
            completeShortcutLaunch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperGenerationFinished)) { _ in
            handleWallpaperGenerationFinished()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                print("📱 Onboarding: App became active, currentPage: \(currentPage), didOpenShortcut: \(didOpenShortcut)")
                // Stop PiP when returning to app
                if pipVideoPlayerManager.isPiPActive {
                    pipVideoPlayerManager.stopPictureInPicture()
                    pipVideoPlayerManager.stop()
                }
                shouldStartPiP = false
                
                // Handle return from Shortcuts app after installing shortcut
                // Only advance if we're still on the install shortcut step and shortcut was opened
                if currentPage == .installShortcut && didOpenShortcut {
                    print("📱 Onboarding: Detected return from Shortcuts app, navigating to add notes step immediately")
                    // Navigate immediately - no delay needed
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.currentPage = .addNotes
                    }
                    self.didOpenShortcut = false
                    print("✅ Onboarding: Now on page: \(self.currentPage)")
                }
                // Only complete shortcut launch if we're on the chooseWallpapers step
                if currentPage == .chooseWallpapers {
                    completeShortcutLaunch()
                }
            } else if newPhase == .background {
                // PiP should automatically take over the already-playing video
                // because we set canStartPictureInPictureAutomaticallyFromInline = true
                if shouldStartPiP && currentPage == .installShortcut {
                    print("🎬 Onboarding: App went to background")
                    print("   - Video should already be playing")
                    print("   - PiP should take over automatically")
                    
                    // If automatic PiP doesn't work, try manual start as fallback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !self.pipVideoPlayerManager.isPiPActive {
                            print("⚠️ Onboarding: Automatic PiP didn't start, trying manual start")
                            if self.pipVideoPlayerManager.isReadyToPlay && self.pipVideoPlayerManager.isPiPControllerReady {
                                let success = self.pipVideoPlayerManager.startPictureInPicture()
                                if success {
                                    print("✅ Onboarding: PiP started manually")
                                } else {
                                    print("❌ Onboarding: Manual PiP start also failed")
                                }
                            }
                        } else {
                            print("✅ Onboarding: Automatic PiP is active")
                        }
                    }
                }
            }
        }
        .onChange(of: currentPage) { page in
            if page == .chooseWallpapers {
                HomeScreenImageManager.prepareStorageStructure()
            }
        }
        .onChange(of: shouldRestartOnboarding) { shouldRestart in
            if shouldRestart {
                // Reset to first page and restart onboarding
                withAnimation {
                    currentPage = .welcome
                }
                shouldRestartOnboarding = false
            }
        }
        .preferredColorScheme(.dark)
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
        VStack(spacing: 0) {
            onboardingProgressIndicatorCompact
                .padding(.top, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .background(
                    Color(.systemBackground)
                        .ignoresSafeArea()
                )

            ZStack {
                // Solid background to prevent seeing underlying content during transitions
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                Group {
                    switch currentPage {
                    case .welcome:
                        welcomeStep()
                    case .installShortcut:
                        installShortcutStep()
                    case .addNotes:
                        addNotesStep()
                    case .chooseWallpapers:
                        chooseWallpapersStep(includePhotoPicker: includePhotoPicker)
                    case .allowPermissions:
                        allowPermissionsStep()
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

            primaryButtonSection
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var onboardingProgressIndicatorCompact: some View {
        HStack(alignment: .center, spacing: 12) {
            ForEach(OnboardingPage.allCases, id: \.self) { page in
                progressIndicatorItem(for: page, displayMode: .compact)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(currentPage.accessibilityLabel) of \(OnboardingPage.allCases.count)")
    }

    private var primaryButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: handlePrimaryButton) {
                HStack(spacing: 12) {
                    if currentPage == .chooseWallpapers && isLaunchingShortcut {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(.white)
                    } else if let iconName = primaryButtonIconName {
                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .semibold))
                    }

                    Text(primaryButtonTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: primaryButtonEnabled))
            .disabled(!primaryButtonEnabled)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    private func welcomeStep() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    Image("OnboardingLogo")
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
                        .accessibilityHidden(true)
                    
                    Text("Welcome to NoteWall")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    Text("Because if you see it 50x per day, you'll do it and will never forget anything again.")
                        .font(.system(.title3))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                
                VStack(spacing: 16) {
                    welcomeHighlightCard(
                        title: "Stay on track",
                        subtitle: "Pin your priorities to the lock screen so the next action is always waiting for you.",
                        icon: "checkmark.circle.fill"
                    )
                    
                    welcomeHighlightCard(
                        title: "Remember what matters",
                        subtitle: "See gratitude notes, reminders, and personal cues right when you pick up your phone.",
                        icon: "sparkles"
                    )
                    
                    welcomeHighlightCard(
                        title: "Move faster",
                        subtitle: "Drop thoughts into NoteWall in seconds and turn them into wallpapers with one tap.",
                        icon: "bolt.fill"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 36)
        }
        .scrollAlwaysBounceIfAvailable()
    }
    
    private func welcomeHighlightCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.appAccent)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
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
    
    private func installShortcutStep() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundColor(.appAccent)
                        .padding(.top, 8)
                    
                    Text("Install the Shortcut")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("This takes 30 seconds. A video guide will help you.")
                        .font(.system(.title3))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                
                VStack(spacing: 14) {
                    installShortcutInfoCard(
                        title: "Add the Shortcut",
                        subtitle: "Tap 'Add Shortcut' in the Shortcuts app.",
                        icon: "plus.circle.fill"
                    )
                    
                    installShortcutInfoCard(
                        title: "Choose Your Current Wallpaper",
                        subtitle: "Select the wallpaper you're using RIGHT NOW. This is the one you want to replace with notes.",
                        icon: "photo.fill",
                        highlightedText: "Current Wallpaper"
                    )
                    
                    installShortcutInfoCard(
                        title: "Follow the Video",
                        subtitle: "A Picture-in-Picture video will show you exactly what to do.",
                        icon: "play.rectangle.fill"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 36)
        }
        .scrollAlwaysBounceIfAvailable()
        .onAppear {
            // Prepare PiP video when this step appears
            preparePiPVideo()
            // Preload/prepare the next step (addNotes) for instant transition
            // This ensures the view is ready when user returns from Shortcuts app
        }
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
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Add Your First Notes")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                    
                    Text("These notes will appear on your lock screen wallpaper")
                        .font(.system(.title3))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 16) {
                        // Display existing notes
                        ForEach(onboardingNotes) { note in
                            HStack(spacing: 12) {
                                Text("\(noteIndex(for: note) + 1).")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, alignment: .leading)
                                
                                Text(note.text)
                                    .font(.system(.body))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button(action: {
                                    withAnimation {
                                        removeNote(note)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .id(note.id)
                        }
                        
                        // Input field for new note
                        HStack(spacing: 12) {
                            TextField("Type a note...", text: $currentNoteText)
                                .font(.system(.body))
                                .focused($isNoteFieldFocused)
                                .onSubmit {
                                    addCurrentNote(scrollProxy: proxy)
                                }
                            
                            Button(action: {
                                addCurrentNote(scrollProxy: proxy)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(currentNoteText.isEmpty ? .gray : .appAccent)
                            }
                            .disabled(currentNoteText.isEmpty)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .id("inputField")
                        
                        if onboardingNotes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text("Add at least one note to continue")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 32)
            }
            .scrollAlwaysBounceIfAvailable()
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                isNoteFieldFocused = false
            }
            .onAppear {
                // Focus the text field when the view appears - reduced delay for faster feel
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isNoteFieldFocused = true
                }
            }
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
        return onboardingNotes.firstIndex(where: { $0.id == note.id }) ?? 0
    }

    private func allowPermissionsStep() -> some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                Text("Allow Permissions")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                
                Text("Click \"Allow\" for ALL permissions")
                    .font(.system(.title3))
                    .foregroundColor(.appAccent)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                    .zIndex(10)
                
                notificationsVideoSection(minHeight: proxy.size.height - 200)
                    .padding(.horizontal, 16)
                    .padding(.top, -30)
                    .zIndex(1)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            // Prepare video player (may already be preloaded from step 3)
            prepareNotificationsVideoPlayerIfNeeded()
        }
    }

    @ViewBuilder
    private func chooseWallpapersStep(includePhotoPicker: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Choose Your Wallpapers")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Edit Notes button to go back to step 2
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage = .addNotes
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Edit Notes")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.appAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.appAccent.opacity(0.1))
                        )
                    }
                }

                if includePhotoPicker {
                    if #available(iOS 16.0, *) {
                        if isLoadingWallpaperStep {
                            VStack(spacing: 16) {
                                LoadingPlaceholder()
                                LoadingPlaceholder()
                                LoadingPlaceholder()
                            }
                            .transition(.opacity)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
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

                                if let message = homeScreenStatusMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(homeScreenStatusColor)
                                }
                                
                                Divider()
                                    .padding(.vertical, 12)

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
                            }
                            .transition(.opacity)
                        }
                    }
                } else {
                        Text("Update to iOS 16+ to pick a photo directly. For now, the shortcut will reuse your current home screen wallpaper.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .onAppear(perform: ensureCustomPhotoFlagIsAccurate)
        .scrollAlwaysBounceIfAvailable()
    }

    private func overviewStep() -> some View {
        VStack(spacing: 24) {
            Text("Ready to Go")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .padding(.top, 32)
            
            Text("You're all set! Start adding notes and updating your wallpaper.")
                .font(.system(.title3))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Spacer(minLength: 40)
            
            AnimatedCheckmarkView()
                .padding(.top, -60)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .accessibilityLabel("NoteWall demo video showing the shortcut flow")
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

    private var primaryButtonTitle: String {
        switch currentPage {
        case .welcome:
            return "Next"
        case .overview:
            return "Start Using NoteWall"
        case .chooseWallpapers:
            return isLaunchingShortcut ? "Launching Shortcut…" : "Next"
        case .allowPermissions:
            return "Continue"
        case .installShortcut:
            return didOpenShortcut ? "Next" : "Install"
        case .addNotes:
            return "Continue"
        }
    }

    private var primaryButtonIconName: String? {
        switch currentPage {
        case .welcome:
            return "arrow.right.circle.fill"
        case .overview:
            return "checkmark.circle.fill"
        case .chooseWallpapers:
            return isLaunchingShortcut ? nil : "paintbrush.pointed.fill"
        case .allowPermissions:
            return "checkmark.shield.fill"
        case .installShortcut:
            return "bolt.fill"
        case .addNotes:
            return "arrow.right.circle.fill"
        }
    }

    private var primaryButtonEnabled: Bool {
        switch currentPage {
        case .welcome:
            return true
        case .installShortcut:
            return true
        case .addNotes:
            return !onboardingNotes.isEmpty
        case .allowPermissions:
            return true
        case .chooseWallpapers:
            let hasHomeSelection = homeScreenUsesCustomPhoto || !homeScreenPresetSelectionRaw.isEmpty
            let hasLockSelection: Bool
            if let mode = LockScreenBackgroundMode(rawValue: lockScreenBackgroundModeRaw) {
                if mode == .photo {
                    hasLockSelection = !lockScreenBackgroundPhotoData.isEmpty
                } else if mode == .notSelected {
                    hasLockSelection = false
                } else {
                    hasLockSelection = true
                }
            } else {
                hasLockSelection = false
            }
            return hasHomeSelection && hasLockSelection && !isSavingHomeScreenPhoto && !isSavingLockScreenBackground && !isLaunchingShortcut
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
        case .welcome:
            advanceStep()
        case .installShortcut:
            if didOpenShortcut {
                // User already tapped "Next" after installing shortcut
                // Navigate to add notes step (this happens if user taps Next before leaving app)
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage = .addNotes
                    didOpenShortcut = false // Reset flag to prevent double navigation
                }
            } else {
                // Open shortcut installation URL
                installShortcut()
                // Navigation to addNotes will happen automatically when user 
                // returns to app (handled in onChange of scenePhase)
                // The flag didOpenShortcut is set in installShortcut() callback
            }
        case .addNotes:
            // Preload video player when moving to step 3 (so it's ready for step 4)
            prepareNotificationsVideoPlayerIfNeeded()
            // Show loading state
            isLoadingWallpaperStep = true
            // Small delay to let keyboard dismiss and show loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentPage = .chooseWallpapers
                }
                // Hide loading after transition completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.isLoadingWallpaperStep = false
                }
            }
        case .chooseWallpapers:
            startShortcutLaunch()
        case .allowPermissions:
            advanceStep()
        case .overview:
            completeOnboarding()
        }
    }

    private func advanceStep() {
        guard let next = OnboardingPage(rawValue: currentPage.rawValue + 1) else { 
            return 
        }
        
        // Light impact haptic for page transition
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation(.easeInOut) {
            currentPage = next
        }
    }
    
    private func goBackStep() {
        guard currentPage.rawValue > 0 else { return }
        guard let previous = OnboardingPage(rawValue: currentPage.rawValue - 1) else { return }
        
        // Light impact haptic for going back
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation(.easeInOut) {
            currentPage = previous
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
            if currentPage == .welcome {
                advanceStep()
            } else if currentPage == .installShortcut && didOpenShortcut {
                currentPage = .addNotes
            } else if currentPage == .chooseWallpapers && primaryButtonEnabled {
                startShortcutLaunch()
            } else if currentPage == .allowPermissions {
                advanceStep()
            }
        }
    }

    private func startShortcutLaunch() {
        guard !isSavingHomeScreenPhoto, !isSavingLockScreenBackground, !isLaunchingShortcut else { 
            return 
        }
        
        HomeScreenImageManager.prepareStorageStructure()
        wallpaperVerificationTask?.cancel()
        wallpaperVerificationTask = nil
        
        // Save notes BEFORE generating wallpaper so ContentView can read them
        saveOnboardingNotes()
        
        isLaunchingShortcut = true
        didTriggerShortcutRun = false
        shortcutLaunchFallback?.cancel()

        let fallback = DispatchWorkItem {
            if self.currentPage == .chooseWallpapers {
                if self.isLaunchingShortcut && !self.didTriggerShortcutRun {
                    self.openShortcutToApplyWallpaper()
                }
            }
        }
        shortcutLaunchFallback = fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: fallback)

        finalizeWallpaperSetup()
    }

    private func installShortcut() {
        guard let url = URL(string: currentShortcutURL) else { return }
        
        // Prepare PiP video before opening Shortcuts app
        preparePiPVideo()
        shouldStartPiP = true
        
        // Prepare the video but DON'T start playing yet
        // We'll start it when the app goes to background so user sees it from the beginning
        Task {
            // Wait for player to be ready
            var attempts = 0
            while !pipVideoPlayerManager.isReadyToPlay && attempts < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                attempts += 1
            }
            
            // Wait for PiP controller to be ready
            attempts = 0
            while !pipVideoPlayerManager.isPiPControllerReady && attempts < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                attempts += 1
            }
            
            if pipVideoPlayerManager.isReadyToPlay && pipVideoPlayerManager.isPiPControllerReady {
                print("✅ Onboarding: Player and PiP controller ready")
                
                // Make sure video is at the beginning
                await MainActor.run {
                    pipVideoPlayerManager.getPlayer()?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                }
                
                // CRITICAL: Start playing the video BEFORE opening Shortcuts
                // iOS requires the video to be actively playing before PiP can work
                _ = pipVideoPlayerManager.play()
                print("✅ Onboarding: Started video playback")
                
                // Wait a moment for playback to actually start (very brief)
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                // Now open Shortcuts - PiP will take over when app backgrounds
                await MainActor.run {
                    UIApplication.shared.open(url) { success in
                        DispatchQueue.main.async {
                            if success {
                                self.didOpenShortcut = true
                                print("✅ Onboarding: Opened Shortcuts, PiP will take over automatically")
                            } else {
                                print("⚠️ Onboarding: Shortcut URL open failed. This may be due to:")
                                print("   - iCloud Drive connectivity issues")
                                print("   - Pending iCloud terms acceptance")
                                print("   - Network connectivity problems")
                                print("   - Shortcuts app privacy settings")
                                self.shouldStartPiP = false
                                // Stop playback if Shortcuts didn't open
                                self.pipVideoPlayerManager.stop()
                            }
                        }
                    }
                }
            } else {
                print("❌ Onboarding: Cannot prepare PiP - Player ready: \(self.pipVideoPlayerManager.isReadyToPlay), Controller ready: \(self.pipVideoPlayerManager.isPiPControllerReady)")
            }
        }
    }
    
    private func preparePiPVideo() {
        guard let bundleURL = Bundle.main.url(forResource: "pip-guide-video", withExtension: "mp4") else {
            print("⚠️ Onboarding: PiP demo video not found in bundle")
            return
        }
        
        print("🎬 Onboarding: Preparing PiP video from: \(bundleURL.path)")
        
        // Load the video
        let loaded = pipVideoPlayerManager.loadVideo(url: bundleURL)
        
        if loaded {
            print("✅ Onboarding: Video loaded, waiting for player to be ready")
            
            // Wait for player to be ready, then set up the layer
            Task {
                var attempts = 0
                while !pipVideoPlayerManager.isReadyToPlay && attempts < 50 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    attempts += 1
                }
                
                if pipVideoPlayerManager.isReadyToPlay {
                    print("✅ Onboarding: Player is ready")
                    
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
        
        hasCompletedSetup = true
        completedOnboardingVersion = onboardingVersion
        shouldShowTroubleshootingBanner = true // Show troubleshooting banner on home screen
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
        
        isPresented = false
    }

    

    private func prepareDemoVideoPlayerIfNeeded() {
        guard demoVideoPlayer == nil else { return }
        guard let bundleURL = Bundle.main.url(forResource: "pip-guide-video", withExtension: "mp4") else {
            print("⚠️ Onboarding: Demo video not found in bundle")
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
                    .allowsHitTesting(false)
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
                    Text("Notifications video loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )
            .frame(minHeight: minHeight)
            .accessibilityHidden(true)
    }
    
    private func prepareNotificationsVideoPlayerIfNeeded() {
        guard notificationsVideoPlayer == nil else { 
            print("⚠️ Video player already exists, skipping preparation")
            return 
        }
        
        print("🔍 Onboarding: Preparing notifications video player...")
        
        // Try to find the video file
        guard let bundleURL = Bundle.main.url(forResource: "notifications", withExtension: "mov") else {
            print("❌ CRITICAL: notifications.mov not found in bundle!")
            print("📁 Bundle path: \(Bundle.main.bundlePath)")
            
            // List ALL video files in bundle for debugging
            if let files = try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath) {
                let videoFiles = files.filter { $0.hasSuffix(".mov") || $0.hasSuffix(".mp4") }
                print("📁 Video files in bundle: \(videoFiles)")
            }
            return
        }
        
        print("✅ Found notifications.mov at: \(bundleURL.path)")
        
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
        let statusObservation = item.observe(\.status, options: [.new, .initial]) { playerItem, _ in
            DispatchQueue.main.async {
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ notifications.mov player item READY TO PLAY (Allow Permissions step)")
                    print("   - Duration: \(playerItem.duration.seconds) seconds")
                    if let videoTrack = playerItem.asset.tracks(withMediaType: .video).first {
                        print("   - Natural size: \(videoTrack.naturalSize)")
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
        let errorObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { notification in
            print("❌ Playback failed to play to end time")
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("   Error: \(error.localizedDescription)")
            }
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
    
    private func saveOnboardingNotes() {
        guard !onboardingNotes.isEmpty else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(onboardingNotes)
            savedNotesData = data
            print("✅ Saved \(onboardingNotes.count) notes from onboarding")
        } catch {
            print("❌ Failed to save onboarding notes: \(error)")
        }
    }

    private func finalizeWallpaperSetup() {
        // Don't track onboarding wallpaper for paywall limit
        let request = WallpaperUpdateRequest(skipDeletionPrompt: true, trackForPaywall: false)
        
        // Small delay to ensure ContentView has loaded the notes from savedNotesData
        // The onChange handler needs time to trigger after saveOnboardingNotes()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: .requestWallpaperUpdate, object: request)
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
            currentPage = .allowPermissions
        }
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
                await launchShortcutAfterVerification()
            } else {
                await handleWallpaperVerificationFailure()
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
        homeScreenStatusMessage = "We couldn’t prepare the wallpaper files. Tap “Save Lock Screen” again."
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

        let shortcutName = "Set NoteWall Wallpaper"
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
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

    @available(iOS 16.0, *)
    private func handlePickedHomeScreenData(_ data: Data) {
        print("📸 Onboarding: Handling picked home screen data")
        print("   Data size: \(data.count) bytes")
        isSavingHomeScreenPhoto = true
        homeScreenStatusMessage = "Saving photo…"
        homeScreenStatusColor = .gray

        Task {
            do {
                guard let image = UIImage(data: data) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }
                print("   Image size: \(image.size)")
                try HomeScreenImageManager.saveHomeScreenImage(image)
                print("✅ Onboarding: Saved custom home screen photo")
                if let url = HomeScreenImageManager.homeScreenImageURL() {
                    print("   File path: \(url.path)")
                    print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
                }

                await MainActor.run {
                    homeScreenUsesCustomPhoto = true
                    homeScreenStatusMessage = nil
                    homeScreenStatusColor = .gray
                    homeScreenPresetSelectionRaw = ""
                    print("   homeScreenUsesCustomPhoto set to: true")
                    print("   homeScreenPresetSelectionRaw cleared")
                }
            } catch {
                print("❌ Onboarding: Failed to save home screen photo: \(error)")
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

private extension OnboardingView {
    enum ProgressIndicatorDisplayMode {
        case large
        case compact
    }

    func progressIndicatorItem(for page: OnboardingPage, displayMode: ProgressIndicatorDisplayMode) -> some View {
        let position = page.rawValue + 1
        let isCurrent = currentPage == page
        let isComplete = currentPage.rawValue > page.rawValue

        let circleFill: Color = {
            if isCurrent || isComplete {
                return Color.appAccent  // Cyan for current and completed
            } else {
                return Color(.systemGray5)  // Light gray for future steps
            }
        }()

        let circleTextColor: Color = isCurrent || isComplete ? .white : Color(.secondaryLabel)

        let circleSize: CGFloat
        let circleShadowOpacity: Double
        let circleStrokeOpacity: Double
        let circleStrokeWidth: CGFloat
        let circleFontSize: CGFloat
        let circleFontDesign: Font.Design
        let labelFont: Font
        let labelWeight: Font.Weight
        let vSpacing: CGFloat

        switch displayMode {
        case .large:
            circleSize = 38
            circleShadowOpacity = isCurrent ? 0.18 : 0.0
            circleStrokeOpacity = isCurrent ? 0.25 : 0.15
            circleStrokeWidth = isCurrent ? 1.5 : 1
            circleFontSize = 16
            circleFontDesign = .rounded
            labelFont = .footnote
            labelWeight = isCurrent ? .semibold : .regular
            vSpacing = 8
        case .compact:
            circleSize = 40
            circleShadowOpacity = 0.0
            circleStrokeOpacity = isCurrent ? 0.28 : 0.18
            circleStrokeWidth = 1
            circleFontSize = 18
            circleFontDesign = .rounded
            labelFont = .caption2
            labelWeight = isCurrent ? .semibold : .regular
            vSpacing = 4
        }

        return ZStack {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(position)")
        .accessibilityValue(isComplete ? "Complete" : (isCurrent ? "Current step" : "Not started"))
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

                Text("You’ve got everything set up. Keep these quick highlights in mind as you start using NoteWall.")
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
                        Text("Add notes, update the wallpaper, and let NoteWall keep your lock screen awesome.")
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

            Text("Create a Shortcuts automation so NoteWall runs on your schedule, like at the start of a workday or when a Focus mode activates.")
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

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let colors = buttonColors(isPressed: configuration.isPressed)

        return configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: colors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
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
        case .welcome:
            return "Welcome"
        case .installShortcut:
            return "Install Shortcut"
        case .addNotes:
            return "Add Notes"
        case .allowPermissions:
            return "Allow Permissions"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .overview:
            return "All Set"
        }
    }

    var progressTitle: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .installShortcut:
            return "Install Shortcut"
        case .addNotes:
            return "Add Notes"
        case .chooseWallpapers:
            return "Choose Wallpapers"
        case .allowPermissions:
            return "Allow Permissions"
        case .overview:
            return "All Set"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .welcome:
            return "Step 0"
        case .installShortcut:
            return "Step 1"
        case .addNotes:
            return "Step 2"
        case .chooseWallpapers:
            return "Step 4"
        case .allowPermissions:
            return "Step 5"
        case .overview:
            return "Step 6"
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
                .foregroundColor(.white)
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

// MARK: - Hidden PiP Player Layer View

/// A hidden UIView that contains the player layer for PiP support.
/// PiP requires the player layer to be in the view hierarchy, even if hidden.
private struct HiddenPiPPlayerLayerView: UIViewRepresentable {
    @ObservedObject var playerManager: PIPVideoPlayerManager
    
    func makeUIView(context: Context) -> PiPContainerView {
        let view = PiPContainerView()
        view.backgroundColor = .clear
        // PiP requires a reasonable frame size with proper aspect ratio
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        view.alpha = 1.0 // Must be visible for automatic PiP
        view.isHidden = false
        view.clipsToBounds = true
        
        print("🔧 HiddenPiPPlayerLayerView: Creating view with frame: \(view.frame)")
        
        // Store a reference to the manager
        view.playerManager = playerManager
        
        return view
    }
    
    func updateUIView(_ uiView: PiPContainerView, context: Context) {
        // When player is loaded and layer hasn't been added yet
        if playerManager.hasLoadedVideo && uiView.layer.sublayers?.isEmpty != false {
            print("🔧 HiddenPiPPlayerLayerView: Player loaded, adding layer")
            if let playerLayer = playerManager.createPlayerLayer() {
                playerLayer.frame = uiView.bounds
                uiView.layer.addSublayer(playerLayer)
                print("✅ HiddenPiPPlayerLayerView: Added player layer with frame: \(playerLayer.frame)")
                print("   - View in window: \(uiView.window != nil)")
                
                // Set up PiP controller after a delay to ensure view is in hierarchy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if uiView.window != nil {
                        print("✅ HiddenPiPPlayerLayerView: View is in window, setting up PiP controller")
                        self.playerManager.setupPictureInPictureControllerWithExistingLayer()
                    } else {
                        print("⚠️ HiddenPiPPlayerLayerView: View not in window, retrying...")
                        // Retry after another delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if uiView.window != nil {
                                print("✅ HiddenPiPPlayerLayerView: View now in window, setting up PiP controller")
                                self.playerManager.setupPictureInPictureControllerWithExistingLayer()
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Container view for PiP player layer
private class PiPContainerView: UIView {
    weak var playerManager: PIPVideoPlayerManager?
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if window != nil {
            print("✅ PiPContainerView: View added to window")
            // If we have a layer but no PiP controller, set it up
            if layer.sublayers?.isEmpty == false,
               let manager = playerManager,
               !manager.isPiPControllerReady {
                print("🔧 PiPContainerView: Setting up PiP controller now that view is in window")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    manager.setupPictureInPictureControllerWithExistingLayer()
                }
            }
        }
    }
}


