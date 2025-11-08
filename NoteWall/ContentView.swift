import SwiftUI

struct ContentView: View {
    @AppStorage("savedNotes") private var savedNotesData: Data = Data()
    @AppStorage("lastLockScreenIdentifier") private var lastLockScreenIdentifier: String = ""
    @AppStorage("skipDeletingOldWallpaper") private var skipDeletingOldWallpaper = false
    @State private var notes: [Note] = []
    @State private var newNoteText = ""
    @State private var isGeneratingWallpaper = false
    @State private var showDeletePermissionAlert = false
    @State private var pendingLockScreenImage: UIImage?
    @State private var showDeleteNoteAlert = false
    @State private var noteToDelete: IndexSet?
    @State private var showMaxNotesAlert = false
    @State private var isEditMode = false
    @State private var selectedNotes: Set<UUID> = []
    @State private var showDeleteSelectedAlert = false
    @FocusState private var isTextFieldFocused: Bool

    // Computed property to get indices of notes that will appear on wallpaper
    private var wallpaperNoteIndices: Set<UUID> {
        let activeNotes = notes.filter { !$0.isCompleted }
        let wallpaperCount = WallpaperRenderer.getWallpaperNoteCount(from: notes)
        return Set(activeNotes.prefix(wallpaperCount).map { $0.id })
    }

    private var activeNotesCount: Int {
        notes.filter { !$0.isCompleted }.count
    }

    private var wallpaperNoteCount: Int {
        WallpaperRenderer.getWallpaperNoteCount(from: notes)
    }

    private var isWallpaperAtCapacity: Bool {
        wallpaperNoteCount < activeNotesCount
    }

    private var sortedNotes: [Note] {
        notes
    }

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
                        List {
                            ForEach(sortedNotes) { note in
                                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                                    NoteRowView(
                                        note: $notes[index],
                                        isOnWallpaper: false,
                                        isEditMode: isEditMode,
                                        isSelected: selectedNotes.contains(note.id),
                                        toggleSelection: {
                                            if selectedNotes.contains(note.id) {
                                                selectedNotes.remove(note.id)
                                            } else {
                                                selectedNotes.insert(note.id)
                                            }
                                        },
                                        onDelete: {
                                            if let actualIndex = notes.firstIndex(where: { $0.id == note.id }) {
                                                noteToDelete = IndexSet(integer: actualIndex)
                                                showDeleteNoteAlert = true
                                            }
                                        },
                                        onCommit: {
                                            saveNotes()
                                            hideKeyboard()
                                        }
                                    )
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.visible)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if !isEditMode {
                                            Button(role: .destructive) {
                                                if let actualIndex = notes.firstIndex(where: { $0.id == note.id }) {
                                                    noteToDelete = IndexSet(integer: actualIndex)
                                                    showDeleteNoteAlert = true
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        if !isEditMode {
                                            Button {
                                                if let actualIndex = notes.firstIndex(where: { $0.id == note.id }) {
                                                    notes[actualIndex].isCompleted.toggle()
                                                    saveNotes()
                                                }
                                            } label: {
                                                Label(note.isCompleted ? "Unmark" : "Complete", systemImage: note.isCompleted ? "arrow.uturn.backward" : "checkmark")
                                            }
                                            .tint(.green)
                                        }
                                    }
                                }
                            }
                            .onMove { source, destination in
                                moveNotes(from: source, to: destination)
                            }

                            // Edit mode toolbar as last row
                            if isEditMode {
                                Section {
                                    HStack {
                                        Button(action: {
                                            if selectedNotes.count == sortedNotes.count {
                                                selectedNotes.removeAll()
                                            } else {
                                                selectedNotes = Set(sortedNotes.map { $0.id })
                                            }
                                        }) {
                                            Text(selectedNotes.count == sortedNotes.count ? "Deselect All" : "Select All")
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)

                                        Spacer()

                                        Button(action: {
                                            showDeleteSelectedAlert = true
                                        }) {
                                            Text("Delete (\(selectedNotes.count))")
                                                .foregroundColor(selectedNotes.isEmpty ? .gray : .red)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(selectedNotes.isEmpty)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .listRowInsets(EdgeInsets())
                                }
                                .listSectionSeparator(.hidden)

                                // Add spacing section below toolbar
                                Section {
                                    Color.clear
                                        .frame(height: 20)
                                        .listRowInsets(EdgeInsets())
                                }
                                .listSectionSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .animation(.easeInOut(duration: 0.3), value: sortedNotes.map { $0.id })
                        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
                    }

                    // Add Note Section
                    if !isEditMode {
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
                    }

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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !notes.isEmpty {
                        Button {
                            withAnimation {
                                isEditMode.toggle()
                                selectedNotes.removeAll()
                            }
                            if !isEditMode {
                                hideKeyboard()
                            }
                        } label: {
                            Image(systemName: isEditMode ? "xmark.circle" : "ellipsis.circle")
                                .imageScale(.large)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .alert("Delete Previous Wallpaper?", isPresented: $showDeletePermissionAlert) {
                Button("Skip", role: .cancel) {
                    if let lockScreen = pendingLockScreenImage {
                        saveNewLockScreenWallpaper(lockScreen)
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
            .alert("Delete Selected Notes?", isPresented: $showDeleteSelectedAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSelectedNotes()
                }
            } message: {
                Text("Are you sure you want to delete the selected notes? This action cannot be undone.")
            }
            .alert("Wallpaper Full", isPresented: $showMaxNotesAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your wallpaper has reached its maximum capacity. Complete or delete existing notes to add new ones.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
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

        // Check if the new note would fit on the wallpaper
        let newNote = Note(text: trimmedText)
        let testNotes = notes + [newNote]

        // Check if this new note would actually appear on the wallpaper
        let activeNotes = testNotes.filter { !$0.isCompleted }
        let wouldFitCount = WallpaperRenderer.getWallpaperNoteCount(from: testNotes)

        // If the new note wouldn't appear on wallpaper, show alert
        if wouldFitCount < activeNotes.count {
            showMaxNotesAlert = true
            return
        }

        notes.append(newNote)
        newNoteText = ""
        saveNotes()
        hideKeyboard()
    }

    private func deleteNotes(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        saveNotes()
        handleNotesChangedAfterDeletion()
    }

    private func moveNotes(from source: IndexSet, to destination: Int) {
        // Create a mapping from sorted notes to actual notes array
        var mutableSortedNotes = sortedNotes
        mutableSortedNotes.move(fromOffsets: source, toOffset: destination)

        // Update the actual notes array to match the new order
        notes = mutableSortedNotes
        saveNotes()
    }

    private func deleteNotesFromList(at indexSet: IndexSet) {
        // Map sorted indices back to actual notes array
        let notesToDelete = indexSet.compactMap { sortedNotes[$0] }
        notes.removeAll { note in notesToDelete.contains(where: { $0.id == note.id }) }
        saveNotes()
        handleNotesChangedAfterDeletion()
    }

    private func deleteSelectedNotes() {
        notes.removeAll { selectedNotes.contains($0.id) }
        selectedNotes.removeAll()
        saveNotes()
        handleNotesChangedAfterDeletion()
        showDeleteSelectedAlert = false
    }

    private func updateWallpaper() {
        isGeneratingWallpaper = true

        // Generate the wallpaper
        let lockScreenImage = WallpaperRenderer.generateWallpaper(from: notes)
        pendingLockScreenImage = lockScreenImage

        // Delete previous wallpaper if it exists and user hasn't opted to skip
        if !lastLockScreenIdentifier.isEmpty && !skipDeletingOldWallpaper {
            // Show explanation alert every time
            showDeletePermissionAlert = true
        } else {
            // No previous wallpaper or user skipped deletion, just save the new one
            saveNewLockScreenWallpaper(lockScreenImage)
        }
    }

    private func proceedWithDeletionAndSave() {
        guard let lockScreen = pendingLockScreenImage else { return }

        // Delete previous wallpaper before saving the new one
        if !lastLockScreenIdentifier.isEmpty {
            PhotoSaver.deleteAsset(withIdentifier: lastLockScreenIdentifier) { _ in
                DispatchQueue.main.async {
                    self.saveNewLockScreenWallpaper(lockScreen)
                }
            }
        } else {
            saveNewLockScreenWallpaper(lockScreen)
        }
    }

    private func saveNewLockScreenWallpaper(_ lockScreen: UIImage) {
        PhotoSaver.saveImage(lockScreen) { success, identifier in
            DispatchQueue.main.async {
                self.isGeneratingWallpaper = false
                self.pendingLockScreenImage = nil

                if success, let id = identifier {
                    self.lastLockScreenIdentifier = id
                    self.openShortcut()
                }
            }
        }
    }

    private func handleNotesChangedAfterDeletion() {
        selectedNotes.removeAll()
        if isEditMode {
            withAnimation {
                isEditMode = false
            }
        }

        if notes.isEmpty {
            setBlankWallpaper()
        }
    }

    private func setBlankWallpaper() {
        let lockScreenImage = WallpaperRenderer.generateBlankWallpaper()
        saveNewLockScreenWallpaper(lockScreenImage)
    }

    private func openShortcut() {
        let shortcutName = "Set NoteWall Wallpaper"
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "shortcuts://run-shortcut?name=\(encodedName)"

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

struct NoteRowView: View {
    @Binding var note: Note
    let isOnWallpaper: Bool
    let isEditMode: Bool
    let isSelected: Bool
    let toggleSelection: () -> Void
    let onDelete: () -> Void
    let onCommit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if isEditMode {
                Button(action: toggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                .buttonStyle(.plain)
            }

            TextField("Note", text: $note.text)
                .submitLabel(.done)
                .textFieldStyle(.plain)
                .foregroundColor(note.isCompleted ? .gray : .primary)
                .onSubmit(onCommit)
                .disabled(isEditMode)
                .overlay(
                    note.isCompleted ?
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray)
                    : nil
                )

            if isOnWallpaper && !isEditMode {
                Image(systemName: "photo.badge.checkmark.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }

            if !isEditMode {
                Spacer(minLength: 0)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditMode {
                toggleSelection()
            }
        }
    }
}

#Preview {
    ContentView()
}
