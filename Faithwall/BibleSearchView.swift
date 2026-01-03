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
            .onChange(of: searchText) { newValue in
                if newValue.isEmpty {
                    searchResults = []
                }
            }
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
            .sheet(item: $selectedVerse) { verse in
                VerseReviewView(verse: verse) { editedText in
                    var modifiedVerse = verse
                    modifiedVerse.text = editedText
                    onVerseSelected?(modifiedVerse)
                    dismiss()
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
            .padding(.horizontal, DS.Spacing.xxl)
            
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
                .padding(.horizontal, DS.Spacing.xl)
            
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
                .padding(.horizontal, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results List View
    
    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section(header: resultsHeader) {
                    ForEach(searchResults) { verse in
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            selectedVerse = verse
                        }) {
                            verseRow(verse)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if verse.id != searchResults.last?.id {
                            Divider()
                                .padding(.horizontal, DS.Spacing.xxl)
                        }
                    }
                }
            }
        }
    }
    
    private var resultsHeader: some View {
        HStack {
            Text("\(searchResults.count) result(s) found")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).opacity(0.95))
    }
    
    private func verseRow(_ verse: BibleVerse) -> some View {
        let totalCount = verse.text.count + verse.reference.count + 1
        let isTooLong = totalCount > 133
        
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                // Reference & Metadata
                HStack {
                    Text(verse.reference)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(isTooLong ? .orange : .appAccent)
                    
                    Spacer()
                    
                    if isTooLong {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("\(totalCount)/133")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                // Verse text with search term highlighting
                Text(highlightedText(verse.text))
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineSpacing(4)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, DS.Spacing.xxl)
        .contentShape(Rectangle())
    }
    
    // MARK: - Helper Functions
    
    private func highlightedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Set base font to match the view
        attributedString.font = .system(size: 16, weight: .regular, design: .rounded)
        attributedString.foregroundColor = DS.Colors.textPrimary
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return attributedString }
        
        // Define highlight style
        // Brand-aligned highlighting: Soft accent background with bold text
        let highlightColor = DS.Colors.accent.opacity(0.2)
        let highlightFont = Font.system(size: 16, weight: .bold, design: .rounded)
        
        // 1. Highlight the full phrase first (if it's more than one word)
        if query.contains(" ") {
            var searchRange = attributedString.startIndex..<attributedString.endIndex
            while let range = attributedString[searchRange].range(of: query, options: .caseInsensitive) {
                attributedString[range].backgroundColor = highlightColor
                attributedString[range].font = highlightFont
                attributedString[range].foregroundColor = .primary
                searchRange = range.upperBound..<attributedString.endIndex
            }
        }
        
        // 2. Highlight individual words (longer than 2 chars)
        let words = query.split(separator: " ")
            .map { String($0).trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 }
        
        for word in words {
            var searchRange = attributedString.startIndex..<attributedString.endIndex
            while let range = attributedString[searchRange].range(of: word, options: .caseInsensitive) {
                // Only apply if not already highlighted by the phrase search
                if attributedString[range].backgroundColor == nil {
                    attributedString[range].backgroundColor = highlightColor
                    attributedString[range].font = highlightFont
                    attributedString[range].foregroundColor = .primary
                }
                searchRange = range.upperBound..<attributedString.endIndex
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
