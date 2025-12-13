import SwiftUI

/// View for selecting promo code type (Lifetime or Monthly)
struct PromoCodeTypeSelectionView: View {
    @Binding var isPresented: Bool
    @State private var selectedType: PromoCodeType?
    @State private var showAdminView = false
    @State private var currentAdminType: PromoCodeType?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Enhanced background gradient
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color(.systemGroupedBackground).opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header section with icon
                    VStack(spacing: 16) {
                        // Icon badge
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccent.opacity(0.2), Color.appAccent.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(.appAccent)
                        }
                        .padding(.top, 20)
                        
                        // Title
                        VStack(spacing: 8) {
                            Text("Promo Code Manager")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Select which type of codes to manage")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    
                    // Type selection cards with improved design
                    VStack(spacing: 16) {
                        // Lifetime option
                        typeCard(
                            type: .lifetime,
                            icon: "infinity",
                            title: "Lifetime Codes",
                            description: "Codes that grant permanent access",
                            color: .appAccent,
                            gradientColors: [Color.appAccent.opacity(0.15), Color.appAccent.opacity(0.05)]
                        )
                        
                        // Monthly option
                        typeCard(
                            type: .monthly,
                            icon: "calendar",
                            title: "Monthly Codes",
                            description: "Codes that grant 1 month of access",
                            color: .blue,
                            gradientColors: [Color.blue.opacity(0.15), Color.blue.opacity(0.05)]
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
            .navigationTitle("Promo Codes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showAdminView) {
            if let type = currentAdminType {
                PromoCodeAdminView(
                    codeType: type,
                    isPresented: $showAdminView,
                    onBackToSelection: {
                        showAdminView = false
                        currentAdminType = nil
                    }
                )
            }
        }
        .onChange(of: selectedType) { newType in
            if let type = newType {
                currentAdminType = type
                showAdminView = true
                selectedType = nil // Reset for next time
            }
        }
    }
    
    private func typeCard(type: PromoCodeType, icon: String, title: String, description: String, color: Color, gradientColors: [Color]) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            selectedType = type
        }) {
            HStack(spacing: 20) {
                // Enhanced icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.2), lineWidth: 1.5)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(color)
                }
                
                // Text with better spacing
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Enhanced chevron
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(color.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}


