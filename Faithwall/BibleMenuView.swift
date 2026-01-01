import SwiftUI

// MARK: - Bible Menu View
/// Main menu for accessing Bible features - Explore or Search
struct BibleMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = BibleLanguageManager.shared
    
    @State private var showExplorer = false
    @State private var showSearch = false
    
    var onVerseSelected: ((BibleVerse) -> Void)?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Open Bible")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Choose how you'd like to find verses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 32)
                
                // Options
                VStack(spacing: 16) {
                    // Explore Button
                    Button(action: {
                        showExplorer = true
                    }) {
                        MenuOptionCard(
                            icon: "books.vertical.fill",
                            title: "Explore",
                            description: "Browse by books and chapters",
                            color: .blue
                        )
                    }
                    
                    // Search Button
                    Button(action: {
                        showSearch = true
                    }) {
                        MenuOptionCard(
                            icon: "magnifyingglass",
                            title: "Search",
                            description: "Find verses by keywords",
                            color: .purple
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Current Translation
                HStack(spacing: 8) {
                    Text(languageManager.selectedTranslation.flagEmoji)
                    Text("Using \(languageManager.selectedTranslation.shortName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showExplorer) {
            BibleExplorerView { verse in
                onVerseSelected?(verse)
                showExplorer = false
                dismiss()
            }
        }
        .sheet(isPresented: $showSearch) {
            BibleSearchView { verse in
                onVerseSelected?(verse)
                showSearch = false
                dismiss()
            }
        }
    }
}

// MARK: - Menu Option Card
private struct MenuOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview
#Preview {
    BibleMenuView { verse in
        print("Selected: \(verse.reference)")
    }
}
