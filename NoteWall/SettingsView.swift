import SwiftUI

struct SettingsView: View {
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("skipDeletingOldWallpaper") private var skipDeletingOldWallpaper = false
    @State private var showDeleteAlert = false
    var selectedTab: Binding<Int>?

    private let shortcutURL = "https://www.icloud.com/shortcuts/9ad9e11424104d2eb14e922abd3b9620"
    private let appVersion = "1.0"
    
    init(selectedTab: Binding<Int>? = nil) {
        self.selectedTab = selectedTab
    }

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
}

#Preview {
    SettingsView()
}
