import SwiftUI
import UIKit
import StoreKit

// MARK: - Letter Spacing Modifier (iOS 15+ Compatible)

struct LetterSpacingModifier: ViewModifier {
    let spacing: CGFloat
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.kerning(spacing)
        } else {
            content
        }
    }
}

// MARK: - Enhanced Onboarding State Management

/// Manages quiz answers and personalization data throughout onboarding
class OnboardingQuizState: ObservableObject {
    static let shared = OnboardingQuizState()
    
    // Quiz answers stored in UserDefaults for persistence
    @AppStorage("quiz_forgetMost") var forgetMost: String = "" // Comma-separated for multi-select
    @AppStorage("quiz_phoneChecks") var phoneChecks: String = ""
    @AppStorage("quiz_biggestDistraction") var biggestDistraction: String = "" // Comma-separated for multi-select
    @AppStorage("quiz_firstNote") var firstNote: String = ""
    
    // Helper for multi-select answers
    var forgetMostList: [String] {
        get { forgetMost.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
        set { forgetMost = newValue.joined(separator: ", ") }
    }
    
    var biggestDistractionList: [String] {
        get { biggestDistraction.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
        set { biggestDistraction = newValue.joined(separator: ", ") }
    }
    
    // Tracking
    @AppStorage("onboarding_startTime") private var startTimeDouble: Double = 0
    @AppStorage("onboarding_paywallShown") var paywallShown: Bool = false
    @AppStorage("onboarding_setupCompleted") var setupCompleted: Bool = false
    
    var startTime: Date {
        get { Date(timeIntervalSince1970: startTimeDouble) }
        set { startTimeDouble = newValue.timeIntervalSince1970 }
    }
    
    var totalSetupTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    // Personalization based on answers
    var personalizedPhoneChecks: String {
        switch phoneChecks {
        case "50-100":
            return "50-100"
        case "100-200":
            return "150+"
        case "200+":
            return "200+"
        default:
            return "100+"
        }
    }
    
    var personalizedDistraction: String {
        biggestDistraction.isEmpty ? "social media" : biggestDistraction.lowercased()
    }
    
    func reset() {
        forgetMost = ""
        phoneChecks = ""
        biggestDistraction = ""
        firstNote = ""
        startTimeDouble = Date().timeIntervalSince1970
        paywallShown = false
        setupCompleted = false
    }
}

// MARK: - Analytics Tracking

struct OnboardingAnalytics {
    static func trackStepShown(_ step: String) {
        #if DEBUG
        print("📊 Analytics: Step shown - \(step)")
        #endif
        // TODO: Integrate with your analytics service (Mixpanel, Amplitude, etc.)
    }
    
    static func trackStepCompleted(_ step: String, timeSpent: TimeInterval) {
        #if DEBUG
        print("📊 Analytics: Step completed - \(step) (took \(String(format: "%.1f", timeSpent))s)")
        #endif
    }
    
    static func trackQuizAnswer(question: String, answer: String) {
        #if DEBUG
        print("📊 Analytics: Quiz answer - \(question): \(answer)")
        #endif
    }
    
    static func trackPaywallShown(totalSetupTime: TimeInterval) {
        #if DEBUG
        print("📊 Analytics: Paywall shown after \(String(format: "%.1f", totalSetupTime))s setup")
        #endif
    }
    
    static func trackPaywallConversion(success: Bool, product: String?) {
        #if DEBUG
        print("📊 Analytics: Paywall conversion - \(success ? "SUCCESS" : "DECLINED") - \(product ?? "none")")
        #endif
    }
    
    static func trackDropOff(step: String, reason: String?) {
        #if DEBUG
        print("📊 Analytics: Drop-off at \(step) - \(reason ?? "unknown")")
        #endif
    }
}

// MARK: - Progress Indicator Component

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    let phaseName: String
    let timeRemaining: String?
    
    var progress: CGFloat {
        CGFloat(currentStep) / CGFloat(totalSteps)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Phase name and step counter
            HStack {
                Text(phaseName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appAccent)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text(String(format: "Step %d of %d", currentStep, totalSteps))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 6)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
            
            // Time remaining (optional)
            if let time = timeRemaining {
                HStack {
                    Spacer()
                    Text(time)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, 16)
    }
}

// MARK: - Pain Point View (Emotional Hook)
// Removed as per user request to skip this step.
// struct PainPointView: View { ... }

// MARK: - Motivational Transition View
// Connects the intro with the quiz - motivational messaging

struct MotivationalTransitionView: View {
    let onContinue: () -> Void
    
    @State private var visibleWordCount = 0
    @State private var showButton = false
    @State private var isNavigating = false
    
    private let message = "We built FaithWall so you see God's Word every time you pick up your phone."
    private var words: [String] {
        message.components(separatedBy: " ")
    }
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Orange background
            Color.appAccent
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main motivational message with word-by-word animation
                Text(attributedString)
                    .font(.system(size: isCompact ? 32 : 42, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, isCompact ? 32 : 40)
                    .animation(.easeOut(duration: 0.2), value: visibleWordCount)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    guard !isNavigating else { return }
                    isNavigating = true
                    
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onContinue()
                }) {
                    HStack(spacing: 12) {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.appAccent)
                    .padding(.vertical, DS.Spacing.m)
                    .padding(.horizontal, 32)
                    .background(Color.white)
                    .cornerRadius(30)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .opacity(showButton ? 1 : 0)
                .scaleEffect(showButton ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showButton)
                .padding(.bottom, isCompact ? 40 : 60)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private var attributedString: AttributedString {
        var string = AttributedString("")
        
        for (index, word) in words.enumerated() {
            var wordString = AttributedString(word + " ")
            
            if index < visibleWordCount {
                wordString.foregroundColor = .white
            } else {
                wordString.foregroundColor = .clear
            }
            
            string.append(wordString)
        }
        
        return string
    }
    
    private func startAnimation() {
        // Reset state
        visibleWordCount = 0
        showButton = false
        
        let totalDuration = 1.5
        let wordDelay = totalDuration / Double(words.count)
        
        // Animate words appearing
        for i in 0..<words.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + (Double(i) * wordDelay)) {
                visibleWordCount = i + 1
            }
        }
        
        // Show button after text is done
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + totalDuration + 0.5) {
            showButton = true
        }
    }
}




// MARK: - Stat Mini Card

private struct StatMiniCard: View {
    let value: String
    let label: String
    let icon: String
    let isCompact: Bool
    
    var body: some View {
        VStack(spacing: isCompact ? 6 : 8) {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 14 : 16))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: isCompact ? 18 : 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: isCompact ? 10 : 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isCompact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 12 : 14, style: .continuous)
                .fill(Color.black.opacity(0.03))
        )
    }
}

// MARK: - Quiz Transition View (Connection between Pain Point and Quiz)

struct QuizTransitionView: View {
    let onContinue: () -> Void
    
    @State private var headerOpacity: Double = 0
    @State private var questionOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        ZStack {
            // Dark gradient background with subtle depth
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.99, green: 0.98, blue: 0.97), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Subtle radial glow
                RadialGradient(
                    colors: [Color.appAccent.opacity(0.06), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 350
                )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isCompact ? 28 : 40) {
                        Spacer(minLength: isCompact ? 50 : 80)
                        
                        // Header badge
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: isCompact ? 12 : 14))
                                .foregroundColor(.appAccent)
                            
                            Text("Quick Check")
                                .font(.system(size: isCompact ? 12 : 13, weight: .medium))
                                .foregroundColor(.appAccent)
                        }
                        .padding(.horizontal, isCompact ? 12 : 16)
                        .padding(.vertical, isCompact ? 6 : 8)
                        .background(
                            Capsule()
                                .fill(Color.appAccent.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .opacity(headerOpacity)
                        
                        // Brain icon with animation
                        ZStack {
                            // Outer glow rings
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .stroke(Color.appAccent.opacity(0.15 - Double(i) * 0.04), lineWidth: 1.5)
                                    .frame(
                                        width: (isCompact ? 80 : 100) + CGFloat(i) * (isCompact ? 24 : 30),
                                        height: (isCompact ? 80 : 100) + CGFloat(i) * (isCompact ? 24 : 30)
                                    )
                            }
                            
                            Circle()
                                .fill(Color.appAccent.opacity(0.12))
                                .frame(width: isCompact ? 80 : 100, height: isCompact ? 80 : 100)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: isCompact ? 36 : 44, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.appAccent, .appAccent.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                        
                        // Main question section
                        VStack(spacing: isCompact ? 14 : 20) {
                            Text("Before we start...")
                                .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .opacity(subtitleOpacity)
                            
                            Text("What do you most want to remember?")
                                .font(.system(size: isCompact ? 26 : 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .opacity(questionOpacity)
                            
                            Text("Just a few quick questions")
                                .font(.system(size: isCompact ? 14 : 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .opacity(subtitleOpacity)
                        }
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // Time estimate
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: isCompact ? 12 : 14))
                                .foregroundColor(.secondary)
                            
                            Text("Takes less than 30 seconds")
                                .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .opacity(subtitleOpacity)
                        
                        Spacer(minLength: isCompact ? 80 : 100)
                    }
                }
                
                // Continue button
                VStack(spacing: 0) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onContinue()
                    }) {
                        HStack(spacing: isCompact ? 8 : 10) {
                            Text("Let's Find Out")
                                .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                        }
                        .frame(height: isCompact ? 50 : 56)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                .padding(.vertical, isCompact ? 16 : 20)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0), Color.white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                    .offset(y: -40)
                    , alignment: .top
                )
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            // Header badge
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                headerOpacity = 1
            }
            
            // Icon with spring
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.3)) {
                iconOpacity = 1
                iconScale = 1.0
            }
            
            // Subtitle
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                subtitleOpacity = 1
            }
            
            // Main question
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
                questionOpacity = 1
            }
            
            // Button
            withAnimation(.easeOut(duration: 0.4).delay(1.0)) {
                buttonOpacity = 1
            }
            
            OnboardingAnalytics.trackStepShown("quiz_transition")
        }
    }
}

// MARK: - Personalization Loading View (After Quiz, Before Results)

struct PersonalizationLoadingView: View {
    let onComplete: () -> Void
    
    @State private var progress: CGFloat = 0
    @State private var displayedPercentage: Int = 0
    @State private var messageIndex: Int = 0
    @State private var messageOpacity: Double = 1
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    private let messages = [
        "Analyzing your responses...",
        "Identifying growth areas...",
        "Personalizing your plan...",
        "Finalizing your profile..."
    ]
    
    private let totalDuration: Double = 4.0 // Slightly longer to allow reading
    
    var body: some View {
        ZStack {
            // Light Background
            DS.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: isCompact ? 30 : 40) {
                Spacer()
                
                // Circular Progress
                ZStack {
                    // Track
                    Circle()
                        .stroke(Color.black.opacity(0.05), lineWidth: 20)
                        .frame(width: 200, height: 200)
                    
                    // Progress Indicator
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.appAccent,
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                    
                    // Percentage Text
                    if #available(iOS 17.0, *) {
                        Text("\(displayedPercentage)%")
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText(value: Double(displayedPercentage)))
                    } else {
                        Text("\(displayedPercentage)%")
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.bottom, 20)
                
                // Text Section
                VStack(spacing: 12) {
                    Text("Calculating Results...")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(messages[messageIndex])
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(messageOpacity)
                        .animation(.easeInOut(duration: 0.3), value: messageOpacity)
                        .id("message-\(messageIndex)")
                }
                
                Spacer()
            }
        }
        .onAppear {
            startLoadingProcess()
        }
    }
    
    private func startLoadingProcess() {
        // 1. Animate Progress
        withAnimation(.easeOut(duration: totalDuration)) {
            progress = 1.0
        }
        
        // 2. Animate Percentage Number
        // Use a Timer for smoother, continuous updates instead of a loop of asyncAfter
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(totalDuration)
        
        // Prepare haptics
        let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
        hapticGenerator.prepare()
        
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            let now = Date()
            if now >= endTime {
                timer.invalidate()
                displayedPercentage = 100
                
                // Success haptic
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)
                
                // Complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
                return
            }
            
            let elapsed = now.timeIntervalSince(startTime)
            let currentProgress = elapsed / totalDuration
            
            // Use easeOut curve to match the circle animation
            // easeOutQuad: 1 - (1-t) * (1-t)
            let easedProgress = 1.0 - (1.0 - currentProgress) * (1.0 - currentProgress)
            
            let newPercentage = Int(easedProgress * 100)
            
            if newPercentage > displayedPercentage {
                displayedPercentage = newPercentage
                // Haptic on every number change for that "ticking" feel
                hapticGenerator.impactOccurred(intensity: 0.5)
            }
        }
        
        // 3. Animate Messages
        let messageDuration = totalDuration / Double(messages.count)
        
        for i in 0..<messages.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + messageDuration * Double(i)) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    messageOpacity = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    messageIndex = i
                    withAnimation(.easeInOut(duration: 0.3)) {
                        messageOpacity = 1
                    }
                }
            }
        }
        
        OnboardingAnalytics.trackStepShown("personalization_loading")
    }
}

// MARK: - Phone Usage Slider Question View

struct PhoneUsageSliderQuestionView: View {
    let onSelect: (String) -> Void
    
    @State private var phoneChecks: Double = 100 // Default to 100
    @State private var contentOpacity: Double = 0
    @State private var gaugeOpacity: Double = 0
    @State private var sliderOpacity: Double = 0
    @State private var lastHapticValue: Int = 100
    @State private var isNavigating = false
    
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    // Gauge configuration
    private let totalTicks = 50
    private let minVal: Double = 0
    private let maxVal: Double = 300
    
    var body: some View {
        ZStack {
            // Orange gradient background (matching Step 0)
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.4, blue: 0.2), Color(red: 1.0, green: 0.5, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Question number and title
                VStack(spacing: isCompact ? 16 : 24) {
                    Text("Question #2")
                        .font(.system(size: isCompact ? 36 : 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(contentOpacity)
                    
                    Text("How many times do you\npick up your phone daily?")
                        .font(.system(size: isCompact ? 18 : 22, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .opacity(contentOpacity)
                }
                
                Spacer()
                
                // Circular Tick Gauge Visualization
                ZStack {
                    // Ticks
                    ForEach(0..<totalTicks, id: \.self) { index in
                        let progress = Double(index) / Double(totalTicks)
                        let activeProgress = (phoneChecks - minVal) / (maxVal - minVal)
                        let isActive = progress < activeProgress
                        
                        Capsule()
                            .fill(isActive ? Color.white : Color.white.opacity(0.2))
                            .frame(width: 6, height: 18)
                            .offset(y: -110) // Radius
                            .rotationEffect(.degrees(Double(index) * (360.0 / Double(totalTicks))))
                    }
                    
                    // Center value display
                    VStack(spacing: 4) {
                        Text("\(Int(phoneChecks))")
                            .font(.system(size: isCompact ? 54 : 64, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("times")
                            .font(.system(size: isCompact ? 16 : 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(width: 260, height: 260)
                .opacity(gaugeOpacity)
                
                Spacer()
                
                // Slider
                VStack(spacing: isCompact ? 24 : 32) {
                    Slider(
                        value: $phoneChecks,
                        in: minVal...maxVal,
                        step: 10,
                        onEditingChanged: { editing in
                            if !editing {
                                // Trigger haptic when user finishes dragging
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                        }
                    )
                    .accentColor(.white)
                    .onChange(of: phoneChecks) { newValue in
                        let roundedValue = Int(newValue / 10) * 10
                        if roundedValue != lastHapticValue {
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                            lastHapticValue = roundedValue
                        }
                    }
                    .padding(.horizontal, isCompact ? 32 : 40)
                    .opacity(sliderOpacity)
                    
                    // Next button
                    Button(action: {
                        guard !isNavigating else { return }
                        isNavigating = true
                        
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Convert to range categories
                        let value: String
                        if phoneChecks < 100 {
                            value = "50-100"
                        } else if phoneChecks < 200 {
                            value = "100-200"
                        } else {
                            value = "200+"
                        }
                        
                        onSelect(value)
                    }) {
                        Text("Next")
                            .font(.system(size: isCompact ? 17 : 19, weight: .bold))
                            .foregroundColor(.appAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: isCompact ? 54 : 60)
                            .background(Color.white)
                            .cornerRadius(isCompact ? 27 : 30)
                    }
                    .padding(.horizontal, isCompact ? 24 : 32)
                    .opacity(sliderOpacity)
                }
                
                Spacer().frame(height: isCompact ? 40 : 60)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1.0
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
                gaugeOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                sliderOpacity = 1.0
            }
        }
    }
}

// MARK: - Quiz Question View

struct QuizQuestionView: View {
    let question: String
    let subtitle: String?
    let options: [QuizOption]
    let onSelect: (String) -> Void
    
    @State private var selectedOption: String?
    @State private var contentOpacity: Double = 0
    @State private var optionsOpacity: Double = 0
    @State private var isNavigating = false
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    private var questionFontSize: CGFloat { isCompact ? 22 : 28 }
    private var topSpacing: CGFloat { isCompact ? 30 : 60 }
    private var optionSpacing: CGFloat { isCompact ? 8 : 12 }
    
    struct QuizOption: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let value: String
    }
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.98, blue: 0.97), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: topSpacing)
                
                // Question
                    VStack(spacing: isCompact ? 8 : 12) {
                    Text(question)
                            .font(.system(size: questionFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.85)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                                .font(.system(size: isCompact ? 14 : 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                .opacity(contentOpacity)
                
                    Spacer(minLength: isCompact ? 24 : 40)
                
                // Options
                    VStack(spacing: optionSpacing) {
                    ForEach(options) { option in
                        QuizOptionButton(
                            emoji: option.emoji,
                            title: option.title,
                            isSelected: selectedOption == option.value
                        ) {
                            guard !isNavigating else { return }
                            isNavigating = true
                            
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedOption = option.value
                            }
                            
                            OnboardingAnalytics.trackQuizAnswer(question: question, answer: option.value)
                            
                            // Delay before advancing to show selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                onSelect(option.value)
                            }
                        }
                    }
                }
                .opacity(optionsOpacity)
                    .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                
                    Spacer(minLength: isCompact ? 30 : 50)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                optionsOpacity = 1
            }
            
            OnboardingAnalytics.trackStepShown("quiz_\(question.prefix(20))")
        }
    }
}

struct QuizOptionButton: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 12 : 16) {
                Text(emoji)
                    .font(.system(size: isCompact ? 24 : 28))
                
                Text(title)
                    .font(.system(size: isCompact ? 15 : 17, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: isCompact ? 20 : 24))
                        .foregroundColor(.appAccent)
                }
            }
            .padding(.horizontal, isCompact ? 16 : 20)
            .padding(.vertical, isCompact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                    .fill(isSelected ? Color.appAccent.opacity(0.2) : Color.black.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.appAccent : Color.black.opacity(0.05),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
    }
}
            
// MARK: - Results Preview View

struct ResultsPreviewViewOld: View {
    let onContinue: () -> Void
    @ObservedObject private var quizState = OnboardingQuizState.shared
    
    @State private var headerOpacity: Double = 0
    @State private var profileOpacity: Double = 0
    @State private var insightOpacity: Double = 0
    @State private var planOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var progressValue: CGFloat = 0
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    // Personalized insights based on quiz answers
    private var focusAreas: [String] {
        let areas = quizState.forgetMostList
        return areas.isEmpty ? ["Your priorities"] : Array(areas.prefix(2))
    }
    
    private var distractionText: String {
        let distractions = quizState.biggestDistractionList
        if distractions.isEmpty { return "distractions" }
        return distractions.first ?? "distractions"
    }
    
    private var reminderFrequency: String {
        switch quizState.phoneChecks {
        case "50-100": return "Every 15 min"
        case "100-200": return "Every 8 min"
        case "200+": return "Every 5 min"
        default: return "Every 10 min"
        }
    }
    
    private var phoneCheckCount: String {
        switch quizState.phoneChecks {
        case "50-100": return "50-100"
        case "100-200": return "100-200"
        case "200+": return "200+"
        default: return "100+"
        }
    }
    
    var body: some View {
        ZStack {
            // Dark gradient background with subtle glow
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.99, green: 0.98, blue: 0.97), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Subtle accent glow at top
                RadialGradient(
                    colors: [Color.appAccent.opacity(0.08), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isCompact ? 20 : 28) {
                        Spacer(minLength: isCompact ? 20 : 32)
                        
                        // MARK: - Header with completion indicator
                        VStack(spacing: isCompact ? 6 : 10) {
                            // Connecting badge
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: isCompact ? 12 : 14))
                                    .foregroundColor(.appAccent)
                                
                                Text("Analysis Complete")
                                    .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal, isCompact ? 12 : 16)
                            .padding(.vertical, isCompact ? 6 : 8)
                            .background(
                                Capsule()
                                    .fill(Color.appAccent.opacity(0.12))
                            )
                            .scaleEffect(checkmarkScale)
                            
                            Text("Your Focus Profile")
                                .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.top, isCompact ? 8 : 12)
                        }
                        .opacity(headerOpacity)
                        
                        // MARK: - Personalized Profile Card
                        VStack(spacing: 0) {
                            // Profile header
                            HStack(spacing: isCompact ? 10 : 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.appAccent.opacity(0.15))
                                        .frame(width: isCompact ? 40 : 48, height: isCompact ? 40 : 48)
                                    
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: isCompact ? 18 : 22))
                                        .foregroundColor(.appAccent)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Based on your answers")
                                        .font(.system(size: isCompact ? 11 : 12))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Here's what we learned about you:")
                                        .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                            }
                            .padding(isCompact ? 14 : 18)
                            .background(Color.white.opacity(0.03))
                            
                            // Profile insights
                            VStack(spacing: isCompact ? 14 : 18) {
                                // Focus areas
                                ProfileInsightRow(
                                    icon: "target",
                                    label: "YOU WANT TO REMEMBER",
                                    values: focusAreas,
                                    isCompact: isCompact
                                )
                                
                                Divider()
                                    .background(Color.black.opacity(0.05))
                                
                                // Distraction
                                ProfileInsightRow(
                                    icon: "xmark.circle",
                                    label: "YOUR BIGGEST CHALLENGE",
                                    values: [distractionText],
                                    isCompact: isCompact
                                )
                                
                                Divider()
                                    .background(Color.black.opacity(0.05))
                                
                                // Phone usage
                                HStack {
                                    Image(systemName: "iphone")
                                        .font(.system(size: isCompact ? 14 : 16))
                                        .foregroundColor(.secondary)
                                        .frame(width: isCompact ? 20 : 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Daily Phone Checks")
                                            .font(.system(size: isCompact ? 9 : 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .tracking(0.5)
                                        
                                        Text("\(phoneCheckCount) times")
                                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Visual indicator
                                    HStack(spacing: 3) {
                                        ForEach(0..<5, id: \.self) { i in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(i < intensityLevel ? Color.appAccent : Color.white.opacity(0.15))
                                                .frame(width: isCompact ? 4 : 5, height: isCompact ? 16 : 20)
                                        }
                                    }
                                }
                            }
                            .padding(isCompact ? 14 : 18)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                .fill(Color.black.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                                )
                        )
                        .opacity(profileOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // MARK: - What This Means insight
                        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: isCompact ? 14 : 16))
                                    .foregroundColor(.yellow.opacity(0.8))
                                
                                Text("What This Means")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            Text("You check your phone \(phoneCheckCount) times per day. That's \(phoneCheckCount) chances to be reminded of God's Word and strengthen your faith, instead of getting distracted by \(distractionText.lowercased()).")
                                .font(.system(size: isCompact ? 13 : 15))
                                .foregroundColor(.white.opacity(0.7))
                                .lineSpacing(4)
                        }
                        .padding(isCompact ? 14 : 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                .fill(Color.yellow.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                        .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .opacity(insightOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // MARK: - Your Plan preview
                        VStack(spacing: isCompact ? 12 : 16) {
                            HStack {
                                Text("Your Faith Growth Plan")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("Three steps to transform your phone")
                                    .font(.system(size: isCompact ? 11 : 13))
                                    .foregroundColor(.appAccent)
                            }
                            
                            // Progress steps preview
                            HStack(spacing: isCompact ? 8 : 12) {
                                PlanStepPreview(number: "1", title: "Choose your verse", isCompleted: false, isCompact: isCompact)
                                PlanStepPreview(number: "2", title: "Pick a wallpaper", isCompleted: false, isCompact: isCompact)
                                PlanStepPreview(number: "3", title: "Install shortcut", isCompleted: false, isCompact: isCompact)
                            }
                        }
                        .padding(isCompact ? 14 : 18)
                        .background(
                            RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                        )
                        .opacity(planOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        Spacer(minLength: isCompact ? 80 : 100)
                    }
                }
                
                // Continue button
                VStack(spacing: 0) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onContinue()
                    }) {
                        HStack(spacing: isCompact ? 8 : 10) {
                            Text("Let's Set It Up")
                                .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                        }
                        .frame(height: isCompact ? 50 : 56)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                }
                .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                .padding(.vertical, isCompact ? 16 : 20)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0), Color.white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                    .offset(y: -40)
                    , alignment: .top
                )
                .opacity(buttonOpacity)
            }
        }
        .onAppear {
            // Staggered animations for smooth flow
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                checkmarkScale = 1.0
                headerOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                profileOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                insightOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
                planOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.4).delay(0.9)) {
                buttonOpacity = 1.0
            }
            
            // Success haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            OnboardingAnalytics.trackStepShown("results_preview")
        }
    }
    
    // Intensity level based on phone checks
    private var intensityLevel: Int {
        switch quizState.phoneChecks {
        case "50-100": return 2
        case "100-200": return 4
        case "200+": return 5
        default: return 3
        }
    }
}

// MARK: - Profile Insight Row

private struct ProfileInsightRow: View {
    let icon: String
    let label: String
    let values: [String]
    let isCompact: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 14 : 16))
                .foregroundColor(.secondary)
                .frame(width: isCompact ? 20 : 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: isCompact ? 9 : 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .modifier(LetterSpacingModifier(spacing: 0.5))
                
                HStack(spacing: isCompact ? 6 : 8) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                            .foregroundColor(.appAccent)
                            .padding(.horizontal, isCompact ? 8 : 10)
                            .padding(.vertical, isCompact ? 4 : 6)
                            .background(
                                Capsule()
                                    .fill(Color.appAccent.opacity(0.12))
                            )
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Plan Step Preview

private struct PlanStepPreview: View {
    let number: String
    let title: String
    let isCompleted: Bool
    let isCompact: Bool
    
    var body: some View {
        VStack(spacing: isCompact ? 6 : 8) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.appAccent : Color.black.opacity(0.05))
                    .frame(width: isCompact ? 28 : 34, height: isCompact ? 28 : 34)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: isCompact ? 12 : 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text(number)
                        .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(title)
                .font(.system(size: isCompact ? 10 : 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Social Proof View (Redesigned)

struct ReviewModel: Identifiable {
    let id = UUID()
    let name: String
    let username: String
    let text: String
    let rating: Int
    let initial: String
    let color: Color
}

struct SocialProofView: View {
    let onContinue: () -> Void
    
    // MARK: - Animation States
    @State private var scrollOffset1: CGFloat = 0
    @State private var scrollOffset2: CGFloat = 0
    @State private var isAnimating = false
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    // Sample Data
    private let reviews1: [ReviewModel] = [
        ReviewModel(name: "Sarah Jenkins", username: "@sarahj_92", text: "Simple, effective, and beautiful. Exactly what I needed to get back on track.", rating: 5, initial: "S", color: .purple),
        ReviewModel(name: "Michael Chen", username: "@mchen_dev", text: "The daily reminders are perfect. Not too pushy but keeps me accountable.", rating: 5, initial: "M", color: .blue),
        ReviewModel(name: "Jessica Lee", username: "@jesslee", text: "Love the clean design and how easy it is to use. A must-have.", rating: 5, initial: "J", color: .pink)
    ]
    
    private let reviews2: [ReviewModel] = [
        ReviewModel(name: "David Miller", username: "@dmiller", text: "Finally an app that understands what I need. Highly recommend!", rating: 5, initial: "D", color: .orange),
        ReviewModel(name: "Emily Wilson", username: "@emilyw", text: "Changed my life. So grateful for this app and the community.", rating: 5, initial: "E", color: .green),
        ReviewModel(name: "Alex Thompson", username: "@alex_t", text: "Great for building consistent habits. The widgets are amazing.", rating: 5, initial: "A", color: .teal)
    ]
    
    var body: some View {
        ZStack {
            // Orange Background
            Color.appAccent
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: isCompact ? 20 : 40)
                        
                        // Header Image (Laurel Wreath / Rating Image)
                        Image("FAITHWALL")
                            .resizable()
                            .scaledToFit()
                            .frame(height: isCompact ? 120 : 160)
                            .padding(.bottom, 10)
                        
                        // Subtitle
                        Text("This app was designed for people like you...")
                            .font(.system(size: isCompact ? 16 : 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        // User Count Section
                        HStack(spacing: 12) {
                            HStack(spacing: -12) {
                                ForEach(["image-3-review", "image-2-review", "image-1-review"], id: \.self) { imageName in
                                    Image(imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 36, height: 36)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                }
                            }
                            
                            Text("+10 000 believers")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, isCompact ? 20 : 30)
                        
                        // Reviews Marquee
                        VStack(spacing: 16) {
                            // Row 1: Right to Left
                            ReviewMarqueeRow(reviews: reviews1, direction: .rightToLeft, speed: 30)
                            
                            // Row 2: Left to Right (Blurred)
                            ReviewMarqueeRow(reviews: reviews2, direction: .leftToRight, speed: 35)
                                .blur(radius: 0.5)
                        }
                        .frame(height: 280)
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.1),
                                    .init(color: .black, location: 0.9),
                                    .init(color: .clear, location: 1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        
                        Spacer(minLength: 40)
                    }
                }
                
                // Bottom Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onContinue()
                }) {
                    Text("Next")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(30)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, isCompact ? 20 : 40)
            }
        }
        .onAppear {
            // Request review when this screen appears
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
}

struct ReviewMarqueeRow: View {
    let reviews: [ReviewModel]
    let direction: MarqueeDirection
    let speed: Double
    
    enum MarqueeDirection {
        case leftToRight
        case rightToLeft
    }
    
    @State private var offset: CGFloat = 0
    private let cardWidth: CGFloat = 280
    private let spacing: CGFloat = 16
    
    var body: some View {
        GeometryReader { geometry in
            let contentWidth = CGFloat(reviews.count) * (cardWidth + spacing)
            
            HStack(spacing: spacing) {
                // Repeat enough times to cover screen and allow scrolling
                ForEach(0..<20) { _ in 
                    ForEach(reviews) { review in
                        ReviewCard(review: review)
                    }
                }
            }
            .offset(x: offset)
            .onAppear {
                // Reset state first
                offset = direction == .rightToLeft ? 0 : -contentWidth
                
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    offset = direction == .rightToLeft ? -contentWidth : 0
                }
            }
        }
        .frame(height: 130)
    }
}

struct ReviewCard: View {
    let review: ReviewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Avatar
                Circle()
                    .fill(review.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(review.initial)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(review.color)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(review.username)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Text(review.text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 40, alignment: .topLeading) // Fixed height for text area
        }
        .padding(16)
        .frame(width: 280, height: 130) // Fixed total height
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}


// MARK: - Setup Intro View (Before Technical Steps)

struct SetupIntroView: View {
    let title: String
    let subtitle: String
    let icon: String
    let steps: [SetupStep]
    let timeEstimate: String
    let ctaText: String
    let onContinue: () -> Void
    
    struct SetupStep: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let time: String
    }
    
    @State private var contentOpacity: Double = 0
    @State private var stepsOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
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
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: isCompact ? 30 : 60)
                        
                        // Icon and title
                        VStack(spacing: isCompact ? 16 : 24) {
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(0.15))
                                    .frame(width: isCompact ? 64 : 80, height: isCompact ? 64 : 80)
                                
                                Image(systemName: icon)
                                    .font(.system(size: isCompact ? 28 : 36, weight: .medium))
                                    .foregroundColor(.appAccent)
                            }
                            
                            VStack(spacing: isCompact ? 8 : 12) {
                                Text(title)
                                    .font(.system(size: isCompact ? 22 : 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text(subtitle)
                                    .font(.system(size: isCompact ? 14 : 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .opacity(contentOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        Spacer(minLength: isCompact ? 24 : 40)
                        
                        // Steps preview
                        VStack(spacing: 0) {
                            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                                HStack(spacing: isCompact ? 12 : 16) {
                                    // Step number
                                    ZStack {
                                        Circle()
                                            .fill(Color.appAccent.opacity(0.2))
                                            .frame(width: isCompact ? 30 : 36, height: isCompact ? 30 : 36)
                                        
                                        Text("\(index + 1)")
                                            .font(.system(size: isCompact ? 14 : 16, weight: .bold))
                                            .foregroundColor(.appAccent)
                                    }
                                    
                                    // Step info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.text)
                                            .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text(step.time)
                                            .font(.system(size: isCompact ? 11 : 13))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: step.icon)
                                        .font(.system(size: isCompact ? 15 : 18))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(.vertical, isCompact ? 12 : 16)
                                
                                if index < steps.count - 1 {
                                    // Connector line
                                    HStack {
                                        Rectangle()
                                            .fill(Color.black.opacity(0.05))
                                            .frame(width: 2, height: isCompact ? 14 : 20)
                                            .padding(.leading, isCompact ? 14 : 17)
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        .opacity(stepsOpacity)
                        
                        Spacer(minLength: isCompact ? 16 : 24)
                        
                        // Time estimate badge
                        HStack(spacing: isCompact ? 6 : 8) {
                            Image(systemName: "clock")
                                .font(.system(size: isCompact ? 12 : 14))
                            
                            Text(timeEstimate)
                                .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, isCompact ? 12 : 16)
                        .padding(.vertical, isCompact ? 6 : 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.05))
                        )
                        .opacity(stepsOpacity)
                        
                        Spacer(minLength: isCompact ? 16 : 24)
                    }
                    .padding(.bottom, isCompact ? 80 : 100)
                }
                
                // Continue button
                VStack(spacing: isCompact ? 8 : 12) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onContinue()
                    }) {
                        Text(ctaText)
                            .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                            .frame(height: isCompact ? 48 : 56)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: true))
                }
                .padding(.horizontal, isCompact ? 16 : 24)
                .padding(.top, isCompact ? 12 : 18)
                .padding(.bottom, isCompact ? 16 : 22)
                .background(Color.clear)
                .opacity(buttonOpacity)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    contentOpacity = 1
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                    stepsOpacity = 1
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
                    buttonOpacity = 1
                }
                
                OnboardingAnalytics.trackStepShown("setup_intro")
            }
        }
    }
}

    // MARK: - Celebration View (After Major Steps)
    
    struct CelebrationView: View {
        let title: String
        let subtitle: String
        let encouragement: String
        let nextStepPreview: String?
        let onContinue: () -> Void
        
        @State private var checkmarkScale: CGFloat = 0
        @State private var checkmarkOpacity: Double = 0
        @State private var textOpacity: Double = 0
        @State private var confettiTrigger: Int = 0
        @State private var buttonOpacity: Double = 0
        
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
                
                // Confetti overlay
                ConfettiView(trigger: $confettiTrigger)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: isCompact ? 40 : 60)
                        
                        // Checkmark with animation
                        ZStack {
                            // Pulse rings
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .stroke(Color.appAccent.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                                    .frame(width: (isCompact ? 90 : 120) + CGFloat(i) * (isCompact ? 22 : 30), height: (isCompact ? 90 : 120) + CGFloat(i) * (isCompact ? 22 : 30))
                                    .scaleEffect(checkmarkScale)
                            }
                            
                            // Main checkmark circle
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: isCompact ? 76 : 100, height: isCompact ? 76 : 100)
                                .shadow(color: Color.appAccent.opacity(0.4), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: isCompact ? 36 : 48, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                        
                        Spacer(minLength: isCompact ? 24 : 40)
                        
                        // Text content
                        VStack(spacing: isCompact ? 10 : 16) {
                            Text(title)
                                .font(.system(size: isCompact ? 26 : 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text(subtitle)
                                .font(.system(size: isCompact ? 15 : 18))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            
                            Text(encouragement)
                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                .foregroundColor(.appAccent)
                                .padding(.top, 8)
                        }
                        .opacity(textOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        if let nextStep = nextStepPreview {
                            Spacer(minLength: isCompact ? 20 : 32)
                            
                            // Next step preview
                            HStack(spacing: isCompact ? 10 : 12) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: isCompact ? 17 : 20))
                                    .foregroundColor(.appAccent)
                                
                                Text("Next: \(nextStep)")
                                    .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .opacity(textOpacity)
                        }
                        
                        Spacer(minLength: isCompact ? 24 : 40)
                        
                        // Continue button
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            onContinue()
                        }) {
                            Text("Continue")
                                .font(.system(size: isCompact ? 16 : 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isCompact ? 14 : 18)
                                .background(
                                    RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous)
                                        .fill(Color.appAccent)
                                )
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .opacity(buttonOpacity)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        .padding(.bottom, isCompact ? 24 : 40)
                    }
                }
            }
            .onAppear {
                // Trigger celebration
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                    checkmarkScale = 1.0
                    checkmarkOpacity = 1.0
                }
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Confetti
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    confettiTrigger += 1
                }
                
                withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                    textOpacity = 1
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
                    buttonOpacity = 1
                }
            }
        }
    }
    
    // MARK: - Motivational Micro-Copy Component
    
    struct MotivationalBanner: View {
        let message: String
        let icon: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appAccent)
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appAccent.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, DS.Spacing.xl)
        }
    }
    
    // MARK: - Final Success View
    
    struct SetupCompleteView: View {
        let onContinue: () -> Void
        @ObservedObject private var quizState = OnboardingQuizState.shared
        
        // Animation states
        @State private var bubble1Offset = CGSize(width: -100, height: -100)
        @State private var bubble2Offset = CGSize(width: 100, height: -100)
        @State private var bubble3Offset = CGSize(width: 0, height: 100)
        @State private var bubble1Opacity: Double = 0
        @State private var bubble2Opacity: Double = 0
        @State private var bubble3Opacity: Double = 0
        @State private var mergedBubbleOpacity: Double = 0
        @State private var mergedBubbleScale: CGFloat = 0.5
        @State private var showFinalContent = false
        
        @State private var textOpacity: Double = 0
        @State private var statsOpacity: Double = 0
        @State private var buttonOpacity: Double = 0
        
        var body: some View {
            ZStack {
                // Dark gradient background with celebratory tint
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.96),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // 3-to-1 Animation Container
                    ZStack {
                        if !showFinalContent {
                            // Bubble 1: Social Media
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 100, height: 100)
                                .overlay(Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 40)).foregroundColor(.red))
                                .offset(bubble1Offset)
                                .opacity(bubble1Opacity)
                            
                            // Bubble 2: News/World
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                                .overlay(Image(systemName: "globe").font(.system(size: 40)).foregroundColor(.blue))
                                .offset(bubble2Offset)
                                .opacity(bubble2Opacity)
                            
                            // Bubble 3: Distractions/Noise
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 100, height: 100)
                                .overlay(Image(systemName: "waveform").font(.system(size: 40)).foregroundColor(.gray))
                                .offset(bubble3Offset)
                                .opacity(bubble3Opacity)
                            
                            // Merged Bubble: God's Word
                            Circle()
                                .fill(Color.appAccent.opacity(0.2))
                                .frame(width: 120, height: 120)
                                .overlay(Image(systemName: "cross.fill").font(.system(size: 50)).foregroundColor(.appAccent))
                                .scaleEffect(mergedBubbleScale)
                                .opacity(mergedBubbleOpacity)
                        } else {
                            // Final Hero State (Checkmark)
                            ZStack {
                                // Animated rings
                                ForEach(0..<4, id: \.self) { i in
                                    Circle()
                                        .stroke(
                                            Color.appAccent.opacity(0.3 - Double(i) * 0.07),
                                            lineWidth: 2
                                        )
                                        .frame(width: 140 + CGFloat(i) * 40, height: 140 + CGFloat(i) * 40)
                                }
                                
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .shadow(color: Color.appAccent.opacity(0.5), radius: 30, x: 0, y: 15)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(height: 300)
                    
                    Spacer()
                        .frame(height: 40)
                    
                    // Success message
                    VStack(spacing: 16) {
                        if !showFinalContent {
                            Text("Connect with God")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                            
                            Text("Through your lock screen")
                                .font(.system(size: 17))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        } else {
                            Text("Your FaithWall is Ready!")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                            
                            Text("You'll now be reminded of God's love every time you check your phone")
                                .font(.system(size: 17))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        }
                    }
                    .opacity(textOpacity)
                    .padding(.horizontal, DS.Spacing.xl)
                    .animation(.easeInOut, value: showFinalContent)
                    
                    Spacer()
                        .frame(height: 32)
                    
                    // Stats card - perfectly symmetrical
                    HStack(spacing: 0) {
                        VStack(spacing: 6) {
                            Text("\(Int(quizState.totalSetupTime / 60)):\(String(format: "%02d", Int(quizState.totalSetupTime) % 60))")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.appAccent)
                            
                            Text("Setup completed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                        }
                        .frame(maxWidth: .infinity)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 1, height: 50)
                        
                        VStack(spacing: 6) {
                            Text("∞")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.appAccent)
                            
                            Text("Daily blessings await")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                        }
                        .frame(maxWidth: .infinity)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 1, height: 50)
                        
                        VStack(spacing: 6) {
                            Text("✝️")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.appAccent)
                            
                            Text("Begin your faith journey")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                            )
                    )
                    .opacity(statsOpacity)
                    .padding(.horizontal, DS.Spacing.xl)
                    
                    Spacer()
                    
                    // Continue button
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        quizState.setupCompleted = true
                        onContinue()
                    }) {
                        Text("Begin Your Journey")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.appAccent)
                            )
                            .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                    }
                    .opacity(buttonOpacity)
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, 40)
                }
            }
            .onAppear {
                // Phase 1: Show bubbles
                withAnimation(.easeOut(duration: 0.8)) {
                    bubble1Opacity = 1
                    bubble2Opacity = 1
                    bubble3Opacity = 1
                    textOpacity = 1 // Show "Connect with God" text
                }
                
                // Phase 2: Merge bubbles (3-to-1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        bubble1Offset = .zero
                        bubble2Offset = .zero
                        bubble3Offset = .zero
                    }
                    
                    // Fade out individual bubbles as they merge
                    withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
                        bubble1Opacity = 0
                        bubble2Opacity = 0
                        bubble3Opacity = 0
                    }
                    
                    // Show merged bubble
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.4)) {
                        mergedBubbleOpacity = 1
                        mergedBubbleScale = 1.2
                    }
                }
                
                // Phase 3: Transition to Final Content
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        mergedBubbleOpacity = 0
                        mergedBubbleScale = 2.0 // Expand out
                    }
                    
                    withAnimation(.easeIn(duration: 0.8).delay(0.3)) {
                        showFinalContent = true
                    }
                    
                    // Haptic
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                
                // Phase 4: Show Stats and Button
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        statsOpacity = 1
                    }
                    withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                        buttonOpacity = 1
                    }
                }
                
                OnboardingAnalytics.trackStepShown("setup_complete")
                OnboardingAnalytics.trackPaywallShown(totalSetupTime: quizState.totalSetupTime)
            }
        }
    }
    
    // MARK: - Reassurance View (For Troubleshooting Friction)
    
    struct ReassuranceView: View {
        let title: String
        let message: String
        let stat: String
        let statLabel: String
        let ctaText: String
        let onContinue: () -> Void
        
        @State private var contentOpacity: Double = 0
        @State private var buttonOpacity: Double = 0
        
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
                    Spacer()
                    
                    VStack(spacing: 32) {
                        // Reassurance icon
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.orange)
                        }
                        
                        // Title and message
                        VStack(spacing: 16) {
                            Text(title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text(message)
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, DS.Spacing.xl)
                        
                        // Stat badge
                        VStack(spacing: 8) {
                            Text(stat)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.appAccent)
                            
                            Text(statLabel)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.black.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                                )
                        )
                    }
                    .opacity(contentOpacity)
                    
                    Spacer()
                    
                    // Continue button
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onContinue()
                    }) {
                        Text(ctaText)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.appAccent)
                            )
                            .shadow(color: Color.appAccent.opacity(0.3), radius: 12, x: 0, y: 6)
                    }
                    .opacity(buttonOpacity)
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, 40)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    contentOpacity = 1
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                    buttonOpacity = 1
                }
            }
        }
    }
    
    // MARK: - Quiz Data
    
    struct QuizData {
        static let forgetMostOptions = [
            QuizQuestionView.QuizOption(emoji: "🙏", title: "Consistency in prayer", value: "Prayer"),
            QuizQuestionView.QuizOption(emoji: "�", title: "Reading the Bible daily", value: "Bible"),
            QuizQuestionView.QuizOption(emoji: "☁️", title: "Feeling distant from God", value: "Distance"),
            QuizQuestionView.QuizOption(emoji: "🌱", title: "Applying Bible verse to life", value: "Application"),
            QuizQuestionView.QuizOption(emoji: "🔊", title: "Distractions & worldly noise", value: "Distractions")
        ]
        
        static let phoneChecksOptions = [
            QuizQuestionView.QuizOption(emoji: "📱", title: "50-100 times", value: "50-100"),
            QuizQuestionView.QuizOption(emoji: "📲", title: "100-200 times", value: "100-200"),
            QuizQuestionView.QuizOption(emoji: "🔥", title: "200+ times", value: "200+")
        ]
        
        static let distractionOptions = [
            QuizQuestionView.QuizOption(emoji: "🎵", title: "Social Media (TikTok/IG)", value: "Social Media"),
            QuizQuestionView.QuizOption(emoji: "💼", title: "Work & Stress", value: "Work"),
            QuizQuestionView.QuizOption(emoji: "🎬", title: "Entertainment/Netflix", value: "Entertainment"),
            QuizQuestionView.QuizOption(emoji: "😰", title: "Anxiety & Worry", value: "Anxiety"),
            QuizQuestionView.QuizOption(emoji: "🏃", title: "Just busy life", value: "Busy")
        ]
        
        static let setupSteps = [
            SetupIntroView.SetupStep(icon: "link", text: "Connect the spiritual shortcut", time: "~3 minutes"),
            SetupIntroView.SetupStep(icon: "book.fill", text: "Add your first Bible verse", time: "~30 seconds"),
            SetupIntroView.SetupStep(icon: "photo", text: "Choose your wallpaper style", time: "~30 seconds")
        ]
    }
    
    // MARK: - Confetti View
    
    struct ConfettiView: View {
        @Binding var trigger: Int
        @State private var particles: [Particle] = []
        
        struct Particle: Identifiable {
            let id = UUID()
            var x: Double
            var y: Double
            var angle: Double
            var spin: Double
            var scale: Double
            var color: Color
            var speedX: Double
            var speedY: Double
            var spinSpeed: Double
            var opacity: Double = 1.0
        }
        
        var body: some View {
            GeometryReader { geometry in
                TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
                    Canvas { context, size in
                        for particle in particles {
                            let rect = CGRect(x: particle.x, y: particle.y, width: 10 * particle.scale, height: 10 * particle.scale)
                            var shape = context.transform
                            shape = shape.translatedBy(x: rect.midX, y: rect.midY)
                            shape = shape.rotated(by: CGFloat(particle.spin * .pi / 180))
                            shape = shape.translatedBy(x: -rect.midX, y: -rect.midY)
                            
                            context.drawLayer { ctx in
                                ctx.transform = shape
                                ctx.opacity = particle.opacity
                                ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(particle.color))
                            }
                        }
                    }
                    .onChange(of: timeline.date) { _ in
                        updateParticles(in: geometry.size)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: trigger) { _ in
                emitConfetti()
            }
        }
        
        private func emitConfetti() {
            // Clear any existing particles first to prevent accumulation
            particles.removeAll()
            
            let colors: [Color] = [.red, .blue, .yellow, .pink, .purple, .orange]
            let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            
            // Reduced from 200 to 100 particles for better performance
            for _ in 0..<100 {
                let angle = Double.random(in: 0...2 * .pi)
                let speed = Double.random(in: 18...35)
                
                let particle = Particle(
                    x: screenWidth / 2,
                    y: screenHeight / 2,
                    angle: Double.random(in: 0...360),
                    spin: Double.random(in: 0...360),
                    scale: Double.random(in: 0.7...1.2),
                    color: colors.randomElement() ?? .blue,
                    speedX: cos(angle) * speed,
                    speedY: sin(angle) * speed,
                    spinSpeed: Double.random(in: -12...12)
                )
                particles.append(particle)
            }
        }
        
        private func updateParticles(in size: CGSize) {
            var indicesToRemove: [Int] = []
            
            for i in particles.indices {
                particles[i].x += particles[i].speedX
                particles[i].y += particles[i].speedY
                particles[i].spin += particles[i].spinSpeed
                
                // Physics: Gravity and Air Resistance
                particles[i].speedX *= 0.96
                particles[i].speedY *= 0.96
                particles[i].speedY += 0.5
                
                // Fade out smoothly
                particles[i].opacity -= 0.008
                
                // Mark for removal if off-screen or invisible
                if particles[i].opacity <= 0 ||
                    particles[i].y > size.height + 50 ||
                    particles[i].x < -50 ||
                    particles[i].x > size.width + 50 {
                    indicesToRemove.append(i)
                }
            }
            
            // Remove in reverse order to maintain indices
            for index in indicesToRemove.reversed() {
                particles.remove(at: index)
            }
        }
    }
    
    // MARK: - Symptoms Screen
    
    struct SymptomsView: View {
        let onContinue: () -> Void
        
        @State private var headerOpacity: Double = 0
        @State private var symptomCards: [(opacity: Double, offset: CGFloat)] = Array(repeating: (0, 30), count: 3)
        @State private var hopeOpacity: Double = 0
        @State private var buttonOpacity: Double = 0
        
        private var isCompact: Bool { ScreenDimensions.isCompactDevice }
        
        struct SymptomCard: Identifiable {
            let id = UUID()
            let icon: String
            let title: String
            let description: String
        }
        
        private let symptoms: [SymptomCard] = [
            SymptomCard(icon: "waveform.path.ecg", title: "Digital Noise", description: "Social media drowns out God's still, small voice."),
            SymptomCard(icon: "brain.head.profile", title: "Spiritual Forgetfulness", description: "We read a Bible verse but forget it by the afternoon."),
            SymptomCard(icon: "wifi.slash", title: "Disconnected from God", description: "Hours on our phones, but 'no time' to pray.")
        ]
        
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.99, green: 0.98, blue: 0.97), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: isCompact ? 20 : 28) {
                            Spacer(minLength: isCompact ? 40 : 60)
                            
                            // Header
                            VStack(spacing: isCompact ? 8 : 12) {
                                Text("The Modern Christian Struggle")
                                    .font(.system(size: isCompact ? 24 : 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text("Why is it so hard to stay consistent?")
                                    .font(.system(size: isCompact ? 14 : 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                            .opacity(headerOpacity)
                            
                            // Struggle label
                            Text("THE REALITY")
                                .font(.system(size: isCompact ? 12 : 13, weight: .medium))
                                .foregroundColor(.appAccent)
                                .textCase(.uppercase)
                                .opacity(headerOpacity)
                            
                            // Symptom cards
                            VStack(spacing: isCompact ? 12 : 16) {
                                ForEach(Array(symptoms.enumerated()), id: \.element.id) { index, symptom in
                                    HStack(spacing: isCompact ? 12 : 16) {
                                        Image(systemName: symptom.icon)
                                            .font(.system(size: isCompact ? 20 : 24))
                                            .foregroundColor(.appAccent)
                                            .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)
                                        
                                        VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
                                            Text(symptom.title)
                                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                            
                                            Text(symptom.description)
                                                .font(.system(size: isCompact ? 12 : 14))
                                                .foregroundColor(.secondary)
                                                .lineSpacing(2)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(isCompact ? 14 : 18)
                                    .background(
                                        RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                            .fill(Color.black.opacity(0.03))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                                                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                                            )
                                    )
                                    .opacity(symptomCards[index].opacity)
                                    .offset(y: symptomCards[index].offset)
                                }
                            }
                            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                            
                            // Hope message
                            VStack(spacing: isCompact ? 8 : 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: isCompact ? 20 : 24))
                                    .foregroundColor(.appAccent)
                                
                                Text("But there is hope.")
                                    .font(.system(size: isCompact ? 16 : 19, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, isCompact ? 16 : 24)
                            .opacity(hopeOpacity)
                            
                            Spacer(minLength: isCompact ? 30 : 50)
                        }
                        .padding(.bottom, isCompact ? 90 : 110)
                    }
                    
                    // Continue Button
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
                    .padding(.top, isCompact ? 12 : 18)
                    .padding(.bottom, isCompact ? 16 : 22)
                    .background(
                        LinearGradient(
                            colors: [Color.white.opacity(0), Color.white.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom)
                        .frame(height: isCompact ? 100 : 120)
                        .offset(y: isCompact ? -30 : -40)
                        .allowsHitTesting(false)
                    )
                    .opacity(buttonOpacity)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    headerOpacity = 1
                }
                
                for i in 0..<symptoms.count {
                    withAnimation(.easeOut(duration: 0.5).delay(0.3 + Double(i) * 0.1)) {
                        symptomCards[i].opacity = 1
                        symptomCards[i].offset = 0
                    }
                }
                
                withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
                    hopeOpacity = 1
                }
                
                withAnimation(.easeOut(duration: 0.4).delay(1.1)) {
                    buttonOpacity = 1
                }
                
                OnboardingAnalytics.trackStepShown("symptoms")
            }
        }
    }
    
    // MARK: - How App Helps Screen
    
    struct HowAppHelpsView: View {
        let onContinue: () -> Void
        
        @State private var headerOpacity: Double = 0
        @State private var benefitCards: [(opacity: Double, offset: CGFloat)] = Array(repeating: (0, 30), count: 3)
        @State private var ctaOpacity: Double = 0
        @State private var buttonOpacity: Double = 0
        
        private var isCompact: Bool { ScreenDimensions.isCompactDevice }
        
        struct BenefitCard: Identifiable {
            let id = UUID()
            let icon: String
            let title: String
            let description: String
        }
        
        private let benefits: [BenefitCard] = [
            BenefitCard(icon: "book.closed.fill", title: "Bible Verses on Lock Screen", description: "See a Bible verse every time you unlock—up to 96x a day."),
            BenefitCard(icon: "photo.artframe", title: "Beautiful Wallpapers", description: "Choose from presets or use your own photos."),
            BenefitCard(icon: "arrow.triangle.2.circlepath", title: "Auto-Update Magic", description: "Change your verse and wallpaper updates instantly.")
        ]
        
        var body: some View {
            ZStack {
                // Morning Light Theme (Warm Peach/Cream)
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.96, blue: 0.94), Color(red: 1.0, green: 0.99, blue: 0.98)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: isCompact ? 20 : 28) {
                            Spacer(minLength: isCompact ? 40 : 60)
                            
                            // Header
                            VStack(spacing: isCompact ? 8 : 12) {
                                Text("Turn Your Phone Into a Sanctuary")
                                    .font(.system(size: isCompact ? 24 : 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text("Reclaim your screen time for God.")
                                    .font(.system(size: isCompact ? 14 : 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                            .opacity(headerOpacity)
                            
                            // How FaithWall Helps label
                            Text("THE SOLUTION")
                                .font(.system(size: isCompact ? 12 : 13, weight: .medium))
                                .foregroundColor(.appAccent)
                                .textCase(.uppercase)
                                .opacity(headerOpacity)
                            
                            // Benefit cards
                            VStack(spacing: isCompact ? 12 : 16) {
                                ForEach(Array(benefits.enumerated()), id: \.element.id) { index, benefit in
                                    VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
                                        HStack(spacing: isCompact ? 10 : 12) {
                                            Image(systemName: benefit.icon)
                                                .font(.system(size: isCompact ? 18 : 22))
                                                .foregroundColor(.appAccent)
                                            
                                            Text(benefit.title)
                                                .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Text(benefit.description)
                                            .font(.system(size: isCompact ? 12 : 14))
                                            .foregroundColor(.secondary) // Fixed: Was white text on light background
                                            .lineSpacing(3)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(isCompact ? 16 : 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.appAccent.opacity(0.08), Color.appAccent.opacity(0.03)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
                                                    .strokeBorder(Color.appAccent.opacity(0.15), lineWidth: 1)
                                            )
                                    )
                                    .opacity(benefitCards[index].opacity)
                                    .offset(y: benefitCards[index].offset)
                                }
                            }
                            .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                            
                            // CTA message
                            VStack(spacing: isCompact ? 6 : 8) {
                                Image(systemName: "cross.case.fill")
                                    .font(.system(size: isCompact ? 18 : 22))
                                    .foregroundColor(.appAccent)
                                
                                Text("Let a Bible verse transform your day.")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, isCompact ? 16 : 24)
                            .opacity(ctaOpacity)
                            
                            Spacer(minLength: isCompact ? 30 : 50)
                        }
                        .padding(.bottom, isCompact ? 90 : 110)
                    }
                    
                    // Continue Button
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
                    .padding(.top, isCompact ? 12 : 18)
                    .padding(.bottom, isCompact ? 16 : 22)
                    .background(
                        LinearGradient(
                            colors: [Color.white.opacity(0), Color.white.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: isCompact ? 100 : 120)
                        .offset(y: isCompact ? -30 : -40)
                        .allowsHitTesting(false)
                    )
                    .opacity(buttonOpacity)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    headerOpacity = 1
                }
                
                for i in 0..<benefits.count {
                    withAnimation(.easeOut(duration: 0.5).delay(0.3 + Double(i) * 0.1)) {
                        benefitCards[i].opacity = 1
                        benefitCards[i].offset = 0
                    }
                }
                
                withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
                    ctaOpacity = 1
                }
                
                withAnimation(.easeOut(duration: 0.4).delay(1.1)) {
                    buttonOpacity = 1
                }
                
                OnboardingAnalytics.trackStepShown("how_app_helps")
            }
        }
    }
    
// MARK: - New Results Preview View (Radar Chart)

struct ResultsPreviewView: View {
    let onContinue: () -> Void
    @ObservedObject private var quizState = OnboardingQuizState.shared
    
    // Animation states
    @State private var showContent = false
    @State private var radarProgress: CGFloat = 0
    @State private var barProgress: CGFloat = 0
    
    // Adaptive layout
    private var isCompact: Bool { ScreenDimensions.isCompactDevice }
    
    private var phoneCheckDisplay: String {
        switch quizState.phoneChecks {
        case "50-100": return "50+"
        case "100-200": return "100+"
        case "200+": return "200+"
        default: return "96+"
        }
    }
    
    var body: some View {
        ZStack {
            // Light gradient background
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.97, blue: 0.95), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Title Section
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Analysis Complete")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.appAccent)
                                    .font(.system(size: 24))
                            }
                            
                            Text("See how FaithWall transforms your faith journey")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // Timeline Comparison Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("YOUR FAITH GROWTH TRAJECTORY")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.appAccent)
                                .tracking(1)
                            
                            // Timeline Graph
                            VStack(spacing: 20) {
                                // With FaithWall line
                                HStack(spacing: 8) {
                                    Circle().fill(Color.appAccent).frame(width: 10, height: 10)
                                    Text("With FaithWall").font(.subheadline).foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Growth curve visualization
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        // Without FaithWall (grey declining line with bump)
                                        Path { path in
                                            let width = geo.size.width
                                            let height = geo.size.height
                                            
                                            // Start at same point as growth
                                            path.move(to: CGPoint(x: 0, y: height * 0.75))
                                            
                                            // Curve pattern: slight dip, bump up, then decline
                                            path.addCurve(
                                                to: CGPoint(x: width * 0.35, y: height * 0.8),
                                                control1: CGPoint(x: width * 0.15, y: height * 0.78),
                                                control2: CGPoint(x: width * 0.25, y: height * 0.82)
                                            )
                                            
                                            // Bump up in the middle
                                            path.addCurve(
                                                to: CGPoint(x: width * 0.5, y: height * 0.7),
                                                control1: CGPoint(x: width * 0.4, y: height * 0.75),
                                                control2: CGPoint(x: width * 0.45, y: height * 0.68)
                                            )
                                            
                                            // Decline to the end
                                            path.addCurve(
                                                to: CGPoint(x: width, y: height * 0.92),
                                                control1: CGPoint(x: width * 0.6, y: height * 0.75),
                                                control2: CGPoint(x: width * 0.8, y: height * 0.88)
                                            )
                                        }
                                        .stroke(
                                            Color.gray.opacity(0.4),
                                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                        )
                                        
                                        // With FaithWall (orange growth curve with glow)
                                        // Glow effect layer 1 (outermost)
                                        Path { path in
                                            let width = geo.size.width
                                            let height = geo.size.height
                                            
                                            path.move(to: CGPoint(x: 0, y: height * 0.75))
                                            
                                            path.addCurve(
                                                to: CGPoint(x: width, y: height * 0.12),
                                                control1: CGPoint(x: width * 0.4, y: height * 0.75),
                                                control2: CGPoint(x: width * 0.6, y: height * 0.12)
                                            )
                                        }
                                        .trim(from: 0, to: radarProgress)
                                        .stroke(
                                            Color.appAccent.opacity(0.2),
                                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                                        )
                                        .blur(radius: 8)
                                        
                                        // Glow effect layer 2 (middle)
                                        Path { path in
                                            let width = geo.size.width
                                            let height = geo.size.height
                                            
                                            path.move(to: CGPoint(x: 0, y: height * 0.75))
                                            
                                            path.addCurve(
                                                to: CGPoint(x: width, y: height * 0.12),
                                                control1: CGPoint(x: width * 0.4, y: height * 0.75),
                                                control2: CGPoint(x: width * 0.6, y: height * 0.12)
                                            )
                                        }
                                        .trim(from: 0, to: radarProgress)
                                        .stroke(
                                            Color.appAccent.opacity(0.4),
                                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                        )
                                        .blur(radius: 4)
                                        
                                        // Main orange line
                                        Path { path in
                                            let width = geo.size.width
                                            let height = geo.size.height
                                            
                                            path.move(to: CGPoint(x: 0, y: height * 0.75))
                                            
                                            path.addCurve(
                                                to: CGPoint(x: width, y: height * 0.12),
                                                control1: CGPoint(x: width * 0.4, y: height * 0.75),
                                                control2: CGPoint(x: width * 0.6, y: height * 0.12)
                                            )
                                        }
                                        .trim(from: 0, to: radarProgress)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.appAccent.opacity(0.8), Color.appAccent, Color.appAccent],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                        )
                                        
                                        // White dot at the end of growth curve
                                        if radarProgress >= 0.95 {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 12, height: 12)
                                                .shadow(color: Color.appAccent.opacity(0.8), radius: 8)
                                                .shadow(color: Color.appAccent.opacity(0.6), radius: 4)
                                                .position(
                                                    x: geo.size.width,
                                                    y: geo.size.height * 0.12
                                                )
                                                .opacity(radarProgress >= 1.0 ? 1 : 0)
                                        }
                                    }
                                }
                                .frame(height: 160)
                                
                                // Without FaithWall line
                                HStack(spacing: 8) {
                                    Circle().fill(Color.gray.opacity(0.4)).frame(width: 10, height: 10)
                                    Text("Without FaithWall").font(.subheadline).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 12)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 10)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // Key Insight Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.appAccent)
                                Text("KEY INSIGHT")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.appAccent)
                                    .tracking(1)
                            }
                            
                            Text("You check your phone \(phoneCheckDisplay) times daily. Each check is an opportunity to see God's Word instead of distractions. FaithWall turns every unlock into a moment of faith.")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.appAccent.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // Consistency Rate Comparison
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CONSISTENCY RATE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.appAccent)
                                .tracking(1)
                            
                            // Alone Bar
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Trying Alone")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("18%")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.gray.opacity(0.15))
                                        Capsule().fill(Color.gray.opacity(0.5))
                                            .frame(width: geo.size.width * 0.18)
                                    }
                                }
                                .frame(height: 12)
                            }
                            
                            // With FaithWall Bar
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("With FaithWall")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.appAccent)
                                    Spacer()
                                    Text("94%")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.appAccent)
                                }
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.appAccent.opacity(0.15))
                                        Capsule().fill(
                                            LinearGradient(
                                                colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * 0.94 * barProgress)
                                    }
                                }
                                .frame(height: 12)
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 10)
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        // Stats Grid
                        HStack(spacing: 16) {
                            // Days to Habit Card
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.appAccent)
                                    .font(.system(size: 24))
                                
                                Spacer()
                                
                                Text("21 Days")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("To Build the Habit")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 140)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.05), radius: 10)
                            
                            // Success Rate Card
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.appAccent)
                                    .font(.system(size: 24))
                                
                                Spacer()
                                
                                Text("94%")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("Success Rate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 140)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.05), radius: 10)
                        }
                        .padding(.horizontal, AdaptiveLayout.horizontalPadding)
                        
                        Spacer(minLength: 40)
                    }
                }
                
                // Bottom Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onContinue()
                }) {
                    HStack(spacing: 10) {
                        Text("Start Your Journey")
                            .font(.system(size: 18, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.m)
                    .background(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appAccent.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(30)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, isCompact ? 20 : 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                radarProgress = 1.0
                barProgress = 1.0
            }
        }
    }
}

// MARK: - Radar Chart Components

struct RadarChartView: View {
    let data: [Double]
    let maxData: [Double]
    let labels: [String]
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 * 0.7
            
            ZStack {
                // Background Grid (Web)
                RadarGrid(sides: data.count, radius: radius, center: center)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                
                // Labels
                ForEach(0..<labels.count, id: \.self) { i in
                    RadarLabel(text: labels[i], index: i, total: labels.count, radius: radius + 35, center: center)
                }
                
                // Potential Shape (Max Data)
                RadarShape(data: maxData, radius: radius, center: center)
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                
                // User Data Shape
                RadarShape(data: data, radius: radius * progress, center: center)
                    .fill(Color.blue.opacity(0.3))
                
                RadarShape(data: data, radius: radius * progress, center: center)
                    .stroke(Color.blue, lineWidth: 2)
            }
        }
    }
}

struct RadarGrid: Shape {
    let sides: Int
    let radius: CGFloat
    let center: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Concentric pentagons
        for i in 1...4 {
            let currentRadius = radius * (CGFloat(i) / 4.0)
            let angleStep = 2 * .pi / Double(sides)
            
            for j in 0..<sides {
                let angle = CGFloat(j) * CGFloat(angleStep) - .pi / 2
                let point = CGPoint(
                    x: center.x + cos(angle) * currentRadius,
                    y: center.y + sin(angle) * currentRadius
                )
                
                if j == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
        
        // Radial lines
        let angleStep = 2 * .pi / Double(sides)
        for j in 0..<sides {
            let angle = CGFloat(j) * CGFloat(angleStep) - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            path.move(to: center)
            path.addLine(to: point)
        }
        
        return path
    }
}

struct RadarShape: Shape {
    let data: [Double]
    let radius: CGFloat
    let center: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sides = data.count
        let angleStep = 2 * .pi / Double(sides)
        
        for i in 0..<sides {
            let angle = CGFloat(i) * CGFloat(angleStep) - .pi / 2
            let value = CGFloat(data[i])
            let point = CGPoint(
                x: center.x + cos(angle) * radius * value,
                y: center.y + sin(angle) * radius * value
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct RadarLabel: View {
    let text: String
    let index: Int
    let total: Int
    let radius: CGFloat
    let center: CGPoint
    
    var body: some View {
        let angleStep = 2 * .pi / Double(total)
        let angle = CGFloat(index) * CGFloat(angleStep) - .pi / 2
        let x = center.x + cos(angle) * radius
        let y = center.y + sin(angle) * radius
        
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.gray)
            .position(x: x, y: y)
    }
}
// MARK: - Pipeline Choice View

struct PipelineChoiceView: View {
    let onSelectFullScreen: () -> Void
    let onSelectWidget: () -> Void
    
    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer()
            
            Text("Choose Your Setup")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            Text("How would you like to see your daily verses?")
                .font(DS.Fonts.bodyLarge())
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: DS.Spacing.m) {
                // Full Screen Option
                Button(action: onSelectFullScreen) {
                    HStack {
                        Image(systemName: "iphone")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .frame(width: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lock Screen Wallpaper")
                                .font(DS.Fonts.bodyLarge().weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text("Automated daily updates")
                                .font(DS.Fonts.bodySmall())
                                .foregroundColor(.white.opacity(0.85))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(DS.Colors.accent)
                    .cornerRadius(DS.Radius.large)
                }
                .buttonStyle(ScaleButtonStyle())
                
                // Widget Option
                Button(action: onSelectWidget) {
                    HStack {
                        Image(systemName: "square.text.square")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .frame(width: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Home Screen Widget")
                                .font(DS.Fonts.bodyLarge().weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text("Simple widget setup")
                                .font(DS.Fonts.bodySmall())
                                .foregroundColor(.white.opacity(0.85))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(DS.Colors.accent)
                    .cornerRadius(DS.Radius.large)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, DS.Spacing.xl)
            
            Spacer()
        }
        .background(DS.Colors.background.ignoresSafeArea())
    }
}

// MARK: - Onboarding Verse Selection View (Adapted from WidgetVerseSelectionView)

struct OnboardingVerseSelectionView: View {
    let onVerseSelected: (String, String) -> Void
    
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
                Text("Add Your First Note")
                    .font(.system(size: isCompact ? 24 : 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Select a verse to display on your lock screen")
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
            
            // Continue Button for Write Mode
            if selectedTab == 0 {
                Button(action: {
                    onVerseSelected(manualText, manualReference)
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(manualText.isEmpty ? Color.gray.opacity(0.5) : Color.appAccent)
                        .cornerRadius(16)
                        .shadow(color: manualText.isEmpty ? .clear : Color.appAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(manualText.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .opacity(contentOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                        onVerseSelected(verse.text, verse.reference)
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
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verse Text")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                TextEditor(text: $manualText)
                    .frame(height: 140)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Reference")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                TextField("e.g. John 3:16", text: $manualReference)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    // MARK: - Explore View
    
    private var exploreView: some View {
        NavigationView {
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
                
                BibleBookListView(
                    languageManager: languageManager,
                    onVerseSelected: { verse in
                        selectedVerseForConfirmation = verse
                        showConfirmationAlert = true
                    }
                )
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
                .padding(.horizontal, 24)
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
        let query = searchText
        let translation = languageManager.selectedTranslation
        
        Task {
            var results: [BibleVerse] = []
            
            do {
                // Use BibleDatabaseService for search (run on background to avoid blocking UI)
                results = try await Task.detached(priority: .userInitiated) {
                    try BibleDatabaseService.shared.searchVerses(
                        query: query,
                        translation: translation
                    )
                }.value
            } catch {
                print("Search error: \(error)")
            }
            
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
}
