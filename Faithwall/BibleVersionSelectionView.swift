import SwiftUI

// MARK: - Bible Version Selection View
/// Simple version picker for English Bible translations
/// Shows available Bible versions with download status
struct BibleVersionSelectionView: View {
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var selectedTranslation: BibleTranslation
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    /// Callback when version is selected and ready
    var onVersionSelected: ((BibleTranslation) -> Void)?
    
    /// Whether to show the continue button (for onboarding)
    var showContinueButton: Bool = true
    
    /// Whether this is being used in onboarding (affects styling)
    var isOnboarding: Bool = true
    
    init(
        initialSelection: BibleTranslation? = nil,
        showContinueButton: Bool = true,
        isOnboarding: Bool = true,
        onVersionSelected: ((BibleTranslation) -> Void)? = nil
    ) {
        _selectedTranslation = State(initialValue: initialSelection ?? BibleLanguageManager.shared.selectedTranslation)
        self.showContinueButton = showContinueButton
        self.isOnboarding = isOnboarding
        self.onVersionSelected = onVersionSelected
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isOnboarding {
                headerSection
            }
            
            ScrollView {
                VStack(spacing: 16) {
                    if isOnboarding {
                        Text("Choose your preferred Bible version")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    
                    versionList
                    
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
                downloadAndSelect(selectedTranslation)
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
                .foregroundColor(.appAccent)
                .padding(.top, 40)
            
            Text("Bible Version")
                .font(.title)
                .fontWeight(.bold)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Version List
    
    private var versionList: some View {
        VStack(spacing: 12) {
            ForEach(BibleTranslation.allCases) { translation in
                versionCard(for: translation)
            }
        }
    }
    
    private func versionCard(for translation: BibleTranslation) -> some View {
        let isSelected = selectedTranslation == translation
        let downloadState = languageManager.downloadState(for: translation)
        
        return Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTranslation = translation
            }
        }) {
            HStack(spacing: 16) {
                // Version info
                VStack(alignment: .leading, spacing: 4) {
                    Text(translation.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(translation.shortName)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                // Download status indicator
                downloadStatusIndicator(for: downloadState, isSelected: isSelected)
                
                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : .appAccent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.appAccent : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
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
                Text("Ready")
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .green)
            
        case .downloading(let progress):
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(isSelected ? .white : .appAccent)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .appAccent)
            
        case .notDownloaded:
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.caption)
                Text("Tap to download")
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption)
                Text("Tap to retry")
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
            downloadAndSelect(selectedTranslation)
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
            .background(Color.appAccent)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDownloading)
        .padding()
    }
    
    // MARK: - Actions
    
    private func downloadAndSelect(_ translation: BibleTranslation) {
        let needsDownload = !BibleDatabaseService.shared.isDownloaded(translation)
        
        if needsDownload {
            isDownloading = true
            downloadProgress = 0
            
            #if DEBUG
            print("📥 Starting download for: \(translation.rawValue)")
            #endif
            
            languageManager.changeTranslation(to: translation) { result in
                isDownloading = false
                
                switch result {
                case .success:
                    #if DEBUG
                    print("📥 Download successful!")
                    #endif
                    languageManager.markLanguageSelectionComplete()
                    onVersionSelected?(translation)
                    
                case .failure(let error):
                    #if DEBUG
                    print("📥 Download failed: \(error)")
                    #endif
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } else {
            // Already downloaded, just select and continue
            languageManager.selectedTranslation = translation
            languageManager.markLanguageSelectionComplete()
            onVersionSelected?(translation)
        }
    }
}

// MARK: - Preview
#Preview {
    BibleVersionSelectionView { translation in
        print("Selected: \(translation.displayName)")
    }
}

// MARK: - Compact Bible Version Picker (for Settings)
/// A compact version for use in Settings
struct CompactBibleVersionPicker: View {
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var showVersionSheet = false
    
    var body: some View {
        Button(action: {
            showVersionSheet = true
        }) {
            HStack {
                Image(systemName: "book.fill")
                    .font(.title2)
                    .foregroundColor(.appAccent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bible Version")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text(languageManager.selectedTranslation.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Show download status
                        if languageManager.isSelectedTranslationReady {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showVersionSheet) {
            SettingsVersionSheet(
                languageManager: languageManager,
                onDismiss: {
                    showVersionSheet = false
                }
            )
        }
    }
}

// MARK: - Settings Version Sheet
/// Full-featured version picker for Settings with download progress
struct SettingsVersionSheet: View {
    @ObservedObject var languageManager: BibleLanguageManager
    var onDismiss: () -> Void
    
    @State private var downloadingTranslation: BibleTranslation?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Available Versions")) {
                    ForEach(BibleTranslation.allCases) { translation in
                        translationRow(for: translation)
                    }
                }
                
                Section(footer: Text("Downloaded versions are available offline (~4MB each)")) {
                    EmptyView()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Bible Version")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .alert("Download Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func translationRow(for translation: BibleTranslation) -> some View {
        let isSelected = languageManager.selectedTranslation == translation
        let downloadState = languageManager.downloadState(for: translation)
        let isDownloading = downloadingTranslation == translation
        
        return Button(action: {
            selectTranslation(translation)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(translation.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(translation.shortName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Download/status indicator
                if isDownloading {
                    if case .downloading(let progress) = downloadState {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.appAccent)
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                } else if downloadState.isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.appAccent)
                        Text("~\(String(format: "%.1f", translation.estimatedSizeMB))MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.appAccent)
                        .font(.body.weight(.semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDownloading)
    }
    
    private func selectTranslation(_ translation: BibleTranslation) {
        let needsDownload = !BibleDatabaseService.shared.isDownloaded(translation)
        
        if needsDownload {
            downloadingTranslation = translation
            
            #if DEBUG
            print("📥 Settings: Starting download for \(translation.rawValue)")
            #endif
            
            languageManager.changeTranslation(to: translation) { result in
                downloadingTranslation = nil
                
                switch result {
                case .success:
                    #if DEBUG
                    print("📥 Settings: Download successful!")
                    #endif
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                case .failure(let error):
                    #if DEBUG
                    print("📥 Settings: Download failed: \(error)")
                    #endif
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } else {
            // Already downloaded, just select
            languageManager.selectedTranslation = translation
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
}
