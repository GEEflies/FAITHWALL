import SwiftUI

struct VerseReviewView: View {
    let verse: BibleVerse
    var onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedText: String
    @State private var charCount: Int = 0
    @FocusState private var isInputActive: Bool
    
    private let maxChars = 133
    
    init(verse: BibleVerse, onConfirm: @escaping (String) -> Void) {
        self.verse = verse
        self.onConfirm = onConfirm
        _editedText = State(initialValue: verse.text)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isInputActive = false
                    }
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Header Info
                            VStack(alignment: .leading, spacing: 8) {
                                Text(verse.reference)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.appAccent)
                                
                                Text(verse.translation.displayName)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.top, 24)
                            
                            // Character Count Indicator
                            HStack(spacing: 16) {
                                // Progress Circle
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.1), lineWidth: 4)
                                        .frame(width: 50, height: 50)
                                    
                                    Circle()
                                        .trim(from: 0, to: min(CGFloat(totalCount) / CGFloat(maxChars), 1.0))
                                        .stroke(isOverLimit ? Color.red : Color.appAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                        .frame(width: 50, height: 50)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.spring(), value: totalCount)
                                    
                                    if isOverLimit {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red)
                                    } else {
                                        Text("\(maxChars - totalCount)")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Widget Capacity")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                    
                                    Text("\(totalCount) of \(maxChars) characters used")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(isOverLimit ? .red : .secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(isOverLimit ? Color.red.opacity(0.05) : Color(.secondarySystemBackground))
                            )
                            .padding(.horizontal, DS.Spacing.xl)
                            
                            if isOverLimit {
                                HStack(spacing: 12) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.orange)
                                    
                                    Text("This verse is slightly too long for the widget. You can trim it below to ensure it fits perfectly.")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                }
                                .padding(16)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal, DS.Spacing.xl)
                                .transition(.opacity)
                            }
                            
                            // Editor
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Edit Verse Text", systemImage: "pencil.line")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                
                                ZStack(alignment: .topLeading) {
                                    if #available(iOS 16.0, *) {
                                        TextEditor(text: $editedText)
                                            .font(.system(size: 17, weight: .regular, design: .rounded))
                                            .frame(minHeight: 180)
                                            .scrollContentBackground(.hidden)
                                            .padding(12)
                                    } else {
                                        // Fallback on earlier versions
                                    }
                                }
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isOverLimit ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1.5)
                                )
                                .focused($isInputActive)
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                            
                            // Preview
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Widget Preview", systemImage: "iphone")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(verse.reference)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.appAccent)
                                    
                                    Text(editedText)
                                        .font(.system(size: 15, weight: .regular, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineSpacing(2)
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: Color.black.opacity(0.06), radius: 15, x: 0, y: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.bottom, 40)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isInputActive = false
                        }
                    }
                    
                    // Action Button
                    VStack(spacing: 0) {
                        Divider()
                            .padding(.bottom, 16)
                        
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            onConfirm(editedText)
                            dismiss()
                        }) {
                            HStack {
                                Text(isOverLimit ? "Add Anyway" : "Add to Lock Screen")
                                Image(systemName: "checkmark.circle.fill")
                            }
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isOverLimit ? Color.orange : Color.appAccent)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: (isOverLimit ? Color.orange : Color.appAccent).opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.bottom, 20)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isInputActive = false
                        }
                    }
                }
            }
        }
    }
    
    private var totalCount: Int {
        editedText.count + verse.reference.count + 1 // +1 for newline
    }
    
    private var isOverLimit: Bool {
        totalCount > maxChars
    }
}
