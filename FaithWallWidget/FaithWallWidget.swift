import WidgetKit
import SwiftUI

extension View {
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            return containerBackground(for: .widget) {
                color
            }
        } else {
            return background(color)
        }
    }
    
    func widgetBackground<V: View>(_ view: V) -> some View {
        if #available(iOS 17.0, *) {
            return containerBackground(for: .widget) {
                view
            }
        } else {
            return background(view)
        }
    }
}

// MARK: - Shared Data Keys
// These keys must match the main app's UserDefaults keys

struct WidgetSharedData {
    static let appGroupIdentifier = "group.faithwall.shared"
    
    // Keys matching the main app
    static let savedNotesKey = "savedNotes"
    static let currentNoteIndexKey = "currentNoteIndex"
    static let lastWidgetUpdateKey = "lastWidgetUpdate"
    
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
}

// MARK: - Note Model (matching main app exactly)

struct WidgetNote: Codable, Identifiable {
    let id: UUID
    var text: String
    var isCompleted: Bool
    
    init(id: UUID = UUID(), text: String, isCompleted: Bool = false) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
    }
}

// MARK: - Timeline Provider

struct FaithWallProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> FaithWallEntry {
        FaithWallEntry(
            date: Date(),
            note: "Be strong and courageous. Do not be afraid; do not be discouraged, for the LORD your God will be with you wherever you go.",
            reference: "Joshua 1:9"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FaithWallEntry) -> Void) {
        let entry = getCurrentEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<FaithWallEntry>) -> Void) {
        let entry = getCurrentEntry()
        
        // Update every hour to cycle through notes
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func getCurrentEntry() -> FaithWallEntry {
        // Try to get notes from shared UserDefaults (App Group)
        if let defaults = WidgetSharedData.sharedDefaults,
           let data = defaults.data(forKey: WidgetSharedData.savedNotesKey) {
            
            let decoder = JSONDecoder()
            if let notes = try? decoder.decode([WidgetNote].self, from: data), !notes.isEmpty {
                // Get current note index or use 0
                let currentIndex = defaults.integer(forKey: WidgetSharedData.currentNoteIndexKey)
                let noteIndex = currentIndex % notes.count
                let note = notes[noteIndex]
                
                // Increment index for next time
                defaults.set((currentIndex + 1) % notes.count, forKey: WidgetSharedData.currentNoteIndexKey)
                defaults.set(Date(), forKey: WidgetSharedData.lastWidgetUpdateKey)
                
                // Parse note text for reference if it contains one
                let (verseText, reference) = parseNoteForReference(note.text)
                
                return FaithWallEntry(
                    date: Date(),
                    note: verseText,
                    reference: reference
                )
            }
        }
        
        // Default entry if no notes found
        return FaithWallEntry(
            date: Date(),
            note: "Open FaithWall to add your first Bible verse note",
            reference: "Tap to get started"
        )
    }
    
    private func parseNoteForReference(_ text: String) -> (verse: String, reference: String?) {
        // Try to find common Bible reference patterns
        // E.g., "- John 3:16", "— Psalm 23:1", "(Romans 8:28)"
        
        let patterns = [
            "—\\s*([A-Za-z]+\\s*\\d+:\\d+(?:-\\d+)?)",
            "-\\s*([A-Za-z]+\\s*\\d+:\\d+(?:-\\d+)?)",
            "\\(([A-Za-z]+\\s*\\d+:\\d+(?:-\\d+)?)\\)",
            "([A-Za-z]+\\s*\\d+:\\d+(?:-\\d+)?)$"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                
                if let referenceRange = Range(match.range(at: 1), in: text) {
                    let reference = String(text[referenceRange])
                    
                    // Remove the reference from the verse text
                    var verseText = text
                    if let fullMatchRange = Range(match.range, in: text) {
                        verseText = text.replacingCharacters(in: fullMatchRange, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    return (verseText, reference)
                }
            }
        }
        
        return (text, nil)
    }
}

// MARK: - Custom Shapes

struct LatinCross: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let thickness = width * 0.35
        
        // Vertical bar
        let verticalRect = CGRect(x: (width - thickness) / 2, y: 0, width: thickness, height: height)
        path.addRoundedRect(in: verticalRect, cornerSize: CGSize(width: 0.5, height: 0.5))
        
        // Horizontal bar
        let crossBarY = height * 0.25
        let horizontalRect = CGRect(x: 0, y: crossBarY, width: width, height: thickness)
        path.addRoundedRect(in: horizontalRect, cornerSize: CGSize(width: 0.5, height: 0.5))
        
        return path
    }
}

// MARK: - Timeline Entry

struct FaithWallEntry: TimelineEntry {
    let date: Date
    let note: String
    let reference: String?
}

// MARK: - Widget Views

struct FaithWallWidgetEntryView: View {
    var entry: FaithWallProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            if #available(iOS 16.0, *) {
                AccessoryCircularView(entry: entry)
            } else {
                EmptyView()
            }
        case .accessoryRectangular:
            if #available(iOS 16.0, *) {
                AccessoryRectangularView(entry: entry)
            } else {
                EmptyView()
            }
        case .accessoryInline:
            if #available(iOS 16.0, *) {
                AccessoryInlineView(entry: entry)
            } else {
                EmptyView()
            }
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: FaithWallEntry
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.6, blue: 0.3), Color(red: 0.9, green: 0.5, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 6) {
                // Cross icon
                LatinCross()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 12, height: 16)
                
                Spacer()
                
                // Bible verse text
                Text(entry.note)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                
                // Reference
                if let reference = entry.reference {
                    Text(reference)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(12)
        }
        .widgetBackground(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.6, blue: 0.3), Color(red: 0.9, green: 0.5, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: FaithWallEntry
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.6, blue: 0.3), Color(red: 0.9, green: 0.5, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack(spacing: 16) {
                // Left side - icon
                VStack {
                    LatinCross()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 24, height: 32)
                    
                    Spacer()
                    
                    Text("FaithWall")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(width: 60)
                
                // Right side - content
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.note)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                    
                    if let reference = entry.reference {
                        Text(reference)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            .padding(16)
        }
        .widgetBackground(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.6, blue: 0.3), Color(red: 0.9, green: 0.5, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: FaithWallEntry
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.6, blue: 0.3), Color(red: 0.85, green: 0.45, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .center, spacing: 16) {
                // Header
                HStack {
                    LatinCross()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 20, height: 28)
                    
                    Text("FaithWall")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Spacer()
                
                // Bible verse
                VStack(spacing: 12) {
                    Text("“")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text(entry.note)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    
                    if let reference = entry.reference {
                        Text("— \(reference)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                // Footer
                Text("Tap to open app")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
        }
        .widgetBackground(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.6, blue: 0.3), Color(red: 0.85, green: 0.45, blue: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Lock Screen Widgets (iOS 16+)

@available(iOS 16.0, *)
struct AccessoryCircularView: View {
    let entry: FaithWallEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            LatinCross()
                .fill(Color.primary)
                .frame(width: 18, height: 24)
        }
        .widgetBackground(Color.clear)
    }
}

@available(iOS 16.0, *)
struct AccessoryRectangularView: View {
    let entry: FaithWallEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Verse text only - no reference (reference moved to Logo widget)
            Text(entry.note)
                .font(.system(size: 11))
                .lineLimit(4)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetBackground(Color.clear)
    }
}

@available(iOS 16.0, *)
struct AccessoryInlineView: View {
    let entry: FaithWallEntry
    
    var body: some View {
        HStack(spacing: 4) {
            LatinCross()
                .fill(Color.primary)
                .frame(width: 10, height: 12)
            Text(entry.note)
                .lineLimit(1)
        }
        .widgetBackground(Color.clear)
    }
}

// MARK: - Widget Configuration

struct FaithWallWidget: Widget {
    let kind: String = "FaithWallWidget"
    
    var families: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [
                .systemSmall,
                .systemMedium,
                .systemLarge,
                .accessoryRectangular,
                .accessoryInline
            ]
        } else {
            return [
                .systemSmall,
                .systemMedium,
                .systemLarge
            ]
        }
    }
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FaithWallProvider()) { entry in
            FaithWallWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FaithWall Verse")
        .description("Daily Bible verses to strengthen your faith")
        .supportedFamilies(families)
    }
}

// MARK: - Branding Widget (Lock Screen)

struct FaithWallBrandingWidget: Widget {
    let kind: String = "FaithWallBrandingWidget"
    
    var body: some WidgetConfiguration {
        if #available(iOS 16.0, *) {
            return StaticConfiguration(kind: kind, provider: FaithWallProvider()) { entry in
                BrandingRectangularView(entry: entry)
            }
            .configurationDisplayName("FaithWall Logo")
            .description("Shows the verse reference - pair with your verse widget")
            .supportedFamilies([.accessoryRectangular])
        } else {
            return StaticConfiguration(kind: kind, provider: FaithWallProvider()) { entry in
                EmptyView()
            }
            .configurationDisplayName("FaithWall Logo")
            .description("Brand widget to pair with your verse widget")
            .supportedFamilies([])
        }
    }
}

@available(iOS 16.0, *)
struct BrandingRectangularView: View {
    let entry: FaithWallEntry
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            // Top row: Cross + FaithWall
            HStack(spacing: 6) {
                LatinCross()
                    .fill(Color.primary)
                    .frame(width: 16, height: 22)
                
                Text("FaithWall")
                    .font(.system(size: 15, weight: .bold))
            }
            
            // Bottom row: Bible reference
            if let reference = entry.reference {
                Text(reference)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text("Select a verse")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(Color.clear)
    }
}

@available(iOS 16.0, *)
struct BrandingCircularView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            LatinCross()
                .fill(Color.primary)
                .frame(width: 20, height: 26)
        }
        .widgetBackground(Color.clear)
    }
}

// MARK: - Widget Bundle

@main
struct FaithWallWidgetBundle: WidgetBundle {
    var body: some Widget {
        FaithWallWidget()
        FaithWallBrandingWidget()
    }
}

// MARK: - Preview

#if DEBUG
struct FaithWallWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FaithWallWidgetEntryView(entry: FaithWallEntry(
                date: Date(),
                note: "For I know the plans I have for you, declares the LORD, plans to prosper you and not to harm you.",
                reference: "Jeremiah 29:11"
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small")
            
            FaithWallWidgetEntryView(entry: FaithWallEntry(
                date: Date(),
                note: "For I know the plans I have for you, declares the LORD, plans to prosper you and not to harm you, plans to give you hope and a future.",
                reference: "Jeremiah 29:11"
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium")
            
            FaithWallWidgetEntryView(entry: FaithWallEntry(
                date: Date(),
                note: "Be strong and courageous. Do not be afraid; do not be discouraged, for the LORD your God will be with you wherever you go.",
                reference: "Joshua 1:9"
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large")
            
            if #available(iOS 16.0, *) {
                FaithWallWidgetEntryView(entry: FaithWallEntry(
                    date: Date(),
                    note: "Trust in the LORD",
                    reference: nil
                ))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Lock Screen Rectangular")
            }
        }
    }
}
#endif
