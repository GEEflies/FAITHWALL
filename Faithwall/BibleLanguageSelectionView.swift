import SwiftUI

// MARK: - Bible Version Selection View
/// Simple Bible version picker for English translations
/// Shows available Bible versions (KJV, BSB, ASV, NHEB, BBE) with download status
struct BibleLanguageSelectionView: View {
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var selectedTranslation: BibleTranslation
    @State private var isDownloading = false
    @State private var isApplying = false
    @State private var showSuccess = false
    @State private var downloadProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    /// Callback when version is selected and ready
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
        ZStack {
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
                        
                        versionsList
                        
                        // Download progress indicator
                        if isDownloading {
                            downloadProgressView
                        }
                        
                        // Size info
                        Text("All versions are stored offline (~4-5MB each)\nNo internet required once downloaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical)
                }
                
                if showContinueButton {
                    continueButton
                }
            }
            .background(Color(.systemBackground))
            
            // Processing Overlay
            if isApplying || showSuccess {
                processingOverlay
            }
        }
        .alert("Download Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                downloadAndSelect(selectedTranslation)
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
                .opacity(0.9)
            
            VStack(spacing: 24) {
                if showSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                        
                        Text("Version Ready!")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.appAccent)
                        
                        Text("Applying Version...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(24)
        }
        .transition(.opacity)
        .animation(.spring(), value: showSuccess)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.appAccent)
            }
            .padding(.top, 40)
            
            VStack(spacing: 4) {
                Text("Bible Version")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("Select your preferred translation")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Versions List
    
    private var versionsList: some View {
        VStack(spacing: 14) {
            ForEach(BibleTranslation.allCases, id: \.id) { translation in
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
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTranslation = translation
            }
            
            // If not showing continue button (pop-up mode), apply immediately
            if !showContinueButton {
                downloadAndSelect(translation)
            }
        }) {
            HStack(spacing: 16) {
                // Version name and details
                VStack(alignment: .leading, spacing: 4) {
                    Text(translation.displayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(translation.shortName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                // Download status indicator
                downloadStatusIndicator(for: downloadState, translation: translation, isSelected: isSelected)
                
                // Selection checkmark
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.appAccent : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(color: isSelected ? Color.appAccent.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func downloadStatusIndicator(for state: TranslationDownloadState, translation: BibleTranslation, isSelected: Bool) -> some View {
        switch state {
        case .downloaded:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                Text(translation == .niv ? "Bundled" : "Ready")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.white.opacity(0.2) : Color.green.opacity(0.1))
            .foregroundColor(isSelected ? .white : .green)
            .cornerRadius(6)
            
        case .downloading(let progress):
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(isSelected ? .white : .appAccent)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.white.opacity(0.2) : Color.appAccent.opacity(0.1))
            .foregroundColor(isSelected ? .white : .appAccent)
            .cornerRadius(6)
            
        case .notDownloaded:
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 10))
                Text("Download")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .secondary)
            .cornerRadius(6)
            
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 10))
                Text("Retry")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.white.opacity(0.2) : Color.red.opacity(0.1))
            .foregroundColor(isSelected ? .white : .red)
            .cornerRadius(6)
        }
    }
    
    // MARK: - Download Progress View
    
    private var downloadProgressView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Downloading \(selectedTranslation.shortName)...")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(downloadProgress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.appAccent)
            }
            
            ProgressView(value: downloadProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(.appAccent)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button(action: {
            downloadAndSelect(selectedTranslation)
        }) {
            HStack(spacing: 12) {
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    // API-based translations don't need download
                    let needsDownload = !selectedTranslation.isAPIBased && !BibleDatabaseService.shared.isDownloaded(selectedTranslation)
                    
                    if needsDownload {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    Text(needsDownload ? "Download & Continue" : "Apply Version")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.appAccent, Color.appAccent.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: Color.appAccent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(isDownloading || isApplying || showSuccess)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.l)
    }
    
    // MARK: - Actions
    
    private func downloadAndSelect(_ translation: BibleTranslation) {
        // API-based translations (like NIV) don't need download
        if translation.isAPIBased {
            withAnimation { isApplying = true }
            
            // Simulate a brief "Applying" state for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                languageManager.selectedTranslation = translation
                languageManager.markLanguageSelectionComplete()
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                withAnimation {
                    showSuccess = true
                    isApplying = false
                }
                
                // Final delay before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onLanguageSelected?(translation)
                }
            }
            return
        }
        
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
                    
                    withAnimation { isApplying = true }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        languageManager.markLanguageSelectionComplete()
                        
                        withAnimation {
                            showSuccess = true
                            isApplying = false
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            onLanguageSelected?(translation)
                        }
                    }
                    
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
            withAnimation { isApplying = true }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                languageManager.selectedTranslation = translation
                languageManager.markLanguageSelectionComplete()
                
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                withAnimation {
                    showSuccess = true
                    isApplying = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onLanguageSelected?(translation)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    BibleLanguageSelectionView { translation in
        print("Selected: \(translation.displayName)")
    }
}

// MARK: - Compact Version Picker (for Settings)
/// A more compact version for use in Settings
struct CompactBibleLanguagePicker: View {
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var showVersionSheet = false
    
    var body: some View {
        Button(action: {
            showVersionSheet = true
        }) {
            HStack {
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
            NavigationView {
                BibleLanguageSelectionView(
                    initialSelection: languageManager.selectedTranslation,
                    showContinueButton: false,
                    isOnboarding: false
                ) { translation in
                    showVersionSheet = false
                }
                .navigationTitle("Bible Version")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showVersionSheet = false
                        }
                    }
                }
            }
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
                Section(header: Text("English Versions")) {
                    ForEach(BibleTranslation.allCases) { translation in
                        translationRow(for: translation)
                    }
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
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(translation.displayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(translation.shortName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
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
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.appAccent)
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                } else if downloadState.isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.appAccent)
                        Text("\(String(format: "%.1f", translation.estimatedSizeMB))MB")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appAccent.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.appAccent)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .padding(.vertical, 8)
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
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Brief delay before dismissing if needed, but here we just update UI
        }
    }
}
