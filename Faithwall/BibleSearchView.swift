import SwiftUI

// MARK: - Bible Search View
/// Search Bible verses by keywords
struct BibleSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = BibleLanguageManager.shared
    
    @State private var searchText = ""
    @State private var searchResults: [BibleVerse] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var selectedVerse: BibleVerse?
    @State private var showAddConfirmation = false
    
    var onVerseSelected: ((BibleVerse) -> Void)?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search instructions
                if searchResults.isEmpty && searchText.isEmpty && !isSearching {
                    instructionsView
                } else if isSearching {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    noResultsView
                } else {
                    resultsListView
                }
            }
            .navigationTitle("Search Bible")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search for verses...")
            .onSubmit(of: .search) {
                performSearch()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAddConfirmation) {
                Button("Cancel", role: .cancel) {
                    selectedVerse = nil
                }
                Button("Add Anyway") {
                    if let verse = selectedVerse {
                        onVerseSelected?(verse)
                        
                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        dismiss()
                    }
                }
            } message: {
                if let verse = selectedVerse {
                    let charCount = verse.lockScreenFormat.count
                    if charCount > 130 {
                        Text("⚠️ This verse has \(charCount) characters. Lock screen widget supports max 130 characters and will be truncated.\n\n\"\(verse.previewText(maxLength: 100))\"")
                    } else {
                        Text("\(verse.reference)\n\n\"\(verse.previewText(maxLength: 150))\"")
                    }
                }
            }
        }
    }
    
    // MARK: - Instructions View
    
    private var instructionsView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Search the Bible")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Enter keywords to find verses")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                SearchTipRow(icon: "character.cursor.ibeam", text: "Type any word from a verse")
                SearchTipRow(icon: "quote.opening", text: "Use quotes for exact phrases")
                SearchTipRow(icon: "text.word.spacing", text: "Multiple words find all of them")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Searching...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Search Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                performSearch()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Results View
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.headline)
            
            Text("No verses found for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results List View
    
    private var resultsListView: some View {
        List {
            Section {
                Text("\(searchResults.count) result(s) found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(searchResults) { verse in
                Button(action: {
                    selectedVerse = verse
                    showAddConfirmation = true
                }) {
                    verseRow(verse)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(.plain)
    }
    
    private func verseRow(_ verse: BibleVerse) -> some View {
        let isTooLong = verse.lockScreenFormat.count > 130
        
        return VStack(alignment: .leading, spacing: 8) {
            // Reference
            Text(verse.reference)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(isTooLong ? .orange : .blue)
            
            // Verse text with search term highlighting
            Text(highlightedText(verse.text))
                .font(.body)
                .foregroundColor(.primary)
            
            // Warning if too long
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
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Functions
    
    private var alertTitle: String {
        if let verse = selectedVerse, verse.lockScreenFormat.count > 130 {
            return "⚠️ Verse Too Long"
        }
        return "Add to Lock Screen?"
    }
    
    private func highlightedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Simple highlighting - bold the search terms
        let searchTerms = searchText.split(separator: " ")
        for term in searchTerms {
            if let range = attributedString.range(of: String(term), options: .caseInsensitive) {
                attributedString[range].font = .body.bold()
                attributedString[range].foregroundColor = .blue
            }
        }
        
        return attributedString
    }
    
    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await searchVerses(query: query)
                
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
    
    private func searchVerses(query: String) async throws -> [BibleVerse] {
        let translation = languageManager.selectedTranslation
        
        // Check if translation is downloaded first
        guard BibleDatabaseService.shared.isDownloaded(translation) else {
            throw BibleDatabaseError.databaseNotFound(translation: translation.displayName)
        }
        
        // For SQLite-based translations, use existing search
        return try BibleDatabaseService.shared.searchVerses(
            query: query,
            translation: translation,
            limit: 100
        )
    }
}

// MARK: - Search Tip Row
private struct SearchTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
#Preview {
    BibleSearchView { verse in
        print("Selected: \(verse.reference)")
    }
}
