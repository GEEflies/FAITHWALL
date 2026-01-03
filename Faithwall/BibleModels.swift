import Foundation
import SwiftUI

// MARK: - Bible Translation Enum
/// Represents available Bible translations with their metadata
/// Maps to SQLite database files from scrollmapper/bible_databases
enum BibleTranslation: String, CaseIterable, Identifiable, Codable {
    // English versions only
    case kjv = "KJV"           // English - King James Version
    case bsb = "BSB"           // English - Berean Standard Bible
    case asv = "ASV"           // English - American Standard Version
    case web = "NHEB"          // English - New Heart English Bible
    case bbe = "BBE"           // English - Bible in Basic English
    case niv = "NIV"           // English - New International Version
    
    var id: String { rawValue }
    
    /// Whether this translation uses online API instead of local database
    var isAPIBased: Bool {
        return false // All translations now use local databases
    }
    
    /// Display name for the translation
    var displayName: String {
        switch self {
        case .kjv: return "King James Version"
        case .bsb: return "Berean Standard Bible"
        case .asv: return "American Standard Version"
        case .web: return "New Heart English Bible"
        case .bbe: return "Bible in Basic English"
        case .niv: return "New International Version"
        }
    }
    
    /// Short name for compact display
    var shortName: String {
        switch self {
        case .kjv: return "KJV"
        case .bsb: return "BSB"
        case .asv: return "ASV"
        case .web: return "NHEB"
        case .bbe: return "BBE"
        case .niv: return "NIV"
        }
    }
    
    /// Language name for display
    var languageName: String {
        "English"
    }
    
    /// Flag emoji for visual identification
    var flagEmoji: String {
        "🇬🇧"
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
        case .asv: return 4.1
        case .web: return 4.3
        case .bbe: return 3.9
        case .niv: return 4.5 // NIV database downloaded from RapidAPI
        }
    }
    
    /// Get all translations as a list (English versions only)
    static var allVersions: [BibleTranslation] {
        [.niv, .kjv, .bsb, .asv, .web, .bbe]
    }
    
    /// Primary translations for initial selection
    static var primaryTranslations: [BibleTranslation] {
        [.niv, .kjv]
    }
    
    /// Returns all translations (same since all are English)
    var relatedTranslations: [BibleTranslation] {
        Self.allVersions
    }
    
    /// Whether this language has multiple version options
    var hasMultipleVersions: Bool {
        true // All English versions are available
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
            rawValue
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
    var text: String
    let translation: BibleTranslation
    
    /// Convenience initializer for API-based verses (without database IDs)
    init(bookName: String, chapter: Int, verse: Int, text: String, translation: BibleTranslation) {
        // Generate a unique ID based on book, chapter, verse
        // Using a simple hash-like approach
        self.id = (bookName.hashValue % 1000) * 1000000 + chapter * 1000 + verse
        // Derive bookId from standard book order
        self.bookId = BibleBookList.standardBooks.firstIndex(of: bookName).map { $0 + 1 } ?? 0
        self.bookName = bookName
        self.chapter = chapter
        self.verse = verse
        self.text = text
        self.translation = translation
    }
    
    /// Full initializer for database-based verses
    init(id: Int, bookId: Int, bookName: String, chapter: Int, verse: Int, text: String, translation: BibleTranslation) {
        self.id = id
        self.bookId = bookId
        self.bookName = bookName
        self.chapter = chapter
        self.verse = verse
        self.text = text
        self.translation = translation
    }
    
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

// MARK: - Standard Bible Book List
struct BibleBookList {
    static let standardBooks = [
        // Old Testament
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
        "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
        "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles",
        "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
        "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations",
        "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
        "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
        "Zephaniah", "Haggai", "Zechariah", "Malachi",
        // New Testament
        "Matthew", "Mark", "Luke", "John", "Acts",
        "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
        "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
        "1 Timothy", "2 Timothy", "Titus", "Philemon",
        "Hebrews", "James", "1 Peter", "2 Peter",
        "1 John", "2 John", "3 John", "Jude", "Revelation"
    ]
}
