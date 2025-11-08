import SwiftUI
import PhotosUI
import UIKit

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onboardingVersion: Int
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0

    @State private var didOpenShortcut = false
    @State private var isSavingHomeScreenPhoto = false
    @State private var homeScreenStatusMessage: String?
    @State private var homeScreenStatusColor: Color = .gray
    @State private var homeScreenImageAvailable = HomeScreenImageManager.homeScreenImageExists()

    private let shortcutURL = "https://www.icloud.com/shortcuts/a2ba5a473ded481684065ae0c38f8b5a"

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                navigationStackOnboarding
            } else {
                navigationViewOnboarding
            }
        }
        .interactiveDismissDisabled()
        .safeAreaInset(edge: .bottom) {
            Button(action: completeOnboarding) {
                Text("Start Using NoteWall")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(didOpenShortcut ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal)
            }
            .disabled(!didOpenShortcut)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var navigationViewOnboarding: some View {
        NavigationView {
            ScrollView {
                onboardingSteps(includePhotoPicker: false)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @available(iOS 16.0, *)
    private var navigationStackOnboarding: some View {
        NavigationStack {
            ScrollView {
                onboardingSteps(includePhotoPicker: true)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func onboardingSteps(includePhotoPicker: Bool) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to NoteWall")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Follow these quick steps to turn your notes into a lock-screen wallpaper and keep your favorite photo on the home screen.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            setupStepCard(
                title: "Step 1 • Install the Shortcut",
                description: "The shortcut updates your wallpapers automatically each time you tap “Update Wallpaper” in the app."
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Tap the button below to download the NoteWall shortcut.")
                    Text("• When Shortcuts opens, add it to your library, then return here.")
                    Text("• The automation will pick the newest photo from NoteWall as your Lock Screen.")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } footer: {
                VStack(spacing: 12) {
                    Button(action: installShortcut) {
                        HStack {
                            Spacer()
                            Text(didOpenShortcut ? "Shortcut Installed?" : "Install Shortcut")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button("I already have it") {
                        didOpenShortcut = true
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                }
            }

            if includePhotoPicker {
                setupStepCard(
                    title: "Step 2 • Choose Your Home Screen Photo",
                    description: "We’ll reuse this photo every time the shortcut runs, so your home screen stays consistent."
                ) {
                    if #available(iOS 16.0, *) {
                        VStack(alignment: .leading, spacing: 12) {
                            HomeScreenPhotoPickerView(
                                isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                                homeScreenStatusMessage: $homeScreenStatusMessage,
                                homeScreenStatusColor: $homeScreenStatusColor,
                                homeScreenImageAvailable: $homeScreenImageAvailable,
                                handlePickedHomeScreenPhoto: handlePickedHomeScreenPhoto
                            )

                            Text("You can change this photo anytime from Settings → Home Screen Photo.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Choosing a new image automatically replaces the one saved before.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                setupStepCard(
                    title: "Step 2 • Choose Your Home Screen Photo",
                    description: "This requires iOS 16 or newer."
                ) {
                    Text("Update to iOS 16+ to pick a photo directly. For now, the shortcut will reuse your current home screen wallpaper.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How NoteWall Works")
                        .font(.headline)

                    Text("• Add notes in the Home tab. The newest active notes are placed on the lock-screen wallpaper.\n• Tap “Update Wallpaper” to generate a fresh lock-screen image.\n• The shortcut saves that image to Photos and sets it as your lock screen. Your home screen keeps the photo you chose above.\n• Demo it now: add a test note, press “Update Wallpaper”, then run the shortcut.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Tip: Use Shortcuts automations to run NoteWall’s shortcut automatically on a schedule or when a Focus mode activates.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    private func setupStepCard<Content: View, Footer: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            content()
            footer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    private func installShortcut() {
        guard let url = URL(string: shortcutURL) else { return }
        UIApplication.shared.open(url) { success in
            if success {
                didOpenShortcut = true
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedSetup = true
        completedOnboardingVersion = onboardingVersion
        isPresented = false
    }

    @available(iOS 16.0, *)
    private func handlePickedHomeScreenPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        isSavingHomeScreenPhoto = true
        homeScreenStatusMessage = "Saving photo…"
        homeScreenStatusColor = .gray

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }

                try HomeScreenImageManager.saveHomeScreenImage(image)

                await MainActor.run {
                    homeScreenImageAvailable = true
                    homeScreenStatusMessage = "Saved to \(HomeScreenImageManager.displayFolderPath)."
                    homeScreenStatusColor = .green
                }
            } catch {
                await MainActor.run {
                    homeScreenStatusMessage = error.localizedDescription
                    homeScreenStatusColor = .red
                }
            }

            await MainActor.run {
                isSavingHomeScreenPhoto = false
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true), onboardingVersion: 2)
}
