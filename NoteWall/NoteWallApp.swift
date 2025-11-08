import SwiftUI

@main
struct NoteWallApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0
    @State private var showOnboarding = false
    
    private let onboardingVersion = 3

    init() {
        // Check onboarding status on init
        let shouldShow = !hasCompletedSetup || completedOnboardingVersion < onboardingVersion
        _showOnboarding = State(initialValue: shouldShow)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(
                        isPresented: $showOnboarding,
                        onboardingVersion: onboardingVersion
                    )
                }
                .onAppear {
                    // Show onboarding if not completed or needs to be refreshed for this version
                    showOnboarding = !hasCompletedSetup || completedOnboardingVersion < onboardingVersion
                }
                .onOpenURL { url in
                    // Handle URL scheme when app is opened via notewall://
                    // This allows the shortcut to redirect back to the app
                    print("Opened via URL: \(url)")
                }
        }
    }
}
