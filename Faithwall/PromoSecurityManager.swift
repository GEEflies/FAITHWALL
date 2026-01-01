import Foundation
import CryptoKit

/// High-security manager for promo code operations
/// Provides encryption, integrity checks, and atomic operations
final class PromoSecurityManager {
    static let shared = PromoSecurityManager()
    
    private let encryptionKey: SymmetricKey
    
    private init() {
        // Generate or retrieve encryption key
        // Uses Keychain for secure storage
        if let keyData = KeychainHelper.shared.get(key: "promo_encryption_key") {
            self.encryptionKey = SymmetricKey(data: keyData)
        } else {
            // Generate new key
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            KeychainHelper.shared.set(key: "promo_encryption_key", value: keyData)
            self.encryptionKey = key
        }
    }
    
    /// Encrypts promo code data
    func encrypt(_ data: Data) -> Data? {
        do {
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
            return sealedBox.combined
        } catch {
            #if DEBUG
            print("❌ PromoSecurityManager: Encryption failed: \(error)")
            #endif
            return nil
        }
    }
    
    /// Decrypts promo code data
    func decrypt(_ encryptedData: Data) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: encryptionKey)
        } catch {
            #if DEBUG
            print("❌ PromoSecurityManager: Decryption failed: \(error)")
            #endif
            return nil
        }
    }
    
    /// Generates cryptographically secure random code
    func generateSecureRandomCode(length: Int, characters: String) -> String {
        var result = ""
        var randomBytes = [UInt8](repeating: 0, count: length)
        
        // Use secure random number generator
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        guard status == errSecSuccess else {
            // Fallback to system random (still secure on iOS)
            for _ in 0..<length {
                let randomIndex = Int.random(in: 0..<characters.count)
                let character = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
                result += String(character)
            }
            return result
        }
        
        // Use cryptographically secure random bytes
        for byte in randomBytes {
            let index = Int(byte) % characters.count
            let character = characters[characters.index(characters.startIndex, offsetBy: index)]
            result += String(character)
        }
        
        return result
    }
    
    /// Creates integrity hash for access flags
    func createIntegrityHash(hasLifetime: Bool, hasPremium: Bool, expiryTimestamp: Double) -> String {
        let data = "\(hasLifetime)|\(hasPremium)|\(expiryTimestamp)".data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Verifies integrity of access flags
    func verifyIntegrity(hasLifetime: Bool, hasPremium: Bool, expiryTimestamp: Double, storedHash: String) -> Bool {
        let computedHash = createIntegrityHash(hasLifetime: hasLifetime, hasPremium: hasPremium, expiryTimestamp: expiryTimestamp)
        return computedHash == storedHash
    }
}

// MARK: - Keychain Helper

final class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let service = "com.faithwall.promo"
    
    private init() {}
    
    func set(key: String, value: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: value
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return data
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

