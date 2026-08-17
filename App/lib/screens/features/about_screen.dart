// lib/screens/features/about_screen.dart
import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // ── Static entry points (callable from outside, e.g. signup_screen.dart) ──

  static void showTermsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx2, scrollController) => Column(
          children: [
            _sheetHandle(),
            _sheetHeader(
              context: ctx2,
              title: 'Terms & Conditions',
              icon: Icons.gavel_rounded,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: AppColors.primaryGreen.withOpacity(0.05),
              child: const Text(
                'Effective Date: April 2026  •  Erasmus+ AGRHI Programme',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legalIntro(
                      'By registering and using the AGRHI mobile application, you agree '
                      'to be bound by these Terms & Conditions. Please read them carefully '
                      'before creating an account. If you do not agree, do not use the '
                      'AGRHI application.',
                    ),
                    _legalSection(
                      title: '1. Acceptance of Terms',
                      body:
                          'By tapping "Sign Up" and creating an AGRHI account, you confirm that:\n\n'
                          '• You have read, understood, and agree to these Terms & Conditions.\n'
                          '• You are at least 13 years of age (or 16 years if you are in an '
                          'EU-partner region such as Greece or Turkey).\n'
                          '• All information you provide during registration is accurate, '
                          'current, and complete.\n'
                          '• You will comply with all applicable local laws and regulations '
                          'while using the AGRHI platform.\n\n'
                          'These Terms & Conditions form a legally binding agreement between '
                          'you ("User") and the AGRHI Programme Consortium ("AGRHI", "we", '
                          '"us", or "our").',
                    ),
                    _legalSection(
                      title: '2. User Roles & Permitted Actions',
                      body:
                          'During registration, you must select one of the following roles. '
                          'Each role defines the features you can access and the responsibilities you carry:\n\n'
                          '🌾 Farmer — May create farm profiles, record crop data, use Plant Doctor, '
                          'set up a Farm Store, view subsidies, and use the AI Chatbot (when available). '
                          'May not impersonate other roles or misrepresent farm ownership.\n\n'
                          '🏪 Retailer — May create a shop profile after admin verification and list '
                          'retail products only once verified. Must provide accurate shop details. '
                          'May not list products before verification or list prohibited items.\n\n'
                          '🛒 Consumer — May browse the Marketplace and Map module, and contact sellers '
                          'via displayed phone numbers. May not use contact details for spam or harassment.\n\n'
                          '🎓 Expert — May provide agricultural advisory responses in the Community '
                          'module (upcoming). Must not advise outside their declared expertise in a way '
                          'that may cause harm, or use the Expert role for commercial promotion.',
                    ),
                    _legalSection(
                      title: '3. Account Integrity & Accurate Information',
                      body:
                          'You must provide truthful, accurate, and complete information during '
                          'registration. Providing false or misleading information may result in '
                          'immediate account suspension.\n\n'
                          'You are responsible for maintaining the confidentiality of your login '
                          'credentials. Notify AGRHI immediately via Help & Support if you suspect '
                          'unauthorised access to your account.\n\n'
                          'Each user may maintain only one active account. Creating multiple accounts '
                          'to circumvent suspensions or restrictions is strictly prohibited.\n\n'
                          'Registering under a false role category is a violation of these Terms and '
                          'may result in account termination.',
                    ),
                    _legalSection(
                      title: '4. Admin Verification & Retailer Conduct',
                      body:
                          'Retailer shop profiles are subject to admin verification before products '
                          'can be listed. Verification is typically completed within 24 hours of shop '
                          'submission. Admin reviews the shop image, GPS location, phone number, and '
                          'business registration details.\n\n'
                          'Submitting false, fabricated, or misleading shop details — including fake '
                          'business registration numbers, incorrect GPS locations, or misrepresented '
                          'business types — constitutes fraud. Consequences include:\n\n'
                          '• Immediate rejection of the verification request.\n'
                          '• Permanent suspension of the associated AGRHI account.\n'
                          '• Reporting to relevant authorities where required by law.\n\n'
                          'Once verified, retailers are solely responsible for the accuracy of their '
                          'product listings, pricing, availability, and all communications with buyers.',
                    ),
                    _legalSection(
                      title: '5. Marketplace Conduct',
                      body:
                          'All product listings must accurately represent the product being offered. '
                          'Listings must not contain false or misleading claims, and must not include '
                          'prohibited, hazardous, illegal, or counterfeit agricultural products.\n\n'
                          'Seller phone numbers are displayed in listings to enable direct buyer–seller '
                          'communication. By listing a product, you consent to your phone number being '
                          'visible to other AGRHI users.\n\n'
                          'You must not use contact information obtained via the Marketplace for spam, '
                          'unsolicited marketing, harassment, or any commercial purpose outside the app.\n\n'
                          'AGRHI is not a buyer, seller, or broker. All transactions are conducted '
                          'directly between users. AGRHI is not responsible for product quality, '
                          'payment disputes, delivery failures, or any loss from Marketplace interactions.',
                    ),
                    _legalSection(
                      title:
                          '6. Farm Store Location — Permanent Selling Location',
                      body:
                          'When setting up your Farm Store, your GPS location is recorded as your '
                          'permanent selling address on the platform and is visible to nearby users.\n\n'
                          'By tapping "Confirm", you acknowledge that:\n\n'
                          '• This location will be visible to other AGRHI users in proximity.\n'
                          '• This is treated as your permanent selling location on the platform.\n'
                          '• You have verified that the GPS coordinates and displayed address are correct.\n\n'
                          'AGRHI is not responsible for errors caused by device GPS inaccuracy or incorrect '
                          'user confirmation. Changes to a confirmed Farm Store location require a request '
                          'through Help & Support and are subject to admin review.',
                    ),
                    _legalSection(
                      title: '7. Plant Doctor — Disease Detection',
                      body:
                          'The Plant Doctor module uses AI-powered machine learning models to detect '
                          'crop diseases from images. By using this feature, you agree that:\n\n'
                          '• Detection results are for informational and reference purposes only.\n'
                          '• AGRHI does not guarantee the accuracy of disease detection results.\n'
                          '• Results must not be treated as a substitute for professional agronomist consultation.\n'
                          '• AGRHI is not liable for crop loss, financial damage, or other consequences '
                          'arising from decisions made based on Plant Doctor results.\n'
                          '• You will capture clear, well-lit images of the relevant crop for best results. '
                          'Inaccurate images may produce unreliable results.',
                    ),
                    _legalSection(
                      title: '8. AI Chatbot — Usage Terms (Upcoming)',
                      body:
                          'The AGRHI AI Chatbot is powered by third-party large language models '
                          '(LLaMA 3.1 via Groq API and Gemma 3 via Google AI). By using the Chatbot, '
                          'you agree that:\n\n'
                          '• Chatbot responses are AI-generated and may not always be accurate, current, '
                          'or applicable to your local conditions.\n'
                          '• You must not submit sensitive personal information, financial data, or '
                          'confidential business information into chatbot queries.\n'
                          '• The Chatbot does not replace professional agricultural, legal, or financial advice.\n'
                          '• AGRHI is not liable for any loss or damage resulting from reliance on '
                          'chatbot-generated responses.\n'
                          '• Query text is transmitted to third-party API providers (Groq, Google) for processing.',
                    ),
                    _legalSection(
                      title: '9. Subsidies Module — Third-Party Redirects',
                      body:
                          'The Subsidies module displays government agricultural subsidy schemes for '
                          'informational purposes only. By using this module, you acknowledge that:\n\n'
                          '• Subsidy availability and eligibility are governed entirely by the respective '
                          'government authorities.\n'
                          '• Tapping "More Info" redirects you to official government websites outside '
                          'the AGRHI application.\n'
                          '• AGRHI has no control over external government websites and is not responsible '
                          'for changes to subsidy schemes or application outcomes.',
                    ),
                    _legalSection(
                      title: '10. Map Module & Google Maps',
                      body:
                          'When you tap "Directions" on a store or shop, you will be redirected to the '
                          'Google Maps application. By using this feature, you agree that:\n\n'
                          '• Directions are provided by Google Maps, a third-party service not operated by AGRHI.\n'
                          '• Google Maps\' own Terms of Service and Privacy Policy govern your interaction.\n'
                          '• AGRHI is not responsible for the accuracy of directions, route safety, or '
                          'any consequences of following directions provided by Google Maps.',
                    ),
                    _legalSection(
                      title: '11. Language Packs',
                      body:
                          'AGRHI supports seven languages: Tamil, English, Hindi, Telugu, Greek, Turkish, '
                          'and Malay. Language packs (~20 MB per language) are available as downloadable '
                          'content. By downloading a language pack, you agree that:\n\n'
                          '• Language pack content is provided exclusively for personal, non-commercial '
                          'use within the AGRHI application.\n'
                          '• You may not copy, extract, redistribute, or commercially exploit language '
                          'pack content in any form.\n'
                          '• Language packs remain the intellectual property of the AGRHI Consortium '
                          'and its partner institutions.',
                    ),
                    _legalSection(
                      title: '12. Intellectual Property',
                      body:
                          'The AGRHI mobile application — including its design, codebase, AI models, '
                          'database architecture, content, and branding — is developed under the '
                          'Erasmus+ Programme and is the intellectual property of the AGRHI Consortium '
                          'and its partner institutions. All rights are reserved.\n\n'
                          'The European Commission and the AGRHI Consortium co-hold intellectual property '
                          'rights over programme outputs. Unauthorized reproduction, distribution, or '
                          'commercial use of any AGRHI programme materials is strictly prohibited.\n\n'
                          'By uploading content to AGRHI, you grant the Consortium a non-exclusive, '
                          'royalty-free, worldwide licence to store and display that content solely for '
                          'operating and improving the platform. You retain ownership of all content you upload.',
                    ),
                    _legalSection(
                      title: '13. Prohibited Conduct',
                      body:
                          'The following actions are strictly prohibited:\n\n'
                          '• Providing false registration details or impersonating another user.\n'
                          '• Uploading offensive, harmful, discriminatory, or illegal content.\n'
                          '• Using the app to conduct fraud, scams, or any illegal activity.\n'
                          '• Attempting to gain unauthorised access to other users\' accounts or AGRHI servers.\n'
                          '• Introducing malware, viruses, or harmful code into the platform.\n'
                          '• Interfering with or disrupting the operation of the AGRHI app.\n'
                          '• Using automated bots or scripts to interact with the platform.\n'
                          '• Listing counterfeit, prohibited, or hazardous products in the Marketplace.\n\n'
                          'Violation of any of these prohibitions may result in immediate account '
                          'suspension and, where applicable, reporting to law enforcement authorities.',
                    ),
                    _legalSection(
                      title: '14. Account Suspension & Termination',
                      body:
                          'AGRHI reserves the right to suspend or permanently terminate your account for:\n\n'
                          '• False registration or fraudulent information at any stage.\n'
                          '• Fraudulent shop listing or false business details.\n'
                          '• Marketplace violations or misuse of contact information.\n'
                          '• Any action listed under Section 13 (Prohibited Conduct).\n'
                          '• Abusive behaviour directed at other users or AGRHI staff.\n'
                          '• Role misrepresentation.\n'
                          '• Underage use without parental consent.\n'
                          '• Accounts inactive for more than 24 months (after prior notice).\n\n'
                          'Voluntary account termination requests will be processed within 30 days.',
                    ),
                    _legalSection(
                      title: '15. Disclaimer of Warranties',
                      body:
                          'The AGRHI application is provided "as is" and "as available" without '
                          'warranties of any kind. AGRHI does not warrant that:\n\n'
                          '• The app will be uninterrupted, error-free, or free from security vulnerabilities.\n'
                          '• Plant Doctor disease detection results will be accurate or complete.\n'
                          '• AI Chatbot responses will always be correct or appropriate for your conditions.\n'
                          '• Marketplace product listings are accurate, genuine, or of satisfactory quality.\n\n'
                          'To the maximum extent permitted by applicable law, AGRHI disclaims all liability '
                          'for direct, indirect, incidental, or consequential damages arising from your use '
                          'of the application.',
                    ),
                    _legalSection(
                      title: '16. Governing Law & Jurisdiction',
                      body:
                          'These Terms are governed by and construed in accordance with the laws of India. '
                          'Disputes shall be subject to the exclusive jurisdiction of the courts located '
                          'in Chennai, Tamil Nadu, India.\n\n'
                          'For users in EU-partner countries (Greece and Turkey): EU consumer protection '
                          'laws and GDPR apply in addition to these Terms.\n\n'
                          'For users in Malaysia and other participating Asian countries: applicable '
                          'national laws shall apply to the extent they are mandatory.\n\n'
                          'As an Erasmus+ funded deliverable, Erasmus+ Programme rules and obligations '
                          'take precedence for matters relating to programme governance and intellectual property.',
                    ),
                    _legalSection(
                      title: '17. Changes to These Terms',
                      body:
                          'AGRHI reserves the right to update or modify these Terms & Conditions at any time. '
                          'You will be notified via a prominent in-app notification when significant changes '
                          'are made. Continued use of the AGRHI application after notification constitutes '
                          'your acceptance of the revised Terms.\n\n'
                          'If you do not agree to the updated Terms, you must discontinue use of the app '
                          'and may request account deletion via the Help & Support module.',
                    ),
                    _legalSection(
                      title: '18. Contact Us',
                      body:
                          'For questions, concerns, or disputes regarding these Terms:\n\n'
                          '📱 In-App: Help & Support → Submit Feedback (toggle "Issue")\n'
                          '📧 Email: projectagrhi@gmail.com\n'
                          '⏱ Response: Within 24 hours (general) / 30 days (formal disputes)\n'
                          '🏛 Programme: Erasmus+ AGRHI Consortium',
                      isLast: true,
                    ),
                    const SizedBox(height: 16),
                    _lastUpdated('April 2026'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx2, scrollController) => Column(
          children: [
            _sheetHandle(),
            _sheetHeader(
              context: ctx2,
              title: 'Privacy Policy',
              icon: Icons.privacy_tip_outlined,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: AppColors.primaryGreen.withOpacity(0.05),
              child: const Text(
                'Effective Date: April 2026  •  Erasmus+ AGRHI Programme',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legalIntro(
                      'This Privacy Policy explains how the AGRHI mobile application '
                      'collects, processes, stores, and protects your personal data. '
                      'We are committed to protecting your privacy and handling your '
                      'data in accordance with applicable data protection laws, including '
                      'the Information Technology Act, 2000 (India) and GDPR (for EU-region users).',
                    ),
                    _legalSection(
                      title: '1. Data We Collect',
                      body:
                          'We collect the following categories of personal data:\n\n'
                          '📋 Registration Data: Full name, phone number, email address, '
                          'date of birth, address, postal code, and role category.\n\n'
                          '📍 Location Data: GPS coordinates when you set up a Farm Store '
                          'or use the Map module. Location access is requested only when needed.\n\n'
                          '📸 Images: Crop photos you upload to the Plant Doctor feature. '
                          'Images are processed for disease detection and may be stored to improve model accuracy.\n\n'
                          '💬 Support Messages: Content of feedback and issue reports you '
                          'submit via Help & Support.\n\n'
                          '🛒 Marketplace Data: Product listings, shop details, and '
                          'contact numbers (for Retailers).\n\n'
                          '📊 Usage Data: App interactions, feature usage patterns, crash '
                          'logs, and diagnostic data for app improvement.',
                    ),
                    _legalSection(
                      title: '2. How We Use Your Data',
                      body:
                          'Your personal data is used for the following purposes:\n\n'
                          '• Account creation, authentication, and profile management.\n'
                          '• Providing core app features: Plant Doctor, Marketplace, Farm Store, Subsidies, and Map.\n'
                          '• Processing and displaying your Retailer shop profile after admin verification.\n'
                          '• Enabling GPS-based Farm Store location and Marketplace proximity features.\n'
                          '• Transmitting crop images to AI disease detection models for analysis.\n'
                          '• Sending in-app notifications about important updates or policy changes.\n'
                          '• Responding to Help & Support requests.\n'
                          '• Improving app performance through aggregated, anonymised usage analytics.\n'
                          '• Fulfilling obligations under the Erasmus+ Programme reporting requirements '
                          '(aggregated, anonymised data only).',
                    ),
                    _legalSection(
                      title: '3. Data Sharing & Third Parties',
                      body:
                          'We do not sell your personal data. We share data only in the following circumstances:\n\n'
                          '🤖 AI Processing: Crop images are processed by our in-app ML models. '
                          'When the AI Chatbot is active, query text is sent to Groq API (LLaMA 3.1) '
                          'and Google AI (Gemma 3) for response generation.\n\n'
                          '🗺 Maps: When you tap "Directions", you are redirected to Google Maps. '
                          'Google\'s Privacy Policy governs that interaction.\n\n'
                          '🏛 Erasmus+ Programme: Aggregated, anonymised usage statistics may be '
                          'shared with Erasmus+ programme evaluators as required under our grant agreement.\n\n'
                          '⚖ Legal Requirements: We may disclose data to comply with a legal obligation, '
                          'court order, or to protect the rights and safety of AGRHI users.',
                    ),
                    _legalSection(
                      title: '4. Data Storage & Security',
                      body:
                          'Your data is stored on secure servers. We implement appropriate technical '
                          'and organisational security measures including:\n\n'
                          '• Encrypted data transmission (HTTPS/TLS).\n'
                          '• Hashed password storage (passwords are never stored in plain text).\n'
                          '• Access controls restricting data access to authorised personnel only.\n'
                          '• Regular security reviews of our infrastructure.\n\n'
                          'While we take all reasonable precautions, no system is completely immune '
                          'to security breaches. In the event of a data breach affecting your rights, '
                          'we will notify you within 72 hours as required by applicable law.',
                    ),
                    _legalSection(
                      title: '5. Location Data',
                      body:
                          'Location access is used only for specific features:\n\n'
                          '• Farm Store Setup: Your GPS coordinates are captured once to set your '
                          'permanent selling location. This location is visible to nearby AGRHI users.\n\n'
                          '• Map Module: Used to show nearby stores relative to your position.\n\n'
                          'We do not track your location continuously in the background. '
                          'Location permission is requested in-context when you use a location-dependent feature.',
                    ),
                    _legalSection(
                      title: '6. Crop Images & Plant Doctor',
                      body:
                          'Images you capture or upload via Plant Doctor are:\n\n'
                          '• Processed by our on-device or server-side ML model for disease detection.\n'
                          '• Potentially retained to improve model accuracy under anonymised conditions.\n'
                          '• Not shared with third parties for commercial purposes.\n\n'
                          'You retain ownership of images you upload. By uploading, you grant AGRHI '
                          'a licence to use those images for model training and improvement purposes only.',
                    ),
                    _legalSection(
                      title: '7. Children\'s Privacy',
                      body:
                          'AGRHI is not intended for children under the age of 13 (or 16 in EU regions). '
                          'We do not knowingly collect personal data from children under these ages.\n\n'
                          'If you are a parent or guardian and believe your child has registered without '
                          'consent, please contact us immediately via Help & Support or at '
                          'projectagrhi@gmail.com. We will promptly delete the account.',
                    ),
                    _legalSection(
                      title: '8. Your Rights',
                      body:
                          'Depending on your location, you have the following rights over your personal data:\n\n'
                          '• Right of Access: Request a copy of the personal data we hold about you.\n'
                          '• Right to Rectification: Request correction of inaccurate or incomplete data.\n'
                          '• Right to Erasure: Request deletion of your account and associated data.\n'
                          '• Right to Restrict Processing: Request that we limit how we use your data.\n'
                          '• Right to Data Portability: Request your data in a machine-readable format.\n'
                          '• Right to Object: Object to processing based on legitimate interests.\n\n'
                          'EU/EEA users have full GDPR rights. Indian users have rights under the '
                          'Information Technology Act, 2000 and the Digital Personal Data Protection '
                          'Act, 2023.\n\n'
                          'To exercise any of these rights, contact us via Help & Support or email '
                          'projectagrhi@gmail.com. We will respond within 30 days.',
                    ),
                    _legalSection(
                      title: '9. Data Retention',
                      body:
                          'We retain your personal data for as long as your account is active or as '
                          'needed to provide services. Specific retention periods:\n\n'
                          '• Account data: Retained until account deletion is requested and processed.\n'
                          '• Crop images: Retained for up to 12 months for model improvement, then anonymised.\n'
                          '• Support messages: Retained for 24 months for quality assurance.\n'
                          '• Usage analytics: Aggregated and anonymised after 6 months.\n\n'
                          'Accounts inactive for more than 24 months will receive a deletion notice '
                          'before data is removed.',
                    ),
                    _legalSection(
                      title: '10. Cookies & Local Storage',
                      body:
                          'The AGRHI mobile app does not use browser cookies. We use local device '
                          'storage (shared preferences) solely to store:\n\n'
                          '• Your selected language preference.\n'
                          '• Downloaded language pack data.\n'
                          '• Session authentication tokens (encrypted).\n\n'
                          'No tracking cookies or advertising identifiers are used.',
                    ),
                    _legalSection(
                      title: '11. Changes to This Privacy Policy',
                      body:
                          'We may update this Privacy Policy from time to time. When we make significant '
                          'changes, you will be notified via an in-app notification before the changes '
                          'take effect.\n\n'
                          'Continued use of AGRHI after the effective date of an updated Privacy Policy '
                          'constitutes your acceptance of the changes.',
                    ),
                    _legalSection(
                      title: '12. Contact Us',
                      body:
                          'For privacy-related questions, data requests, or concerns:\n\n'
                          '📱 In-App: Help & Support → Submit Feedback (toggle "Issue")\n'
                          '📧 Email: projectagrhi@gmail.com\n'
                          '⏱ Response: Within 30 days for formal data requests\n'
                          '🏛 Programme: Erasmus+ AGRHI Consortium',
                      isLast: true,
                    ),
                    const SizedBox(height: 16),
                    _lastUpdated('April 2026'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildAppHeader(),
            const SizedBox(height: 20),
            _buildSectionLabel('About AGRHI'),
            _buildAboutCard(),
            const SizedBox(height: 16),
            _buildSectionLabel('App Info'),
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildSectionLabel('Key Features'),
            _buildFeaturesCard(),
            const SizedBox(height: 16),
            _buildSectionLabel('Contact & Support'),
            _buildContactCard(),
            const SizedBox(height: 16),
            _buildSectionLabel('Legal'),
            _buildLegalCard(context),
            const SizedBox(height: 32),
            _buildFooter(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildAppHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.only(top: 24, bottom: 36),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),
          const Text(
            'AGRHI',
            style: TextStyle(
              color: Colors.black,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Text(
            'Smart Farm Assistant',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ─── About Card ─────────────────────────────────────────────────────────────

  Widget _buildAboutCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        'AGRHI is your farming companion. Whether you grow rice, vegetables, or fruits — use our app to spot crop diseases early, learn better farming practices, and get support from a community of farmers and experts just like you.',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          height: 1.6,
        ),
      ),
    );
  }

  // ─── Info Card ──────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.info_outline_rounded,
            label: 'App Name',
            value: 'AGRHI',
            isFirst: true,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.tag_rounded,
            label: 'Version',
            value: AppConstants.appVersion,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.business_rounded,
            label: 'Developer',
            value: 'AGRHI Team',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Released',
            value: '2026',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Features Card ──────────────────────────────────────────────────────────

  Widget _buildFeaturesCard() {
    final features = [
      (
        Icons.biotech_rounded,
        'Crop Disease Detection',
        'AI-powered image analysis to detect crop diseases instantly across 10 crops',
      ),
      (
        Icons.eco_rounded,
        'Crop Care Manager',
        'Manage your farms and crops with planting schedules and harvest tracking',
      ),
      (
        Icons.shopping_bag_rounded,
        'Marketplace',
        'Discover farm and retail products from sellers near you',
      ),
      (
        Icons.cloud_sync_rounded,
        'Offline Sync',
        'Core features work offline and automatically sync when connected',
      ),
      (
        Icons.translate_rounded,
        'Multi-Language Support',
        'Available in Tamil, English, Hindi, Telugu, Greek, Turkish, and Malay',
      ),
      (
        Icons.support_agent_rounded,
        'Help & Support',
        'Submit feedback or report issues directly to the admin team',
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(features.length, (index) {
          final (icon, title, subtitle) = features[index];
          final isLast = index == features.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) _buildDivider(),
            ],
          );
        }),
      ),
    );
  }

  // ─── Contact Card ───────────────────────────────────────────────────────────

  Widget _buildContactCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildContactRow(
            icon: Icons.email_outlined,
            label: 'Support Email',
            value: 'projectagrhi@gmail.com',
            isFirst: true,
          ),
          _buildDivider(),
          _buildContactRow(
            icon: Icons.language_rounded,
            label: 'Website',
            value: 'www.agrhi.com',
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    bool isFirst = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Legal Card ─────────────────────────────────────────────────────────────

  Widget _buildLegalCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLegalTile(
            context: context,
            icon: Icons.gavel_rounded,
            title: 'Terms & Conditions',
            onTap: () => AboutScreen.showTermsSheet(context),
            isFirst: true,
          ),
          _buildDivider(),
          _buildLegalTile(
            context: context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => AboutScreen.showPrivacySheet(context),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLegalTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        const SizedBox(height: 16),
        Text(
          '© 2026 AGRHI. Erasmus+ Programme.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  // ─── Shared helpers ─────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFF0F0F0),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Top-level helper functions — used by static sheet methods above
// ═══════════════════════════════════════════════════════════════════════════════

Widget _sheetHandle() {
  return Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

Widget _sheetHeader({
  required BuildContext context,
  required String title,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryGreen, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

Widget _legalIntro(String text) {
  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primaryGreen.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.6,
      ),
    ),
  );
}

Widget _legalSection({
  required String title,
  required String body,
  bool isLast = false,
}) {
  return Container(
    margin: EdgeInsets.only(bottom: isLast ? 0 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.65,
          ),
        ),
      ],
    ),
  );
}

Widget _lastUpdated(String date) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.update_rounded, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          'Last updated: $date',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
  );
}
