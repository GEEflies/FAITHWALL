import SwiftUI

/// Login view for promo code admin access
struct PromoCodeLoginView: View {
    @Binding var isPresented: Bool
    let onSuccess: () -> Void
    
    @State private var pin: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAuthenticating = false
    @State private var isLockedOut = false
    @State private var lockoutRemainingSeconds = 0
    @State private var lockoutTimer: Timer?
    @FocusState private var isPINFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
            loginBackground
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss keyboard when tapping background
                    isPINFocused = false
                }
            
            VStack(spacing: 0) {
                // Close button - top right (same as legal page)
                HStack {
                    Spacer()
                    Button(action: {
                        // Dismiss keyboard first
                        isPINFocused = false
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        // Small delay to allow keyboard to dismiss smoothly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isPresented = false
                        }
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
                
                Spacer()
                
                VStack(spacing: 32) {
                    // Lock icon
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.15))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.appAccent)
                    }
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Developer Access")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Enter 8-digit PIN to access developer tools")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    
                    // PIN Input field
                    PINInputView(pin: $pin, isFocused: $isPINFocused)
                        .padding(.horizontal, 24)
                    
                    // Error message
                    if showError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                            
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                    }
                    
                    // Login button
                    Button(action: authenticate) {
                        HStack(spacing: 10) {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            Text(isAuthenticating ? "Authenticating..." : "Login")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    pin.count == 8 && !isAuthenticating && !isLockedOut
                                        ? Color.appAccent
                                        : Color.gray.opacity(0.3)
                                )
                        )
                    }
                    .disabled(pin.count != 8 || isAuthenticating || isLockedOut)
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Cancel button
                Button(action: {
                    // Dismiss keyboard first
                    isPINFocused = false
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    // Small delay to allow keyboard to dismiss smoothly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPresented = false
                    }
                }) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 32)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere in the content
                // But allow buttons to work
                if isPINFocused {
                    isPINFocused = false
                }
            }
        }
        .onAppear {
            // Check lockout status
            checkLockoutStatus()
            
            // Start timer to check lockout status
            startLockoutTimer()
            
            // Auto-focus the PIN field if not locked out
            if !isLockedOut {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPINFocused = true
                }
            }
        }
        .onDisappear {
            lockoutTimer?.invalidate()
            lockoutTimer = nil
        }
    }
    
    private var loginBackground: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.01, green: 0.01, blue: 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Accent glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -200)
                .blur(radius: 60)
        }
    }
    
    private func authenticate() {
        guard !isAuthenticating else { return }
        guard !isLockedOut else { return }
        guard pin.count == 8 else { return }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        isAuthenticating = true
        showError = false
        
        // Add delay to prevent brute force attacks
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let result = PromoCodeAuthManager.shared.authenticate(pin: self.pin)
            
            DispatchQueue.main.async {
                self.isAuthenticating = false
                
                switch result {
                case .success:
                    // Success haptic
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)
                    
                    // Clear field
                    self.pin = ""
                    
                    // Dismiss and show admin view
                    self.isPresented = false
                    self.onSuccess()
                    
                case .failed, .invalid:
                    // Error haptic
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                    
                    self.showError = true
                    self.errorMessage = result.errorMessage
                    
                    // Clear field for security
                    self.pin = ""
                    
                    // Check if we're now locked out
                    self.checkLockoutStatus()
                    
                case .lockedOut:
                    // Lockout haptic
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                    
                    self.showError = true
                    self.errorMessage = result.errorMessage
                    self.isLockedOut = true
                    self.lockoutRemainingSeconds = PromoCodeAuthManager.shared.getRemainingLockoutTime()
                    
                    // Clear field
                    self.pin = ""
                    self.isPINFocused = false
                }
            }
        }
    }
    
    private func checkLockoutStatus() {
        let remaining = PromoCodeAuthManager.shared.getRemainingLockoutTime()
        if remaining > 0 {
            isLockedOut = true
            lockoutRemainingSeconds = remaining
            errorMessage = "Account locked. Try again in \(formatTime(remaining))."
            showError = true
        } else {
            isLockedOut = false
            lockoutRemainingSeconds = 0
            if showError && errorMessage.contains("locked") {
                showError = false
                errorMessage = ""
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    private func startLockoutTimer() {
        lockoutTimer?.invalidate()
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.isLockedOut {
                self.checkLockoutStatus()
            }
        }
    }
}

// MARK: - PIN Input View

private struct PINInputView: View {
    @Binding var pin: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<8, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isFocused && index == pin.count ? Color.appAccent.opacity(0.5) : Color.white.opacity(0.1),
                                    lineWidth: isFocused && index == pin.count ? 2 : 1
                                )
                        )
                        .frame(height: 56)
                    
                    if index < pin.count {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .overlay(
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
        .onChange(of: pin) { newValue in
            // Limit to 8 digits
            if newValue.count > 8 {
                pin = String(newValue.prefix(8))
            }
            // Only allow numbers
            pin = pin.filter { $0.isNumber }
        }
    }
}

