import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false

    private let shortcutURL = "https://www.icloud.com/shortcuts/9ad9e11424104d2eb14e922abd3b9620"

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text("Install Shortcut")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Description
            VStack(spacing: 16) {
                Text("The shortcut is needed to set wallpapers automatically. Tap the button below to install it from the Shortcuts app.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To set wallpaper as Lock Screen only:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("1. After installing, tap the shortcut to edit it\n2. Find the 'Set Wallpaper' action\n3. Tap on it and change 'Where' to 'Lock Screen' only\n4. This ensures it only sets the lock screen wallpaper")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Automatic Return:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("The shortcut is already configured to automatically return you to NoteWall after setting the wallpaper. No additional setup needed!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Install Button
            Button(action: {
                installShortcut()
            }) {
                Text("Install Shortcut")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .interactiveDismissDisabled() // Prevent dismissal by swipe
    }

    private func installShortcut() {
        guard let url = URL(string: shortcutURL) else { return }

        // Open Shortcuts app with the iCloud link
        UIApplication.shared.open(url) { success in
            if success {
                // Mark onboarding as completed and dismiss
                // User will return to app after installing shortcut
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    hasCompletedSetup = true
                    isPresented = false
                }
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
