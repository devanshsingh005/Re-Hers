import SwiftUI

private enum LegalSupportInfo {
    static let operatorName = "Re-Hearse"
    static let supportEmail = "devansh.singh20045@gmail.com"

    static var privacyURL: URL? {
        URL(string: "https://letsrehearse.studio/privacy-policy/")
    }

    static var termsURL: URL? {
        URL(string: "https://letsrehearse.studio/terms-of-service/")
    }

    static var supportMailURL: URL? {
        let subject = "Re-Hearse Support"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Re-Hearse%20Support"
        return URL(string: "mailto:\(supportEmail)?subject=\(subject)")
    }
}

// MARK: - Data Models

struct LegalSection: Identifiable {
    let id = UUID()
    let number: String
    let title: String
    let content: [LegalContent]
}

enum LegalContent {
    case paragraph(String)
    case bullets([String])
    case callout(title: String, body: String)
}

// MARK: - Legal Content

struct LegalData {

    static let tosLastUpdated = "March 2026"
    static let ppLastUpdated  = "March 2026"

    // ── TERMS OF SERVICE ──────────────────────────────────────────────────────

    static let tosSections: [LegalSection] = [
        LegalSection(number: "1", title: "Introduction & Acceptance of Terms", content: [
            .paragraph("By accessing or using this platform, you agree to be bound by these Terms of Service. If you do not agree, please stop using the platform immediately."),
            .paragraph("These Terms form a legally binding agreement between you (the user) and the platform operator. Please read them carefully before uploading any content or using any features."),
            .callout(title: "Important", body: "Continued use of the platform after any updates to these Terms constitutes your acceptance of the revised Terms.")
        ]),
        LegalSection(number: "2", title: "Eligibility & Account Responsibilities", content: [
            .paragraph("You must be at least 13 years of age (or the minimum age of digital consent in your country) to use this platform. By using it, you confirm that you meet this requirement."),
            .paragraph("You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account. Notify us immediately if you suspect unauthorized access."),
            .paragraph("You agree to provide accurate and current information when creating your account and to update it as necessary.")
        ]),
        LegalSection(number: "3", title: "Your Content — Ownership & License", content: [
            .paragraph("You retain full ownership of all files, data, media, and other content you upload to the platform (\"Your Content\"). We do not claim any ownership rights over it."),
            .callout(title: "User Ownership", body: "Uploading content to this platform does NOT transfer ownership to us. You remain the sole owner of everything you upload."),
            .paragraph("To operate the platform, you grant us a limited, non-exclusive, worldwide, royalty-free license to:"),
            .bullets([
                "Host, store, and back up Your Content on our infrastructure",
                "Display Your Content to you and to those you specifically authorize",
                "Process and transform Your Content solely as needed to deliver the service (e.g., compressing files, generating thumbnails)"
            ]),
            .paragraph("When you delete Your Content or close your account, we will remove it from active storage within a reasonable period.")
        ]),
        LegalSection(number: "4", title: "User Responsibilities & Prohibited Content", content: [
            .paragraph("You — not the platform — are solely responsible for all content you upload, share, or process. By uploading content, you confirm that:"),
            .bullets([
                "You own the content or have obtained all necessary permissions and licenses",
                "Your content does not infringe any third party's copyright, trademark, patent, trade secret, privacy, or other legal rights",
                "Your content complies with all applicable laws in your jurisdiction",
                "You have obtained any required consents from individuals whose personal data or likeness may be included"
            ]),
            .callout(title: "Legal Responsibility", body: "We are not responsible for reviewing the legality, ownership, or appropriateness of your uploaded content. Any legal consequences are entirely your responsibility."),
            .paragraph("You agree not to upload or transmit content that is unlawful, harmful, infringing, threatening, defamatory, or that contains malware, spam, or deceptive material.")
        ]),
        LegalSection(number: "5", title: "Content Moderation & Account Suspension", content: [
            .paragraph("We reserve the right, but not the obligation, to review, monitor, remove, or restrict access to any content that we believe violates these Terms, is harmful, or exposes the platform to legal risk."),
            .paragraph("We may remove Your Content without prior notice when required by law, legal process, or credible reports of abuse. Where reasonably practicable, we will notify you of any removal."),
            .paragraph("We may suspend or permanently terminate your account for serious or repeated violations of these Terms. We will make reasonable efforts to provide notice before termination, except where immediate action is required."),
            .paragraph("If you believe a content removal or account action was made in error, you may contact us to request a review. Our decisions are ultimately final.")
        ]),
        LegalSection(number: "6", title: "Intellectual Property Compliance", content: [
            .paragraph("This platform is committed to respecting intellectual property rights. We respond to valid copyright takedown notices in accordance with applicable law."),
            .paragraph("If you believe content on the platform infringes your intellectual property rights, please contact us with: identification of the work, identification of the infringing content, your contact information, and a good-faith statement that the use is not authorized."),
            .paragraph("We will terminate the accounts of users who are found to be repeat infringers.")
        ]),
        LegalSection(number: "7", title: "Third-Party Services & Integrations", content: [
            .paragraph("The platform may integrate with third-party providers for services such as cloud storage, content delivery, analytics, authentication, or payment processing. These third parties operate under their own terms and privacy policies."),
            .paragraph("We are not responsible for the practices, availability, or content of third-party services. Your use of such integrations is at your own risk. We do not sell your data to third parties for advertising purposes.")
        ]),
        LegalSection(number: "8", title: "Disclaimers & \"Use at Your Own Risk\"", content: [
            .callout(title: "Important Disclaimer", body: "This platform is provided on an \"AS IS\" and \"AS AVAILABLE\" basis, without warranties of any kind — express or implied. Your use of the platform is entirely at your own risk."),
            .paragraph("We specifically disclaim all warranties, including fitness for a particular purpose, merchantability, uninterrupted or error-free operation, accuracy or reliability, and freedom from viruses or harmful components.")
        ]),
        LegalSection(number: "9", title: "Limitation of Liability", content: [
            .paragraph("To the fullest extent permitted by applicable law, the platform and its operators shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including loss of data, profits, or business opportunities."),
            .paragraph("Where liability cannot be fully excluded by law, our total liability to you shall not exceed the greater of: (a) the amount you paid us in the twelve months prior to the claim, or (b) USD $100."),
            .callout(title: "User Content Liability", body: "We are not liable for any harm, loss, or damage resulting from content uploaded by you or other users. You assume full legal and financial responsibility for Your Content.")
        ]),
        LegalSection(number: "9A", title: "Absolute No-Liability & Waiver of Legal Claims", content: [
            .callout(title: "CRITICAL NOTICE — PLEASE READ CAREFULLY", body: "By using this platform, you expressly waive your right to bring any claim, lawsuit, or legal action against the platform, its operators, employees, affiliates, or agents — for any reason whatsoever, to the maximum extent permitted by applicable law."),
            .paragraph("We are not responsible for anything that happens as a result of your use of this platform. This includes, but is not limited to:"),
            .bullets([
                "Any financial loss, loss of profits, loss of revenue, or loss of data — regardless of cause",
                "Any defamation, reputational harm, or damage to your image caused by other users or third parties",
                "Any harm arising from content uploaded, shared, or transmitted by you or any other user",
                "Any unauthorized access to your account, files, or personal data",
                "Any interruption, downtime, errors, bugs, or technical failures of the platform",
                "Any actions taken by us in good faith, including content removal or account suspension",
                "Any indirect, incidental, punitive, or consequential damages of any nature"
            ]),
            .paragraph("This waiver applies regardless of the legal theory — whether in contract, tort, negligence, defamation, consumer protection law, intellectual property law, privacy law, or any other legal theory."),
            .paragraph("You agree not to initiate, support, or participate in any class action, collective claim, or representative proceeding against the platform."),
            .callout(title: "No Exceptions", body: "This covers all possible claims including defamation, money/financial claims, data loss, privacy claims, and claims from account suspension. Your sole remedy for dissatisfaction is to stop using the platform."),
            .paragraph("If a court determines that the platform bears some liability to you, that liability is capped at the greater of: (a) total fees you have paid in the 12 months preceding the event, or (b) USD $10. You acknowledge this cap is a fundamental element of the agreement.")
        ]),
        LegalSection(number: "10", title: "Indemnification", content: [
            .paragraph("You agree to defend, indemnify, and hold harmless the platform, its operators, and their respective officers, directors, employees, and agents from and against any claims, damages, losses, and costs (including legal fees) arising from:"),
            .bullets([
                "Your use of the platform",
                "Your Content, including any claims that it infringes a third party's rights",
                "Your violation of these Terms",
                "Your violation of any applicable law or regulation"
            ])
        ]),
        LegalSection(number: "11", title: "Modifications to the Platform & Terms", content: [
            .paragraph("We reserve the right to modify, suspend, or discontinue the platform at any time, with or without notice. We will not be liable for any such modification, suspension, or discontinuation."),
            .paragraph("We may update these Terms from time to time. We will notify you of material changes by updating the 'Last Updated' date. Your continued use after the effective date constitutes acceptance of the new Terms.")
        ]),
        LegalSection(number: "12", title: "Governing Law & Dispute Resolution", content: [
            .paragraph("These Terms are intended to be enforceable under the laws of whatever jurisdiction governs the relationship between you and the platform operator, as determined by applicable conflict-of-laws rules."),
            .paragraph("We encourage you to contact us to resolve any disputes informally before pursuing formal legal proceedings.")
        ]),
        LegalSection(number: "13", title: "General Provisions", content: [
            .paragraph("Entire Agreement: These Terms, together with the Privacy Policy, constitute the entire agreement between you and the platform with respect to your use of the service."),
            .paragraph("Severability: If any provision of these Terms is found to be unenforceable, the remaining provisions will continue in full force and effect."),
            .paragraph("No Waiver: Our failure to enforce any provision shall not be considered a waiver of that provision."),
            .paragraph("Assignment: You may not assign your rights without our prior written consent. We may freely assign our rights and obligations."),
            .paragraph("Contact: If you have questions about these Terms, please contact us through the platform's official support channels.")
        ])
    ]

    // ── PRIVACY POLICY ────────────────────────────────────────────────────────

    static let ppSections: [LegalSection] = [
        LegalSection(number: "1", title: "Overview & Our Commitment", content: [
            .paragraph("We respect your privacy. This Privacy Policy explains what data we collect, why we collect it, how we use it, and the choices you have regarding your information."),
            .paragraph("We are committed to handling your data responsibly. We do not sell your personal information to third parties."),
            .callout(title: "Plain Language Commitment", body: "We've written this policy in plain language because we believe you deserve to understand exactly how your information is handled — not just have access to a document full of legal terms.")
        ]),
        LegalSection(number: "2", title: "What Data We Collect", content: [
            .paragraph("When you use the platform, you may provide us with:"),
            .bullets([
                "Account information such as your name, email address, and password",
                "Profile information you choose to add",
                "Content you upload, including files, data, images, documents, or other media",
                "Communications you send to our support team"
            ]),
            .paragraph("We also automatically collect certain technical information:"),
            .bullets([
                "Log data: IP address, browser type, pages visited, time spent, and referring URLs",
                "Device information: operating system, device type, and identifiers",
                "Usage data: features used, actions taken, and interaction patterns",
                "Cookies and similar tracking technologies"
            ]),
            .paragraph("We currently support account access through your Re-Hearse credentials. If we add a third-party sign-in option in the future, we will update this policy before collecting any additional profile information from that provider.")
        ]),
        LegalSection(number: "3", title: "How We Use Your Data", content: [
            .paragraph("We use the data we collect to:"),
            .bullets([
                "Provide, operate, and improve the platform and its features",
                "Create and manage your account and verify your identity",
                "Process and store your uploaded content as instructed by you",
                "Respond to your support requests and communications",
                "Send important service announcements and security alerts",
                "Detect and prevent fraud, abuse, and security incidents",
                "Perform analytics to understand and improve usage",
                "Comply with legal obligations and respond to lawful requests"
            ]),
            .paragraph("We will not use your data for any purpose incompatible with this Policy without first obtaining your consent.")
        ]),
        LegalSection(number: "4", title: "Your Uploaded Content & Data", content: [
            .paragraph("Your Content belongs to you. We store and process it solely to provide the service. We do not analyze, mine, or use Your Content for advertising, training AI models, or any other purpose beyond delivering the platform's features."),
            .paragraph("We implement reasonable security measures to protect Your Content, but we cannot guarantee absolute security. You should consider the sensitivity of what you upload.")
        ]),
        LegalSection(number: "5", title: "Data Sharing & Disclosure", content: [
            .paragraph("We work with third-party companies to help us operate the platform. These providers access your data only as necessary and are required to protect it under confidentiality agreements. Examples include cloud hosting, security services, analytics tools, and customer support software."),
            .paragraph("We may disclose your information if required by law, court order, or governmental authority, or when we believe in good faith that disclosure is necessary to comply with legal obligations, protect safety, or prevent fraud."),
            .paragraph("If the platform is involved in a merger or sale of assets, your information may be transferred. We will notify you of such a transfer."),
            .callout(title: "We Do Not Sell Your Data", body: "We do not sell, rent, or trade your personal information to any third party for marketing or commercial purposes, period.")
        ]),
        LegalSection(number: "6", title: "Cookies & Tracking Technologies", content: [
            .paragraph("We use cookies and similar technologies to operate the platform, remember your preferences, and understand how users interact with our service."),
            .bullets([
                "Essential cookies: Required for the platform to function. You cannot opt out of these.",
                "Preference cookies: Remember your settings and choices.",
                "Analytics cookies: Help us understand usage patterns and improve the platform."
            ]),
            .paragraph("You can control cookie settings through your browser. Note that disabling certain cookies may affect platform functionality.")
        ]),
        LegalSection(number: "7", title: "Data Retention", content: [
            .paragraph("We retain your personal data for as long as your account is active or as needed to provide you with the service. You may delete Your Content at any time."),
            .paragraph("Upon account deletion, we will delete or anonymize your personal data within a reasonable period. We may retain certain information to comply with legal obligations, resolve disputes, or enforce our agreements."),
            .paragraph("Aggregated and anonymized data may be retained indefinitely for analytics purposes.")
        ]),
        LegalSection(number: "8", title: "Data Security", content: [
            .paragraph("We implement commercially reasonable technical and organizational security measures to protect your data from unauthorized access, alteration, disclosure, or destruction. These include encryption in transit, access controls, and regular security reviews."),
            .paragraph("However, no method of transmission over the internet is 100% secure. We cannot guarantee absolute security. You are responsible for keeping your account credentials confidential."),
            .paragraph("In the event of a data breach likely to affect your rights, we will notify you and applicable regulatory authorities as required by law.")
        ]),
        LegalSection(number: "9", title: "Your Privacy Rights", content: [
            .paragraph("Depending on your location and applicable law, you may have the right to:"),
            .bullets([
                "Access: Request a copy of the personal data we hold about you",
                "Correction: Request correction of inaccurate or incomplete data",
                "Deletion: Request deletion of your personal data",
                "Portability: Request a machine-readable export of your data",
                "Objection: Object to certain types of processing, such as marketing",
                "Restriction: Request that we restrict processing of your data"
            ]),
            .paragraph("To exercise any of these rights, please contact us through our official support channels. We will not discriminate against you for exercising your privacy rights.")
        ]),
        LegalSection(number: "10", title: "Children's Privacy", content: [
            .paragraph("This platform is not directed to children under the age of 13 (or the applicable minimum age in your jurisdiction). We do not knowingly collect personal information from children."),
            .paragraph("If we become aware that we have inadvertently collected information from a child, we will delete it promptly. If you are a parent or guardian and believe your child has provided us information, please contact us immediately.")
        ]),
        LegalSection(number: "11", title: "International Data Transfers", content: [
            .paragraph("Your information may be stored and processed in countries other than your own. These countries may have data protection laws that differ from those in your country."),
            .paragraph("Where we transfer personal data internationally, we take steps to ensure appropriate safeguards are in place, such as relying on recognized legal transfer mechanisms.")
        ]),
        LegalSection(number: "12", title: "Changes to This Policy", content: [
            .paragraph("We may update this Privacy Policy periodically to reflect changes in our practices, technology, or legal requirements. When we make material changes, we will notify you by updating the 'Last Updated' date."),
            .paragraph("We encourage you to review this Policy regularly. Your continued use of the platform after any update constitutes your acceptance of the revised Policy.")
        ]),
        LegalSection(number: "13", title: "Contact Us", content: [
            .paragraph("If you have questions, concerns, or requests regarding this Privacy Policy or your personal data, please contact us through the platform's official support channels. We will do our best to address your inquiry promptly and fairly.")
        ])
    ]
}

// MARK: - Tab Enum

public enum LegalTab: String, CaseIterable, Identifiable {
    case terms   = "Terms of Service"
    case privacy = "Privacy Policy"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .terms:   return "doc.text.fill"
        case .privacy: return "lock.shield.fill"
        }
    }
}

// MARK: - Main Legal Screen View

public struct LegalScreenView: View {

    @State private var selectedTab: LegalTab
    @Environment(\.presentationMode) private var presentationMode

    public init(initialTab: LegalTab = .privacy) {
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        NavigationView {
            List {
                Section {
                    Picker("Legal Document", selection: $selectedTab) {
                        ForEach(LegalTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    VStack(alignment: .leading) {
                        Label(selectedTab.rawValue, systemImage: selectedTab.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(UIColor.label))

                        Text("Last updated: \(selectedTab == .terms ? LegalData.tosLastUpdated : LegalData.ppLastUpdated)")
                            .font(.system(.subheadline))
                            .foregroundColor(Color(UIColor.secondaryLabel))

                        Text(selectedTab == .terms
                             ? "These terms govern your use of our platform. By using the app, you agree to the following."
                             : "This policy explains how we collect, use, and protect your personal information.")
                            .font(.system(.body))
                            .foregroundColor(Color(UIColor.label))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(selectedSections) { section in
                            LegalSectionContentView(section: section)
                        }
                    }
                }

                Section(header: Text("Contact & Public Links")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Operator: \(LegalSupportInfo.operatorName)")
                            .font(.system(.body))
                            .foregroundColor(Color(UIColor.label))

                        if let privacyURL = LegalSupportInfo.privacyURL {
                            Button("Open Public Privacy Policy") {
                                UIApplication.shared.open(privacyURL)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }

                        if let termsURL = LegalSupportInfo.termsURL {
                            Button("Open Public Terms of Service") {
                                UIApplication.shared.open(termsURL)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }

                        if let mailURL = LegalSupportInfo.supportMailURL {
                            Link("Email Support: \(LegalSupportInfo.supportEmail)", destination: mailURL)
                        } else {
                            Text("Support: \(LegalSupportInfo.supportEmail)")
                                .font(.system(.body))
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(footer: Text("Copyright Rehearse")) {
                    EmptyView()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Legal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var selectedSections: [LegalSection] {
        selectedTab == .terms ? LegalData.tosSections : LegalData.ppSections
    }
}

// MARK: - Section Content

private struct LegalSectionContentView: View {
    let section: LegalSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.number)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.accentColor)
                Text(section.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(UIColor.label))
            }

            ForEach(Array(section.content.enumerated()), id: \.offset) { _, item in
                legalContentView(item)
            }
        }
    }

    @ViewBuilder
    private func legalContentView(_ content: LegalContent) -> some View {
        switch content {
        case .paragraph(let text):
            Text(text)
                .font(.system(.body))
                .foregroundColor(Color(UIColor.label))
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top) {
                        Text("\u{2022}")
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        Text(item)
                            .font(.system(.body))
                            .foregroundColor(Color(UIColor.label))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .callout(let title, let body):
            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(UIColor.label))
                    Text(body)
                        .font(.system(.subheadline))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Legal Agreement View (Onboarding / First-Launch)

public struct LegalAgreementView: View {

    public var onAccept:  () -> Void
    public var onDecline: () -> Void

    @State private var didConfirmAgreement = false
    @State private var showLegalSheet = false          // ← changed
    @State private var presentedTab: LegalTab = .terms // ← changed

    public init(onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        self.onAccept  = onAccept
        self.onDecline = onDecline
    }

    private var canAccept: Bool { didConfirmAgreement }

    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Documents")) {
                    Button {
                        presentedTab = .terms          // ← set tab first
                        showLegalSheet = true           // ← then trigger sheet
                    } label: {
                        HStack {
                            Text(LegalTab.terms.rawValue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }

                    Button {
                        presentedTab = .privacy        // ← set tab first
                        showLegalSheet = true           // ← then trigger sheet
                    } label: {
                        HStack {
                            Text(LegalTab.privacy.rawValue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                }

                Section {
                    Button {
                        didConfirmAgreement.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: didConfirmAgreement ? "checkmark.square.fill" : "square")
                                .foregroundColor(didConfirmAgreement ? Color.accentColor : Color(UIColor.secondaryLabel))

                            Text("I agree to the Terms of Service and Privacy Policy.")
                                .foregroundColor(Color(UIColor.label))

                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    Button("Continue") {
                        if canAccept { onAccept() }
                    }
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canAccept ? Color.accentColor : Color(UIColor.systemGray3))
                    .cornerRadius(12)
                    .disabled(!canAccept)
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                Section(footer: Text("Copyright Rehearse")) {
                    EmptyView()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Legal Agreement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Decline") {
                        onDecline()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showLegalSheet) {      // ← fixed: Bool-driven sheet
            LegalScreenView(initialTab: presentedTab)
        }
    }
}

// MARK: - Previews

#Preview("Legal Screen") {
    LegalScreenView()
}

#Preview("Legal Agreement (Onboarding)") {
    LegalAgreementView(
        onAccept:  { print("User accepted") },
        onDecline: { print("User declined") }
    )
}
