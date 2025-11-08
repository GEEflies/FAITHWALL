import Foundation
import UIKit

enum HomeScreenImageManagerError: LocalizedError {
    case documentsDirectoryUnavailable
    case unableToCreateDirectory
    case unableToEncodeImage

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            return "The app's local files directory could not be accessed."
        case .unableToCreateDirectory:
            return "The NoteWall folder inside Files could not be created."
        case .unableToEncodeImage:
            return "The selected image could not be saved."
        }
    }
}

enum HomeScreenImageManager {
    private static let shortcutsFolderName = "Shortcuts"
    private static let noteWallFolderName = "NoteWall"
    private static let homeScreenFileName = "homescreen.jpg"
    private static let legacyHomeScreenExtensions = ["png", "heic", "heif"]

    static var displayFolderPath: String {
        "Files → On My iPhone → NoteWall → \(shortcutsFolderName) → \(noteWallFolderName)"
    }

    private static var homeScreenDirectoryURL: URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        return documentsURL
            .appendingPathComponent(shortcutsFolderName, isDirectory: true)
            .appendingPathComponent(noteWallFolderName, isDirectory: true)
    }

    private static var homeScreenFileURL: URL? {
        homeScreenDirectoryURL?.appendingPathComponent(homeScreenFileName, isDirectory: false)
    }

    static func saveHomeScreenImage(_ image: UIImage) throws {
        guard let directoryURL = homeScreenDirectoryURL else {
            throw HomeScreenImageManagerError.documentsDirectoryUnavailable
        }

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw HomeScreenImageManagerError.unableToCreateDirectory
        }

        guard let destinationURL = homeScreenFileURL else {
            throw HomeScreenImageManagerError.documentsDirectoryUnavailable
        }

        removeLegacyHomeScreenFiles(at: directoryURL)

        guard let data = jpegData(from: image, compressionQuality: 0.9) else {
            throw HomeScreenImageManagerError.unableToEncodeImage
        }

        try data.write(to: destinationURL, options: .atomic)
    }

    static func removeHomeScreenImage() throws {
        guard let directoryURL = homeScreenDirectoryURL else {
            throw HomeScreenImageManagerError.documentsDirectoryUnavailable
        }

        if let destinationURL = homeScreenFileURL,
           FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        removeLegacyHomeScreenFiles(at: directoryURL)
    }

    static func homeScreenImageURL() -> URL? {
        homeScreenFileURL
    }

    static func homeScreenImageExists() -> Bool {
        guard let url = homeScreenFileURL else {
            return false
        }

        return FileManager.default.fileExists(atPath: url.path)
    }

    private static func removeLegacyHomeScreenFiles(at directoryURL: URL) {
        legacyHomeScreenExtensions.forEach { ext in
            let legacyURL = directoryURL.appendingPathComponent("homescreen.\(ext)", isDirectory: false)
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                try? FileManager.default.removeItem(at: legacyURL)
            }
        }
    }

    private static func jpegData(from image: UIImage, compressionQuality: CGFloat) -> Data? {
        if let data = image.jpegData(compressionQuality: compressionQuality) {
            return data
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        return rendered.jpegData(compressionQuality: compressionQuality)
    }
}

