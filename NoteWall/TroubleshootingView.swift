import SwiftUI

struct TroubleshootingView: View {
    @Binding var isPresented: Bool
    @Binding var shouldRestartOnboarding: Bool
    @State private var currentStep: TroubleshootingStep = .start
    @Environment(\.dismiss) private var dismiss
    
    // Animation states
    @State private var animateIn = false
    @State private var pulseAnimation = false
    @State private var floatOffset: CGFloat = 0
    @State private var progressWidth: CGFloat = 0
    
    private var stepProgress: CGFloat {
        switch currentStep {
        case .start: return 0
        case .issue1: return 0.33
        case .issue2: return 0.66
        case .support: return 1.0
        }
    }
    
    var body: some View {
        ZStack {
            // Animated dark background
            troubleshootingBackground
            
            VStack(spacing: 0) {
                // Header with close button and progress
                headerView
                
                // Content
                ZStack {
                    switch currentStep {
                    case .start:
                        startView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case .issue1:
                        issue1View
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case .issue2:
                        issue2View
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case .support:
                        supportView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity
                            ))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                floatOffset = -10
            }
        }
    }
    
    // MARK: - Background
    
    private var troubleshootingBackground: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.02, green: 0.02, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Accent glow orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -120, y: -280)
                .blur(radius: 50)
                .opacity(pulseAnimation ? 0.8 : 0.5)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .offset(x: 140, y: 400)
                .blur(radius: 40)
                .opacity(pulseAnimation ? 0.6 : 0.4)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                // Back button (when not on start)
                if currentStep != .start {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            animateIn = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                goToPreviousStep()
                                animateIn = true
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                    }
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: animateIn)
                } else {
                    Spacer().frame(width: 36)
                }
                
                Spacer()
                
                // Close button
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Progress bar (when not on start)
            if currentStep != .start {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        // Progress fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * stepProgress, height: 4)
                            .shadow(color: Color.appAccent.opacity(0.5), radius: 4, x: 0, y: 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: stepProgress)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 24)
                .opacity(animateIn ? 1 : 0)
            }
        }
    }
    
    // MARK: - Start View
    
    private var startView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Animated icon
            ZStack {
                // Outer pulsing rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        .frame(width: 140 + CGFloat(i) * 35, height: 140 + CGFloat(i) * 35)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .opacity(pulseAnimation ? 0.3 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                            value: pulseAnimation
                        )
                }
                
                // Main icon container
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                                colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.appAccent)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .offset(y: floatOffset)
            }
            .frame(height: 220)
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateIn)
            
            // Title
            VStack(spacing: 12) {
            Text("Troubleshooting")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            
            Text("Let's fix the issue together")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .multilineTextAlignment(.center)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
            
            Spacer()
            
            // CTA Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    animateIn = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentStep = .issue1
                        animateIn = true
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Start Troubleshooting")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appAccent)
                            .blur(radius: 15)
                            .opacity(0.5)
                            .offset(y: 5)
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 28)
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.9)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: animateIn)
            
            Spacer().frame(height: 60)
        }
    }
    
    // MARK: - Issue 1: Shortcut Setup
    
    private var issue1View: some View {
        VStack(spacing: 0) {
            // Header section
            VStack(spacing: 16) {
                // Step indicator
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Text("1")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.appAccent)
                }
                .offset(y: floatOffset * 0.5)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: animateIn)
                
                VStack(spacing: 8) {
                Text("Shortcut Setup")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                
                    // Badge
                Text("Most Common Issue")
                        .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appAccent)
                        .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                                .fill(Color.appAccent.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: animateIn)
            }
            .padding(.top, 20)
            .padding(.bottom, 28)
            
            Spacer()
            
            // Content card
            VStack(alignment: .leading, spacing: 0) {
                // Problem section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.orange)
                        }
                        
                        Text("The Problem")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("Something may have gone wrong during the shortcut installation process.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .opacity(animateIn ? 1 : 0)
                .offset(x: animateIn ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: animateIn)
                
                Spacer().frame(height: 14)
                
                // Solution section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundColor(.appAccent)
                        }
                        
                        Text("The Solution")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("Click \"Yes, Fix This\" below to re-install the shortcut and complete the setup correctly with our step-by-step guide.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appAccent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        )
                )
                .opacity(animateIn ? 1 : 0)
                .offset(x: animateIn ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: animateIn)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    shouldRestartOnboarding = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPresented = false
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .bold))
                        Text("Yes, Fix This")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appAccent)
                                .blur(radius: 12)
                                .opacity(0.4)
                                .offset(y: 4)
                            
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appAccent)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.95)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.35), value: animateIn)
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        animateIn = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = .issue2
                            animateIn = true
                        }
                    }
                }) {
                    Text("No, This Is Not the Issue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.4), value: animateIn)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Issue 2: Wrong Wallpaper Selected
    
    private var issue2View: some View {
        VStack(spacing: 0) {
            // Header section - EXACT same as step 1
            VStack(spacing: 16) {
                // Step indicator
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Text("2")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.appAccent)
                }
                .offset(y: floatOffset * 0.5)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: animateIn)
                
                VStack(spacing: 8) {
                    Text("Wrong Wallpaper")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Badge
                    Text("Second Most Common")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.appAccent.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: animateIn)
            }
            .padding(.top, 20)
            .padding(.bottom, 28)
            
            Spacer()
            
            // Content cards - EXACT same styling as step 1
            VStack(alignment: .leading, spacing: 0) {
                // Problem section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 18))
                                .foregroundColor(.purple)
                        }
                        
                        Text("The Problem")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("The shortcut worked, but it put notes on the wrong wallpaper in your collection.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .opacity(animateIn ? 1 : 0)
                .offset(x: animateIn ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: animateIn)
                
                Spacer().frame(height: 14)
                
                // Solution section with steps
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.green)
                        }
                        
                        Text("Quick Fix")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        solutionStep(number: 1, text: "Swipe down on your Lock Screen")
                        solutionStep(number: 2, text: "Long-press on your wallpaper")
                        solutionStep(number: 3, text: "Select the one with notes")
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.green.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                )
                .opacity(animateIn ? 1 : 0)
                .offset(x: animateIn ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: animateIn)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Action buttons - EXACT same as step 1
            VStack(spacing: 12) {
                Button(action: {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    isPresented = false
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                        Text("Got It, I'll Fix This")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appAccent)
                                .blur(radius: 12)
                                .opacity(0.4)
                                .offset(y: 4)
                            
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appAccent)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.95)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.35), value: animateIn)
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        animateIn = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentStep = .support
                            animateIn = true
                        }
                    }
                }) {
                    Text("Still Having Issues")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.4), value: animateIn)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    private func solutionStep(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Support View
    
    private var supportView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Animated icon
            ZStack {
                // Pulsing rings
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                        .frame(width: 130 + CGFloat(i) * 30, height: 130 + CGFloat(i) * 30)
                        .scaleEffect(pulseAnimation ? 1.08 : 1.0)
                        .opacity(pulseAnimation ? 0.4 : 0.7)
                        .animation(
                            Animation.easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: pulseAnimation
                        )
                }
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                                colors: [Color.appAccent.opacity(0.2), Color.appAccent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                        .frame(width: 110, height: 110)
                
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 50))
                    .foregroundColor(.appAccent)
                        .shadow(color: Color.appAccent.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .offset(y: floatOffset)
            }
            .frame(height: 200)
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateIn)
            
            // Title
            VStack(spacing: 10) {
            Text("We're Here to Help")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Our team responds within 24 hours")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }
            .multilineTextAlignment(.center)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 15)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: animateIn)
            
            Spacer()
            
            // Contact options
            VStack(spacing: 14) {
                // Email button
                Button(action: {
                    if let url = URL(string: "mailto:support@notewall.app") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(0.15))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.appAccent)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Email Support")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("support@notewall.app")
                                .font(.system(size: 13))
                                .foregroundColor(.appAccent)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.appAccent.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .opacity(animateIn ? 1 : 0)
                .offset(x: animateIn ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: animateIn)
                
                // Twitter button
                Button(action: {
                    if let url = URL(string: "https://twitter.com/notewall") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(0.15))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "at")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.appAccent)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Twitter / X")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("@notewall")
                                .font(.system(size: 13))
                                .foregroundColor(.appAccent)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.appAccent.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .opacity(animateIn ? 1 : 0)
                .offset(x: animateIn ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: animateIn)
                
                // Close button
                Button(action: {
                    isPresented = false
                }) {
                    Text("Close")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .padding(.top, 8)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.3), value: animateIn)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Navigation
    
    private func goToPreviousStep() {
        switch currentStep {
        case .start: break
        case .issue1: currentStep = .start
        case .issue2: currentStep = .issue1
        case .support: currentStep = .issue2
        }
    }
}

// MARK: - Troubleshooting Steps

private enum TroubleshootingStep {
    case start
    case issue1
    case issue2
    case support
}

// MARK: - Preview

#Preview {
    TroubleshootingView(
        isPresented: .constant(true),
        shouldRestartOnboarding: .constant(false)
    )
}
