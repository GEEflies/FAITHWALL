import Foundation
import SwiftUI
import Combine

// MARK: - Language Manager
/// Manages Bible language/translation selection across the app
/// Stores user preference and tracks download states
final class BibleLanguageManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = BibleLanguageManager()
    
    // MARK: - Published Properties
    @Published var selectedTranslation: BibleTranslation {
        didSet {
            UserDefaults.standard.set(selectedTranslation.rawValue, forKey: "selectedBibleTranslation")
            NotificationCenter.default.post(name: .bibleLanguageChanged, object: selectedTranslation)
            
            #if DEBUG
            print("📚 Bible language changed to: \(selectedTranslation.displayName)")
            #endif
        }
    }
    
    @Published var downloadStates: [BibleTranslation: TranslationDownloadState] = [:]
    @Published var isDownloading = false
    @Published var currentDownloadProgress: Double = 0
    
    // MARK: - Private Properties
    private let databaseService = BibleDatabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Returns true if the selected translation is downloaded and ready
    var isSelectedTranslationReady: Bool {
        // API-based translations are always ready (no download needed)
        if selectedTranslation.isAPIBased {
            return true
        }
        return databaseService.isDownloaded(selectedTranslation)
    }
    
    /// Returns all downloaded translations
    var downloadedTranslations: [BibleTranslation] {
        BibleTranslation.allCases.filter { translation in
            // API-based translations are always "downloaded"
            translation.isAPIBased || databaseService.isDownloaded(translation)
        }
    }
    
    /// Returns translations that need to be downloaded
    var notDownloadedTranslations: [BibleTranslation] {
        BibleTranslation.allCases.filter { translation in
            // API-based translations never need download
            !translation.isAPIBased && !databaseService.isDownloaded(translation)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved translation or default to KJV
        if let savedRaw = UserDefaults.standard.string(forKey: "selectedBibleTranslation"),
           let saved = BibleTranslation(rawValue: savedRaw) {
            self.selectedTranslation = saved
        } else {
            self.selectedTranslation = .kjv
        }
        
        // Initialize download states
        refreshDownloadStates()
        
        // Listen for download completions
        NotificationCenter.default.publisher(for: .bibleTranslationDownloaded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let translation = notification.object as? BibleTranslation {
                    self?.downloadStates[translation] = .downloaded
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Refreshes the download state for all translations
    func refreshDownloadStates() {
        for translation in BibleTranslation.allCases {
            // API-based translations are always ready
            if translation.isAPIBased {
                downloadStates[translation] = .downloaded
            } else if databaseService.isDownloaded(translation) {
                downloadStates[translation] = .downloaded
            } else {
                downloadStates[translation] = .notDownloaded
            }
        }
    }
    
    /// Downloads a translation if not already downloaded
    func downloadTranslation(_ translation: BibleTranslation, completion: ((Result<Void, Error>) -> Void)? = nil) {
        // API-based translations don't need download
        if translation.isAPIBased {
            downloadStates[translation] = .downloaded
            completion?(.success(()))
            return
        }
        
        guard !databaseService.isDownloaded(translation) else {
            downloadStates[translation] = .downloaded
            completion?(.success(()))
            return
        }
        
        isDownloading = true
        currentDownloadProgress = 0
        downloadStates[translation] = .downloading(progress: 0)
        
        databaseService.downloadTranslation(
            translation,
            progress: { [weak self] progress in
                self?.currentDownloadProgress = progress
                self?.downloadStates[translation] = .downloading(progress: progress)
            },
            completion: { [weak self] result in
                self?.isDownloading = false
                self?.currentDownloadProgress = 0
                
                switch result {
                case .success:
                    self?.downloadStates[translation] = .downloaded
                    completion?(.success(()))
                case .failure(let error):
                    self?.downloadStates[translation] = .failed(error: error.localizedDescription)
                    completion?(.failure(error))
                }
            }
        )
    }
    
    /// Downloads the selected translation if needed
    func ensureSelectedTranslationDownloaded(completion: ((Result<Void, Error>) -> Void)? = nil) {
        downloadTranslation(selectedTranslation, completion: completion)
    }
    
    /// Deletes a downloaded translation
    func deleteTranslation(_ translation: BibleTranslation) {
        do {
            try databaseService.deleteTranslation(translation)
            downloadStates[translation] = .notDownloaded
            
            // If deleted translation was selected, switch to another downloaded one
            if translation == selectedTranslation {
                if let firstDownloaded = downloadedTranslations.first {
                    selectedTranslation = firstDownloaded
                }
            }
        } catch {
            #if DEBUG
            print("❌ Failed to delete translation: \(error)")
            #endif
        }
    }
    
    /// Changes the selected translation and downloads if needed
    func changeTranslation(to translation: BibleTranslation, completion: ((Result<Void, Error>) -> Void)? = nil) {
        selectedTranslation = translation
        
        // API-based translations don't need download
        if translation.isAPIBased {
            completion?(.success(()))
            return
        }
        
        if !databaseService.isDownloaded(translation) {
            downloadTranslation(translation, completion: completion)
        } else {
            completion?(.success(()))
        }
    }
    
    /// Returns the download state for a translation
    func downloadState(for translation: BibleTranslation) -> TranslationDownloadState {
        downloadStates[translation] ?? (databaseService.isDownloaded(translation) ? .downloaded : .notDownloaded)
    }
    
    /// Returns formatted size string for downloaded databases
    func formattedDownloadedSize() -> String {
        let bytes = databaseService.totalDownloadedSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Clears all downloaded databases and resets states (for troubleshooting)
    func resetAllDatabases() {
        databaseService.clearAllDatabases()
        refreshDownloadStates()
        
        #if DEBUG
        print("🔄 Reset all Bible databases")
        #endif
    }
    
    /// Force re-downloads the selected translation
    func forceRedownloadSelected(completion: ((Result<Void, Error>) -> Void)? = nil) {
        // Delete existing
        try? databaseService.deleteTranslation(selectedTranslation)
        downloadStates[selectedTranslation] = .notDownloaded
        
        // Re-download
        downloadTranslation(selectedTranslation, completion: completion)
    }
    
    /// Checks if user has completed language selection (for onboarding)
    var hasCompletedLanguageSelection: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedBibleLanguageSelection") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedBibleLanguageSelection") }
    }
    
    /// Mark language selection as completed (after onboarding)
    func markLanguageSelectionComplete() {
        hasCompletedLanguageSelection = true
    }
}

// MARK: - SwiftUI Environment Key
private struct BibleLanguageManagerKey: EnvironmentKey {
    static let defaultValue = BibleLanguageManager.shared
}

extension EnvironmentValues {
    var bibleLanguageManager: BibleLanguageManager {
        get { self[BibleLanguageManagerKey.self] }
        set { self[BibleLanguageManagerKey.self] = newValue }
    }
}
