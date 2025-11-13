import SwiftUI
import StoreKit

@available(iOS 15.0, *)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paywallManager = PaywallManager.shared
    @StateObject private var storeManager = StoreKitManager.shared
    
    let triggerReason: PaywallTriggerReason
    let allowDismiss: Bool
    
    @State private var selectedProductIndex = 0  // Default to Lifetime (index 0)
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateIn = false
    @State private var currentStep = 1  // 1 = plan selection, 2 = trial explanation
    @State private var showTermsAndPrivacy = false
    @State private var selectedLegalDocument: LegalDocumentType = .termsAndPrivacy
    
    init(triggerReason: PaywallTriggerReason = .manual, allowDismiss: Bool = true) {
        self.triggerReason = triggerReason
        self.allowDismiss = allowDismiss
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.appAccent.opacity(0.15),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if currentStep == 1 {
                step1PlanSelection
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                step2TrialExplanation
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showTermsAndPrivacy) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(getLegalDocumentContent())
                            .font(.system(.body, design: .default))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                }
                .navigationTitle(selectedLegalDocument.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showTermsAndPrivacy = false
                        }
                    }
                }
            }
        }
        .onAppear {
            paywallManager.trackPaywallView()
            Task {
                await storeManager.loadProducts()
            }
            
            // Trigger animations
            withAnimation {
                animateIn = true
            }
        }
    }
    
    // MARK: - Step 1: Plan Selection
    
    private var step1PlanSelection: some View {
        VStack(spacing: 20) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        paywallManager.trackPaywallDismiss()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
                // Header
                VStack(spacing: 8) {
                    Text(triggerReason.title)
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Because if you see it - you'll do it")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIn)
                
                
                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "brain", title: "Never Forget Again", subtitle: "Keep your key goals, notes, and ideas always visible - every time you look at your phone.", delay: 0.1)
                    featureRow(icon: "target", title: "Stay Focused, Not Busy", subtitle: "See your priorities 50× a day and act on what really matters.", delay: 0.2)
                }
                .padding(.horizontal, 4)
                
                // Pricing options
                pricingSection
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateIn)
                
                
                // Continue button (goes to step 2)
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = 2
                        animateIn = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            animateIn = true
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Start Free Trial")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(Color.appAccent)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.appAccent.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7), value: animateIn)
                .padding(.top, 8)
                
                // Terms & Privacy and Restore Purchases
                HStack(spacing: 24) {
                    Button("Terms & Privacy") {
                        selectedLegalDocument = .termsAndPrivacy
                        showTermsAndPrivacy = true
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Button("Restore Purchases") {
                        Task {
                            await storeManager.restorePurchases()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 0)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.7), value: animateIn)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Step 2: Trial Explanation
    
    private var step2TrialExplanation: some View {
        VStack(spacing: 20) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        paywallManager.trackPaywallDismiss()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, -6)
                // Header
                VStack(spacing: 8) {
                    Text("How your free trial works")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIn)
                
                // Timeline
                trialTimeline
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateIn)
                
                // Value proposition box
                VStack(spacing: 16) {
                    // Guarantee badge
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.appAccent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("100% Risk-Free")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Cancel anytime during trial.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appAccent.opacity(0.1))
                    .cornerRadius(12)
                    
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.4), value: animateIn)
                
                // Start trial button with urgency
                VStack(spacing: 12) {
                    Button(action: handlePurchase) {
                        VStack(spacing: 6) {
                            if isPurchasing || storeManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18, weight: .bold))
                                    Text(purchaseButtonTitle)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                        .frame(height: 64)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.appAccent, Color.appAccent.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: Color.appAccent.opacity(0.5), radius: 16, x: 0, y: 8)
                    }
                    .disabled(isPurchasing || storeManager.isLoading)
                    
                }
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: animateIn)
                .padding(.top, 8)
                
                // Show all plans button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = 1
                        animateIn = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            animateIn = true
                        }
                    }
                }) {
                    Text("Show all plans")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeIn.delay(0.6), value: animateIn)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Pricing Section (iOS 15+)
    
    @available(iOS 15.0, *)
    private var pricingSection: some View {
        VStack(spacing: 12) {
            if storeManager.isLoading {
                ProgressView()
                    .padding()
            } else if storeManager.products.isEmpty {
                // Show fallback pricing when products aren't loaded from App Store Connect
                fallbackPricingCards
            } else {
                ForEach(Array(storeManager.products.enumerated()), id: \.element.id) { index, product in
                    pricingCard(for: product, index: index)
                }
            }
        }
    }
    
    // Fallback pricing cards for testing before App Store Connect setup
    private var fallbackPricingCards: some View {
        VStack(spacing: 12) {
            fallbackPricingCard(title: "NoteWall+ Lifetime", price: "€9.99", subtitle: "7-day free trial", index: 0)
            fallbackPricingCard(title: "NoteWall+ Monthly", price: "€5.99/m", subtitle: "5-day free trial", index: 1)
        }
    }
    
    private func fallbackPricingCard(title: String, price: String, subtitle: String, index: Int) -> some View {
        let isSelected = selectedProductIndex == index
        let isLifetime = index == 0  // Lifetime is now first
        
        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedProductIndex = index
            }
        }) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 16) {
                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.appAccent : Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.appAccent)
                                .frame(width: 14, height: 14)
                                .scaleEffect(isSelected ? 1 : 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isLifetime ? "Lifetime" : "Monthly")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if isLifetime {
                            Text("7-day free trial")
                                .font(.subheadline)
                                .foregroundColor(.appAccent)
                                .fontWeight(.medium)
                        } else {
                            Text("5-day free trial")
                                .font(.subheadline)
                                .foregroundColor(.appAccent)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(price)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(18)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? Color.appAccent.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 12 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.appAccent : Color.clear, lineWidth: 2)
            )
            .overlay(
                // Popular badge on the edge - in separate overlay to be above border
                Group {
                    if isLifetime {
                        HStack {
                            Spacer()
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.appAccent))
                                .offset(x: -8, y: -8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
            )
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    @available(iOS 15.0, *)
    private func pricingCard(for product: Product, index: Int) -> some View {
        let isSelected = selectedProductIndex == index
        let isLifetime = !product.id.contains("monthly")  // Lifetime doesn't contain "monthly"
        
        return Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedProductIndex = index
            }
        }) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 16) {
                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.appAccent : Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.appAccent)
                                .frame(width: 14, height: 14)
                                .scaleEffect(isSelected ? 1 : 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isLifetime ? "Lifetime" : "Monthly")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if isLifetime {
                            Text("7-day free trial")
                                .font(.subheadline)
                                .foregroundColor(.appAccent)
                                .fontWeight(.medium)
                        } else {
                            Text("5-day free trial")
                                .font(.subheadline)
                                .foregroundColor(.appAccent)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(18)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? Color.appAccent.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 12 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.appAccent : Color.clear, lineWidth: 2)
            )
            .overlay(
                // Popular badge on the edge - in separate overlay to be above border
                Group {
                    if isLifetime {
                        HStack {
                            Spacer()
                            Text("POPULAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.appAccent))
                                .offset(x: -8, y: -8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
            )
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    
    private var purchaseButtonTitle: String {
        selectedProductIndex == 0 ? "Start 7-Day Free Trial" : "Start 5-Day Free Trial"
    }
    
    // MARK: - Actions
    
    private func handlePurchase() {
        // If products aren't loaded from App Store Connect, show helpful message
        if storeManager.products.isEmpty {
            errorMessage = "In-app purchases are not yet configured. Please set up products in App Store Connect first."
            showError = true
            return
        }
        
        guard selectedProductIndex < storeManager.products.count else {
            errorMessage = "Please select a pricing option"
            showError = true
            return
        }
        
        let product = storeManager.products[selectedProductIndex]
        
        Task {
            isPurchasing = true
            
            do {
                let transaction = try await storeManager.purchase(product)
                
                await MainActor.run {
                    isPurchasing = false
                    
                    if transaction != nil {
                        // Purchase successful with haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    // MARK: - Trial Timeline
    
    private struct TimelineEvent: Identifiable {
        let id = UUID()
        let iconName: String
        let iconColor: Color
        let title: String
        let subtitle: String
    }

    private var trialTimeline: some View {
        let isLifetime = selectedProductIndex == 0  // Index 0 is now Lifetime
        let trialDays = isLifetime ? 7 : 5
        let reminderDay = isLifetime ? 5 : 3
        let iconSize: CGFloat = 44
        let itemSpacing: CGFloat = 18

        // Get price information
        let priceText: String
        if !storeManager.products.isEmpty && selectedProductIndex < storeManager.products.count {
            let product = storeManager.products[selectedProductIndex]
            priceText = product.displayPrice
        } else {
            // Fallback prices
            priceText = isLifetime ? "€9.99" : "€5.99/month"
        }

        let events: [TimelineEvent] = [
            TimelineEvent(
                iconName: "crown.fill",
                iconColor: .appAccent,
                title: "Today",
                subtitle: "Start enjoying full access to unlimited wallpapers."
            ),
            TimelineEvent(
                iconName: "bell.fill",
                iconColor: .appAccent,
                title: "In \(reminderDay) days",
                subtitle: "You'll get a reminder that your trial is about to end."
            ),
            TimelineEvent(
                iconName: "checkmark.circle.fill",
                iconColor: .appAccent,
                title: "In \(trialDays) days",
                subtitle: isLifetime ? "Your lifetime access will begin and you'll be charged \(priceText)." : "Your subscription will begin and you'll be charged \(priceText)."
            )
        ]

        return VStack(alignment: .leading, spacing: itemSpacing) {
            ForEach(events) { event in
                HStack(alignment: .top, spacing: 12) {
                    timelineIcon(for: event, size: iconSize)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(event.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .leading) {
            timelineLineBackground(iconSize: iconSize, spacing: itemSpacing, eventCount: events.count)
                .blendMode(.normal)
        }
    }

    private func timelineLineBackground(iconSize: CGFloat, spacing: CGFloat, eventCount: Int) -> some View {
        GeometryReader { geo in
            let lineColor = Color.appAccent.opacity(0.16)
            let fadeHeight: CGFloat = 36
            let topOffset = iconSize / 2
            let totalHeight = geo.size.height
            let lineHeight = max(totalHeight - topOffset, 0)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 2, height: max(lineHeight - fadeHeight, 0))

                if lineHeight > 0 {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.appAccent.opacity(0.16), Color.appAccent.opacity(0)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 2, height: min(fadeHeight, lineHeight))
                }
            }
            .frame(width: 2, height: lineHeight, alignment: .top)
            .offset(x: iconSize / 2 - 1, y: topOffset)
        }
        .frame(width: iconSize)
        .allowsHitTesting(false)
    }

    private func timelineIcon(for event: TimelineEvent, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(event.iconColor.opacity(0.16))
                .frame(width: size, height: size)

            Image(systemName: event.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(event.iconColor)
        }
        .frame(width: size, height: size)
    }
    
    private var selectedPlanInfo: some View {
        let isLifetime = selectedProductIndex == 0  // Index 0 is now Lifetime
        let trialDays = isLifetime ? 7 : 5
        let price = isLifetime ? "€9.99" : "€5.99/month"
        let planName = isLifetime ? "Lifetime" : "Monthly"
        
        return VStack(spacing: 8) {
            Text("\(trialDays)-day free trial, then \(price)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(planName)
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
    
    // MARK: - Feature Row
    
    private func featureRow(icon: String, title: String, subtitle: String, delay: Double) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.appAccent)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .opacity(animateIn ? 1 : 0)
        .offset(x: animateIn ? 0 : -20)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: animateIn)
    }
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appAccent)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private func getLegalDocumentContent() -> String {
        switch selectedLegalDocument {
        case .termsOfService:
            return """
            Terms of Service
            
            Last Updated: November 13, 2025
            
            1. Acceptance of Terms
            
            By downloading, installing, or using NoteWall ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.
            
            2. Description of Service
            
            NoteWall is a productivity application that allows users to create custom wallpapers with personal notes and reminders for their iOS devices.
            
            3. Subscription Terms
            
            • NoteWall+ Monthly: Monthly subscription with automatic renewal
            • NoteWall+ Lifetime: One-time payment for permanent access
            • Free trial periods may be offered for subscription plans
            • Subscriptions automatically renew unless cancelled 24 hours before renewal
            • Manage subscriptions in your Apple ID account settings
            
            4. User Obligations
            
            You agree to use the App only for lawful purposes and in accordance with these Terms.
            
            5. Privacy
            
            Your privacy is important to us. All notes and personal data are stored locally on your device and are not transmitted to our servers.
            
            6. Contact Information
            
            For questions or support, contact us at: iosnotewall@gmail.com
            
            Developer: [YOUR FULL LEGAL NAME]
            """
        case .privacyPolicy:
            return """
            Privacy Policy
            
            Last Updated: November 13, 2025
            
            1. Information We Collect
            
            • Notes and text you create (stored locally on your device only)
            • Photos you select for wallpapers (processed locally)
            • Device information for app compatibility
            • Anonymous performance data to improve the app
            
            2. How We Use Information
            
            • Provide wallpaper generation functionality
            • Process in-app purchases through Apple's App Store
            • Improve app performance and fix bugs
            • Provide customer support
            
            3. Data Storage
            
            • All personal content is stored locally on your device
            • We do not upload your personal content to external servers
            • Your data remains private and under your control
            
            4. Contact
            
            Email: iosnotewall@gmail.com
            Developer: [YOUR FULL LEGAL NAME]
            """
        case .termsAndPrivacy:
            return """
            TERMS OF SERVICE & PRIVACY POLICY
            
            Last Updated: November 13, 2025
            
            PART I: END-USER LICENSE AGREEMENT (EULA)
            
            1. ACKNOWLEDGEMENT
            
            This End-User License Agreement ("EULA") is a legal agreement between you ("End-User") and NoteWall Team ("Developer") for the NoteWall mobile application ("Licensed Application"). This EULA is concluded between you and the Developer only, and not with Apple Inc. ("Apple"). The Developer, not Apple, is solely responsible for the Licensed Application and its content. The EULA may not provide for usage rules for Licensed Applications that are in conflict with the Apple Media Services Terms and Conditions.
            
            2. SCOPE OF LICENSE
            
            The license granted to the End-User for the Licensed Application must be limited to a non-transferable license to use the Licensed Application on any Apple-branded Products that the End-User owns or controls and as permitted by the Usage Rules set forth in the Apple Media Services Terms and Conditions, except that such Licensed Application may be accessed and used by other accounts associated with the purchaser via Family Sharing or volume purchasing.
            
            3. MAINTENANCE AND SUPPORT
            
            You must be solely responsible for providing any maintenance and support services with respect to the Licensed Application, as specified in the EULA, or as required under applicable law. You and the End-User must acknowledge that Apple has no obligation whatsoever to furnish any maintenance and support services with respect to the Licensed Application.
            
            Contact for support: iosnotewall@gmail.com
            
            4. WARRANTY
            
            You must be solely responsible for any product warranties, whether express or implied by law, to the extent not effectively disclaimed. The EULA must provide that, in the event of any failure of the Licensed Application to conform to any applicable warranty, the End-User may notify Apple, and Apple will refund the purchase price for the Licensed Application to that End-User; and that, to the maximum extent permitted by applicable law, Apple will have no other warranty obligation whatsoever with respect to the Licensed Application, and any other claims, losses, liabilities, damages, costs or expenses attributable to any failure to conform to any warranty will be Your sole responsibility.
            
            5. PRODUCT CLAIMS
            
            You and the End-User must acknowledge that You, not Apple, are responsible for addressing any claims of the End-User or any third party relating to the Licensed Application or the end-user's possession and/or use of that Licensed Application, including, but not limited to: (i) product liability claims; (ii) any claim that the Licensed Application fails to conform to any applicable legal or regulatory requirement; and (iii) claims arising under consumer protection, privacy, or similar legislation, including in connection with Your Licensed Application's use of the HealthKit and HomeKit frameworks. The EULA may not limit Your liability to the End-User beyond what is permitted by applicable law.
            
            6. INTELLECTUAL PROPERTY RIGHTS
            
            You and the End-User must acknowledge that, in the event of any third party claim that the Licensed Application or the End-User's possession and use of that Licensed Application infringes that third party's intellectual property rights, You, not Apple, will be solely responsible for the investigation, defense, settlement and discharge of any such intellectual property infringement claim.
            
            7. LEGAL COMPLIANCE
            
            The End-User must represent and warrant that (i) he/she is not located in a country that is subject to a U.S. Government embargo, or that has been designated by the U.S. Government as a "terrorist supporting" country; and (ii) he/she is not listed on any U.S. Government list of prohibited or restricted parties.
            
            8. DEVELOPER NAME AND ADDRESS
            
            Developer Name: [YOUR FULL LEGAL NAME]
            Address: [YOUR FULL ADDRESS, CITY, POSTAL CODE, SLOVAKIA]
            Email: iosnotewall@gmail.com
            
            Contact information to which any End-User questions, complaints or claims with respect to the Licensed Application should be directed.
            
            9. THIRD PARTY TERMS OF AGREEMENT
            
            You must state in the EULA that the End-User must comply with applicable third party terms of agreement when using Your Application.
            
            10. THIRD PARTY BENEFICIARY
            
            You and the End-User must acknowledge and agree that Apple, and Apple's subsidiaries, are third party beneficiaries of the EULA, and that, upon the End-User's acceptance of the terms and conditions of the EULA, Apple will have the right (and will be deemed to have accepted the right) to enforce the EULA against the End-User as a third party beneficiary thereof.
            

            PART II: SUBSCRIPTION TERMS


            11. AUTO-RENEWABLE SUBSCRIPTIONS
            
            • Payment will be charged to your iTunes Account at confirmation of purchase
            • Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period
            • Account will be charged for renewal within 24-hours prior to the end of the current period, and identify the cost of the renewal
            • Subscriptions may be managed by the user and auto-renewal may be turned off by going to the user's Account Settings after purchase
            • Any unused portion of a free trial period, if offered, will be forfeited when the user purchases a subscription to that publication, where applicable
            
            12. FREE TRIAL TERMS
            
            • New users receive 3 free wallpaper exports to try the app
            • Premium subscriptions may include a free trial period (typically 5-7 days)
            • You will be charged at the end of the trial period unless you cancel before it ends
            • To cancel: Settings app → [Your Name] → Subscriptions → NoteWall → Cancel Subscription
            • Free trials are available to new subscribers only
            
            13. REFUND POLICY
            
            • All refund requests must be made through Apple's App Store
            • Contact Apple Support directly for refund assistance
            • Refunds are subject to Apple's refund policy
            • We cannot process refunds directly as all payments are handled by Apple
            
            14. PRICING AND AVAILABILITY
            
            • Prices are subject to change without notice
            • Subscription prices may vary by region and currency
            • Features and availability may vary by device and iOS version
            • We reserve the right to modify or discontinue features at any time
            

            PART III: PRIVACY POLICY

            
            15. INFORMATION WE COLLECT
            
            15.1 Personal Information You Provide:
            • Notes and Text: All notes you create are stored locally on your device only
            • Photos: Any photos you select for wallpaper backgrounds are processed locally on your device
            • No personal content is transmitted to our servers or third parties
            
            15.2 Automatically Collected Information:
            • Device Information: iOS version, device model (for app compatibility and optimization)
            • App Performance Data: Anonymous crash reports and performance metrics to improve the app
            • Purchase Information: Subscription status and transaction records (processed by Apple)
            • Usage Analytics: Anonymous data about app features used (no personal content)
            
            15.3 Information We Do NOT Collect:
            • We do not collect your name, email address, or contact information unless you contact us
            • We do not access your contacts, location, camera roll, or other personal data
            • We do not track your browsing habits or app usage patterns across other apps
            • We do not use cookies or similar tracking technologies
            
            16. HOW WE USE YOUR INFORMATION
            
            We use collected information to:
            • Provide the core wallpaper generation functionality
            • Process in-app purchases through Apple's App Store
            • Improve app performance and fix technical issues
            • Provide customer support when you contact us directly
            • Ensure app compatibility across different iOS versions and devices
            • Analyze app usage patterns to improve user experience (anonymized data only)
            
            17. DATA STORAGE AND SECURITY
            
            17.1 Local Storage:
            • All your notes and photos are stored exclusively on your device using iOS secure storage
            • We do not upload, sync, or backup your personal content to external servers
            • Your data remains completely private and under your control
            • Data is protected by iOS built-in security features including device encryption
            • When you delete the app, all your data is permanently removed
            
            17.2 Data Transmission:
            • No personal content (notes, photos) is transmitted over the internet
            • Only anonymous technical data may be sent for app improvement purposes
            • All purchase transactions are handled securely by Apple using industry-standard encryption
            • Any data transmission uses secure HTTPS protocols
            
            18. DATA SHARING AND DISCLOSURE
            
            We do not sell, trade, rent, or share your personal information with third parties, except in the following limited circumstances:
            
            18.1 Apple Inc.:
            • Purchase and subscription information is shared with Apple for payment processing
            • Anonymous crash reports may be shared through Apple's developer tools
            • App Store analytics data is processed by Apple according to their privacy policy
            
            18.2 Legal Requirements:
            • We may disclose information if required by law, court order, or government request
            • We may disclose information to protect our rights, property, or safety
            • We may disclose information to prevent fraud or illegal activities
            
            18.3 Business Transfers:
            • In the event of a merger, acquisition, or sale of assets, user information may be transferred
            • Users will be notified of any such transfer and their rights regarding their data
            
            19. YOUR PRIVACY RIGHTS
            
            19.1 European Union (GDPR) Rights:
            If you are located in the EU, you have the following rights:
            • Right of Access: Request information about data we process about you
            • Right of Rectification: Correct inaccurate personal data
            • Right of Erasure: Request deletion of your personal data
            • Right of Portability: Export your data in a readable format
            • Right to Object: Object to processing of your personal data
            • Right to Restrict Processing: Limit how we process your data
            • Right to Lodge a Complaint: File a complaint with your local data protection authority
            
            19.2 California Privacy Rights (CCPA):
            If you are a California resident, you have the right to:
            • Know what personal information is collected about you
            • Delete personal information we have collected
            • Opt-out of the sale of personal information (we do not sell personal information)
            • Non-discrimination for exercising your privacy rights
            
            19.3 Exercising Your Rights:
            To exercise any of these rights, contact us at: iosnotewall@gmail.com
            We will respond to your request within 30 days.
            
            20. DATA RETENTION
            
            • Notes: Stored locally on your device until you delete them or uninstall the app
            • App Settings: Stored locally until app is uninstalled
            • Purchase Records: Maintained by Apple according to their retention policies
            • Technical Data: Anonymous performance data may be retained for up to 2 years for app improvement
            • Support Communications: Retained for up to 3 years for customer service purposes
            
            21. CHILDREN'S PRIVACY
            
            NoteWall is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information immediately. Parents who believe their child has provided us with personal information should contact us at iosnotewall@gmail.com.
            
            22. INTERNATIONAL DATA TRANSFERS
            
            Since all personal data is processed locally on your device, there are no international data transfers of your personal content. Any anonymous technical data shared with us is processed in accordance with applicable data protection laws and may be transferred to countries with different data protection standards.
            
            23. CHANGES TO THIS PRIVACY POLICY
            
            We may update this Privacy Policy from time to time to reflect changes in our practices, technology, or applicable laws. We will notify you of any material changes by:
            • Posting the updated policy in the app
            • Updating the "Last Updated" date at the top of this policy
            • Sending a notification through the app if changes are significant
            
            Your continued use of the app after any changes constitutes acceptance of the updated policy.
            
            24. CONTACT INFORMATION
            
            If you have questions, concerns, or requests regarding this Privacy Policy or our privacy practices, please contact us:
            
            Email: iosnotewall@gmail.com
            Developer: [YOUR FULL LEGAL NAME]
            
            For EU residents: You also have the right to lodge a complaint with your local data protection authority.
            
            
            PART IV: GENERAL TERMS

            
            25. DISCLAIMER OF WARRANTIES
            
            THE LICENSED APPLICATION IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED OR ERROR-FREE.
            
            26. LIMITATION OF LIABILITY
            
            TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE DEVELOPER SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES, WHETHER INCURRED DIRECTLY OR INDIRECTLY, OR ANY LOSS OF DATA, USE, GOODWILL, OR OTHER INTANGIBLE LOSSES.
            
            27. TERMINATION
            
            This EULA is effective until terminated by you or the Developer. Your rights under this EULA will terminate automatically without notice if you fail to comply with any term(s) of this EULA. Upon termination, you must cease all use of the Licensed Application and delete all copies.
            
            28. GOVERNING LAW
            
            This EULA and Privacy Policy are governed by the laws of Slovakia, without regard to conflict of law principles. Any disputes will be resolved in the courts of Slovakia.
            
            29. SEVERABILITY
            
            If any provision of this EULA is held to be unenforceable or invalid, such provision will be changed and interpreted to accomplish the objectives of such provision to the greatest extent possible under applicable law, and the remaining provisions will continue in full force and effect.
            
            30. ENTIRE AGREEMENT
            
            This EULA, together with this Privacy Policy, constitutes the entire agreement between you and the Developer regarding the Licensed Application and supersedes all prior or contemporaneous understandings regarding such subject matter. No amendment to or modification of this EULA will be binding unless in writing and signed by the Developer.


            
            By using NoteWall, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and Privacy Policy.
            
            Thank you for using NoteWall!
            """
        }
    }
}

// MARK: - Preview

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView(triggerReason: .firstWallpaperCreated)
        
        PaywallView(triggerReason: .limitReached, allowDismiss: false)
            .preferredColorScheme(.dark)
    }
}
