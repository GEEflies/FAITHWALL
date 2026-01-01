import SwiftUI
import UIKit
import WidgetKit

// MARK: - Widget Onboarding State

enum WidgetOnboardingPage: Int, CaseIterable {
    case intro           // Welcome to widgets
    case selectVerse     // Select initial verse
    case selectLocation  // Choose home screen or lock screen
    case addWidget       // Guide to add widget
    case verification    // Verify widget was added
    case complete        // Success!
    
    var stepNumber: Int {
        switch self {
        case .intro: return 1
        case .selectVerse: return 2
        case .selectLocation: return 3
        case .addWidget: return 4
        case .verification: return 5
        case .complete: return 6
        }
    }
    
    static var totalSteps: Int { 5 } // Not counting complete
    
    var progressTitle: String {
        switch self {
        case .intro: return "Introduction"
        case .selectVerse: return "Select Verse"
        case .selectLocation: return "Choose Location"
        case .addWidget: return "Add Widget"
        case .verification: return "Verify"
        case .complete: return "Complete"
        }
    }
}

// MARK: - Widget Location Options

enum WidgetLocation: String, CaseIterable {
    case homeScreen = "home_screen"
    case lockScreen = "lock_screen"
    
    var displayName: String {
        switch self {
        case .homeScreen: return "Home Screen"
        case .lockScreen: return "Lock Screen"
        }
    }
    
    var icon: String {
        switch self {
        case .homeScreen: return "apps.iphone"
        case .lockScreen: return "lock.iphone"
        }
    }
    
    var description: String {
        switch self {
        case .homeScreen: return "See Bible verses among your apps"
        case .lockScreen: return "See Bible verses when you wake your phone"
        }
    }
}

// MARK: - Widget Onboarding View

struct WidgetOnboardingView: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    
    @State private var currentPage: WidgetOnboardingPage = .intro
    @State private var selectedLocation: WidgetLocation = .homeScreen
    @AppStorage("widgetOnboardingCompleted") private var widgetOnboardingCompleted = false
    @AppStorage("selectedWidgetLocation") private var selectedWidgetLocationRaw = ""
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.98, blue: 0.97), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                if currentPage != .complete {
                    widgetProgressIndicator
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                }
                
                // Content
                Group {
                    switch currentPage {
                    case .intro:
                        WidgetIntroView {
                            advanceStep()
                        }
                    case .selectVerse:
                        WidgetVerseSelectionView {
                            advanceStep()
                        }
                    case .selectLocation:
                        WidgetLocationSelectionView(selectedLocation: $selectedLocation) {
                            selectedWidgetLocationRaw = selectedLocation.rawValue
                            advanceStep()
                        }
                    case .addWidget:
                        WidgetAddGuideView(location: selectedLocation) {
                            advanceStep()
                        }
                    case .verification:
                        WidgetVerificationView {
                            advanceStep()
                        }
                    case .complete:
                        WidgetCompleteView {
                            widgetOnboardingCompleted = true
                            onComplete()
                        }
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Progress Indicator
    
    private var widgetProgressIndicator: some View {
        HStack(alignment: .center, spacing: 12) {
            ForEach(WidgetOnboardingPage.allCases.filter { $0 != .complete }, id: \.self) { page in
                progressIndicatorItem(for: page)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func progressIndicatorItem(for page: WidgetOnboardingPage) -> some View {
        let isCompleted = page.rawValue < currentPage.rawValue
        let isCurrent = page == currentPage
        
        // Match OnboardingView styling
        let circleFill: Color = (isCurrent || isCompleted) ? Color.appAccent : Color(.systemGray5)
        let circleTextColor: Color = (isCurrent || isCompleted) ? .white : Color(.secondaryLabel)
        
        // Compact mode values from OnboardingView
        let circleSize: CGFloat = 40
        let circleStrokeOpacity: Double = isCurrent ? 0.28 : 0.18
        let circleStrokeWidth: CGFloat = 1
        let circleFontSize: CGFloat = 18
        
        return ZStack {
            Circle()
                .fill(circleFill)
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(circleStrokeOpacity), lineWidth: circleStrokeWidth)
                )
            
            Text("\(page.stepNumber)")
                .font(.system(size: circleFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(circleTextColor)
        }
    }
    
    // MARK: - Navigation
    
    private func advanceStep() {
        guard let next = WidgetOnboardingPage(rawValue: currentPage.rawValue + 1) else {
            return
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation(.easeInOut) {
            currentPage = next
        }
    }
}

// MARK: - Widget Verse Selection View

struct WidgetVerseSelectionView: View {
    let onContinue: () -> Void
    
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var selectedTab = 1 // Default to Explore
    @State private var manualText = ""
    @State private var manualReference = ""
    @State private var searchText = ""
    @State private var searchResults: [BibleVerse] = []
    @State private var isSearching = false
    @State private var showVersionPicker = false
    @State private var selectedVerseForConfirmation: BibleVerse?
    @State private var showConfirmationAlert = false
    @State private var contentOpacity: Double = 0
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Choose Your Verse")
                    .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Select the first verse to display on your widget")
                    .font(.system(size: isCompact ? 14 : 16))
                    .foregroundColor(.secondary)
            }
            .padding(.top, isCompact ? 20 : 30)
            .padding(.horizontal)
            .opacity(contentOpacity)
            
            // Custom Tab Bar
            HStack(spacing: 0) {
                tabButton(title: "Explore", icon: "book.fill", index: 1)
                tabButton(title: "Search", icon: "magnifyingglass", index: 2)
                tabButton(title: "Write", icon: "pencil", index: 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            .opacity(contentOpacity)
            
            // Content
            TabView(selection: $selectedTab) {
                // Manual Entry
                manualEntryView
                    .tag(0)
                
                // Explore
                exploreView
                    .tag(1)
                
                // Search
                searchView
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
        .sheet(isPresented: $showVersionPicker) {
            SettingsVersionSheet(
                languageManager: languageManager,
                onDismiss: { showVersionPicker = false }
            )
        }
        .alert(isPresented: $showConfirmationAlert) {
            Alert(
                title: Text("Use this verse?"),
                message: Text(selectedVerseForConfirmation?.text ?? ""),
                primaryButton: .default(Text("Yes"), action: {
                    if let verse = selectedVerseForConfirmation {
                        saveVerseAndContinue(text: verse.text, reference: verse.reference)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
    }
    
    // MARK: - Tab Button
    
    private func tabButton(title: String, icon: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .appAccent : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.appAccent.opacity(0.1) : Color.clear)
            )
        }
    }
    
    // MARK: - Version Button
    
    private var versionButton: some View {
        Button(action: {
            showVersionPicker = true
        }) {
            HStack(spacing: 4) {
                if languageManager.isDownloading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Text(languageManager.selectedTranslation.shortName)
                    .font(.system(size: 13, weight: .semibold))
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.appAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.appAccent.opacity(0.1))
            )
        }
    }
    
    // MARK: - Manual Entry
    
    private var manualEntryView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verse Text")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                TextEditor(text: $manualText)
                    .frame(height: 120)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Reference")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                TextField("e.g. John 3:16", text: $manualReference)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            }
            
            Spacer()
            
            Button(action: {
                saveVerseAndContinue(text: manualText, reference: manualReference)
            }) {
                Text("Use This Verse")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(manualText.isEmpty ? Color.gray.opacity(0.5) : Color.appAccent)
                    .cornerRadius(16)
                    .shadow(color: manualText.isEmpty ? .clear : .appAccent.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(manualText.isEmpty)
            .padding(.bottom)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Explore View
    
    private var exploreView: some View {
        VStack(spacing: 0) {
            // Version selector header
            HStack {
                Text("Browse Books")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                versionButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // Embedded Explorer
            // We use a simplified version of BibleExplorerView logic here or embed it
            // Since BibleExplorerView has its own NavigationView, we might need to be careful.
            // Let's use a custom implementation that fits better here.
            
            BibleBookListView(
                languageManager: languageManager,
                onVerseSelected: { verse in
                    selectedVerseForConfirmation = verse
                    showConfirmationAlert = true
                }
            )
        }
    }
    
    // MARK: - Search View
    
    private var searchView: some View {
        VStack(spacing: 0) {
            // Search Bar & Version
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search verses...", text: $searchText)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                
                versionButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Results
            if isSearching {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if !searchResults.isEmpty {
                List(searchResults) { verse in
                    Button(action: {
                        selectedVerseForConfirmation = verse
                        showConfirmationAlert = true
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(verse.reference)
                                    .font(.headline)
                                    .foregroundColor(.appAccent)
                                
                                Spacer()
                                
                                Text(verse.translation.shortName)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.appAccent.opacity(0.1))
                                    .cornerRadius(4)
                                    .foregroundColor(.appAccent)
                            }
                            
                            Text(verse.text)
                                .font(.body)
                                .foregroundColor(.primary.opacity(0.8))
                                .lineLimit(3)
                                .lineSpacing(2)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.plain)
            } else if !searchText.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No verses found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different search term or Bible version")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.appAccent.opacity(0.3))
                    
                    Text("Search for Bible Verse")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Type keywords like 'love', 'hope', or 'strength' to find verses.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            }
        }
        .onChange(of: searchText) { newValue in
            if newValue.count > 2 {
                performSearch()
            }
        }
        .onChange(of: languageManager.selectedTranslation) { _ in
            if !searchText.isEmpty {
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        
        // Debounce slightly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Check if text changed since
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let results = try BibleDatabaseService.shared.searchVerses(
                        query: searchText,
                        translation: languageManager.selectedTranslation
                    )
                    
                    DispatchQueue.main.async {
                        self.searchResults = results
                        self.isSearching = false
                    }
                } catch {
                    print("Search error: \(error)")
                    DispatchQueue.main.async {
                        self.isSearching = false
                    }
                }
            }
        }
    }
    
    private func saveVerseAndContinue(text: String, reference: String) {
        let fullText = reference.isEmpty ? text : "\(text) - \(reference)"
        let note = Note(text: fullText, isCompleted: false)
        
        if let defaults = UserDefaults(suiteName: "group.faithwall.shared") {
            if let encoded = try? JSONEncoder().encode([note]) {
                defaults.set(encoded, forKey: "savedNotes")
                defaults.set(0, forKey: "currentNoteIndex")
                defaults.set(Date(), forKey: "lastWidgetUpdate")
                
                // Reload widget
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
        
        onContinue()
    }
}

// MARK: - Bible Book List View (Embedded)

struct BibleBookListView: View {
    @ObservedObject var languageManager: BibleLanguageManager
    var onVerseSelected: (BibleVerse) -> Void
    
    @State private var books: [BibleBook] = []
    @State private var isLoading = true
    @State private var selectedBook: BibleBook?
    @State private var selectedChapter: Int?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    List {
                        Section(header: Text("Old Testament")) {
                            ForEach(books.filter { $0.testament == .old }) { book in
                                NavigationLink(destination: ChapterPickerView(book: book, onVerseSelected: onVerseSelected)) {
                                    Text(book.name)
                                }
                            }
                        }
                        
                        Section(header: Text("New Testament")) {
                            ForEach(books.filter { $0.testament == .new }) { book in
                                NavigationLink(destination: ChapterPickerView(book: book, onVerseSelected: onVerseSelected)) {
                                    Text(book.name)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadBooks()
        }
        .onChange(of: languageManager.selectedTranslation) { _ in
            loadBooks()
        }
    }
    
    private func loadBooks() {
        isLoading = true
        
        // Check if translation is downloaded
        guard languageManager.isSelectedTranslationReady else {
            // If not ready, it should be downloading via the manager/picker
            // We can just wait or show loading
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let loadedBooks = try BibleDatabaseService.shared.getBooks(for: languageManager.selectedTranslation)
                DispatchQueue.main.async {
                    self.books = loadedBooks
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Widget Intro View

struct WidgetIntroView: View {
    let onContinue: () -> Void
    
    @State private var contentOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var buttonOpacity: Double = 0
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: isCompact ? 40 : 60)
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.15))
                            .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                        
                        Image(systemName: "rectangle.grid.1x2.fill")
                            .font(.system(size: isCompact ? 44 : 52, weight: .medium))
                            .foregroundColor(.appAccent)
                    }
                    .scaleEffect(iconScale)
                    
                    Spacer(minLength: isCompact ? 24 : 36)
                    
                    // Title and description
                    VStack(spacing: isCompact ? 12 : 16) {
                        Text("Add a Bible Verse Widget")
                            .font(.system(size: isCompact ? 26 : 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("In just a few taps, you'll have daily Bible verses visible on your phone at a glance.")
                            .font(.system(size: isCompact ? 15 : 17))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                    }
                    .opacity(contentOpacity)
                    
                    Spacer(minLength: isCompact ? 24 : 40)
                    
                    // Benefits
                    VStack(spacing: isCompact ? 12 : 16) {
                        WidgetBenefitRow(icon: "clock.fill", text: "Takes less than 1 minute")
                        WidgetBenefitRow(icon: "sparkles", text: "Beautiful Bible verse display")
                        WidgetBenefitRow(icon: "arrow.triangle.2.circlepath", text: "Updates automatically")
                    }
                    .opacity(contentOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                    
                    Spacer(minLength: isCompact ? 60 : 80)
                }
            }
            
            // Continue button
            VStack(spacing: 0) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onContinue()
                }) {
                    Text("Let's Get Started")
                        .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                        .frame(height: isCompact ? 48 : 56)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
            }
            .padding(.horizontal, isCompact ? 16 : 24)
            .padding(.bottom, isCompact ? 16 : 22)
            .opacity(buttonOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                contentOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                buttonOpacity = 1
            }
        }
    }
}

// MARK: - Widget Benefit Row

struct WidgetBenefitRow: View {
    let icon: String
    let text: String
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        HStack(spacing: isCompact ? 12 : 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: isCompact ? 40 : 48, height: isCompact ? 40 : 48)
                
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 16 : 20))
                    .foregroundColor(.appAccent)
            }
            
            Text(text)
                .font(.system(size: isCompact ? 15 : 17, weight: .medium))
                .foregroundColor(.primary.opacity(0.8))
            
            Spacer()
        }
        .padding(.vertical, isCompact ? 8 : 12)
        .padding(.horizontal, isCompact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 12 : 14, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
    }
}

// MARK: - Widget Location Selection View

struct WidgetLocationSelectionView: View {
    @Binding var selectedLocation: WidgetLocation
    let onContinue: () -> Void
    
    @State private var contentOpacity: Double = 0
    @State private var cardsOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: isCompact ? 30 : 50)
                    
                    // Title
                    VStack(spacing: isCompact ? 8 : 12) {
                        Text("Where do you want it?")
                            .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("Choose where you'd like to see your Bible verse widget")
                            .font(.system(size: isCompact ? 14 : 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(contentOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                    
                    Spacer(minLength: isCompact ? 24 : 36)
                    
                    // Location options
                    VStack(spacing: isCompact ? 12 : 16) {
                        ForEach(WidgetLocation.allCases, id: \.self) { location in
                            WidgetLocationCard(
                                location: location,
                                isSelected: selectedLocation == location
                            ) {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                selectedLocation = location
                            }
                        }
                    }
                    .opacity(cardsOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                    
                    Spacer(minLength: isCompact ? 60 : 80)
                }
            }
            
            // Continue button
            VStack(spacing: 0) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                        .frame(height: isCompact ? 48 : 56)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
            }
            .padding(.horizontal, isCompact ? 16 : 24)
            .padding(.bottom, isCompact ? 16 : 22)
            .opacity(buttonOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                cardsOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                buttonOpacity = 1
            }
        }
    }
}

// MARK: - Widget Location Card

struct WidgetLocationCard: View {
    let location: WidgetLocation
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: isCompact ? 14 : 18) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous)
                        .fill(isSelected ? Color.appAccent.opacity(0.2) : Color.black.opacity(0.05))
                        .frame(width: isCompact ? 52 : 64, height: isCompact ? 52 : 64)
                    
                    Image(systemName: location.icon)
                        .font(.system(size: isCompact ? 22 : 26, weight: .medium))
                        .foregroundColor(isSelected ? .appAccent : .white.opacity(0.5))
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.displayName)
                        .font(.system(size: isCompact ? 16 : 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(location.description)
                        .font(.system(size: isCompact ? 13 : 15))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.appAccent : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: isCompact ? 22 : 26, height: isCompact ? 22 : 26)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: isCompact ? 14 : 16, height: isCompact ? 14 : 16)
                    }
                }
            }
            .padding(isCompact ? 14 : 18)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
                    .fill(Color.black.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.appAccent.opacity(0.5) : Color.black.opacity(0.05),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Widget Add Guide View

struct WidgetAddGuideView: View {
    let location: WidgetLocation
    let onContinue: () -> Void
    
    @State private var contentOpacity: Double = 0
    @State private var stepsOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var currentStep: Int = 0
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    private var steps: [(icon: String, title: String, description: String)] {
        switch location {
        case .homeScreen:
            return [
                ("hand.tap.fill", "Long Press", "Touch and hold any empty area on your home screen until the apps start to jiggle"),
                ("plus.circle.fill", "Tap the + Button", "Look for the + button in the top-left corner and tap it"),
                ("magnifyingglass", "Search for FaithWall", "Type 'FaithWall' in the search bar at the top"),
                ("hand.tap.fill", "Select Widget Size", "Choose your preferred widget size and tap 'Add Widget'"),
                ("checkmark.circle.fill", "Position & Done", "Drag the widget where you want it, then tap 'Done'")
            ]
        case .lockScreen:
            return [
                ("lock.fill", "Lock Your Screen", "Press the side button to lock your iPhone"),
                ("hand.tap.fill", "Long Press", "Touch and hold the lock screen until 'Customize' appears"),
                ("slider.horizontal.3", "Tap Customize", "Select 'Customize' and choose 'Lock Screen'"),
                ("plus.circle.fill", "Add Widget", "Tap the widget area below the time, then tap + to add"),
                ("magnifyingglass", "Find FaithWall", "Search for 'FaithWall' and select the widget you want")
            ]
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: isCompact ? 20 : 30)
                    
                    // Title
                    VStack(spacing: isCompact ? 8 : 12) {
                        Text("Follow These Steps")
                            .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("Adding a widget to your \(location.displayName.lowercased())")
                            .font(.system(size: isCompact ? 14 : 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(contentOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                    
                    Spacer(minLength: isCompact ? 20 : 28)
                    
                    // Steps
                    VStack(spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            WidgetStepRow(
                                stepNumber: index + 1,
                                icon: step.icon,
                                title: step.title,
                                description: step.description,
                                isActive: index <= currentStep,
                                isLast: index == steps.count - 1
                            )
                        }
                    }
                    .opacity(stepsOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                    
                    Spacer(minLength: isCompact ? 60 : 80)
                }
            }
            
            // Continue button
            VStack(spacing: isCompact ? 8 : 12) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onContinue()
                }) {
                    Text("I've Added the Widget")
                        .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                        .frame(height: isCompact ? 48 : 56)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                
                Text("Take your time, then tap when ready")
                    .font(.system(size: isCompact ? 12 : 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, isCompact ? 16 : 24)
            .padding(.bottom, isCompact ? 16 : 22)
            .opacity(buttonOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                stepsOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                buttonOpacity = 1
            }
            
            // Animate steps one by one
            animateSteps()
        }
    }
    
    private func animateSteps() {
        for i in 0..<steps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    currentStep = i
                }
            }
        }
    }
}

// MARK: - Widget Step Row

struct WidgetStepRow: View {
    let stepNumber: Int
    let icon: String
    let title: String
    let description: String
    let isActive: Bool
    let isLast: Bool
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        HStack(alignment: .top, spacing: isCompact ? 12 : 16) {
            // Step number and connector
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.appAccent : Color.black.opacity(0.05))
                        .frame(width: isCompact ? 32 : 38, height: isCompact ? 32 : 38)
                    
                    if isActive {
                        Image(systemName: icon)
                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                            .foregroundColor(.primary)
                    } else {
                        Text("\(stepNumber)")
                            .font(.system(size: isCompact ? 14 : 16, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                
                if !isLast {
                    Rectangle()
                        .fill(isActive ? Color.appAccent.opacity(0.3) : Color.black.opacity(0.05))
                        .frame(width: 2)
                        .frame(height: isCompact ? 30 : 40)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
                Text(title)
                    .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                    .foregroundColor(isActive ? .white : .white.opacity(0.5))
                
                Text(description)
                    .font(.system(size: isCompact ? 13 : 15))
                    .foregroundColor(isActive ? .white.opacity(0.7) : .white.opacity(0.4))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
            
            Spacer()
        }
        .padding(.vertical, isCompact ? 4 : 6)
    }
}

// MARK: - Widget Verification View

struct WidgetVerificationView: View {
    let onContinue: () -> Void
    
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var isChecking: Bool = false
    @State private var showSuccess: Bool = false
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: isCompact ? 50 : 80)
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(showSuccess ? Color.green.opacity(0.15) : Color.appAccent.opacity(0.15))
                            .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                        
                        if isChecking {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                                .scaleEffect(isCompact ? 1.3 : 1.5)
                        } else if showSuccess {
                            Image(systemName: "checkmark")
                                .font(.system(size: isCompact ? 44 : 52, weight: .bold))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "widget.small")
                                .font(.system(size: isCompact ? 44 : 52, weight: .medium))
                                .foregroundColor(.appAccent)
                        }
                    }
                    
                    Spacer(minLength: isCompact ? 24 : 36)
                    
                    // Title and description
                    VStack(spacing: isCompact ? 12 : 16) {
                        Text(showSuccess ? "Widget Ready!" : "Let's Verify")
                            .font(.system(size: isCompact ? 26 : 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text(showSuccess 
                            ? "Your Bible verse widget is all set up and ready to inspire you daily."
                            : "Did you successfully add the FaithWall widget to your phone?")
                            .font(.system(size: isCompact ? 15 : 17))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                    }
                    .opacity(contentOpacity)
                    
                    Spacer(minLength: isCompact ? 60 : 80)
                }
            }
            
            // Buttons
            VStack(spacing: isCompact ? 12 : 16) {
                if !showSuccess {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Simulate verification
                        isChecking = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isChecking = false
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                showSuccess = true
                            }
                            
                            // Trigger widget refresh
                            if #available(iOS 14.0, *) {
                                WidgetCenter.shared.reloadAllTimelines()
                            }
                            
                            // Auto-advance after short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                onContinue()
                            }
                        }
                    }) {
                        Text("Yes, I Added It!")
                            .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            .frame(height: isCompact ? 48 : 56)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: !isChecking))
                    .disabled(isChecking)
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        // Still continue, but could track this for analytics
                        onContinue()
                    }) {
                        Text("Skip for Now")
                            .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, isCompact ? 16 : 24)
            .padding(.bottom, isCompact ? 16 : 22)
            .opacity(buttonOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                buttonOpacity = 1
            }
        }
    }
}

// MARK: - Widget Complete View

struct WidgetCompleteView: View {
    let onComplete: () -> Void
    
    @State private var iconScale: CGFloat = 0.5
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var confettiTrigger: Int = 0
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Confetti
            ConfettiView(trigger: $confettiTrigger)
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: isCompact ? 60 : 100)
                        
                        // Success icon
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: isCompact ? 54 : 64))
                                .foregroundColor(.green)
                        }
                        .scaleEffect(iconScale)
                        
                        Spacer(minLength: isCompact ? 24 : 36)
                        
                        // Title and description
                        VStack(spacing: isCompact ? 12 : 16) {
                            Text("You're All Set!")
                                .font(.system(size: isCompact ? 28 : 34, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("Your Bible verse widget is ready to inspire you throughout your day. God's word is now just a glance away.")
                                .font(.system(size: isCompact ? 15 : 17))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 20)
                        }
                        .opacity(contentOpacity)
                        
                        Spacer(minLength: isCompact ? 30 : 50)
                        
                        // Tips
                        VStack(spacing: isCompact ? 10 : 14) {
                            WidgetTipRow(icon: "arrow.triangle.2.circlepath", text: "Your widget updates with new Bible verses daily")
                            WidgetTipRow(icon: "hand.tap", text: "Tap the widget to open the full app")
                        }
                        .opacity(contentOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        Spacer(minLength: isCompact ? 60 : 80)
                    }
                }
                
                // Complete button
                VStack(spacing: 0) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onComplete()
                    }) {
                        Text("Get Started")
                            .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            .frame(height: isCompact ? 48 : 56)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                }
                .padding(.horizontal, isCompact ? 16 : 24)
                .padding(.bottom, isCompact ? 16 : 22)
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                contentOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
                buttonOpacity = 1
            }
            
            // Trigger confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                confettiTrigger += 1
            }
        }
    }
}

// MARK: - Widget Tip Row

struct WidgetTipRow: View {
    let icon: String
    let text: String
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        HStack(spacing: isCompact ? 12 : 14) {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 16 : 18))
                .foregroundColor(.appAccent)
                .frame(width: isCompact ? 24 : 28)
            
            Text(text)
                .font(.system(size: isCompact ? 14 : 16))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.vertical, isCompact ? 10 : 14)
        .padding(.horizontal, isCompact ? 14 : 18)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous)
                .fill(Color.black.opacity(0.03))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct WidgetOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetOnboardingView(isPresented: .constant(true)) {}
    }
}
#endif
