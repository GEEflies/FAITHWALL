import UIKit
import SwiftUI

struct WallpaperRenderer {
    static func generateWallpaper(
        from notes: [Note],
        backgroundColor: UIColor,
        backgroundImage: UIImage? = nil
    ) -> UIImage {
        print("🎨 WallpaperRenderer: Generating wallpaper")
        print("   Total notes: \(notes.count)")
        print("   Background image: \(backgroundImage != nil ? "YES" : "NO")")
        
        // iPhone wallpaper dimensions
        let width: CGFloat = 1290
        let height: CGFloat = 2796

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { context in
            let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)

            backgroundColor.setFill()
            context.fill(canvasRect)

            if let image = backgroundImage {
                drawBackground(image: image, in: canvasRect, on: context.cgContext)
                print("   ✅ Drew background image")
            }

            // Include all notes (both active and completed) and limit to notes that fit
            let notesToShow = limitNotesToSafeArea(notes)
            
            let activeNotes = notes.filter { !$0.isCompleted }
            let completedNotes = notes.filter { $0.isCompleted }
            print("   Active notes: \(activeNotes.count)")
            print("   Completed notes: \(completedNotes.count)")
            print("   Notes to show: \(notesToShow.count)")

            guard !notesToShow.isEmpty else {
                print("   ⚠️ NO NOTES TO SHOW - Wallpaper will be blank")
                return
            }

            // Text attributes - white, left-aligned
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineSpacing = 12

            // Increased font size for better visibility
            let fontSize: CGFloat = 96
            let baseTextColor = textColorForBackground(
                backgroundColor: backgroundColor,
                backgroundImage: backgroundImage
            )
            
            // App accent color for strikethrough (cyan: RGB 0, 0.768, 0.722)
            let accentColor = UIColor(red: 0.0, green: 0.768, blue: 0.722, alpha: 1.0)
            
            print("   🎨 Text color: \(baseTextColor == .white ? "WHITE" : "BLACK")")

            // Build attributed string with strikethrough for completed notes
            let attributedString = NSMutableAttributedString()
            
            for (index, note) in notesToShow.enumerated() {
                if index > 0 {
                    // Add separator between notes
                    attributedString.append(NSAttributedString(string: "\n\n"))
                }
                
                // Base attributes for all notes
                var noteAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                    .paragraphStyle: paragraphStyle
                ]
                
                if note.isCompleted {
                    // Completed notes: dimmed text color and strikethrough
                    let dimmedColor = baseTextColor.withAlphaComponent(0.5)
                    noteAttributes[.foregroundColor] = dimmedColor
                    noteAttributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                    noteAttributes[.strikethroughColor] = accentColor
                } else {
                    // Active notes: normal text color
                    noteAttributes[.foregroundColor] = baseTextColor
                }
                
                let noteAttributedString = NSAttributedString(string: note.text, attributes: noteAttributes)
                attributedString.append(noteAttributedString)
            }
            
            print("   📝 Combined text length: \(attributedString.length) chars")

            // Calculate text size and position
            let horizontalPadding: CGFloat = 80
            // Position text below time and widgets - moved further down
            // For iPhone 14 Pro (2796px height), this positions text lower on the screen
            let topPadding: CGFloat = 1075 // Increased to move notes further down towards bottom
            let textMaxWidth = width - (horizontalPadding * 2)

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
            
            print("   📍 Text rect: x=\(horizontalPadding), y=\(topPadding), w=\(textMaxWidth), h=\(textSize.height)")

            // Draw attributed text
            attributedString.draw(in: textRect)
            print("   ✅ Drew text on wallpaper (with strikethrough for completed notes)")
        }
    }

    static func generateBlankWallpaper(
        backgroundColor: UIColor,
        backgroundImage: UIImage? = nil
    ) -> UIImage {
        let width: CGFloat = 1290
        let height: CGFloat = 2796
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)

            backgroundColor.setFill()
            context.fill(canvasRect)

            if let image = backgroundImage {
                drawBackground(image: image, in: canvasRect, on: context.cgContext)
            }
        }
    }

    // Calculate how many notes will appear on wallpaper
    static func getWallpaperNoteCount(from notes: [Note]) -> Int {
        // Include all notes (both active and completed) in the count
        return limitNotesToSafeArea(notes).count
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

    private static func drawBackground(image: UIImage, in canvasRect: CGRect, on context: CGContext) {
        let canvasSize = canvasRect.size
        let imageSize = image.size

        let coverScale = max(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let coverSize = CGSize(width: imageSize.width * coverScale, height: imageSize.height * coverScale)
        let coverOrigin = CGPoint(
            x: (canvasSize.width - coverSize.width) / 2,
            y: (canvasSize.height - coverSize.height) / 2
        )

        image.draw(in: CGRect(origin: coverOrigin, size: coverSize))

        context.setFillColor(UIColor.black.withAlphaComponent(0.18).cgColor)
        context.fill(canvasRect)
    }

    private static func textColorForBackground(backgroundColor: UIColor, backgroundImage: UIImage?) -> UIColor {
        let brightness: CGFloat

        if let image = backgroundImage {
            brightness = averageBrightness(of: image)
        } else {
            brightness = brightnessOfColor(backgroundColor)
        }

        // Threshold chosen so mid-tone images still get high-contrast text.
        if brightness < 0.55 {
            return UIColor.white
        } else {
            return UIColor.black.withAlphaComponent(0.9)
        }
    }

    private static func brightnessOfColor(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var white: CGFloat = 0
        var alpha: CGFloat = 0

        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return 0.299 * red + 0.587 * green + 0.114 * blue
        } else if color.getWhite(&white, alpha: &alpha) {
            return white
        } else if let components = color.cgColor.components, components.count >= 3 {
            return 0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2]
        }

        return 0.5
    }

    private static func averageBrightness(of image: UIImage) -> CGFloat {
        let sampleSize = CGSize(width: 12, height: 12)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: sampleSize, format: format)
        let downsampled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: sampleSize))
        }

        guard let cgImage = downsampled.cgImage,
              let data = cgImage.dataProvider?.data,
              let pointer = CFDataGetBytePtr(data) else {
            return 0.5
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        guard bytesPerPixel >= 3 else { return 0.5 }

        var total: CGFloat = 0
        let width = Int(sampleSize.width)
        let height = Int(sampleSize.height)

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * cgImage.bytesPerRow) + (x * bytesPerPixel)
                let r = CGFloat(pointer[index])
                let g = CGFloat(pointer[index + 1])
                let b = CGFloat(pointer[index + 2])
                total += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            }
        }

        let pixelCount = CGFloat(width * height)
        guard pixelCount > 0 else { return 0.5 }
        return total / pixelCount
    }
}
