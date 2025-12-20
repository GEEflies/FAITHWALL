import SwiftUI

/// Admin view for viewing and managing promo codes
struct PromoCodeAdminView: View {
    let codeType: PromoCodeType
    @Binding var isPresented: Bool
    var onBackToSelection: (() -> Void)?
    
    @State private var allCodes: [String] = []
    @State private var usedCodes: Set<String> = []
    @State private var copiedCode: String?
    @State private var filterOption: FilterOption = .all
    @State private var searchText: String = ""
    @State private var showGenerateCodeSheet = false
    
    init(codeType: PromoCodeType, isPresented: Binding<Bool>, onBackToSelection: (() -> Void)? = nil) {
        self.codeType = codeType
        self._isPresented = isPresented
        self.onBackToSelection = onBackToSelection
    }
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case unused = "Unused"
        case used = "Used"
    }
    
    var body: some View {
        Group {
            if PromoCodeAuthManager.shared.isAuthenticated() {
                adminContentView
            } else {
                // Session expired, show login
                VStack {
                    Text("Session Expired")
                        .font(.title2)
                        .padding()
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private var adminContentView: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Stats header
                    statsHeader
                    
                    // Filter and search
                    filterSection
                    
                    // Codes list
                    codesList
                }
            }
            .navigationTitle("\(codeType.displayName) Codes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Logout") {
                            PromoCodeAuthManager.shared.endSession()
                            isPresented = false
                        }
                        .foregroundColor(.red)
                        
                        Button("Back") {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            if let onBack = onBackToSelection {
                                onBack()
                            } else {
                                isPresented = false
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Generate Code") {
                            showGenerateCodeSheet = true
                        }
                        Button("Copy All Unused") {
                            copyAllUnusedCodes()
                        }
                        Button("Copy All Codes") {
                            copyAllCodes()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showGenerateCodeSheet) {
            GenerateCodeSheet(
                isPresented: $showGenerateCodeSheet,
                codeType: codeType,
                onGenerate: { count in
                    generateCodesNow(count: count)
                }
            )
        }
        .onAppear {
            loadCodes()
            // Trigger backup when admin view appears (ensures codes are backed up)
            PromoCodeManager.shared.performBackupIfNeeded()
        }
    }
    
    private var statsHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                // Total codes
                VStack(spacing: 4) {
                    Text("\(allCodes.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.appAccent)
                    Text("Total")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                // Unused codes
                VStack(spacing: 4) {
                    Text("\(unusedCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("Unused")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                // Used codes
                VStack(spacing: 4) {
                    Text("\(usedCodes.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("Used")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            // Filter buttons
            HStack(spacing: 12) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Button(action: {
                        withAnimation {
                            filterOption = option
                        }
                    }) {
                        Text(option.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(filterOption == option ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(filterOption == option ? Color.appAccent : Color(.systemGray5))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search codes...", text: $searchText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }
    
    private var codesList: some View {
        let filteredCodes = filteredAndSearchedCodes
        
        return ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredCodes, id: \.self) { code in
                    codeRow(code: code)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    private func codeRow(code: String) -> some View {
        let isUsed = usedCodes.contains(code)
        let isCopied = copiedCode == code
        
        return HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(isUsed ? Color.orange : Color.green)
                .frame(width: 10, height: 10)
            
            // Code
            Text(code)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Status badge
            Text(isUsed ? "USED" : "AVAILABLE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isUsed ? .orange : .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill((isUsed ? Color.orange : Color.green).opacity(0.15))
                )
            
            // Copy button
            Button(action: {
                copyCode(code)
            }) {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 18))
                    .foregroundColor(isCopied ? .green : .appAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .opacity(isUsed ? 0.6 : 1.0)
    }
    
    // MARK: - Computed Properties
    
    private var unusedCount: Int {
        allCodes.count - usedCodes.count
    }
    
    private var filteredAndSearchedCodes: [String] {
        var codes = allCodes
        
        // Apply filter
        switch filterOption {
        case .all:
            break
        case .unused:
            codes = codes.filter { !usedCodes.contains($0) }
        case .used:
            codes = codes.filter { usedCodes.contains($0) }
        }
        
        // Apply search
        if !searchText.isEmpty {
            let search = searchText.uppercased().replacingOccurrences(of: "-", with: "")
            codes = codes.filter { code in
                code.uppercased().replacingOccurrences(of: "-", with: "").contains(search)
            }
        }
        
        // Sort: unused first, then used
        return codes.sorted { code1, code2 in
            let used1 = usedCodes.contains(code1)
            let used2 = usedCodes.contains(code2)
            if used1 != used2 {
                return !used1 // Unused first
            }
            return code1 < code2
        }
    }
    
    // MARK: - Actions
    
    private func loadCodes() {
        // Load codes for the specific type only
        allCodes = PromoCodeManager.shared.getCodes(type: codeType)
        
        // Load used codes for THIS SPECIFIC TYPE ONLY (completely separate)
        usedCodes = Set(PromoCodeManager.shared.getUsedCodesForTesting(type: codeType))
    }
    
    private func generateCodesNow(count: Int = 100) {
        PromoCodeManager.shared.generateCodes(count: count, type: codeType)
        loadCodes()
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        copiedCode = code
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Reset copied state after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedCode == code {
                copiedCode = nil
            }
        }
    }
    
    private func copyAllUnusedCodes() {
        let unusedCodes = allCodes.filter { !usedCodes.contains($0) }
        let codesText = unusedCodes.joined(separator: "\n")
        UIPasteboard.general.string = codesText
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func copyAllCodes() {
        let codesText = allCodes.joined(separator: "\n")
        UIPasteboard.general.string = codesText
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Generate Code Sheet

private struct GenerateCodeSheet: View {
    @Binding var isPresented: Bool
    let codeType: PromoCodeType
    let onGenerate: (Int) -> Void
    
    @State private var codeCount: Double = 100
    @State private var isGenerating = false
    
    private let minCount = 1
    private let maxCount = 100
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.15))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.appAccent)
                    }
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Generate \(codeType.displayName) Codes")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Choose how many unique codes to generate")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Slider section
                    VStack(spacing: 20) {
                        // Count display
                        VStack(spacing: 8) {
                            Text("\(Int(codeCount))")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundColor(.appAccent)
                            
                            Text("codes")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                        
                        // Slider
                        VStack(spacing: 12) {
                            HStack {
                                Text("\(minCount)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(maxCount)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $codeCount, in: Double(minCount)...Double(maxCount), step: 1)
                                .tint(.appAccent)
                                .onChange(of: codeCount) { newValue in
                                    // Haptic feedback on slider change
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 24)
                    
                    // Generate button
                    Button(action: {
                        guard !isGenerating else { return }
                        
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        isGenerating = true
                        
                        // Generate codes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onGenerate(Int(codeCount))
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isGenerating = false
                                isPresented = false
                                
                                // Success haptic
                                let successGenerator = UINotificationFeedbackGenerator()
                                successGenerator.notificationOccurred(.success)
                            }
                        }
                    }) {
                        HStack(spacing: 10) {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            Text(isGenerating ? "Generating..." : "Generate Codes")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isGenerating ? Color.gray.opacity(0.3) : Color.appAccent)
                        )
                    }
                    .disabled(isGenerating)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .padding(.vertical, 40)
            }
            .navigationTitle("Generate Codes")
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
    }
}


