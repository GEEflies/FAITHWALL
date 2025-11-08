import UIKit
import SwiftUI

struct WallpaperRenderer {
    static func generateWallpaper(from notes: [Note]) -> UIImage {
        // iPhone wallpaper dimensions
        let width: CGFloat = 1290
        let height: CGFloat = 2796

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { context in
            // Black background
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // Filter out completed notes and limit to notes that fit
            let activeNotes = notes.filter { !$0.isCompleted }
            let notesToShow = limitNotesToSafeArea(activeNotes)

            guard !notesToShow.isEmpty else { return }

            // Prepare text
            let combinedText = notesToShow.map { $0.text }.joined(separator: "\n\n")

            // Text attributes - white, left-aligned
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineSpacing = 12

            // Increased font size for better visibility
            let fontSize: CGFloat = 96
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            // Calculate text size and position
            let horizontalPadding: CGFloat = 80
            // Position text below time and widgets - moved further down
            // For iPhone 14 Pro (2796px height), this positions text lower on the screen
            let topPadding: CGFloat = 1075 // Increased to move notes further down towards bottom
            let textMaxWidth = width - (horizontalPadding * 2)

            let attributedString = NSAttributedString(string: combinedText, attributes: attributes)
            let textSize = attributedString.boundingRect(
                with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            // Position text in upper portion, left-aligned, with enough space to avoid widgets
            let textRect = CGRect(
                x: horizontalPadding,
                y: topPadding,
                width: textMaxWidth,
                height: textSize.height
            )

            // Draw text
            combinedText.draw(in: textRect, withAttributes: attributes)
        }
    }

    static func generateBlankWallpaper() -> UIImage {
        let width: CGFloat = 1290
        let height: CGFloat = 2796
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    // Calculate how many notes will appear on wallpaper
    static func getWallpaperNoteCount(from notes: [Note]) -> Int {
        let activeNotes = notes.filter { !$0.isCompleted }
        return limitNotesToSafeArea(activeNotes).count
    }

    private static func limitNotesToSafeArea(_ notes: [Note]) -> [Note] {
        // Available space calculation
        // Screen height: 2796px
        // Top padding (below widgets): 1075px
        // Bottom safe area (above flashlight/camera): 2600px
        // Available height: 2600 - 1075 = 1525px
        let maxHeight: CGFloat = 1525
        let fontSize: CGFloat = 96
        let lineSpacing: CGFloat = 12
        let noteSeparatorHeight: CGFloat = 24 // \n\n between notes
        let width: CGFloat = 1290
        let horizontalPadding: CGFloat = 80
        let textMaxWidth = width - (horizontalPadding * 2)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = lineSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .paragraphStyle: paragraphStyle
        ]

        var notesToShow: [Note] = []
        var currentHeight: CGFloat = 0

        for note in notes {
            let attributedString = NSAttributedString(string: note.text, attributes: attributes)
            let textSize = attributedString.boundingRect(
                with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            let noteHeight = textSize.height + (notesToShow.isEmpty ? 0 : noteSeparatorHeight)

            if currentHeight + noteHeight <= maxHeight {
                notesToShow.append(note)
                currentHeight += noteHeight
            } else {
                break // Stop adding notes if we exceed the safe area
            }
        }

        return notesToShow
    }
}
