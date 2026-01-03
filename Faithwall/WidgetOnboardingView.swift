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
        .contentShape(Rectangle()) // Make the whole area tappable
        .onTapGesture {
            if isCompleted {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                
                withAnimation(.easeInOut) {
                    currentPage = page
                }
            }
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
    
    var body: some View {
        UnifiedVerseSelectionView { text, reference in
            saveVerseAndContinue(text: text, reference: reference)
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
        
        // Ensure UI update happens on main thread
        DispatchQueue.main.async {
            onContinue()
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
                VStack(spacing: isCompact ? 8 : 12) {
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
                    
                    // Switch to shortcuts button
                    Button(action: {
                        // This will be handled by the parent OnboardingView
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToShortcutsPipeline"), object: nil)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Change Setup Choice")
                                .font(.system(size: isCompact ? 14 : 15, weight: .semibold))
                        }
                        .foregroundColor(.appAccent)
                        .frame(height: (isCompact ? 48 : 56) - 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 14 : 20, style: .continuous)
                                .fill(Color.appAccent.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 14 : 20, style: .continuous)
                                .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1.5)
                        )
                    }
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
                                .foregroundColor(.white)
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
                        .foregroundColor(isActive ? .primary : .secondary)
                    
                    Text(description)
                        .font(.system(size: isCompact ? 13 : 15))
                        .foregroundColor(isActive ? .secondary : Color.secondary.opacity(0.7))
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


// MARK: - Unified Verse Selection View
/// A robust, unified view for selecting a Bible verse via Explore, Search, or Write.
/// Designed to work reliably across Widget and Shortcut pipelines.
struct UnifiedVerseSelectionView: View {
    // MARK: - Callbacks
    /// Called when a verse is selected or written.
    /// - Parameters:
    ///   - text: The verse text.
    ///   - reference: The verse reference (e.g., "John 3:16").
    var onVerseSelected: (_ text: String, _ reference: String) -> Void
    
    // MARK: - State
    @StateObject private var languageManager = BibleLanguageManager.shared
    @State private var selectedTab: SelectionMode = .explore
    
    // Explore State
    @State private var explorePath: ExplorePath = .books
    @State private var books: [BibleBook] = []
    @State private var isLoadingBooks = false
    @State private var exploreError: String?
    
    // Search State
    @State private var searchText = ""
    @State private var searchResults: [BibleVerse] = []
    @State private var isSearching = false
    @State private var searchError: String?
    
    // Write State
    @State private var manualText = ""
    @State private var manualReference = ""
    
    // UI State
    @State private var showVersionPicker = false
    @State private var selectedVerseForReview: BibleVerse?
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    private let accentColor = Color(red: 0.95, green: 0.4, blue: 0.2) // Orange accent
    
    // MARK: - Enums
    
    enum SelectionMode: Int {
        case write = 0
        case explore = 1
        case search = 2
    }
    
    enum ExplorePath: Equatable {
        case books
        case chapters(BibleBook)
        case verses(BibleBook, Int)
        
        static func == (lhs: ExplorePath, rhs: ExplorePath) -> Bool {
            switch (lhs, rhs) {
            case (.books, .books): return true
            case (.chapters(let b1), .chapters(let b2)): return b1.id == b2.id
            case (.verses(let b1, let c1), .verses(let b2, let c2)): return b1.id == b2.id && c1 == c2
            default: return false
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Tab Bar
            tabBarView
            
            // Content
            ZStack {
                switch selectedTab {
                case .explore:
                    exploreView
                case .search:
                    searchView
                case .write:
                    writeView
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .background(
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
        .sheet(isPresented: $showVersionPicker) {
            NavigationView {
                BibleLanguageSelectionView(
                    initialSelection: languageManager.selectedTranslation,
                    showContinueButton: false,
                    isOnboarding: false
                ) { translation in
                    showVersionPicker = false
                }
                .navigationTitle("Bible Version")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showVersionPicker = false
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedVerseForReview) { verse in
            VerseReviewView(verse: verse) { editedText in
                onVerseSelected(editedText, verse.reference)
            }
        }
        .onAppear {
            if books.isEmpty {
                loadBooks()
            }
        }
        .onChange(of: languageManager.selectedTranslation) { _ in
            loadBooks()
            // Clear search results when translation changes
            searchResults = []
            searchText = ""
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Choose Your Verse")
                .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Select the first verse to display")
                .font(.system(size: isCompact ? 14 : 16))
                .foregroundColor(.secondary)
        }
        .padding(.top, isCompact ? 16 : 24)
        .padding(.horizontal)
    }
    
    // MARK: - Tab Bar
    
    private var tabBarView: some View {
        HStack(spacing: 0) {
            tabButton(title: "Explore", icon: "book.fill", mode: .explore)
            tabButton(title: "Search", icon: "magnifyingglass", mode: .search)
            tabButton(title: "Write", icon: "pencil", mode: .write)
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
    
    private func tabButton(title: String, icon: String, mode: SelectionMode) -> some View {
        let isSelected = selectedTab == mode
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = mode
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor.opacity(0.1) : Color.clear)
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
            .foregroundColor(accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.1))
            )
        }
    }
    
    // MARK: - Explore View
    
    private var exploreView: some View {
        VStack(spacing: 0) {
            // Breadcrumb / Header
            HStack {
                if case .books = explorePath {
                    Text("Browse Books")
                        .font(.headline)
                } else {
                    Button(action: {
                        navigateBack()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(accentColor)
                    }
                    
                    Spacer()
                    
                    if case .chapters(let book) = explorePath {
                        Text(book.name)
                            .font(.headline)
                    } else if case .verses(let book, let chapter) = explorePath {
                        Text("\(book.name) \(chapter)")
                            .font(.headline)
                    }
                }
                
                Spacer()
                versionButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(height: 44)
            
            // Content
            if isLoadingBooks {
                Spacer()
                ProgressView("Loading Bible...")
                Spacer()
            } else if let error = exploreError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") { loadBooks() }
                }
                Spacer()
            } else {
                switch explorePath {
                case .books:
                    booksList
                case .chapters(let book):
                    chaptersGrid(for: book)
                case .verses(let book, let chapter):
                    versesList(book: book, chapter: chapter)
                }
            }
        }
    }
    
    private var booksList: some View {
        List {
            Section(header: Text("Old Testament")) {
                ForEach(books.filter { $0.testament == .old }) { book in
                    Button(action: {
                        withAnimation {
                            explorePath = .chapters(book)
                        }
                    }) {
                        HStack {
                            Text(book.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section(header: Text("New Testament")) {
                ForEach(books.filter { $0.testament == .new }) { book in
                    Button(action: {
                        withAnimation {
                            explorePath = .chapters(book)
                        }
                    }) {
                        HStack {
                            Text(book.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func chaptersGrid(for book: BibleBook) -> some View {
        ChapterGridView(book: book, languageManager: languageManager) { chapter in
            withAnimation {
                explorePath = .verses(book, chapter)
            }
        }
    }
    
    private func versesList(book: BibleBook, chapter: Int) -> some View {
        VerseListViewInternal(
            book: book,
            chapter: chapter,
            languageManager: languageManager,
            onSelect: { verse in
                selectVerse(verse)
            }
        )
    }
    
    private func navigateBack() {
        withAnimation {
            switch explorePath {
            case .verses(let book, _):
                explorePath = .chapters(book)
            case .chapters:
                explorePath = .books
            case .books:
                break
            }
        }
    }
    
    // MARK: - Search View
    
    private var searchView: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search verses (e.g. 'Lord', 'Love')...", text: $searchText)
                        .submitLabel(.search)
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
                Spacer()
            } else if let error = searchError {
                Spacer()
                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else if !searchResults.isEmpty {
                List(searchResults) { verse in
                    Button(action: {
                        selectVerse(verse)
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(verse.reference)
                                    .font(.headline)
                                    .foregroundColor(accentColor)
                                Spacer()
                            }
                            Text(verse.text)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.plain)
            } else if !searchText.isEmpty {
                Spacer()
                Text("No verses found.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(accentColor.opacity(0.3))
                    Text("Search for Bible Verse")
                        .font(.headline)
                }
                Spacer()
            }
        }
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty {
                searchResults = []
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    // MARK: - Write View
    
    private var writeView: some View {
        let totalChars = manualText.count + manualReference.count + 1
        let isOverLimit = totalChars > 133
        
        return ScrollView {
            VStack(spacing: 24) {
                // Verse Text Input
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Verse Text", systemImage: "quote.opening")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("\(totalChars)")
                                .foregroundColor(isOverLimit ? .red : .appAccent)
                            Text("/ 133")
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isOverLimit ? Color.red.opacity(0.1) : Color.appAccent.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if manualText.isEmpty {
                            Text("Type your favorite verse here...")
                                .foregroundColor(Color(.placeholderText))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                        }
                        
                        if #available(iOS 16.0, *) {
                            TextEditor(text: $manualText)
                                .font(.system(size: 17, weight: .regular, design: .rounded))
                                .frame(minHeight: 160)
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
                            .stroke(isOverLimit ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
                }
                
                if isOverLimit {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("This verse is too long for the widget and will be truncated. Try shortening it.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Reference Input
                VStack(alignment: .leading, spacing: 10) {
                    Label("Reference", systemImage: "book.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    TextField("e.g. John 3:16", text: $manualReference)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                }
                
                Spacer(minLength: 20)
                
                // Action Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onVerseSelected(manualText, manualReference)
                }) {
                    HStack {
                        Text(isOverLimit ? "Continue Anyway" : "Save Verse")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        manualText.isEmpty ? Color.gray.opacity(0.3) : 
                        (isOverLimit ? Color.orange : accentColor)
                    )
                    .cornerRadius(16)
                    .shadow(color: (manualText.isEmpty ? Color.clear : (isOverLimit ? Color.orange : accentColor)).opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(manualText.isEmpty)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
    
    // MARK: - Logic
    
    private func loadBooks() {
        isLoadingBooks = true
        exploreError = nil
        
        let translation = languageManager.selectedTranslation
        
        // Ensure downloaded
        if !BibleDatabaseService.shared.isDownloaded(translation) {
            languageManager.ensureSelectedTranslationDownloaded { result in
                switch result {
                case .success:
                    self.fetchBooks()
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isLoadingBooks = false
                        self.exploreError = "Download failed: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            fetchBooks()
        }
    }
    
    private func fetchBooks() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let loadedBooks = try BibleDatabaseService.shared.getBooks(for: languageManager.selectedTranslation)
                DispatchQueue.main.async {
                    self.books = loadedBooks
                    self.isLoadingBooks = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.exploreError = "Failed to load books: \(error.localizedDescription)"
                    self.isLoadingBooks = false
                }
            }
        }
    }
    
    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        isSearching = true
        searchError = nil
        
        let translation = languageManager.selectedTranslation
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let results = try BibleDatabaseService.shared.searchVerses(
                    query: query,
                    translation: translation
                )
                DispatchQueue.main.async {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.searchError = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
    
    private func selectVerse(_ verse: BibleVerse) {
        selectedVerseForReview = verse
    }
}

// MARK: - Internal Helper Views

struct ChapterGridView: View {
    let book: BibleBook
    @ObservedObject var languageManager: BibleLanguageManager
    let onSelect: (Int) -> Void
    
    @State private var chapterCount = 0
    @State private var isLoading = true
    
    let columns = [GridItem(.adaptive(minimum: 60), spacing: 12)]
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView().padding()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(1...chapterCount, id: \.self) { chapter in
                        Button(action: { onSelect(chapter) }) {
                            Text("\(chapter)")
                                .font(.title2)
                                .fontWeight(.medium)
                                .frame(width: 60, height: 60)
                                .background(Color(.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadChapters()
        }
    }
    
    private func loadChapters() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try BibleDatabaseService.shared.getChapterCount(
                    bookId: book.id,
                    translation: languageManager.selectedTranslation
                )
                DispatchQueue.main.async {
                    self.chapterCount = count
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

struct VerseListViewInternal: View {
    let book: BibleBook
    let chapter: Int
    @ObservedObject var languageManager: BibleLanguageManager
    let onSelect: (BibleVerse) -> Void
    
    @State private var verses: [BibleVerse] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                ForEach(verses) { verse in
                    Button(action: { onSelect(verse) }) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(verse.verse)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 24, alignment: .trailing)
                            
                            Text(verse.text)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.plain)
        .onAppear {
            loadVerses()
        }
    }
    
    private func loadVerses() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let loadedVerses = try BibleDatabaseService.shared.getVerses(
                    bookId: book.id,
                    chapter: chapter,
                    translation: languageManager.selectedTranslation
                )
                DispatchQueue.main.async {
                    self.verses = loadedVerses
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
