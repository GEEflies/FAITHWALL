import SwiftUI

struct ContentView: View {
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("lastWallpaperIdentifier") private var lastWallpaperIdentifier: String = ""
    @AppStorage("skipDeletingOldWallpaper") private var skipDeletingOldWallpaper = false
    @State private var notes: [Note] = []
    @State private var newNoteText = ""
    @State private var isGeneratingWallpaper = false
    @State private var showDeletePermissionAlert = false
    @State private var pendingWallpaperImage: UIImage?
    @State private var showDeleteNoteAlert = false
    @State private var noteToDelete: IndexSet?
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Notes List
                    if notes.isEmpty {
                        VStack {
                            Spacer()
                            Text("No notes yet")
                                .foregroundColor(.gray)
                                .font(.title3)
                            Text("Add a note below to get started")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            hideKeyboard()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach($notes) { $note in
                                    HStack {
                                        TextField("Note", text: $note.text)
                                            .submitLabel(.done)
                                            .textFieldStyle(.plain)
                                            .onSubmit {
                                                saveNotes()
                                                hideKeyboard()
                                            }

                                        Button(action: {
                                            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                                                noteToDelete = IndexSet(integer: index)
                                                showDeleteNoteAlert = true
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .font(.body)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .contentShape(Rectangle())
                                    .onTapGesture { }

                                    Divider()
                                }

                                // Empty space at bottom to allow tapping to dismiss keyboard
                                Color.clear
                                    .frame(height: 100)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        hideKeyboard()
                                    }
                            }
                        }
                        .background(
                            Color(.systemBackground)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    hideKeyboard()
                                }
                        )
                        .simultaneousGesture(
                            DragGesture().onChanged { _ in
                                hideKeyboard()
                            }
                        )
                    }

                    // Add Note Section
                    HStack(spacing: 12) {
                        TextField("Add a note...", text: $newNoteText)
                            .focused($isTextFieldFocused)
                            .submitLabel(.done)
                            .font(.system(size: 16))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .onSubmit {
                                addNote()
                            }

                        Button(action: {
                            addNote()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                        }
                        .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Color(.systemBackground)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -1)
                    )

                    // Update Wallpaper Button
                    Button(action: {
                        hideKeyboard()
                        updateWallpaper()
                    }) {
                        HStack {
                            if isGeneratingWallpaper {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isGeneratingWallpaper ? "Generating..." : "Update Wallpaper")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(notes.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .disabled(notes.isEmpty || isGeneratingWallpaper)
                }
            }
            .navigationTitle("NoteWall")
            .navigationBarTitleDisplayMode(.large)
            .alert("Delete Previous Wallpaper?", isPresented: $showDeletePermissionAlert) {
                Button("Skip", role: .cancel) {
                    if let image = pendingWallpaperImage {
                        saveNewWallpaper(image: image)
                    }
                }
                Button("Continue", role: .destructive) {
                    proceedWithDeletionAndSave()
                }
            } message: {
                Text("To avoid filling your Photos library, NoteWall can delete the previous wallpaper. If you continue, iOS will ask for permission to delete the photo.")
            }
            .alert("Delete Note?", isPresented: $showDeleteNoteAlert) {
                Button("Cancel", role: .cancel) {
                    noteToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let offsets = noteToDelete {
                        deleteNotes(at: offsets)
                    }
                    noteToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this note? This action cannot be undone.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            loadNotes()
        }
        .onChange(of: savedNotesData) { _ in
            loadNotes()
        }
    }

    private func hideKeyboard() {
        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func loadNotes() {
        guard !savedNotesData.isEmpty else {
            notes = []
            return
        }

        do {
            notes = try JSONDecoder().decode([Note].self, from: savedNotesData)
        } catch {
            print("Failed to decode notes: \(error)")
            notes = []
        }
    }

    private func saveNotes() {
        do {
            savedNotesData = try JSONEncoder().encode(notes)
        } catch {
            print("Failed to encode notes: \(error)")
        }
    }

    private func addNote() {
        let trimmedText = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let newNote = Note(text: trimmedText)
        notes.append(newNote)
        newNoteText = ""
        saveNotes()
        hideKeyboard()
    }

    private func deleteNotes(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        saveNotes()
    }

    private func updateWallpaper() {
        isGeneratingWallpaper = true
        
        // Generate wallpaper image first
        let image = WallpaperRenderer.generateWallpaper(from: notes)
        pendingWallpaperImage = image

        // Delete previous wallpaper if it exists and user hasn't opted to skip
        if !lastWallpaperIdentifier.isEmpty && !skipDeletingOldWallpaper {
            // Show explanation alert every time
            showDeletePermissionAlert = true
        } else {
            // No previous wallpaper or user skipped deletion, just save the new one
            saveNewWallpaper(image: image)
        }
    }
    
    private func proceedWithDeletionAndSave() {
        guard let image = pendingWallpaperImage else { return }
        
        // Always delete the previous wallpaper before saving the new one
        // The system popup will only show once (iOS behavior), but deletion happens every time
        PhotoSaver.deleteAsset(withIdentifier: lastWallpaperIdentifier) { success in
            // Continue with saving new wallpaper regardless of deletion result
            // Even if deletion fails (e.g., photo was already deleted), we still save the new one
            self.saveNewWallpaper(image: image)
        }
    }
    
    private func saveNewWallpaper(image: UIImage) {
        // Save to Photos
        PhotoSaver.saveImage(image) { success, identifier in
            DispatchQueue.main.async {
                self.isGeneratingWallpaper = false

                if success {
                    // Store the new wallpaper identifier
                    if let identifier = identifier {
                        self.lastWallpaperIdentifier = identifier
                    }
                    
                    // Open Shortcuts app to run the shortcut
                    self.openShortcut()
                }
            }
        }
    }

    private func openShortcut() {
        let shortcutName = "Set NoteWall Wallpaper"
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "shortcuts://run-shortcut?name=\(encodedName)"

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    ContentView()
}
