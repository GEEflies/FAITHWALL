import SwiftUI

struct LegalDocumentView: View {
    let documentType: LegalDocumentType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(documentContent)
                        .font(.system(.body, design: .default))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
            }
            .navigationTitle(documentType.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var documentContent: String {
        switch documentType {
        case .termsOfService:
            return termsOfServiceContent
        case .privacyPolicy:
            return privacyPolicyContent
        case .termsAndPrivacy:
            return termsAndPrivacyContent
        }
    }
}

// MARK: - Document Content

private let termsOfServiceContent = """
Terms of Service

Last Updated: November 13, 2024

1. Acceptance of Terms

By downloading, installing, or using NoteWall ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.

2. Description of Service

NoteWall is a mobile application that allows users to create personalized lock screen wallpapers with notes. The App integrates with Apple Shortcuts to apply wallpapers to your device.

3. Subscription and Payments

3.1 Free Trial
• New users receive a limited number of free wallpaper exports
• Premium subscriptions may include a free trial period (5-7 days)
• You will be charged at the end of the trial period unless you cancel before it ends

3.2 Subscription Plans
• NoteWall+ Lifetime: One-time payment for permanent access
• NoteWall+ Monthly: Monthly subscription with automatic renewal

3.3 Payment Processing
• All payments are processed through Apple's App Store
• Prices are displayed in your local currency
• Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period

3.4 Refunds
• Refund requests must be made through Apple's App Store
• We follow Apple's standard refund policy
• Contact Apple Support for refund assistance

4. User Obligations

You agree to:
• Use the App only for lawful purposes
• Not attempt to reverse engineer or modify the App
• Not use the App to create offensive or illegal content
• Comply with all applicable laws and regulations

5. Intellectual Property

5.1 App Ownership
• NoteWall and all related intellectual property rights belong to the developer
• You receive a limited, non-exclusive, non-transferable license to use the App

5.2 User Content
• You retain ownership of notes and photos you create or upload
• You grant us a license to process your content solely to provide the App's functionality
• We do not claim ownership of your personal content

6. Privacy and Data Protection

Your privacy is important to us. Please review our Privacy Policy for details on how we collect, use, and protect your data in compliance with GDPR and data protection laws.

7. Disclaimer of Warranties

THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.

8. Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES.

9. Changes to Terms

We reserve the right to modify these Terms at any time. Continued use of the App after changes constitutes acceptance of the modified Terms.

10. Termination

We may terminate or suspend your access to the App at any time, with or without cause or notice, for violation of these Terms.

11. Contact Information

For questions about these Terms, please contact:
• Email: support@notewall.app
• Developer: NoteWall Team

12. Severability

If any provision of these Terms is found to be unenforceable, the remaining provisions will continue in full force and effect.

13. Entire Agreement

These Terms, together with our Privacy Policy, constitute the entire agreement between you and NoteWall regarding the use of the App.
"""

private let privacyPolicyContent = """
Privacy Policy

Last Updated: November 13, 2024

1. Information We Collect

1.1 Personal Information
• Notes and Text: We store your notes locally on your device and do not transmit them to our servers
• Photos: Any photos you select for wallpaper backgrounds are processed locally on your device
• App Usage: We may collect anonymous usage statistics to improve the app

1.2 Automatically Collected Information
• Device Information: iOS version, device model (for compatibility)
• App Performance: Crash reports and performance metrics (anonymous)
• Purchase Information: Subscription status (processed by Apple)

2. How We Use Your Information

We use your information to:
• Provide the core wallpaper generation functionality
• Process in-app purchases through Apple's App Store
• Improve app performance and fix bugs
• Provide customer support

3. Data Storage and Security

3.1 Local Storage
• All your notes and photos are stored locally on your device
• We do not upload your personal content to external servers
• Your data remains private and under your control

3.2 Security Measures
• Data is protected by iOS security features
• No personal data is transmitted over the internet
• Purchase information is handled securely by Apple

4. Data Sharing

We do not sell, trade, or share your personal information with third parties, except:
• Apple: For processing in-app purchases
• Legal Requirements: If required by law or to protect our rights

5. Your Rights (GDPR Compliance)

As a user in the European Union, you have the right to:
• Access: Request information about data we process
• Rectification: Correct inaccurate personal data
• Erasure: Request deletion of your personal data
• Portability: Export your data in a readable format
• Objection: Object to processing of your personal data

6. Children's Privacy

NoteWall is not intended for children under 13. We do not knowingly collect personal information from children under 13.

7. Changes to This Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the app.

8. Contact Us

If you have questions about this Privacy Policy, please contact us:
• Email: support@notewall.app
• Developer: NoteWall Team

9. Data Retention

• Notes: Stored locally until you delete them
• App Settings: Stored locally until app is uninstalled
• Purchase Records: Maintained by Apple according to their policies

10. International Transfers

Since all data is processed locally on your device, there are no international data transfers.
"""

private let termsAndPrivacyContent = """
TERMS & PRIVACY

Last Updated: November 13, 2024

END-USER LICENSE AGREEMENT (EULA)

1. Acknowledgement

You and the End-User must acknowledge that the EULA is concluded between You and the End-User only, and not with Apple, and You, not Apple, are solely responsible for the Licensed Application and the content thereof. The EULA may not provide for usage rules for Licensed Applications that are in conflict with the Apple Media Services Terms and Conditions.

2. Scope of License

The license granted to the End-User for the Licensed Application must be limited to a non-transferable license to use the Licensed Application on any Apple-branded Products that the End-User owns or controls and as permitted by the Usage Rules set forth in the Apple Media Services Terms and Conditions, except that such Licensed Application may be accessed and used by other accounts associated with the purchaser via Family Sharing or volume purchasing.

3. Maintenance and Support

You must be solely responsible for providing any maintenance and support services with respect to the Licensed Application, as specified in the EULA, or as required under applicable law. You and the End-User must acknowledge that Apple has no obligation whatsoever to furnish any maintenance and support services with respect to the Licensed Application.

Contact for support: support@notewall.app

4. Warranty

You must be solely responsible for any product warranties, whether express or implied by law, to the extent not effectively disclaimed. The EULA must provide that, in the event of any failure of the Licensed Application to conform to any applicable warranty, the End-User may notify Apple, and Apple will refund the purchase price for the Licensed Application to that End-User; and that, to the maximum extent permitted by applicable law, Apple will have no other warranty obligation whatsoever with respect to the Licensed Application, and any other claims, losses, liabilities, damages, costs or expenses attributable to any failure to conform to any warranty will be Your sole responsibility.

5. Product Claims

You and the End-User must acknowledge that You, not Apple, are responsible for addressing any claims of the End-User or any third party relating to the Licensed Application or the end-user's possession and/or use of that Licensed Application, including, but not limited to: (i) product liability claims; (ii) any claim that the Licensed Application fails to conform to any applicable legal or regulatory requirement; and (iii) claims arising under consumer protection, privacy, or similar legislation, including in connection with Your Licensed Application's use of the HealthKit and HomeKit frameworks. The EULA may not limit Your liability to the End-User beyond what is permitted by applicable law.

6. Intellectual Property Rights

You and the End-User must acknowledge that, in the event of any third party claim that the Licensed Application or the End-User's possession and use of that Licensed Application infringes that third party's intellectual property rights, You, not Apple, will be solely responsible for the investigation, defense, settlement and discharge of any such intellectual property infringement claim.

7. Legal Compliance

The End-User must represent and warrant that (i) he/she is not located in a country that is subject to a U.S. Government embargo, or that has been designated by the U.S. Government as a "terrorist supporting" country; and (ii) he/she is not listed on any U.S. Government list of prohibited or restricted parties.

8. Developer Name and Address

Developer Name: NoteWall Team
Email: support@notewall.app
Contact information to which any End-User questions, complaints or claims with respect to the Licensed Application should be directed.

9. Third Party Terms of Agreement

You must state in the EULA that the End-User must comply with applicable third party terms of agreement when using Your Application.

10. Third Party Beneficiary

You and the End-User must acknowledge and agree that Apple, and Apple's subsidiaries, are third party beneficiaries of the EULA, and that, upon the End-User's acceptance of the terms and conditions of the EULA, Apple will have the right (and will be deemed to have accepted the right) to enforce the EULA against the End-User as a third party beneficiary thereof.

SUBSCRIPTION TERMS

Auto-Renewable Subscriptions:
• Payment will be charged to your iTunes Account at confirmation of purchase
• Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period
• Account will be charged for renewal within 24-hours prior to the end of the current period
• You can manage and cancel your subscriptions by going to your Account Settings on the App Store after purchase
• Any unused portion of a free trial period will be forfeited when you purchase a subscription

Free Trial:
• New users receive 3 free wallpaper exports
• Premium subscriptions include a free trial period (5-7 days depending on plan)
• You will be charged at the end of the trial period unless you cancel before it ends

Refunds:
• All refund requests must be made through Apple's App Store
• Contact Apple Support for refund assistance

PRIVACY POLICY

Information We Collect:
• Notes and text you create (stored locally on your device only)
• Photos you select for wallpapers (processed locally on your device)
• Device information (iOS version, device model for compatibility)
• Anonymous app performance data to improve the app
• Purchase information (processed by Apple)

How We Use Information:
• Provide wallpaper generation functionality
• Process in-app purchases through Apple's App Store
• Improve app performance and fix bugs
• Provide customer support

Data Storage:
• All personal content (notes, photos) is stored locally on your device
• We do not upload your personal content to external servers
• Your data remains private and under your control
• Data is protected by iOS security features

Data Sharing:
• We do not sell, trade, or share your personal information
• Purchase information is shared with Apple for payment processing
• Anonymous crash reports may be shared through Apple's developer tools
• Information may be disclosed if required by law

Your Rights:
• EU residents have GDPR rights (access, rectification, erasure, portability)
• California residents have CCPA rights
• Contact support@notewall.app to exercise your rights

Children's Privacy:
• This app is not intended for children under 13
• We do not knowingly collect information from children under 13

Contact:
• Email: support@notewall.app
• Developer: NoteWall Team

Changes to Terms:
• We may update these terms and privacy policy
• Continued use constitutes acceptance of changes
• Check the "Last Updated" date for recent changes

This agreement is governed by applicable law and constitutes the entire agreement between you and NoteWall Team regarding use of this application.
"""

#Preview {
    LegalDocumentView(documentType: .privacyPolicy)
}
