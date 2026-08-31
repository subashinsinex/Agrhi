// lib/screens/features/about_screen.dart
import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import 'delete_account.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // ── Static entry points (callable from outside, e.g. signup_screen.dart) ──

  static void showTermsSheet(BuildContext context) {
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
                          '📧 Email: support@farmlead.in\n'
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
                'Effective Date: August 2026  •  Erasmus+ AGRHI Programme',
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
                      'This Privacy Policy explains how the AGRHI mobile '
                      'application collects, uses, processes, stores, shares, '
                      'and protects information when you use our services. '
                      'AGRHI is committed to handling personal data responsibly '
                      'and in accordance with applicable privacy and data '
                      'protection laws.',
                    ),

                    _legalSection(
                      title: '1. Data We Collect',
                      body:
                          'AGRHI may collect or process the following categories '
                          'of information depending on the features you use:\n\n'
                          '📋 Registration & Profile Data\n'
                          '• Full name.\n'
                          '• Phone number.\n'
                          '• Email address.\n'
                          '• Date of birth.\n'
                          '• Address and postal code.\n'
                          '• User role/category.\n'
                          '• Profile image, where provided.\n\n'
                          '📍 Location Data\n'
                          'GPS coordinates may be accessed when you use '
                          'location-based features such as Farm Store setup, '
                          'weather information, or nearby stores on the Map.\n\n'
                          '📸 Images\n'
                          'Crop images submitted to Plant Doctor may be processed '
                          'for disease detection. Profile, retailer, shop, or '
                          'product images may also be processed when those '
                          'features are used.\n\n'
                          '💬 User-Provided Content\n'
                          'Feedback, support messages, marketplace listings, '
                          'shop information, product information, and other '
                          'content that you choose to submit.\n\n'
                          '🤖 AI Chatbot Data\n'
                          'When the AI Chatbot is available and you choose to use '
                          'it, the text you submit is processed to generate an '
                          'AI response.\n\n'
                          '📊 Technical & SDK Diagnostics\n'
                          'Limited application, device, SDK, model-download, '
                          'performance, and diagnostic information may be '
                          'processed by integrated technologies used to operate '
                          'and maintain AGRHI.',
                    ),

                    _legalSection(
                      title: '2. How We Use Your Data',
                      body:
                          'Information is used only for purposes related to '
                          'operating and improving AGRHI, including:\n\n'
                          '• Creating and authenticating user accounts.\n'
                          '• Managing user profiles and application settings.\n'
                          '• Providing Plant Doctor disease detection.\n'
                          '• Managing farms, crops, reminders, and crop-care data.\n'
                          '• Providing Marketplace and Farm Store features.\n'
                          '• Verifying retailer shop profiles.\n'
                          '• Displaying nearby shops and Farm Stores.\n'
                          '• Providing weather and location-based information.\n'
                          '• Processing AI Chatbot requests when that feature is used.\n'
                          '• Responding to Help & Support requests.\n'
                          '• Sending important application and policy notifications.\n'
                          '• Maintaining security and preventing misuse.\n'
                          '• Diagnosing technical problems and improving reliability.\n'
                          '• Preparing aggregated or anonymised Erasmus+ Programme '
                          'reports where required.',
                    ),

                    _legalSection(
                      title: '3. Data Sharing & Third Parties',
                      body:
                          'AGRHI does not sell your personal data.\n\n'
                          'Information may be processed by third-party services '
                          'only where required to provide particular features:\n\n'
                          '🤖 Groq API\n'
                          'When the AGRHI AI Chatbot is enabled, chatbot query '
                          'text may be sent to Groq for AI response generation.\n\n'
                          '🤖 Google AI\n'
                          'When applicable, chatbot query text may be sent to '
                          'Google AI services for AI response generation.\n\n'
                          '🌐 Google ML Kit Translation\n'
                          'AGRHI uses Google ML Kit for on-device translation and '
                          'language model downloads. Google ML Kit may process '
                          'limited SDK, application, device, model-download, and '
                          'diagnostic telemetry required to provide, maintain, '
                          'and improve its services. Translation text used by the '
                          'translation feature is processed on the device.\n\n'
                          '🗺 Google Maps\n'
                          'When you select "Directions", AGRHI may redirect you '
                          'to Google Maps. Your interaction with Google Maps is '
                          'governed by Google\'s own Privacy Policy and Terms.\n\n'
                          '🏛 Erasmus+ Programme\n'
                          'Aggregated or anonymised statistics may be shared with '
                          'programme evaluators where required under programme '
                          'reporting obligations.\n\n'
                          '⚖ Legal Requirements\n'
                          'Information may be disclosed where required by '
                          'applicable law, valid legal process, or where necessary '
                          'to protect users, AGRHI, or its systems.',
                    ),

                    _legalSection(
                      title: '4. Data Storage & Security',
                      body:
                          'AGRHI uses reasonable technical and organisational '
                          'security measures to protect information, including:\n\n'
                          '• HTTPS/TLS encrypted communication with production servers.\n'
                          '• Secure authentication mechanisms.\n'
                          '• Password hashing instead of plain-text password storage.\n'
                          '• Protected storage for authentication credentials on supported devices.\n'
                          '• Access controls for authorised personnel.\n'
                          '• Server and application security reviews.\n\n'
                          'No electronic system can guarantee absolute security. '
                          'If a security incident affects personal data, AGRHI '
                          'will take appropriate action and provide notifications '
                          'where required by applicable law.',
                    ),

                    _legalSection(
                      title: '5. Location Data',
                      body:
                          'AGRHI accesses location only when required by '
                          'location-dependent features.\n\n'
                          '🌾 Farm Store Setup\n'
                          'Your GPS coordinates may be saved as your Farm Store '
                          'selling location. This location may be visible to other '
                          'AGRHI users using nearby-store features.\n\n'
                          '🗺 Map Module\n'
                          'Your current location may be used to calculate and show '
                          'nearby stores relative to your position.\n\n'
                          '🌦 Weather\n'
                          'Your location may be used to provide locally relevant '
                          'weather information.\n\n'
                          'AGRHI does not continuously track your location in the '
                          'background. Location access is requested in context '
                          'when a feature requires it.',
                    ),

                    _legalSection(
                      title: '6. Crop Images & Plant Doctor',
                      body:
                          'Crop images selected or captured through Plant Doctor '
                          'may be processed on the device or by AGRHI server-side '
                          'services for crop disease detection.\n\n'
                          'Images may be retained for a limited period where '
                          'required for application functionality or model '
                          'improvement.\n\n'
                          'Where images are used for model improvement, AGRHI will '
                          'take reasonable steps to separate them from directly '
                          'identifying account information where appropriate.\n\n'
                          'AGRHI does not sell crop images or provide them to '
                          'third parties for advertising purposes.\n\n'
                          'You retain ownership of images you upload. By submitting '
                          'an image through Plant Doctor, you permit AGRHI to '
                          'process it for disease detection and the purposes '
                          'described in this Privacy Policy.',
                    ),

                    _legalSection(
                      title: '7. Children\'s Privacy',
                      body:
                          'AGRHI is not intended for children below the minimum '
                          'age permitted to independently use the service under '
                          'applicable law.\n\n'
                          'AGRHI does not knowingly collect personal information '
                          'from children where parental or guardian consent is '
                          'legally required and has not been obtained.\n\n'
                          'If you believe a child has provided personal information '
                          'without appropriate consent, contact us at '
                          'support@farmlead.in so that the account and associated '
                          'information can be reviewed and removed where required.',
                    ),

                    _legalSection(
                      title: '8. Your Privacy Rights',
                      body:
                          'Depending on applicable law and your location, you may '
                          'have rights concerning your personal information, '
                          'including:\n\n'
                          '• Right to request access to your personal data.\n'
                          '• Right to request correction of inaccurate data.\n'
                          '• Right to request deletion of your account and data.\n'
                          '• Right to request restriction of certain processing.\n'
                          '• Right to data portability where applicable.\n'
                          '• Right to object to certain processing where applicable.\n'
                          '• Right to withdraw consent where processing is based on consent.\n\n'
                          'EU/EEA users may have rights under the GDPR.\n\n'
                          'Users in India may have rights under applicable Indian '
                          'privacy and data-protection legislation, including the '
                          'Digital Personal Data Protection Act, 2023, where applicable.\n\n'
                          'Requests can be submitted through Help & Support or '
                          'by emailing support@farmlead.in.',
                    ),

                    _legalSection(
                      title: '9. Data Retention & Account Deletion',
                      body:
                          'AGRHI retains personal information only for as long as '
                          'reasonably necessary to provide the service or comply '
                          'with legitimate legal, security, fraud-prevention, '
                          'regulatory, or programme requirements.\n\n'
                          'Typical retention periods include:\n\n'
                          '• Account data — retained while your account is active '
                          'and deleted after an account deletion request is completed, '
                          'except where retention is legally required.\n\n'
                          '• Crop images — may be retained for up to 12 months for '
                          'model improvement and then deleted or anonymised where applicable.\n\n'
                          '• Support messages — may be retained for up to 24 months '
                          'for issue resolution and service quality purposes.\n\n'
                          '• Aggregated analytics — may be anonymised after approximately '
                          '6 months where applicable.\n\n'
                          '• Third-party SDK diagnostic information — retention may '
                          'also be governed by the applicable service provider\'s policies.\n\n'
                          'You can request deletion of your AGRHI account and '
                          'associated personal information through the application '
                          'or using our public account deletion page:\n\n'
                          'https://farmlead.in/delete-account\n\n'
                          'Certain information may be retained after deletion only '
                          'where required for legal, regulatory, security, fraud '
                          'prevention, or compliance purposes.',
                    ),

                    _legalSection(
                      title: '10. Cookies, Device Storage & Identifiers',
                      body:
                          'The AGRHI mobile application does not use browser '
                          'tracking cookies.\n\n'
                          'AGRHI uses local device storage for application '
                          'functionality, including:\n\n'
                          '• Language preferences.\n'
                          '• Downloaded language packs and models.\n'
                          '• Offline application data.\n'
                          '• Application settings.\n'
                          '• Authentication/session information stored using '
                          'protected storage where supported.\n\n'
                          'AGRHI does not use personal information for advertising. '
                          'Some integrated SDKs may process limited technical '
                          'identifiers or diagnostic information as described in '
                          'Section 3 of this Privacy Policy.',
                    ),

                    _legalSection(
                      title: '11. AI Chatbot Privacy',
                      body:
                          'When the AGRHI AI Chatbot is available, the message '
                          'you submit may be transmitted to third-party AI '
                          'providers such as Groq or Google AI to generate a response.\n\n'
                          'You should not enter sensitive personal information, '
                          'financial details, passwords, confidential business '
                          'information, or other information that you do not want '
                          'processed by those services.\n\n'
                          'AI Chatbot processing occurs only when you actively use '
                          'the chatbot feature.',
                    ),

                    _legalSection(
                      title: '12. Changes to This Privacy Policy',
                      body:
                          'AGRHI may update this Privacy Policy when application '
                          'features, technologies, legal requirements, or data '
                          'practices change.\n\n'
                          'Where required, significant changes will be communicated '
                          'through an appropriate in-app notice.\n\n'
                          'The latest effective date will be shown at the top of '
                          'this Privacy Policy.',
                    ),

                    _legalSection(
                      title: '13. Developer & Privacy Contact',
                      body:
                          'Application: AGRHI — Smart Farm Assistant\n\n'
                          'Website / Service: Farmlead\n\n'
                          'Developer / Programme Operator: Erasmus+ AGRHI Programme Consortium\n\n'
                          'Privacy & Support Email: support@farmlead.in\n\n'
                          'Website: https://farmlead.in\n\n'
                          'Account Deletion: https://farmlead.in/delete-account\n\n'
                          'For privacy questions, access requests, corrections, '
                          'account deletion requests, or other privacy concerns, '
                          'contact AGRHI through Help & Support or email '
                          'support@farmlead.in.',
                      isLast: true,
                    ),

                    const SizedBox(height: 16),
                    _lastUpdated('August 2026'),
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
            value: 'support@farmlead.in',
            isFirst: true,
          ),
          _buildDivider(),
          _buildContactRow(
            icon: Icons.language_rounded,
            label: 'Website',
            value: 'farmlead.in',
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
          ),

          _buildDivider(),

          _buildLegalTile(
            context: context,
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            iconColor: AppColors.errorColor,
            textColor: AppColors.errorColor,
            onTap: () {
              Navigator.of(context).push(DeleteAccountScreen.route());
            },
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
    Color iconColor = AppColors.primaryGreen,
    Color textColor = AppColors.textPrimary,
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
                color: iconColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              color: textColor == AppColors.errorColor
                  ? AppColors.errorColor.withOpacity(0.7)
                  : AppColors.textSecondary,
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
