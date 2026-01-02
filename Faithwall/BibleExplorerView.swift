import SwiftUI

// MARK: - Bible Explorer View
/// Main view for exploring the Bible: Books → Chapters → Verses
struct BibleExplorerView: View {
    @StateObject private var languageManager = BibleLanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var books: [BibleBook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showLanguagePicker = false
    
    /// Callback when a verse is selected (to add to lock screen)
    var onVerseSelected: ((BibleVerse) -> Void)?
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    bookListView
                }
            }
            .navigationTitle("Explore Bible")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    languageButton
                }
            }
            .searchable(text: $searchText, prompt: "Search books...")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            loadBooks()
        }
        .onChange(of: languageManager.selectedTranslation) { _ in
            loadBooks()
        }
        .sheet(isPresented: $showLanguagePicker) {
            NavigationView {
                BibleLanguageSelectionView(
                    initialSelection: languageManager.selectedTranslation,
                    showContinueButton: false,
                    isOnboarding: false
                ) { translation in
                    // Translation selected - it's already set in languageManager
                    // Don't dismiss yet - let user click Done
                }
                .navigationTitle("Change Language")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showLanguagePicker = false
                            // Force reload after dismissing
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                loadBooks()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Language Button
    
    private var languageButton: some View {
        Button(action: {
            showLanguagePicker = true
        }) {
            HStack(spacing: 4) {
                Text(languageManager.selectedTranslation.flagEmoji)
                Text(languageManager.selectedTranslation.shortName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Bible...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Unable to Load Bible")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                // Download button
                Button(action: {
                    downloadSelectedTranslation()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download \(languageManager.selectedTranslation.shortName) Bible")
                    }
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Reset button (for troubleshooting)
                Button(action: {
                    resetAndRedownload()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset & Redownload")
                    }
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Change language button
                Button(action: {
                    showLanguagePicker = true
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Change Version")
                    }
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Book List View
    
    private var bookListView: some View {
        List {
            // Old Testament Section
            Section(header: Text("Old Testament")) {
                ForEach(filteredBooks.filter { $0.testament == .old }) { book in
                    NavigationLink(destination: ChapterPickerView(book: book, onVerseSelected: onVerseSelected)) {
                        bookRow(book)
                    }
                }
            }
            
            // New Testament Section
            Section(header: Text("New Testament")) {
                ForEach(filteredBooks.filter { $0.testament == .new }) { book in
                    NavigationLink(destination: ChapterPickerView(book: book, onVerseSelected: onVerseSelected)) {
                        bookRow(book)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func bookRow(_ book: BibleBook) -> some View {
        HStack {
            Text(book.name)
                .font(.body)
            
            Spacer()
            
            Text("\(book.id)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(6)
        }
    }
    
    private var filteredBooks: [BibleBook] {
        if searchText.isEmpty {
            return books
        }
        return books.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Actions
    
    private func loadBooks() {
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        print("📖 Loading books for: \(languageManager.selectedTranslation.rawValue)")
        print("📖 Is ready: \(languageManager.isSelectedTranslationReady)")
        print("📖 Database path: \(BibleDatabaseService.shared.databasePath(for: languageManager.selectedTranslation).path)")
        #endif
        
        // Check if translation is downloaded - if not, auto-download
        guard languageManager.isSelectedTranslationReady else {
            #if DEBUG
            print("📖 Translation not ready, attempting download...")
            #endif
            downloadSelectedTranslation()
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let loadedBooks = try BibleDatabaseService.shared.getBooks(for: languageManager.selectedTranslation)
                
                #if DEBUG
                print("📖 Loaded \(loadedBooks.count) books")
                #endif
                
                DispatchQueue.main.async {
                    self.books = loadedBooks
                    self.isLoading = false
                }
            } catch {
                #if DEBUG
                print("📖 Error loading books: \(error)")
                #endif
                
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func downloadSelectedTranslation() {
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        print("📥 Starting download for: \(languageManager.selectedTranslation.rawValue)")
        print("📥 Download URL: \(languageManager.selectedTranslation.downloadURL?.absoluteString ?? "nil")")
        #endif
        
        languageManager.ensureSelectedTranslationDownloaded { result in
            switch result {
            case .success:
                #if DEBUG
                print("📥 Download completed successfully!")
                #endif
                loadBooks()
            case .failure(let error):
                #if DEBUG
                print("📥 Download failed: \(error)")
                #endif
                isLoading = false
                errorMessage = "Download failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func resetAndRedownload() {
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        print("🔄 Resetting and redownloading...")
        #endif
        
        // Force redownload the selected translation
        languageManager.forceRedownloadSelected { result in
            switch result {
            case .success:
                #if DEBUG
                print("🔄 Reset and redownload successful!")
                #endif
                loadBooks()
            case .failure(let error):
                #if DEBUG
                print("🔄 Reset failed: \(error)")
                #endif
                isLoading = false
                errorMessage = "Reset failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Chapter Picker View
/// Shows chapters for a selected book
struct ChapterPickerView: View {
    let book: BibleBook
    var onVerseSelected: ((BibleVerse) -> Void)?
    
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var chapterCount = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let columns = [
        GridItem(.adaptive(minimum: 60), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(1...chapterCount, id: \.self) { chapter in
                            NavigationLink(destination: VerseListView(
                                book: book,
                                chapter: chapter,
                                onVerseSelected: onVerseSelected
                            )) {
                                chapterCell(chapter)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadChapterCount()
        }
        .onChange(of: languageManager.selectedTranslation) { _ in
            loadChapterCount()
        }
    }
    
    private func chapterCell(_ chapter: Int) -> some View {
        Text("\(chapter)")
            .font(.title2)
            .fontWeight(.medium)
            .frame(width: 60, height: 60)
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(12)
    }
    
    private func loadChapterCount() {
        isLoading = true
        
        // Check if translation is downloaded
        guard languageManager.isSelectedTranslationReady else {
            // If not ready, wait for download (handled by manager/UI elsewhere)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try BibleDatabaseService.shared.getChapterCount(
                    bookId: book.id,
                    translation: languageManager.selectedTranslation
                )
                
                DispatchQueue.main.async {
                    self.chapterCount = count
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Verse List View
/// Shows verses for a selected chapter
struct VerseListView: View {
    let book: BibleBook
    let chapter: Int
    var onVerseSelected: ((BibleVerse) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var verses: [BibleVerse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedVerse: BibleVerse?
    @State private var showAddConfirmation = false
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.secondary)
            } else {
                verseList
            }
        }
        .navigationTitle("\(book.name) \(chapter)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadVerses()
        }
        .onChange(of: languageManager.selectedTranslation) { _ in
            loadVerses()
        }
        // Alert removed for direct selection
    }
    
    private var alertTitle: String {
        if let verse = selectedVerse, verse.lockScreenFormat.count > 130 {
            return "⚠️ Verse Too Long"
        }
        return "Add to Lock Screen?"
    }
    
    private var verseList: some View {
        List {
            ForEach(verses) { verse in
                Button(action: {
                    // Directly select the verse without confirmation
                    onVerseSelected?(verse)
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // No need to dismiss manually if the parent handles navigation
                    // but we'll keep it just in case
                    dismiss()
                }) {
                    verseRow(verse)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(.plain)
        .padding(.horizontal, 24)
    }
    
    private func verseRow(_ verse: BibleVerse) -> some View {
        let isTooLong = verse.lockScreenFormat.count > 130
        
        return HStack(alignment: .top, spacing: 12) {
            // Verse number
            Text("\(verse.verse)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isTooLong ? .orange : .blue)
                .frame(width: 28, alignment: .trailing)
            
            // Verse text
            VStack(alignment: .leading, spacing: 4) {
                Text(verse.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                if isTooLong {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Too long for widget (\(verse.lockScreenFormat.count)/130)")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func loadVerses() {
        isLoading = true
        
        // Check if translation is downloaded
        guard languageManager.isSelectedTranslationReady else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let loadedVerses = try BibleDatabaseService.shared.getVerses(
                    bookId: book.id,
                    chapter: chapter,
                    translation: languageManager.selectedTranslation
                )
                
                DispatchQueue.main.async {
                    self.verses = loadedVerses
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    BibleExplorerView { verse in
        print("Selected: \(verse.reference)")
    }
}
