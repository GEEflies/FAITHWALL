import Foundation
import SQLite3

// MARK: - Bible Database Errors
enum BibleDatabaseError: LocalizedError {
    case databaseNotFound(translation: String)
    case cannotOpenDatabase(reason: String)
    case queryFailed(reason: String)
    case downloadFailed(reason: String)
    case bookNotFound(id: Int)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .databaseNotFound(let translation):
            return "Bible database not found for \(translation). Please download it first."
        case .cannotOpenDatabase(let reason):
            return "Cannot open database: \(reason)"
        case .queryFailed(let reason):
            return "Database query failed: \(reason)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .bookNotFound(let id):
            return "Book with ID \(id) not found"
        case .invalidData:
            return "Invalid data received from database"
        }
    }
}

// MARK: - Bible Database Service
/// Service for querying local SQLite Bible databases
/// Downloads databases on-demand and caches them in the app's Documents directory
final class BibleDatabaseService {
    
    // MARK: - Singleton
    static let shared = BibleDatabaseService()
    
    // MARK: - Properties
    private var db: OpaquePointer?
    private var currentTranslation: BibleTranslation?
    private let fileManager = FileManager.default
    
    /// Directory where downloaded databases are stored
    private var databaseDirectory: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbDirectory = documentsURL.appendingPathComponent("BibleDatabases", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: dbDirectory.path) {
            try? fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)
        }
        
        return dbDirectory
    }
    
    // MARK: - Initialization
    private init() {}
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Connection
    
    /// Opens the database for a specific translation
    /// Downloads the database if not already present
    func openDatabase(for translation: BibleTranslation) throws {
        // If already connected to this translation, return
        if currentTranslation == translation && db != nil {
            #if DEBUG
            print("📖 Database already open for \(translation.rawValue)")
            #endif
            return
        }
        
        // Close any existing connection
        closeDatabase()
        
        let dbPath = databasePath(for: translation)
        
        #if DEBUG
        print("📖 Attempting to open database at: \(dbPath.path)")
        print("📖 File exists: \(fileManager.fileExists(atPath: dbPath.path))")
        #endif
        
        // Check if database exists
        guard fileManager.fileExists(atPath: dbPath.path) else {
            throw BibleDatabaseError.databaseNotFound(translation: translation.displayName)
        }
        
        // Open database
        if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw BibleDatabaseError.cannotOpenDatabase(reason: errorMessage)
        }
        
        currentTranslation = translation
        
        #if DEBUG
        print("📖 Opened Bible database: \(translation.rawValue)")
        #endif
    }
    
    /// Closes the current database connection
    func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
            currentTranslation = nil
            
            #if DEBUG
            print("📕 Closed Bible database")
            #endif
        }
    }
    
    /// Returns the local path for a translation's database
    func databasePath(for translation: BibleTranslation) -> URL {
        databaseDirectory.appendingPathComponent(translation.databaseFileName)
    }
    
    /// Checks if a translation is downloaded
    func isDownloaded(_ translation: BibleTranslation) -> Bool {
        fileManager.fileExists(atPath: databasePath(for: translation).path)
    }
    
    // MARK: - Download Management
    
    /// Downloads a Bible translation database
    /// - Parameters:
    ///   - translation: The translation to download
    ///   - progress: Progress callback (0.0 to 1.0)
    ///   - completion: Completion callback with result
    func downloadTranslation(
        _ translation: BibleTranslation,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, BibleDatabaseError>) -> Void
    ) {
        guard let downloadURL = translation.downloadURL else {
            completion(.failure(.downloadFailed(reason: "Invalid download URL")))
            return
        }
        
        let destinationURL = databasePath(for: translation)
        
        #if DEBUG
        print("📥 Starting download: \(translation.rawValue) from \(downloadURL)")
        #endif
        
        let task = URLSession.shared.downloadTask(with: downloadURL) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.downloadFailed(reason: error.localizedDescription)))
                }
                return
            }
            
            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    completion(.failure(.downloadFailed(reason: "No data received")))
                }
                return
            }
            
            do {
                // Remove existing file if present
                if self.fileManager.fileExists(atPath: destinationURL.path) {
                    try self.fileManager.removeItem(at: destinationURL)
                }
                
                // Move downloaded file to destination
                try self.fileManager.moveItem(at: tempURL, to: destinationURL)
                
                #if DEBUG
                print("✅ Downloaded \(translation.rawValue) to \(destinationURL.path)")
                #endif
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .bibleTranslationDownloaded, object: translation)
                    completion(.success(destinationURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.downloadFailed(reason: error.localizedDescription)))
                }
            }
        }
        
        // Observe download progress
        let observation = task.progress.observe(\.fractionCompleted) { progressObj, _ in
            DispatchQueue.main.async {
                progress(progressObj.fractionCompleted)
            }
        }
        
        // Store observation to keep it alive
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)
        
        task.resume()
    }
    
    /// Deletes a downloaded translation
    func deleteTranslation(_ translation: BibleTranslation) throws {
        let path = databasePath(for: translation)
        
        if currentTranslation == translation {
            closeDatabase()
        }
        
        if fileManager.fileExists(atPath: path.path) {
            try fileManager.removeItem(at: path)
            
            #if DEBUG
            print("🗑️ Deleted \(translation.rawValue) database")
            #endif
        }
    }
    
    /// Clears all databases and old files (for migration/reset)
    func clearAllDatabases() {
        closeDatabase()
        
        // Delete the entire BibleDatabases directory
        if fileManager.fileExists(atPath: databaseDirectory.path) {
            try? fileManager.removeItem(at: databaseDirectory)
            
            // Recreate empty directory
            try? fileManager.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
            
            #if DEBUG
            print("🗑️ Cleared all Bible databases")
            #endif
        }
    }
    
    /// Returns total size of downloaded databases in bytes
    func totalDownloadedSize() -> Int64 {
        var totalSize: Int64 = 0
        
        for translation in BibleTranslation.allCases {
            let path = databasePath(for: translation)
            if let attributes = try? fileManager.attributesOfItem(atPath: path.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    // MARK: - Query Functions
    
    /// Gets all books for the current translation
    func getBooks(for translation: BibleTranslation) throws -> [BibleBook] {
        try openDatabase(for: translation)
        
        let tableName = "\(translation.tablePrefix)_books"
        let sql = "SELECT id, name FROM \(tableName) ORDER BY id"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw BibleDatabaseError.queryFailed(reason: errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        var books: [BibleBook] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let name = String(cString: sqlite3_column_text(statement, 1))
            
            books.append(BibleBook(id: id, name: name, translation: translation))
        }
        
        return books
    }
    
    /// Gets the number of chapters in a book
    func getChapterCount(bookId: Int, translation: BibleTranslation) throws -> Int {
        try openDatabase(for: translation)
        
        let tableName = "\(translation.tablePrefix)_verses"
        let sql = "SELECT MAX(chapter) FROM \(tableName) WHERE book_id = ?"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw BibleDatabaseError.queryFailed(reason: errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(bookId))
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        
        throw BibleDatabaseError.bookNotFound(id: bookId)
    }
    
    /// Gets all verses for a specific chapter
    func getVerses(bookId: Int, chapter: Int, translation: BibleTranslation) throws -> [BibleVerse] {
        try openDatabase(for: translation)
        
        // First get book name
        let bookName = try getBookName(bookId: bookId, translation: translation)
        
        let tableName = "\(translation.tablePrefix)_verses"
        let sql = "SELECT id, verse, text FROM \(tableName) WHERE book_id = ? AND chapter = ? ORDER BY verse"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw BibleDatabaseError.queryFailed(reason: errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(bookId))
        sqlite3_bind_int(statement, 2, Int32(chapter))
        
        var verses: [BibleVerse] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let verseNum = Int(sqlite3_column_int(statement, 1))
            let text = String(cString: sqlite3_column_text(statement, 2))
            
            verses.append(BibleVerse(
                id: id,
                bookId: bookId,
                bookName: bookName,
                chapter: chapter,
                verse: verseNum,
                text: text,
                translation: translation
            ))
        }
        
        return verses
    }
    
    /// Gets a specific verse
    func getVerse(bookId: Int, chapter: Int, verse: Int, translation: BibleTranslation) throws -> BibleVerse? {
        try openDatabase(for: translation)
        
        let bookName = try getBookName(bookId: bookId, translation: translation)
        
        let tableName = "\(translation.tablePrefix)_verses"
        let sql = "SELECT id, text FROM \(tableName) WHERE book_id = ? AND chapter = ? AND verse = ?"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw BibleDatabaseError.queryFailed(reason: errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(bookId))
        sqlite3_bind_int(statement, 2, Int32(chapter))
        sqlite3_bind_int(statement, 3, Int32(verse))
        
        if sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let text = String(cString: sqlite3_column_text(statement, 1))
            
            return BibleVerse(
                id: id,
                bookId: bookId,
                bookName: bookName,
                chapter: chapter,
                verse: verse,
                text: text,
                translation: translation
            )
        }
        
        return nil
    }
    
    /// Searches verses by text content
    func searchVerses(query: String, translation: BibleTranslation, limit: Int = 50) throws -> [BibleVerse] {
        try openDatabase(for: translation)
        
        let versesTable = "\(translation.tablePrefix)_verses"
        let booksTable = "\(translation.tablePrefix)_books"
        
        // Use LIKE for simple text search (FTS can be added later for performance)
        let sql = """
            SELECT v.id, v.book_id, b.name, v.chapter, v.verse, v.text
            FROM \(versesTable) v
            JOIN \(booksTable) b ON v.book_id = b.id
            WHERE v.text LIKE ?
            ORDER BY v.book_id, v.chapter, v.verse
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw BibleDatabaseError.queryFailed(reason: errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        let searchPattern = "%\(query)%"
        sqlite3_bind_text(statement, 1, searchPattern, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(limit))
        
        var verses: [BibleVerse] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let bookId = Int(sqlite3_column_int(statement, 1))
            let bookName = String(cString: sqlite3_column_text(statement, 2))
            let chapter = Int(sqlite3_column_int(statement, 3))
            let verseNum = Int(sqlite3_column_int(statement, 4))
            let text = String(cString: sqlite3_column_text(statement, 5))
            
            verses.append(BibleVerse(
                id: id,
                bookId: bookId,
                bookName: bookName,
                chapter: chapter,
                verse: verseNum,
                text: text,
                translation: translation
            ))
        }
        
        return verses
    }
    
    // MARK: - Helper Functions
    
    /// Gets the name of a book by ID
    private func getBookName(bookId: Int, translation: BibleTranslation) throws -> String {
        let tableName = "\(translation.tablePrefix)_books"
        let sql = "SELECT name FROM \(tableName) WHERE id = ?"
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw BibleDatabaseError.queryFailed(reason: errorMessage)
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(bookId))
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(statement, 0))
        }
        
        throw BibleDatabaseError.bookNotFound(id: bookId)
    }
    
    /// Parses a reference string like "John 3:16" into components
    func parseReference(_ input: String) -> (bookName: String, chapter: Int, verse: Int?)? {
        // Pattern: "Book Chapter:Verse" or "Book Chapter"
        // Examples: "John 3:16", "Genesis 1", "1 John 2:3"
        
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        
        // Regex to match: optional number + book name + chapter + optional verse
        let pattern = #"^(\d?\s?[A-Za-z]+)\s+(\d+)(?::(\d+))?$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return nil
        }
        
        guard let bookRange = Range(match.range(at: 1), in: trimmed),
              let chapterRange = Range(match.range(at: 2), in: trimmed) else {
            return nil
        }
        
        let bookName = String(trimmed[bookRange]).trimmingCharacters(in: .whitespaces)
        guard let chapter = Int(trimmed[chapterRange]) else { return nil }
        
        var verse: Int? = nil
        if match.range(at: 3).location != NSNotFound,
           let verseRange = Range(match.range(at: 3), in: trimmed) {
            verse = Int(trimmed[verseRange])
        }
        
        return (bookName, chapter, verse)
    }
    
    // MARK: - Test Function
    
    /// Tests database connection and basic queries
    func testConnection(for translation: BibleTranslation) -> (success: Bool, message: String) {
        do {
            try openDatabase(for: translation)
            let books = try getBooks(for: translation)
            
            if books.isEmpty {
                return (false, "Database opened but no books found")
            }
            
            // Try to get John 3:16 (book 43, chapter 3, verse 16)
            if let verse = try getVerse(bookId: 43, chapter: 3, verse: 16, translation: translation) {
                return (true, "Success! Found \(books.count) books. Sample: \(verse.reference)")
            } else {
                return (true, "Success! Found \(books.count) books.")
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
