import Foundation

// MARK: - Bible API Service
/// Service for fetching Bible verses from RapidAPI NIV Bible
/// Implements caching to minimize API calls and improve performance
final class BibleAPIService {
    
    // MARK: - Singleton
    static let shared = BibleAPIService()
    
    // MARK: - Configuration
    private let baseURL = "https://niv-bible.p.rapidapi.com"
    private let apiKey = Config.rapidAPIKey
    private let host = "niv-bible.p.rapidapi.com"
    
    // MARK: - Cache
    private var verseCache: [String: BibleVerse] = [:]
    private var chapterCache: [String: [BibleVerse]] = [:]
    private var bookCache: [String: [BibleBook]] = [:]
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fetch a single verse
    func fetchVerse(book: String, chapter: Int, verse: Int) async throws -> BibleVerse {
        let cacheKey = "\(book)_\(chapter)_\(verse)"
        
        // Check cache first
        if let cached = verseCache[cacheKey] {
            #if DEBUG
            print("📖 Cache hit for \(cacheKey)")
            #endif
            return cached
        }
        
        // Build URL
        guard var urlComponents = URLComponents(string: "\(baseURL)/row") else {
            throw BibleDatabaseError.invalidData
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "Book", value: book),
            URLQueryItem(name: "Chapter", value: "\(chapter)"),
            URLQueryItem(name: "Verse", value: "\(verse)")
        ]
        
        guard let url = urlComponents.url else {
            throw BibleDatabaseError.invalidData
        }
        
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(host, forHTTPHeaderField: "x-rapidapi-host")
        request.addValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        
        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BibleDatabaseError.downloadFailed(reason: "API request failed")
        }
        
        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
        guard let book = json?["Book"]?.values.first as? String,
              let chapterNum = json?["Chapter"]?.values.first as? Int,
              let verseNum = json?["Verse"]?.values.first as? Int,
              let text = json?["Text"]?.values.first as? String else {
            throw BibleDatabaseError.invalidData
        }
        
        // Clean text (remove escape characters)
        let cleanText = text.replacingOccurrences(of: "\\\"", with: "\"")
                            .replacingOccurrences(of: "\\", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create verse object
        let bibleVerse = BibleVerse(
            bookName: book,
            chapter: chapterNum,
            verse: verseNum,
            text: cleanText,
            translation: .niv
        )
        
        // Cache it
        verseCache[cacheKey] = bibleVerse
        
        #if DEBUG
        print("📖 Fetched and cached \(cacheKey)")
        #endif
        
        return bibleVerse
    }
    
    /// Fetch all verses in a chapter
    func fetchChapter(book: String, chapter: Int) async throws -> [BibleVerse] {
        let cacheKey = "\(book)_\(chapter)"
        
        // Check cache first
        if let cached = chapterCache[cacheKey] {
            #if DEBUG
            print("📖 Cache hit for chapter \(cacheKey)")
            #endif
            return cached
        }
        
        // Build URL
        guard var urlComponents = URLComponents(string: "\(baseURL)/row") else {
            throw BibleDatabaseError.invalidData
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "Book", value: book),
            URLQueryItem(name: "Chapter", value: "\(chapter)")
        ]
        
        guard let url = urlComponents.url else {
            throw BibleDatabaseError.invalidData
        }
        
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(host, forHTTPHeaderField: "x-rapidapi-host")
        request.addValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        
        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BibleDatabaseError.downloadFailed(reason: "API request failed")
        }
        
        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
        guard let textDict = json?["Text"],
              let verseDict = json?["Verse"] else {
            throw BibleDatabaseError.invalidData
        }
        
        // Convert to verses
        var verses: [BibleVerse] = []
        for (key, text) in textDict {
            guard let verseNum = verseDict[key] as? Int,
                  let verseText = text as? String else {
                continue
            }
            
            // Clean text
            let cleanText = verseText.replacingOccurrences(of: "\\\"", with: "\"")
                                    .replacingOccurrences(of: "\\", with: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let verse = BibleVerse(
                bookName: book,
                chapter: chapter,
                verse: verseNum,
                text: cleanText,
                translation: .niv
            )
            verses.append(verse)
            
            // Cache individual verse too
            let verseKey = "\(book)_\(chapter)_\(verseNum)"
            verseCache[verseKey] = verse
        }
        
        // Sort by verse number
        verses.sort { $0.verse < $1.verse }
        
        // Cache chapter
        chapterCache[cacheKey] = verses
        
        #if DEBUG
        print("📖 Fetched and cached chapter \(cacheKey) with \(verses.count) verses")
        #endif
        
        return verses
    }
    
    /// Get list of books for NIV
    /// Since NIV uses standard Bible structure, we return the standard book list
    func getBooks() -> [BibleBook] {
        // Return cached if available
        if let cached = bookCache["niv"] {
            return cached
        }
        
        // Standard Bible books in order - use the shared list from BibleModels
        let books = BibleBookList.standardBooks.enumerated().map { index, name in
            BibleBook(id: index + 1, name: name, translation: .niv)
        }
        
        bookCache["niv"] = books
        return books
    }
    
    /// Clear all caches (useful for memory management)
    func clearCache() {
        verseCache.removeAll()
        chapterCache.removeAll()
        bookCache.removeAll()
        
        #if DEBUG
        print("📖 API cache cleared")
        #endif
    }
}
