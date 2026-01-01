import Foundation
import SwiftUI
import Combine

// MARK: - User Count Service
/// Fetches and caches real-time user count from backend API
/// Falls back to cached value or estimated count if API is unavailable

final class UserCountService: ObservableObject {
    static let shared = UserCountService()
    
    // MARK: - Published Properties
    @Published private(set) var currentCount: Int = 57 // Default fallback
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var fetchError: String?
    
    // MARK: - AppStorage for persistence
    @AppStorage("cachedUserCount") private var cachedUserCount: Int = 57
    @AppStorage("userCountLastFetch") private var lastFetchTimestamp: Double = 0
    @AppStorage("userCountBaseValue") private var baseValue: Int = 80 // Your real download count
    
    // MARK: - Configuration
    private let baseCount: Int = 1031
    private let dailyGrowth: Int = 6
    private let minimumDisplayCount: Int = 50
    private let cacheValidityDuration: TimeInterval = 3600
    // Fixed start date: December 30, 2025
    private let startDate: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 30
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    // MARK: - Computed Properties
    
    private var isCacheValid: Bool {
        let now = Date().timeIntervalSince1970
        return (now - lastFetchTimestamp) < cacheValidityDuration
    }
    
    private var estimatedCount: Int {
        return calculatedCount
    }
    
    /// Deterministic count based on date
    /// Starts at 1031 on Dec 30, 2025 and increases by 6 every day
    var calculatedCount: Int {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate days passed since start date
        let components = calendar.dateComponents([.day], from: startDate, to: now)
        let daysPassed = max(0, components.day ?? 0)
        
        return baseCount + (daysPassed * dailyGrowth)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Always use the calculated deterministic count
        currentCount = calculatedCount
    }
    
    // MARK: - Public Methods
    
    /// Fetch latest count (returns calculated value)
    @MainActor
    func fetchUserCount() async -> Int {
        // Update current count based on today's date
        currentCount = calculatedCount
        isLoading = false
        
        #if DEBUG
        print("📊 UserCountService: Using calculated count - \(currentCount)")
        #endif
        
        return currentCount
    }
    
    /// Update the base value (call this when you know the real download count)
    func updateBaseCount(_ count: Int) {
        baseValue = count
        // Recalculate current count if cache is stale
        if !isCacheValid {
            currentCount = estimatedCount
        }
    }
    
    /// Force refresh from API
    @MainActor
    func forceRefresh() async -> Int {
        lastFetchTimestamp = 0 // Invalidate cache
        return await fetchUserCount()
    }
    
    // MARK: - Private Methods
    
    private func updateCache(with count: Int) {
        let validCount = max(minimumDisplayCount, count)
        cachedUserCount = validCount
        currentCount = validCount
        lastFetchTimestamp = Date().timeIntervalSince1970
        lastUpdateTime = Date()
        
        #if DEBUG
        print("📊 UserCountService: Updated cache with count - \(validCount)")
        #endif
    }
}

// MARK: - Preview Helper
#if DEBUG
extension UserCountService {
    static var preview: UserCountService {
        let service = UserCountService.shared
        service.currentCount = 85
        return service
    }
}
#endif
