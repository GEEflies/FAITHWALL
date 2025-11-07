import SwiftUI

@main
struct NoteWallApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var showOnboarding = false

    init() {
        // Check onboarding status on init
        _showOnboarding = State(initialValue: !hasCompletedSetup)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                }
                .onAppear {
                    // Show onboarding if not completed
                    showOnboarding = !hasCompletedSetup
                }
                .onOpenURL { url in
                    // Handle URL scheme when app is opened via notewall://
                    // This allows the shortcut to redirect back to the app
                    print("Opened via URL: \(url)")
                }
        }
    }
}
