import SwiftUI

// MARK: - Bible Language Selection View
/// Beautiful language picker for onboarding and settings
/// Shows available Bible translations with flags and download status
struct BibleLanguageSelectionView: View {
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var selectedTranslation: BibleTranslation
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    /// Callback when language is selected and ready
    var onLanguageSelected: ((BibleTranslation) -> Void)?
    
    /// Whether to show the continue button (for onboarding)
    var showContinueButton: Bool = true
    
    /// Whether this is being used in onboarding (affects styling)
    var isOnboarding: Bool = true
    
    init(
        initialSelection: BibleTranslation? = nil,
        showContinueButton: Bool = true,
        isOnboarding: Bool = true,
        onLanguageSelected: ((BibleTranslation) -> Void)? = nil
    ) {
        _selectedTranslation = State(initialValue: initialSelection ?? BibleLanguageManager.shared.selectedTranslation)
        self.showContinueButton = showContinueButton
        self.isOnboarding = isOnboarding
        self.onLanguageSelected = onLanguageSelected
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isOnboarding {
                headerSection
            }
            
            ScrollView {
                VStack(spacing: 16) {
                    if isOnboarding {
                        Text("Choose your preferred Bible language")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    
                    languageGrid
                    
                    // Download progress indicator
                    if isDownloading {
                        downloadProgressView
                    }
                    
                    // Size info
                    Text("Bible databases are downloaded for offline use (~4MB each)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                .padding()
            }
            
            if showContinueButton {
                continueButton
            }
        }
        .background(Color(.systemBackground))
        .alert("Download Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                downloadSelectedTranslation()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .padding(.top, 40)
            
            Text("Select Bible Language")
                .font(.title)
                .fontWeight(.bold)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Language Grid
    
    private var languageGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(BibleTranslation.primaryTranslations) { translation in
                languageCard(for: translation)
            }
        }
    }
    
    private func languageCard(for translation: BibleTranslation) -> some View {
        let isSelected = selectedTranslation == translation
        let downloadState = languageManager.downloadState(for: translation)
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTranslation = translation
            }
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            VStack(spacing: 8) {
                // Flag emoji
                Text(translation.flagEmoji)
                    .font(.system(size: 36))
                
                // Language name
                Text(translation.languageName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                // Translation short name
                Text(translation.shortName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                
                // Download status indicator
                downloadStatusIndicator(for: downloadState, isSelected: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func downloadStatusIndicator(for state: TranslationDownloadState, isSelected: Bool) -> some View {
        switch state {
        case .downloaded:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                Text("Downloaded")
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .green)
            
        case .downloading(let progress):
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .blue)
            
        case .notDownloaded:
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.caption)
                Text("~\(String(format: "%.1f", languageManager.selectedTranslation.estimatedSizeMB))MB")
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption)
                Text("Failed")
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .red)
        }
    }
    
    // MARK: - Download Progress View
    
    private var downloadProgressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: downloadProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("Downloading \(selectedTranslation.displayName)...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button(action: {
            downloadSelectedTranslation()
        }) {
            HStack {
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    let needsDownload = !BibleDatabaseService.shared.isDownloaded(selectedTranslation)
                    
                    if needsDownload {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    
                    Text(needsDownload ? "Download & Continue" : "Continue")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDownloading)
        .padding()
    }
    
    // MARK: - Actions
    
    private func downloadSelectedTranslation() {
        let needsDownload = !BibleDatabaseService.shared.isDownloaded(selectedTranslation)
        
        if needsDownload {
            isDownloading = true
            downloadProgress = 0
            
            languageManager.changeTranslation(to: selectedTranslation) { result in
                isDownloading = false
                
                switch result {
                case .success:
                    languageManager.markLanguageSelectionComplete()
                    onLanguageSelected?(selectedTranslation)
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } else {
            // Already downloaded, just select and continue
            languageManager.selectedTranslation = selectedTranslation
            languageManager.markLanguageSelectionComplete()
            onLanguageSelected?(selectedTranslation)
        }
    }
}

// MARK: - Preview
#Preview {
    BibleLanguageSelectionView { translation in
        print("Selected: \(translation.displayName)")
    }
}

// MARK: - Compact Language Picker (for Settings)
/// A more compact version for use in Settings
struct CompactBibleLanguagePicker: View {
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var showLanguageSheet = false
    
    var body: some View {
        Button(action: {
            showLanguageSheet = true
        }) {
            HStack {
                Text(languageManager.selectedTranslation.flagEmoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(languageManager.selectedTranslation.languageName)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(languageManager.selectedTranslation.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showLanguageSheet) {
            NavigationView {
                BibleLanguageSelectionView(
                    initialSelection: languageManager.selectedTranslation,
                    showContinueButton: false,
                    isOnboarding: false
                ) { translation in
                    showLanguageSheet = false
                }
                .navigationTitle("Bible Language")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showLanguageSheet = false
                        }
                    }
                }
            }
        }
    }
}
