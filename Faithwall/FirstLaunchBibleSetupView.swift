import SwiftUI

// MARK: - First Launch Language Picker
/// Shows on first app launch to let user select their Bible language
/// This appears before anything else and downloads the selected translation
struct FirstLaunchBibleSetupView: View {
    @StateObject private var languageManager = BibleLanguageManager.shared
    @Binding var hasCompletedBibleSetup: Bool
    
    @State private var selectedTranslation: BibleTranslation = .kjv
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.top, 60)
                
                // Language selection grid
                ScrollView {
                    languageGrid
                        .padding()
                }
                
                // Download progress or continue button
                bottomSection
            }
        }
        .alert("Download Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                downloadAndContinue()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon or Bible icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "book.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)
            }
            
            Text("Welcome to FaithWall")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Choose your Bible language to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.bottom, 24)
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
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTranslation = translation
            }
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            VStack(spacing: 10) {
                // Flag emoji
                Text(translation.flagEmoji)
                    .font(.system(size: 40))
                
                // Language name
                Text(translation.languageName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                // Translation short name
                Text(translation.shortName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Info text
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(.caption)
                Text("~\(String(format: "%.1f", selectedTranslation.estimatedSizeMB))MB download for offline use")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            // Download progress
            if isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    Text("Downloading \(selectedTranslation.languageName) Bible...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            // Continue button
            Button(action: {
                downloadAndContinue()
            }) {
                HStack {
                    if isDownloading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    
                    Text(isDownloading ? "Downloading..." : "Continue")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDownloading ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isDownloading)
            .padding(.horizontal)
            
            // Skip option
            if !isDownloading {
                Button(action: {
                    // Skip download, use default (KJV) - user can download later
                    languageManager.selectedTranslation = .kjv
                    hasCompletedBibleSetup = true
                }) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Actions
    
    private func downloadAndContinue() {
        isDownloading = true
        downloadProgress = 0
        
        languageManager.changeTranslation(to: selectedTranslation) { result in
            isDownloading = false
            
            switch result {
            case .success:
                languageManager.markLanguageSelectionComplete()
                
                // Haptic success
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Proceed to main app
                withAnimation {
                    hasCompletedBibleSetup = true
                }
                
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - App Entry Point Modifier
/// Use this modifier on your root view to show language picker on first launch
struct FirstLaunchBibleSetupModifier: ViewModifier {
    @AppStorage("hasCompletedBibleLanguageSetup") private var hasCompletedBibleSetup = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(!hasCompletedBibleSetup)
                .blur(radius: hasCompletedBibleSetup ? 0 : 10)
            
            if !hasCompletedBibleSetup {
                FirstLaunchBibleSetupView(hasCompletedBibleSetup: $hasCompletedBibleSetup)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: hasCompletedBibleSetup)
    }
}

extension View {
    func withFirstLaunchBibleSetup() -> some View {
        modifier(FirstLaunchBibleSetupModifier())
    }
}

// MARK: - Preview
#Preview {
    FirstLaunchBibleSetupView(hasCompletedBibleSetup: .constant(false))
}
