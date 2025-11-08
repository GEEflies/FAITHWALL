import SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("skipDeletingOldWallpaper") private var skipDeletingOldWallpaper = false
    @State private var showDeleteAlert = false
    var selectedTab: Binding<Int>?

    private let shortcutURL = "https://www.icloud.com/shortcuts/62d89adfc4074e22acb0b58b11850ea4"
    private let appVersion = "1.0"
    
    init(selectedTab: Binding<Int>? = nil) {
        self.selectedTab = selectedTab
    }

    @State private var isSavingHomeScreenPhoto = false
    @State private var homeScreenStatusMessage: String?
    @State private var homeScreenStatusColor: Color = .gray
    @State private var homeScreenImageAvailable = HomeScreenImageManager.homeScreenImageExists()

    var body: some View {
        NavigationView {
            List {
                // App Info Section
                Section(header: Text("App Info")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.gray)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("About App")
                            .fontWeight(.medium)
                        Text("NoteWall converts your text notes into black wallpaper images with white centered text. Create notes, generate wallpapers, and set them via Shortcuts.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }

                // Wallpaper Settings Section
                Section(header: Text("Wallpaper Settings")) {
                    Toggle(isOn: $skipDeletingOldWallpaper) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Skip Deleting Old Wallpapers")
                            Text("When enabled, old wallpapers won't be deleted automatically. This avoids system permission popups.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                if #available(iOS 16.0, *) {
                    Section(header: Text("Home Screen Photo")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose Home Screen Image")
                                .fontWeight(.medium)
                            Text("Select any photo to reuse as your home screen background. The Shortcuts automation will load this saved photo each time you update the lock screen.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)

                        HomeScreenPhotoPickerView(
                            isSavingHomeScreenPhoto: $isSavingHomeScreenPhoto,
                            homeScreenStatusMessage: $homeScreenStatusMessage,
                            homeScreenStatusColor: $homeScreenStatusColor,
                            homeScreenImageAvailable: $homeScreenImageAvailable,
                            handlePickedHomeScreenPhoto: handlePickedHomeScreenPhoto
                        )

                        Text("Picking a new photo automatically replaces the previous one.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section(header: Text("Home Screen Photo")) {
                        Text("Save a home screen image requires iOS 16 or newer.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.vertical, 4)
                    }
                }

                // Actions Section
                Section(header: Text("Actions")) {
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        HStack {
                            Text("Delete All Notes")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }

                    Button(action: reinstallShortcut) {
                        HStack {
                            Text("Reinstall Shortcut")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Support Section
                Section(header: Text("Support")) {
                    HStack {
                        Text("Contact")
                        Spacer()
                        Text("NoteWall Support")
                            .foregroundColor(.gray)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Delete All Notes?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllNotes()
                }
            } message: {
                Text("This action cannot be undone. All your notes will be permanently deleted.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func deleteAllNotes() {
        savedNotesData = Data()
        // Switch back to Home tab after deleting notes
        if let selectedTab = selectedTab {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                selectedTab.wrappedValue = 0
            }
        }
    }

    private func reinstallShortcut() {
        guard let url = URL(string: shortcutURL) else { return }
        UIApplication.shared.open(url)
    }

    @available(iOS 16.0, *)
    fileprivate func handlePickedHomeScreenPhoto(_ item: PhotosPickerItem?) {
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
    SettingsView()
}
