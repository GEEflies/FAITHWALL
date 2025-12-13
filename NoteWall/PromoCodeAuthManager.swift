import Foundation

/// Manages authentication for promo code admin access
final class PromoCodeAuthManager {
    // MARK: - Singleton
    static let shared = PromoCodeAuthManager()
    
    // MARK: - Developer Credentials
    // PIN is loaded from Config.swift (gitignored file)
    // See Config.swift.example for template
    private var developerPIN: String {
        // Load from Config.swift (gitignored)
        // If Config.swift doesn't exist, this will cause a compile error
        // which is intentional - forces developer to create the config file
        return Config.developerPIN
    }
    
    // MARK: - UserDefaults Keys
    private let authKey = "promo_code_admin_authenticated"
    private let authExpiryKey = "promo_code_admin_auth_expiry"
    private let failedAttemptsKey = "promo_code_failed_attempts"
    private let lockoutUntilKey = "promo_code_lockout_until"
    
    // MARK: - Constants
    private let sessionDuration: TimeInterval = 300 // 5 minutes session
    private let maxFailedAttempts = 5 // Maximum failed attempts before lockout
    private let lockoutDuration: TimeInterval = 900 // 15 minutes lockout after max attempts
    private let delayAfterFailedAttempt: TimeInterval = 2.0 // 2 second delay after each failed attempt
    
    private init() {}
    
    // MARK: - Authentication
    
    /// Authenticates with PIN (returns result with optional error message)
    func authenticate(pin: String) -> AuthenticationResult {
        // Check if account is locked out
        if isLockedOut() {
            let lockoutUntil = UserDefaults.standard.double(forKey: lockoutUntilKey)
            let lockoutDate = Date(timeIntervalSince1970: lockoutUntil)
            let remainingSeconds = Int(lockoutDate.timeIntervalSinceNow)
            return .lockedOut(remainingSeconds: max(0, remainingSeconds))
        }
        
        // Normalize PIN (remove any spaces, ensure it's exactly 8 digits)
        let normalizedPIN = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate PIN format
        guard normalizedPIN.count == 8 else {
            recordFailedAttempt()
            return .invalid("PIN must be exactly 8 digits")
        }
        
        guard normalizedPIN.allSatisfy({ $0.isNumber }) else {
            recordFailedAttempt()
            return .invalid("PIN must contain only numbers")
        }
        
        // Constant-time comparison to prevent timing attacks
        let isValid = constantTimeCompare(normalizedPIN, developerPIN)
        
        if isValid {
            // Success - reset failed attempts and start session
            resetFailedAttempts()
            startSession()
            return .success
        } else {
            // Failed attempt
            recordFailedAttempt()
            
            // Check if we've hit max attempts
            let failedAttempts = getFailedAttempts()
            if failedAttempts >= maxFailedAttempts {
                startLockout()
                return .lockedOut(remainingSeconds: Int(lockoutDuration))
            }
            
            let remainingAttempts = maxFailedAttempts - failedAttempts
            return .failed(remainingAttempts: remainingAttempts)
        }
    }
    
    /// Constant-time string comparison to prevent timing attacks
    private func constantTimeCompare(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }
        var result: UInt8 = 0
        for (charA, charB) in zip(a.utf8, b.utf8) {
            result |= charA ^ charB
        }
        return result == 0
    }
    
    /// Records a failed authentication attempt
    private func recordFailedAttempt() {
        let currentAttempts = getFailedAttempts()
        UserDefaults.standard.set(currentAttempts + 1, forKey: failedAttemptsKey)
        UserDefaults.standard.synchronize()
    }
    
    /// Gets current number of failed attempts
    private func getFailedAttempts() -> Int {
        return UserDefaults.standard.integer(forKey: failedAttemptsKey)
    }
    
    /// Resets failed attempts counter
    private func resetFailedAttempts() {
        UserDefaults.standard.removeObject(forKey: failedAttemptsKey)
        UserDefaults.standard.removeObject(forKey: lockoutUntilKey)
        UserDefaults.standard.synchronize()
    }
    
    /// Starts lockout period
    private func startLockout() {
        let lockoutUntil = Date().addingTimeInterval(lockoutDuration).timeIntervalSince1970
        UserDefaults.standard.set(lockoutUntil, forKey: lockoutUntilKey)
        UserDefaults.standard.synchronize()
    }
    
    /// Checks if account is currently locked out
    private func isLockedOut() -> Bool {
        let lockoutUntil = UserDefaults.standard.double(forKey: lockoutUntilKey)
        guard lockoutUntil > 0 else { return false }
        
        let lockoutDate = Date(timeIntervalSince1970: lockoutUntil)
        if Date() < lockoutDate {
            return true
        } else {
            // Lockout expired, reset it
            resetFailedAttempts()
            return false
        }
    }
    
    /// Checks if user is currently authenticated
    func isAuthenticated() -> Bool {
        guard UserDefaults.standard.bool(forKey: authKey) else {
            return false
        }
        
        // Check if session expired
        let expiry = UserDefaults.standard.double(forKey: authExpiryKey)
        if expiry > 0 {
            let expiryDate = Date(timeIntervalSince1970: expiry)
            if Date() > expiryDate {
                // Session expired
                endSession()
                return false
            }
        }
        
        return true
    }
    
    /// Starts an authenticated session
    private func startSession() {
        UserDefaults.standard.set(true, forKey: authKey)
        let expiry = Date().addingTimeInterval(sessionDuration).timeIntervalSince1970
        UserDefaults.standard.set(expiry, forKey: authExpiryKey)
        UserDefaults.standard.synchronize()
    }
    
    /// Ends the current session
    func endSession() {
        UserDefaults.standard.removeObject(forKey: authKey)
        UserDefaults.standard.removeObject(forKey: authExpiryKey)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Security Utilities
    
    /// Gets remaining lockout time in seconds (0 if not locked)
    func getRemainingLockoutTime() -> Int {
        guard isLockedOut() else { return 0 }
        let lockoutUntil = UserDefaults.standard.double(forKey: lockoutUntilKey)
        let lockoutDate = Date(timeIntervalSince1970: lockoutUntil)
        return max(0, Int(lockoutDate.timeIntervalSinceNow))
    }
    
    /// Gets remaining failed attempts before lockout
    func getRemainingAttempts() -> Int {
        let failedAttempts = getFailedAttempts()
        return max(0, maxFailedAttempts - failedAttempts)
    }
    
    // MARK: - Credential Retrieval (for developer reference)
    
    #if DEBUG
    /// Returns whether PIN is configured (debug only)
    /// Does NOT return the actual PIN for security
    func isPINConfigured() -> Bool {
        return !Config.developerPIN.isEmpty && Config.developerPIN != "00000000"
    }
    #endif
}

// MARK: - Authentication Result

enum AuthenticationResult {
    case success
    case failed(remainingAttempts: Int)
    case invalid(String)
    case lockedOut(remainingSeconds: Int)
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var errorMessage: String {
        switch self {
        case .success:
            return ""
        case .failed(let remaining):
            return "Invalid PIN. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining."
        case .invalid(let message):
            return message
        case .lockedOut(let seconds):
            let minutes = seconds / 60
            let secs = seconds % 60
            if minutes > 0 {
                return "Account locked. Try again in \(minutes) minute\(minutes == 1 ? "" : "s") \(secs > 0 ? "\(secs) second\(secs == 1 ? "" : "s")" : "")."
            } else {
                return "Account locked. Try again in \(seconds) second\(seconds == 1 ? "" : "s")."
            }
        }
    }
}

