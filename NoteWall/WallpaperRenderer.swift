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

            // Prepare text
            let combinedText = notes.map { $0.text }.joined(separator: "\n\n")

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
}
