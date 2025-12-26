import Foundation
import SwiftUI

// MARK: - Bible Translation Enum
/// Represents available Bible translations with their metadata
/// Maps to SQLite database files from scrollmapper/bible_databases
enum BibleTranslation: String, CaseIterable, Identifiable, Codable {
    case kjv = "KJV"           // English - King James Version
    case bsb = "BSB"           // English - Berean Standard Bible
    case ukrOgienko = "UkrOgienko"  // Ukrainian - Ohienko translation
    case rusSynodal = "RusSynodal"  // Russian - Synodal translation
    case spaRV = "SpaRV"       // Spanish - Reina-Valera
    case freJND = "FreJND"     // French - J.N. Darby
    case gerSch = "GerSch"     // German - Schlachter
    case porBLivre = "PorBLivre"   // Portuguese - Bíblia Livre
    case chiUn = "ChiUn"       // Chinese Traditional - 和合本
    
    var id: String { rawValue }
    
    /// Display name for the translation
    var displayName: String {
        switch self {
        case .kjv: return "King James Version"
        case .bsb: return "Berean Standard Bible"
        case .ukrOgienko: return "Українська Біблія (Огієнко)"
        case .rusSynodal: return "Синодальный перевод"
        case .spaRV: return "Reina-Valera 1909"
        case .freJND: return "Bible J.N. Darby"
        case .gerSch: return "Schlachter Bibel"
        case .porBLivre: return "Bíblia Livre"
        case .chiUn: return "和合本 (繁體)"
        }
    }
    
    /// Short name for compact display
    var shortName: String {
        switch self {
        case .kjv: return "KJV"
        case .bsb: return "BSB"
        case .ukrOgienko: return "УКР"
        case .rusSynodal: return "РУС"
        case .spaRV: return "ESP"
        case .freJND: return "FRA"
        case .gerSch: return "DEU"
        case .porBLivre: return "POR"
        case .chiUn: return "中文"
        }
    }
    
    /// Language name for display
    var languageName: String {
        switch self {
        case .kjv, .bsb: return "English"
        case .ukrOgienko: return "Українська"
        case .rusSynodal: return "Русский"
        case .spaRV: return "Español"
        case .freJND: return "Français"
        case .gerSch: return "Deutsch"
        case .porBLivre: return "Português"
        case .chiUn: return "中文"
        }
    }
    
    /// Flag emoji for visual identification
    var flagEmoji: String {
        switch self {
        case .kjv, .bsb: return "🇬🇧"
        case .ukrOgienko: return "🇺🇦"
        case .rusSynodal: return "🇷🇺"
        case .spaRV: return "🇪🇸"
        case .freJND: return "🇫🇷"
        case .gerSch: return "🇩🇪"
        case .porBLivre: return "🇧🇷"
        case .chiUn: return "🇨🇳"
        }
    }
    
    /// SQLite table prefix (same as rawValue)
    var tablePrefix: String { rawValue }
    
    /// SQLite database filename (.db format from scrollmapper repo)
    var databaseFileName: String { "\(rawValue).db" }
    
    /// Remote URL to download the SQLite database
    /// Uses GitHub raw URL - files are ~4MB each
    var downloadURL: URL? {
        // GitHub raw URL for .db files in scrollmapper/bible_databases
        URL(string: "https://github.com/scrollmapper/bible_databases/raw/master/formats/sqlite/\(rawValue).db")
    }
    
    /// Estimated file size in MB (approximate)
    var estimatedSizeMB: Double {
        switch self {
        case .kjv: return 4.5
        case .bsb: return 4.2
        case .ukrOgienko: return 3.8
        case .rusSynodal: return 4.0
        case .spaRV: return 3.9
        case .freJND: return 4.1
        case .gerSch: return 4.0
        case .porBLivre: return 3.7
        case .chiUn: return 5.2
        }
    }
    
    /// Group translations by language for picker UI
    static var groupedByLanguage: [(language: String, translations: [BibleTranslation])] {
        [
            ("English", [.kjv, .bsb]),
            ("Українська", [.ukrOgienko]),
            ("Русский", [.rusSynodal]),
            ("Español", [.spaRV]),
            ("Français", [.freJND]),
            ("Deutsch", [.gerSch]),
            ("Português", [.porBLivre]),
            ("中文", [.chiUn])
        ]
    }
    
    /// Primary translations (one per language) for initial selection
    static var primaryTranslations: [BibleTranslation] {
        [.kjv, .ukrOgienko, .rusSynodal, .spaRV, .freJND, .gerSch, .porBLivre, .chiUn]
    }
}

// MARK: - Bible Book
/// Represents a book of the Bible
struct BibleBook: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let translation: BibleTranslation
    
    /// Testament classification
    var testament: Testament {
        id <= 39 ? .old : .new
    }
    
    enum Testament: String, CaseIterable {
        case old = "Old Testament"
        case new = "New Testament"
        
        var localizedName: String {
            switch self {
            case .old: return NSLocalizedString("Old Testament", comment: "")
            case .new: return NSLocalizedString("New Testament", comment: "")
            }
        }
    }
}

// MARK: - Bible Chapter
/// Represents a chapter in a Bible book
struct BibleChapter: Identifiable, Codable, Equatable {
    let bookId: Int
    let bookName: String
    let chapter: Int
    let translation: BibleTranslation
    
    var id: String { "\(translation.rawValue)-\(bookId)-\(chapter)" }
    
    /// Display title like "John 3"
    var displayTitle: String {
        "\(bookName) \(chapter)"
    }
}

// MARK: - Bible Verse
/// Represents a single verse
struct BibleVerse: Identifiable, Codable, Equatable {
    let id: Int
    let bookId: Int
    let bookName: String
    let chapter: Int
    let verse: Int
    let text: String
    let translation: BibleTranslation
    
    /// Reference string like "John 3:16"
    var reference: String {
        "\(bookName) \(chapter):\(verse)"
    }
    
    /// Formatted string for display: "John 3:16 - For God so loved..."
    var formattedDisplay: String {
        "\(reference) - \(text)"
    }
    
    /// Short formatted string for lock screen (reference on one line, text on next)
    var lockScreenFormat: String {
        "\(reference)\n\(text)"
    }
    
    /// Truncated text for preview (first N characters)
    func previewText(maxLength: Int = 100) -> String {
        if text.count <= maxLength {
            return text
        }
        let truncated = String(text.prefix(maxLength))
        return truncated + "..."
    }
}

// MARK: - Download State
/// Tracks download state for a translation
enum TranslationDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)
    
    var isDownloaded: Bool {
        if case .downloaded = self { return true }
        return false
    }
    
    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}

// MARK: - Search Result
/// Represents a search result with context
struct BibleSearchResult: Identifiable {
    let verse: BibleVerse
    let matchedText: String
    let highlightRanges: [Range<String.Index>]
    
    var id: String { "\(verse.translation.rawValue)-\(verse.bookId)-\(verse.chapter)-\(verse.verse)" }
}

// MARK: - Notification Names
extension Notification.Name {
    static let bibleLanguageChanged = Notification.Name("bibleLanguageChanged")
    static let bibleTranslationDownloaded = Notification.Name("bibleTranslationDownloaded")
}
