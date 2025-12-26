import SwiftUI

// MARK: - Bible Language Selection View
/// Beautiful language picker for onboarding and settings
/// Shows available Bible translations with flags and download status
/// Now supports language → version selection flow
struct BibleLanguageSelectionView: View {
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var selectedTranslation: BibleTranslation
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showVersionPicker = false
    @State private var selectedLanguageGroup: (language: String, flag: String, translations: [BibleTranslation])?
    
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
                        Text(BL(.chooseBibleLanguage))
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
                    Text(BL(.offlineAvailable))
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
        .sheet(isPresented: $showVersionPicker) {
            if let group = selectedLanguageGroup {
                VersionPickerSheet(
                    languageGroup: group,
                    selectedTranslation: $selectedTranslation,
                    languageManager: languageManager,
                    onVersionSelected: { translation in
                        showVersionPicker = false
                        downloadAndSelect(translation)
                    },
                    onDismiss: {
                        showVersionPicker = false
                    }
                )
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .padding(.top, 40)
            
            Text(BL(.bibleLanguage))
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
            ForEach(BibleTranslation.groupedByLanguage, id: \.language) { group in
                languageCard(for: group)
            }
        }
    }
    
    private func languageCard(for group: (language: String, flag: String, translations: [BibleTranslation])) -> some View {
        let primaryTranslation = group.translations.first!
        let isSelected = group.translations.contains(selectedTranslation)
        let downloadState = languageManager.downloadState(for: isSelected ? selectedTranslation : primaryTranslation)
        let hasMultipleVersions = group.translations.count > 1
        
        return Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            if hasMultipleVersions {
                // Show version picker for languages with multiple versions
                selectedLanguageGroup = group
                showVersionPicker = true
            } else {
                // Single version - select and download directly
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTranslation = primaryTranslation
                }
                downloadAndSelect(primaryTranslation)
            }
        }) {
            VStack(spacing: 8) {
                // Flag emoji
                Text(group.flag)
                    .font(.system(size: 36))
                
                // Language name
                Text(group.language)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                // Show version count or translation name
                if hasMultipleVersions {
                    Text("\(group.translations.count) \(BL(.versions))")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .blue)
                } else {
                    Text(primaryTranslation.shortName)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
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
                Text(BL(.ready))
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .green)
            
        case .downloading(let progress):
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(isSelected ? .white : .blue)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .blue)
            
        case .notDownloaded:
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.caption)
                Text(BL(.tapToDownload))
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption)
                Text(BL(.tapToRetry))
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
            
            Text("\(BL(.downloading)) \(selectedTranslation.displayName)...")
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
            .background(Color.blue)
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
                    onLanguageSelected?(translation)
                    
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
            onLanguageSelected?(translation)
        }
    }
}

// MARK: - Version Picker Sheet
/// Shows available versions for a language (e.g., KJV, BSB, ASV for English)
struct VersionPickerSheet: View {
    let languageGroup: (language: String, flag: String, translations: [BibleTranslation])
    @Binding var selectedTranslation: BibleTranslation
    @ObservedObject var languageManager: BibleLanguageManager
    var onVersionSelected: (BibleTranslation) -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("\(BL(.chooseVersion)) - \(languageGroup.language)")) {
                    ForEach(languageGroup.translations) { translation in
                        versionRow(for: translation)
                    }
                }
                
                Section(footer: Text(BL(.downloadedVersions))) {
                    EmptyView()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("\(languageGroup.flag) \(languageGroup.language)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func versionRow(for translation: BibleTranslation) -> some View {
        let isSelected = selectedTranslation == translation
        let downloadState = languageManager.downloadState(for: translation)
        let isDownloaded = downloadState.isDownloaded
        
        return Button(action: {
            selectedTranslation = translation
            onVersionSelected(translation)
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
                if case .downloading(let progress) = downloadState {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.blue)
                        Text("~\(String(format: "%.1f", translation.estimatedSizeMB))MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body.weight(.semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    BibleLanguageSelectionView { translation in
        print("Selected: \(translation.displayName)")
    }
}

// MARK: - Compact Language Picker (for Settings)
/// A more compact version for use in Settings - with proper download functionality
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
        .sheet(isPresented: $showLanguageSheet) {
            SettingsLanguageSheet(
                languageManager: languageManager,
                onDismiss: {
                    showLanguageSheet = false
                }
            )
        }
    }
}

// MARK: - Settings Language Sheet
/// Full-featured language/version picker for Settings with download progress
struct SettingsLanguageSheet: View {
    @ObservedObject var languageManager: BibleLanguageManager
    var onDismiss: () -> Void
    
    @State private var downloadingTranslation: BibleTranslation?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(BibleTranslation.groupedByLanguage, id: \.language) { group in
                    Section(header: HStack {
                        Text(group.flag)
                        Text(group.language)
                    }) {
                        ForEach(group.translations) { translation in
                            translationRow(for: translation)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(BL(.bibleLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(BL(.done)) {
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
                                .foregroundColor(.blue)
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
                            .foregroundColor(.blue)
                        Text("~\(String(format: "%.1f", translation.estimatedSizeMB))MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
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
