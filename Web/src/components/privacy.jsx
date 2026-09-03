import React, { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import AnimatedContent from "./reactbits/AnimatedContent";
import usePageMetadata from "../hooks/usePageMetadata";

const LOGO_SRC = "/logo.png";
const LANGUAGE_STORAGE_KEY = "agrhi-website-language";

const LANGUAGES = [
  { code: "en", label: "English" },
  { code: "ta", label: "தமிழ்" },
  { code: "hi", label: "हिन्दी" },
  { code: "te", label: "తెలుగు" },
];

const PRIVACY_TRANSLATIONS = {
  en: {
    homeAria: "Go to AGRHI home",
    logoTag: "Leading the Future of Agriculture.",
    backHome: "Back to Home",
    language: "Language",
    badge: "AGRHI Privacy & Data Protection",
    title: ["Your privacy", "matters to AGRHI."],
    description:
      "This Privacy Policy explains how the AGRHI mobile application collects, uses, stores, shares, and protects personal and device data when you use our services.",
    effectiveDate: "Effective Date: April 2026 • Last reviewed: August 2026",
    transparencyTitle: "Privacy built around transparency",
    transparencyText:
      "AGRHI explains what data is needed, why it is used, when it may be shared, how long it may be retained, and how you can request deletion or other privacy actions.",
    sectionTitles: [
      "1. Data We Collect",
      "2. How We Use Your Data",
      "3. Data Sharing & Third Parties",
      "4. Data Storage & Security",
      "5. Location Data",
      "6. Crop Images & Plant Doctor",
      "7. Children's Privacy",
      "8. Your Privacy Rights",
      "9. Data Retention & Deletion",
      "10. Cookies & Local Device Storage",
      "11. Changes to This Privacy Policy",
      "12. Developer & Privacy Contact",
    ],
    glance: "Privacy at a glance",
    summary: [
      "We do not sell personal data.",
      "HTTPS/TLS protects data in transit.",
      "Passwords are stored as hashes.",
      "Location is used only for location-based features.",
      "No continuous background location tracking.",
      "No tracking cookies or advertising identifiers.",
      "Account and data deletion can be requested.",
    ],
    policySections: "Policy sections",
    deleteTitle: "Delete your account",
    deleteText:
      "AGRHI users can request deletion of their account and associated data through the dedicated web deletion page.",
    deleteLink: "Open Account Deletion",
    supportTitle: "Questions about your privacy?",
    supportText:
      "Contact AGRHI for privacy questions, data requests, or concerns.",
    footer: "Privacy Policy • Erasmus+ AGRHI Programme",
  },
  ta: {
    homeAria: "AGRHI முகப்புக்குச் செல்லவும்",
    logoTag: "வேளாண்மையின் எதிர்காலத்தை வழிநடத்துகிறோம்.",
    backHome: "முகப்புக்குத் திரும்பு",
    language: "மொழி",
    badge: "AGRHI தனியுரிமை மற்றும் தரவுப் பாதுகாப்பு",
    title: ["உங்கள் தனியுரிமை", "AGRHIக்கு முக்கியமானது."],
    description:
      "நீங்கள் எங்கள் சேவைகளைப் பயன்படுத்தும்போது AGRHI மொபைல் செயலி தனிப்பட்ட மற்றும் சாதனத் தரவை எவ்வாறு சேகரிக்கிறது, பயன்படுத்துகிறது, சேமிக்கிறது, பகிர்கிறது மற்றும் பாதுகாக்கிறது என்பதை இந்தத் தனியுரிமைக் கொள்கை விளக்குகிறது.",
    effectiveDate: "நடைமுறை தேதி: ஏப்ரல் 2026 • கடைசியாக மதிப்பாய்வு: ஆகஸ்ட் 2026",
    transparencyTitle: "வெளிப்படைத்தன்மையை மையமாகக் கொண்ட தனியுரிமை",
    transparencyText:
      "எந்தத் தரவு தேவை, அது ஏன் பயன்படுத்தப்படுகிறது, எப்போது பகிரப்படலாம், எவ்வளவு காலம் வைத்திருக்கப்படலாம் மற்றும் நீக்கம் உள்ளிட்ட தனியுரிமை நடவடிக்கைகளை எவ்வாறு கோரலாம் என்பதை AGRHI விளக்குகிறது.",
    sectionTitles: [
      "1. நாங்கள் சேகரிக்கும் தரவு",
      "2. உங்கள் தரவை எவ்வாறு பயன்படுத்துகிறோம்",
      "3. தரவுப் பகிர்வு மற்றும் மூன்றாம் தரப்பினர்",
      "4. தரவுச் சேமிப்பு மற்றும் பாதுகாப்பு",
      "5. இருப்பிடத் தரவு",
      "6. பயிர்ப் படங்கள் மற்றும் தாவர மருத்துவர்",
      "7. குழந்தைகளின் தனியுரிமை",
      "8. உங்கள் தனியுரிமை உரிமைகள்",
      "9. தரவு வைத்திருத்தல் மற்றும் நீக்கம்",
      "10. குக்கீகள் மற்றும் உள்ளூர் சாதனச் சேமிப்பு",
      "11. இந்தத் தனியுரிமைக் கொள்கையில் மாற்றங்கள்",
      "12. உருவாக்குநர் மற்றும் தனியுரிமை தொடர்பு",
    ],
    glance: "தனியுரிமை ஒரு பார்வையில்",
    summary: [
      "தனிப்பட்ட தரவை நாங்கள் விற்பதில்லை.",
      "தரவு பரிமாற்றத்தை HTTPS/TLS பாதுகாக்கிறது.",
      "கடவுச்சொற்கள் ஹாஷ் வடிவில் சேமிக்கப்படுகின்றன.",
      "இருப்பிடம் சார்ந்த அம்சங்களுக்கு மட்டுமே இருப்பிடம் பயன்படுத்தப்படுகிறது.",
      "தொடர்ச்சியான பின்னணி இருப்பிடக் கண்காணிப்பு இல்லை.",
      "கண்காணிப்புக் குக்கீகள் அல்லது விளம்பர அடையாளங்கள் இல்லை.",
      "கணக்கு மற்றும் தரவை நீக்கக் கோரலாம்.",
    ],
    policySections: "கொள்கைப் பிரிவுகள்",
    deleteTitle: "உங்கள் கணக்கை நீக்குங்கள்",
    deleteText:
      "AGRHI பயனர்கள் தனிப்பட்ட இணைய நீக்கப் பக்கத்தின் மூலம் தங்கள் கணக்கையும் அதனுடன் தொடர்புடைய தரவையும் நீக்கக் கோரலாம்.",
    deleteLink: "கணக்கு நீக்கப் பக்கத்தைத் திறக்கவும்",
    supportTitle: "உங்கள் தனியுரிமை குறித்து கேள்விகள் உள்ளதா?",
    supportText:
      "தனியுரிமைக் கேள்விகள், தரவுக் கோரிக்கைகள் அல்லது கவலைகளுக்கு AGRHIயைத் தொடர்புகொள்ளவும்.",
    footer: "தனியுரிமைக் கொள்கை • Erasmus+ AGRHI திட்டம்",
  },
  hi: {
    homeAria: "AGRHI होम पर जाएँ",
    logoTag: "कृषि के भविष्य का नेतृत्व।",
    backHome: "होम पर वापस जाएँ",
    language: "भाषा",
    badge: "AGRHI गोपनीयता और डेटा सुरक्षा",
    title: ["आपकी गोपनीयता", "AGRHI के लिए महत्वपूर्ण है।"],
    description:
      "यह गोपनीयता नीति बताती है कि हमारी सेवाओं का उपयोग करते समय AGRHI मोबाइल ऐप व्यक्तिगत और डिवाइस डेटा को कैसे एकत्र, उपयोग, संग्रहीत, साझा और सुरक्षित करता है।",
    effectiveDate: "प्रभावी तिथि: अप्रैल 2026 • अंतिम समीक्षा: अगस्त 2026",
    transparencyTitle: "पारदर्शिता पर आधारित गोपनीयता",
    transparencyText:
      "AGRHI बताता है कि कौन-सा डेटा आवश्यक है, उसका उपयोग क्यों होता है, उसे कब साझा किया जा सकता है, कितने समय तक रखा जा सकता है और आप उसे हटाने या अन्य गोपनीयता कार्रवाइयों का अनुरोध कैसे कर सकते हैं।",
    sectionTitles: [
      "1. हम कौन-सा डेटा एकत्र करते हैं",
      "2. हम आपके डेटा का उपयोग कैसे करते हैं",
      "3. डेटा साझाकरण और तृतीय पक्ष",
      "4. डेटा संग्रहण और सुरक्षा",
      "5. स्थान डेटा",
      "6. फसल चित्र और प्लांट डॉक्टर",
      "7. बच्चों की गोपनीयता",
      "8. आपके गोपनीयता अधिकार",
      "9. डेटा प्रतिधारण और विलोपन",
      "10. कुकीज़ और स्थानीय डिवाइस संग्रहण",
      "11. इस गोपनीयता नीति में बदलाव",
      "12. डेवलपर और गोपनीयता संपर्क",
    ],
    glance: "गोपनीयता एक नज़र में",
    summary: [
      "हम व्यक्तिगत डेटा नहीं बेचते।",
      "HTTPS/TLS भेजे जा रहे डेटा की सुरक्षा करता है।",
      "पासवर्ड हैश के रूप में संग्रहीत किए जाते हैं।",
      "स्थान का उपयोग केवल स्थान-आधारित सुविधाओं के लिए होता है।",
      "पृष्ठभूमि में लगातार स्थान ट्रैकिंग नहीं होती।",
      "कोई ट्रैकिंग कुकी या विज्ञापन पहचानकर्ता नहीं है।",
      "खाता और डेटा हटाने का अनुरोध किया जा सकता है।",
    ],
    policySections: "नीति के अनुभाग",
    deleteTitle: "अपना खाता हटाएँ",
    deleteText:
      "AGRHI उपयोगकर्ता समर्पित वेब विलोपन पृष्ठ से अपना खाता और संबंधित डेटा हटाने का अनुरोध कर सकते हैं।",
    deleteLink: "खाता विलोपन पृष्ठ खोलें",
    supportTitle: "आपकी गोपनीयता के बारे में प्रश्न हैं?",
    supportText:
      "गोपनीयता प्रश्नों, डेटा अनुरोधों या चिंताओं के लिए AGRHI से संपर्क करें।",
    footer: "गोपनीयता नीति • Erasmus+ AGRHI कार्यक्रम",
  },
  te: {
    homeAria: "AGRHI హోమ్‌కు వెళ్లండి",
    logoTag: "వ్యవసాయ భవిష్యత్తుకు నాయకత్వం.",
    backHome: "హోమ్‌కు తిరిగి వెళ్లండి",
    language: "భాష",
    badge: "AGRHI గోప్యత మరియు డేటా రక్షణ",
    title: ["మీ గోప్యత", "AGRHIకి ముఖ్యం."],
    description:
      "మీరు మా సేవలను ఉపయోగించినప్పుడు AGRHI మొబైల్ యాప్ వ్యక్తిగత మరియు పరికర డేటాను ఎలా సేకరిస్తుంది, ఉపయోగిస్తుంది, నిల్వ చేస్తుంది, పంచుకుంటుంది మరియు రక్షిస్తుంది అనేది ఈ గోప్యతా విధానం వివరిస్తుంది.",
    effectiveDate: "అమలు తేదీ: ఏప్రిల్ 2026 • చివరి సమీక్ష: ఆగస్టు 2026",
    transparencyTitle: "పారదర్శకత ఆధారంగా రూపొందించిన గోప్యత",
    transparencyText:
      "ఏ డేటా అవసరం, దాన్ని ఎందుకు ఉపయోగిస్తారు, ఎప్పుడు పంచుకోవచ్చు, ఎంతకాలం ఉంచవచ్చు మరియు తొలగింపు లేదా ఇతర గోప్యతా చర్యలను ఎలా అభ్యర్థించవచ్చో AGRHI వివరిస్తుంది.",
    sectionTitles: [
      "1. మేము సేకరించే డేటా",
      "2. మీ డేటాను మేము ఎలా ఉపయోగిస్తాము",
      "3. డేటా భాగస్వామ్యం మరియు మూడవ పక్షాలు",
      "4. డేటా నిల్వ మరియు భద్రత",
      "5. స్థాన డేటా",
      "6. పంట చిత్రాలు మరియు ప్లాంట్ డాక్టర్",
      "7. పిల్లల గోప్యత",
      "8. మీ గోప్యతా హక్కులు",
      "9. డేటా నిలుపుదల మరియు తొలగింపు",
      "10. కుకీలు మరియు స్థానిక పరికర నిల్వ",
      "11. ఈ గోప్యతా విధానంలో మార్పులు",
      "12. డెవలపర్ మరియు గోప్యతా సంప్రదింపు",
    ],
    glance: "గోప్యత ఒక చూపులో",
    summary: [
      "మేము వ్యక్తిగత డేటాను విక్రయించము.",
      "డేటా బదిలీని HTTPS/TLS రక్షిస్తుంది.",
      "పాస్‌వర్డ్‌లు హాష్‌లుగా నిల్వ చేయబడతాయి.",
      "స్థాన ఆధారిత ఫీచర్లకు మాత్రమే స్థానాన్ని ఉపయోగిస్తాము.",
      "నిరంతర నేపథ్య స్థాన ట్రాకింగ్ ఉండదు.",
      "ట్రాకింగ్ కుకీలు లేదా ప్రకటన గుర్తింపులు ఉండవు.",
      "ఖాతా మరియు డేటా తొలగింపును అభ్యర్థించవచ్చు.",
    ],
    policySections: "విధాన విభాగాలు",
    deleteTitle: "మీ ఖాతాను తొలగించండి",
    deleteText:
      "AGRHI వినియోగదారులు ప్రత్యేక వెబ్ తొలగింపు పేజీ ద్వారా తమ ఖాతా మరియు సంబంధిత డేటాను తొలగించమని అభ్యర్థించవచ్చు.",
    deleteLink: "ఖాతా తొలగింపు పేజీని తెరవండి",
    supportTitle: "మీ గోప్యత గురించి ప్రశ్నలు ఉన్నాయా?",
    supportText:
      "గోప్యతా ప్రశ్నలు, డేటా అభ్యర్థనలు లేదా ఆందోళనల కోసం AGRHIని సంప్రదించండి.",
    footer: "గోప్యతా విధానం • Erasmus+ AGRHI కార్యక్రమం",
  },
};

function getInitialLanguage() {
  try {
    const savedLanguage = localStorage.getItem(LANGUAGE_STORAGE_KEY);
    return PRIVACY_TRANSLATIONS[savedLanguage] ? savedLanguage : "en";
  } catch {
    return "en";
  }
}

function Icon({ name, size = 24 }) {
  const props = {
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.9",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    "aria-hidden": true,
  };

  const icons = {
    leaf: (
      <>
        <path d="M20 4c-7.3.6-12.3 4.2-14.2 11C10.7 15.7 16.4 12.1 20 4Z" />
        <path d="M5 20c2.1-5.4 5.7-9.2 10.7-11.3" />
      </>
    ),
    shield: (
      <>
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" />
        <path d="m9 12 2 2 4-5" />
      </>
    ),
    globe: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M3 12h18" />
        <path d="M12 3a15 15 0 0 1 0 18" />
        <path d="M12 3a15 15 0 0 0 0 18" />
      </>
    ),
    home: (
      <>
        <path d="m3 11 9-8 9 8" />
        <path d="M5 10v10h14V10" />
        <path d="M9 20v-6h6v6" />
      </>
    ),
    database: (
      <>
        <ellipse cx="12" cy="5" rx="8" ry="3" />
        <path d="M4 5v6c0 1.7 3.6 3 8 3s8-1.3 8-3V5" />
        <path d="M4 11v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6" />
      </>
    ),
    lock: (
      <>
        <rect x="5" y="10" width="14" height="11" rx="2" />
        <path d="M8 10V7a4 4 0 0 1 8 0v3" />
      </>
    ),
    map: (
      <>
        <path d="M12 21s6-5.2 6-11a6 6 0 1 0-12 0c0 5.8 6 11 6 11Z" />
        <circle cx="12" cy="10" r="2" />
      </>
    ),
    image: (
      <>
        <rect x="3" y="4" width="18" height="16" rx="2" />
        <circle cx="9" cy="9" r="2" />
        <path d="m21 15-5-5L5 20" />
      </>
    ),
    users: (
      <>
        <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
        <circle cx="9" cy="7" r="4" />
        <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
        <path d="M16 3.13a4 4 0 0 1 0 7.75" />
      </>
    ),
    clock: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3 2" />
      </>
    ),
    cookie: (
      <>
        <path d="M20.5 13.2A8.5 8.5 0 1 1 10.8 3.5 4.8 4.8 0 0 0 20.5 13.2Z" />
        <circle cx="8" cy="10" r=".7" fill="currentColor" stroke="none" />
        <circle cx="11" cy="15" r=".7" fill="currentColor" stroke="none" />
        <circle cx="6.5" cy="15.5" r=".7" fill="currentColor" stroke="none" />
      </>
    ),
    mail: (
      <>
        <rect x="3" y="5" width="18" height="14" rx="2" />
        <path d="m3 7 9 6 9-6" />
      </>
    ),
    trash: (
      <>
        <path d="M3 6h18" />
        <path d="M8 6V4h8v2" />
        <path d="M19 6l-1 14H6L5 6" />
        <path d="M10 11v5" />
        <path d="M14 11v5" />
      </>
    ),
    check: <path d="m5 12 4 4L19 6" />,
    arrow: <path d="m9 18 6-6-6-6" />,
  };

  return <svg {...props}>{icons[name]}</svg>;
}

const policySections = [
  {
    id: "data-collected",
    icon: "database",
    title: "1. Data We Collect",
    content: (
      <>
        <p>We collect the following categories of personal data:</p>
        <ul>
          <li>
            <strong>Registration Data:</strong> Full name, phone number, email
            address, date of birth, address, postal code, and role category.
          </li>
          <li>
            <strong>Location Data:</strong> GPS coordinates when you set up a
            Farm Store or use the Map module. Location access is requested only
            when needed.
          </li>
          <li>
            <strong>Images:</strong> Crop photos you upload to Plant Doctor.
            Images are processed for disease detection and may be stored to
            improve model accuracy.
          </li>
          <li>
            <strong>Support Messages:</strong> Feedback and issue reports
            submitted through Help &amp; Support.
          </li>
          <li>
            <strong>Marketplace Data:</strong> Product listings, shop details,
            and retailer contact numbers.
          </li>
          <li>
            <strong>Usage Data:</strong> App interactions, feature usage
            patterns, crash logs, and diagnostic data used to improve the app.
          </li>
        </ul>
      </>
    ),
  },
  {
    id: "use",
    icon: "leaf",
    title: "2. How We Use Your Data",
    content: (
      <>
        <p>Your personal data is used to:</p>
        <ul>
          <li>Create and authenticate your account and manage your profile.</li>
          <li>
            Provide Plant Doctor, Marketplace, Farm Store, Subsidies, and Map
            features.
          </li>
          <li>
            Process and display retailer shop profiles after admin verification.
          </li>
          <li>
            Enable GPS-based Farm Store location and nearby Marketplace
            features.
          </li>
          <li>Process crop images for disease detection.</li>
          <li>Send important in-app updates and policy notices.</li>
          <li>Respond to Help &amp; Support requests.</li>
          <li>
            Improve performance using aggregated and anonymised usage analytics.
          </li>
          <li>
            Fulfil Erasmus+ Programme reporting obligations using aggregated,
            anonymised data only.
          </li>
        </ul>
      </>
    ),
  },
  {
    id: "sharing",
    icon: "users",
    title: "3. Data Sharing & Third Parties",
    content: (
      <>
        <p>
          We do not sell your personal data. Data is shared only where needed
          for the following purposes:
        </p>
        <ul>
          <li>
            <strong>AI Processing:</strong> Crop images may be processed by
            AGRHI&apos;s on-device or server-side ML models. When the AI Chatbot
            is active, query text may be sent to Groq API (LLaMA 3.1) and Google
            AI (Gemma 3) to generate responses.
          </li>
          <li>
            <strong>Google Maps:</strong> When you select Directions, you are
            redirected to Google Maps and Google&apos;s own privacy terms apply
            to that interaction.
          </li>
          <li>
            <strong>Erasmus+ Programme:</strong> Aggregated and anonymised usage
            statistics may be shared with programme evaluators where required by
            the grant agreement.
          </li>
          <li>
            <strong>Legal Requirements:</strong> We may disclose information
            where required by law, a valid court order, or to protect users and
            the platform.
          </li>
        </ul>
      </>
    ),
  },
  {
    id: "security",
    icon: "lock",
    title: "4. Data Storage & Security",
    content: (
      <>
        <p>
          Your data is stored on secured systems. AGRHI uses technical and
          organisational safeguards including:
        </p>
        <ul>
          <li>Encrypted transmission using HTTPS/TLS.</li>
          <li>
            Hashed password storage; passwords are not stored in plain text.
          </li>
          <li>Access controls for authorised personnel.</li>
          <li>Regular security reviews of the supporting infrastructure.</li>
        </ul>
        <p>
          No system can be guaranteed completely secure. Where applicable law
          requires notification of a personal-data breach affecting your rights,
          AGRHI will provide the required notification.
        </p>
      </>
    ),
  },
  {
    id: "location",
    icon: "map",
    title: "5. Location Data",
    content: (
      <>
        <p>Location access is used only for location-dependent features:</p>
        <ul>
          <li>
            <strong>Farm Store Setup:</strong> GPS coordinates are captured to
            set your selling location, which can be visible to nearby AGRHI
            users.
          </li>
          <li>
            <strong>Map Module:</strong> Your current location may be used to
            show nearby stores relative to you.
          </li>
        </ul>
        <p>
          AGRHI does not continuously track your location in the background.
          Location permission is requested in context when you use a feature
          that needs it.
        </p>
      </>
    ),
  },
  {
    id: "plant-doctor",
    icon: "image",
    title: "6. Crop Images & Plant Doctor",
    content: (
      <>
        <p>Images captured or uploaded through Plant Doctor may be:</p>
        <ul>
          <li>Processed on-device or by a server-side ML model.</li>
          <li>
            Retained for a limited period under anonymised conditions to improve
            model accuracy.
          </li>
          <li>Not shared with third parties for commercial purposes.</li>
        </ul>
        <p>
          You retain ownership of uploaded images. By uploading them, you grant
          AGRHI permission to use them for disease detection and model
          improvement as described in this policy.
        </p>
      </>
    ),
  },
  {
    id: "children",
    icon: "shield",
    title: "7. Children's Privacy",
    content: (
      <>
        <p>
          AGRHI is not intended for children under 13, or under 16 where a
          higher minimum age applies in an EU region. We do not knowingly
          collect personal data from children below the applicable age.
        </p>
        <p>
          A parent or guardian who believes a child registered without
          appropriate consent can contact us at{" "}
          <a href="mailto:support@farmlead.in">support@farmlead.in</a> to
          request review and deletion.
        </p>
      </>
    ),
  },
  {
    id: "rights",
    icon: "check",
    title: "8. Your Privacy Rights",
    content: (
      <>
        <p>Depending on applicable law, you may request:</p>
        <ul>
          <li>Access to personal data held about you.</li>
          <li>Correction of inaccurate or incomplete data.</li>
          <li>Deletion of your account and associated personal data.</li>
          <li>Restriction of certain processing.</li>
          <li>Data portability where applicable.</li>
          <li>Objection to processing where the law provides that right.</li>
        </ul>
        <p>
          EU/EEA users may have rights under the GDPR. Indian users may have
          rights under applicable Indian privacy and data-protection law,
          including the Digital Personal Data Protection Act, 2023 as
          applicable.
        </p>
        <p>
          Privacy requests can be submitted through Help &amp; Support or by
          email at <a href="mailto:support@farmlead.in">support@farmlead.in</a>.
        </p>
      </>
    ),
  },
  {
    id: "retention",
    icon: "clock",
    title: "9. Data Retention & Deletion",
    content: (
      <>
        <p>
          We retain personal data only for as long as it is needed to provide
          AGRHI services or satisfy legitimate legal, security,
          fraud-prevention, regulatory, or compliance requirements.
        </p>
        <ul>
          <li>
            <strong>Account data:</strong> Retained while the account is active
            and removed when an account deletion request is completed, except
            data that must lawfully be retained.
          </li>
          <li>
            <strong>Crop images:</strong> May be retained for up to 12 months
            for model improvement and then anonymised or deleted as applicable.
          </li>
          <li>
            <strong>Support messages:</strong> May be retained for up to 24
            months for support quality and issue resolution.
          </li>
          <li>
            <strong>Usage analytics:</strong> Aggregated and anonymised after 6
            months.
          </li>
        </ul>
        <p>
          You can request deletion outside the app through our{" "}
          <a href="/delete-account">Account Deletion page</a>. Account deletion
          includes deletion of associated user data, subject only to legitimate
          retention requirements disclosed above.
        </p>
      </>
    ),
  },
  {
    id: "local-storage",
    icon: "cookie",
    title: "10. Cookies & Local Device Storage",
    content: (
      <>
        <p>
          The AGRHI mobile app does not use browser cookies. Local device
          storage may be used for:
        </p>
        <ul>
          <li>Your selected language preference.</li>
          <li>Downloaded language-pack data.</li>
          <li>
            Session authentication data stored using protected device storage.
          </li>
        </ul>
        <p>
          AGRHI does not use tracking cookies or advertising identifiers as
          described by the current application privacy implementation.
        </p>
      </>
    ),
  },
  {
    id: "changes",
    icon: "shield",
    title: "11. Changes to This Privacy Policy",
    content: (
      <>
        <p>
          We may update this Privacy Policy when our services, legal
          obligations, or data practices change. Significant changes will be
          communicated through an appropriate in-app notice before or when the
          revised policy takes effect, where required.
        </p>
        <p>
          The latest effective date will always be displayed at the top of this
          page.
        </p>
      </>
    ),
  },
  {
    id: "contact",
    icon: "mail",
    title: "12. Developer & Privacy Contact",
    content: (
      <>
        <p>
          <strong>Application:</strong> AGRHI — Smart Farm Assistant
          <br />
          <strong>Web identity:</strong> Farmlead
          <br />
          <strong>Programme:</strong> Erasmus+ AGRHI Programme
          <br />
          <strong>Privacy email:</strong>{" "}
          <a href="mailto:support@farmlead.in">support@farmlead.in</a>
        </p>
        <p>
          For privacy questions, access requests, correction requests, or
          deletion requests, contact us through the AGRHI Help &amp; Support
          feature or the email address above.
        </p>
      </>
    ),
  },
];

const POLICY_CONTENT_TRANSLATIONS = {
  ta: [
    {
      intro: "பின்வரும் வகையான தனிப்பட்ட தரவை நாங்கள் சேகரிக்கிறோம்:",
      items: [
        "பதிவுத் தரவு: முழுப் பெயர், தொலைபேசி எண், மின்னஞ்சல் முகவரி, பிறந்த தேதி, முகவரி, அஞ்சல் குறியீடு மற்றும் பங்கு வகை.",
        "இருப்பிடத் தரவு: பண்ணைக் கடையை அமைக்கும்போது அல்லது வரைபடத் தொகுதியைப் பயன்படுத்தும்போது GPS ஆயத்தொலைவுகள். தேவைப்படும்போது மட்டுமே இருப்பிட அணுகல் கோரப்படும்.",
        "படங்கள்: தாவர மருத்துவரில் நீங்கள் பதிவேற்றும் பயிர்ப் படங்கள். நோய் கண்டறிதலுக்காக அவை செயலாக்கப்படுகின்றன; மாதிரியின் துல்லியத்தை மேம்படுத்தச் சேமிக்கப்படலாம்.",
        "ஆதரவுச் செய்திகள்: உதவி மற்றும் ஆதரவு மூலம் சமர்ப்பிக்கப்படும் கருத்துகள் மற்றும் சிக்கல் அறிக்கைகள்.",
        "சந்தைத் தரவு: பொருள் பட்டியல்கள், கடை விவரங்கள் மற்றும் விற்பனையாளரின் தொடர்பு எண்கள்.",
        "பயன்பாட்டுத் தரவு: செயலி தொடர்புகள், அம்சப் பயன்பாட்டு முறைகள், செயலிழப்பு பதிவுகள் மற்றும் செயலியை மேம்படுத்தப் பயன்படும் கண்டறியும் தரவு.",
      ],
    },
    {
      intro: "உங்கள் தனிப்பட்ட தரவு பின்வரும் நோக்கங்களுக்குப் பயன்படுத்தப்படுகிறது:",
      items: [
        "உங்கள் கணக்கை உருவாக்கி அங்கீகரித்தல் மற்றும் சுயவிவரத்தை நிர்வகித்தல்.",
        "தாவர மருத்துவர், சந்தை, பண்ணைக் கடை, மானியங்கள் மற்றும் வரைபட அம்சங்களை வழங்குதல்.",
        "நிர்வாகி சரிபார்ப்புக்குப் பிறகு விற்பனையாளர் கடைச் சுயவிவரங்களைச் செயலாக்கிக் காட்டுதல்.",
        "GPS அடிப்படையிலான பண்ணைக் கடை இருப்பிடம் மற்றும் அருகிலுள்ள சந்தை அம்சங்களைச் செயல்படுத்துதல்.",
        "நோய் கண்டறிதலுக்காக பயிர்ப் படங்களைச் செயலாக்குதல்.",
        "முக்கிய செயலி அறிவிப்புகள் மற்றும் கொள்கை அறிவிப்புகளை அனுப்புதல்.",
        "உதவி மற்றும் ஆதரவு கோரிக்கைகளுக்குப் பதிலளித்தல்.",
        "திரட்டப்பட்டு அடையாளம் நீக்கப்பட்ட பயன்பாட்டுப் பகுப்பாய்வு மூலம் செயல்திறனை மேம்படுத்துதல்.",
        "திரட்டப்பட்டு அடையாளம் நீக்கப்பட்ட தரவை மட்டுமே பயன்படுத்தி Erasmus+ திட்ட அறிக்கை கடமைகளை நிறைவேற்றுதல்.",
      ],
    },
    {
      intro: "உங்கள் தனிப்பட்ட தரவை நாங்கள் விற்பதில்லை. பின்வரும் தேவைகளுக்காக மட்டுமே தரவு பகிரப்படுகிறது:",
      items: [
        "AI செயலாக்கம்: பயிர்ப் படங்கள் AGRHI-யின் சாதனத்திலுள்ள அல்லது சேவையக ML மாதிரிகளால் செயலாக்கப்படலாம். AI உரையாடல் செயல்பாட்டில் இருக்கும்போது, பதில்களை உருவாக்க வினா உரை Groq API (LLaMA 3.1) மற்றும் Google AI (Gemma 3) ஆகியவற்றுக்கு அனுப்பப்படலாம்.",
        "Google Maps: வழிகாட்டுதலைத் தேர்ந்தெடுக்கும்போது Google Maps-க்கு மாற்றப்படுவீர்கள்; அந்தத் தொடர்புக்கு Google-ன் சொந்த தனியுரிமை விதிகள் பொருந்தும்.",
        "Erasmus+ திட்டம்: மானிய ஒப்பந்தம் கோரும்போது திரட்டப்பட்டு அடையாளம் நீக்கப்பட்ட பயன்பாட்டுப் புள்ளிவிவரங்கள் திட்ட மதிப்பீட்டாளர்களுடன் பகிரப்படலாம்.",
        "சட்டத் தேவைகள்: சட்டம், செல்லுபடியான நீதிமன்ற உத்தரவு அல்லது பயனர்களையும் தளத்தையும் பாதுகாக்க வேண்டிய சூழலில் தகவலை வெளியிடலாம்.",
      ],
    },
    {
      intro: "உங்கள் தரவு பாதுகாப்பான அமைப்புகளில் சேமிக்கப்படுகிறது. AGRHI பயன்படுத்தும் தொழில்நுட்ப மற்றும் நிறுவனப் பாதுகாப்புகள்:",
      items: [
        "HTTPS/TLS மூலம் மறையாக்கப்பட்ட பரிமாற்றம்.",
        "ஹாஷ் செய்யப்பட்ட கடவுச்சொல் சேமிப்பு; கடவுச்சொற்கள் சாதாரண உரையாகச் சேமிக்கப்படுவதில்லை.",
        "அங்கீகரிக்கப்பட்ட பணியாளர்களுக்கான அணுகல் கட்டுப்பாடுகள்.",
        "ஆதரவு உள்கட்டமைப்பின் வழக்கமான பாதுகாப்பு மதிப்பாய்வுகள்.",
      ],
      outro: ["எந்த அமைப்பும் முழுமையாகப் பாதுகாப்பானது என்று உத்தரவாதம் அளிக்க முடியாது. உங்கள் உரிமைகளைப் பாதிக்கும் தனிப்பட்ட தரவு மீறல் குறித்து அறிவிக்கப் பொருந்தும் சட்டம் கோரினால், AGRHI தேவையான அறிவிப்பை வழங்கும்."],
    },
    {
      intro: "இருப்பிடம் சார்ந்த அம்சங்களுக்கு மட்டுமே இருப்பிட அணுகல் பயன்படுத்தப்படுகிறது:",
      items: [
        "பண்ணைக் கடை அமைப்பு: உங்கள் விற்பனை இருப்பிடத்தை அமைக்க GPS ஆயத்தொலைவுகள் பதிவு செய்யப்படுகின்றன; இது அருகிலுள்ள AGRHI பயனர்களுக்குத் தெரியக்கூடும்.",
        "வரைபடத் தொகுதி: உங்களுக்கு அருகிலுள்ள கடைகளைக் காட்ட உங்கள் தற்போதைய இருப்பிடம் பயன்படுத்தப்படலாம்.",
      ],
      outro: ["AGRHI பின்னணியில் உங்கள் இருப்பிடத்தைத் தொடர்ந்து கண்காணிப்பதில்லை. இருப்பிடம் தேவைப்படும் அம்சத்தைப் பயன்படுத்தும்போது மட்டுமே அனுமதி கோரப்படும்."],
    },
    {
      intro: "தாவர மருத்துவர் மூலம் எடுக்கப்படும் அல்லது பதிவேற்றப்படும் படங்கள்:",
      items: [
        "சாதனத்திலோ சேவையக ML மாதிரியிலோ செயலாக்கப்படலாம்.",
        "மாதிரியின் துல்லியத்தை மேம்படுத்த அடையாளம் நீக்கப்பட்ட நிலையில் வரையறுக்கப்பட்ட காலத்துக்கு வைத்திருக்கப்படலாம்.",
        "வணிக நோக்கங்களுக்காக மூன்றாம் தரப்பினருடன் பகிரப்படுவதில்லை.",
      ],
      outro: ["பதிவேற்றிய படங்களின் உரிமை உங்களிடமே இருக்கும். அவற்றைப் பதிவேற்றுவதன் மூலம், இந்தக் கொள்கையில் விளக்கப்பட்டபடி நோய் கண்டறிதல் மற்றும் மாதிரி மேம்பாட்டிற்குப் பயன்படுத்த AGRHIக்கு அனுமதி அளிக்கிறீர்கள்."],
    },
    {
      outro: [
        "AGRHI 13 வயதிற்குட்பட்ட குழந்தைகளுக்காக வடிவமைக்கப்படவில்லை; ஐரோப்பிய ஒன்றியப் பகுதியில் அதிக குறைந்தபட்ச வயது பொருந்தினால் 16 வயதிற்குட்பட்டவர்களுக்காகவும் அல்ல. பொருந்தும் வயதிற்குக் குறைவான குழந்தைகளிடமிருந்து தனிப்பட்ட தரவை அறிந்தே சேகரிப்பதில்லை.",
        "உரிய ஒப்புதல் இல்லாமல் ஒரு குழந்தை பதிவு செய்ததாக நம்பும் பெற்றோர் அல்லது பாதுகாவலர் ஆய்வு மற்றும் நீக்கத்தைக் கோர {email} என்ற முகவரியில் எங்களைத் தொடர்புகொள்ளலாம்.",
      ],
    },
    {
      intro: "பொருந்தும் சட்டத்தைப் பொறுத்து, நீங்கள் பின்வருவனவற்றைக் கோரலாம்:",
      items: [
        "உங்களைப் பற்றி வைத்திருக்கும் தனிப்பட்ட தரவை அணுகுதல்.",
        "தவறான அல்லது முழுமையற்ற தரவைத் திருத்துதல்.",
        "உங்கள் கணக்கையும் தொடர்புடைய தனிப்பட்ட தரவையும் நீக்குதல்.",
        "சில செயலாக்கங்களைக் கட்டுப்படுத்துதல்.",
        "பொருந்தும் இடங்களில் தரவு மாற்றத்திறன்.",
        "சட்டம் அந்த உரிமையை வழங்கும் இடங்களில் செயலாக்கத்திற்கு எதிர்ப்பு தெரிவித்தல்.",
      ],
      outro: [
        "EU/EEA பயனர்களுக்கு GDPR-ன் கீழ் உரிமைகள் இருக்கலாம். இந்தியப் பயனர்களுக்கு, பொருந்தும் 2023 டிஜிட்டல் தனிப்பட்ட தரவுப் பாதுகாப்புச் சட்டம் உள்ளிட்ட இந்தியத் தனியுரிமை மற்றும் தரவுப் பாதுகாப்புச் சட்டங்களின் கீழ் உரிமைகள் இருக்கலாம்.",
        "தனியுரிமைக் கோரிக்கைகளை உதவி மற்றும் ஆதரவு மூலமாகவோ {email} என்ற மின்னஞ்சல் மூலமாகவோ சமர்ப்பிக்கலாம்.",
      ],
    },
    {
      intro: "AGRHI சேவைகளை வழங்க அல்லது சட்டம், பாதுகாப்பு, மோசடித் தடுப்பு, ஒழுங்குமுறை அல்லது இணக்கத் தேவைகளை நிறைவேற்றத் தேவையான காலத்திற்கு மட்டுமே தனிப்பட்ட தரவை வைத்திருக்கிறோம்.",
      items: [
        "கணக்குத் தரவு: கணக்கு செயலில் இருக்கும் வரை வைத்திருக்கப்படும்; சட்டப்படி வைத்திருக்க வேண்டிய தரவைத் தவிர, கணக்கு நீக்கக் கோரிக்கை முடிந்ததும் அகற்றப்படும்.",
        "பயிர்ப் படங்கள்: மாதிரி மேம்பாட்டிற்காக 12 மாதங்கள் வரை வைத்திருந்து, பின்னர் பொருந்துமாறு அடையாளம் நீக்கப்படலாம் அல்லது அழிக்கப்படலாம்.",
        "ஆதரவுச் செய்திகள்: ஆதரவுத் தரம் மற்றும் சிக்கல் தீர்வுக்காக 24 மாதங்கள் வரை வைத்திருக்கப்படலாம்.",
        "பயன்பாட்டுப் பகுப்பாய்வு: 6 மாதங்களுக்குப் பிறகு திரட்டப்பட்டு அடையாளம் நீக்கப்படும்.",
      ],
      outro: ["செயலிக்கு வெளியே எங்கள் {deletion} மூலம் நீக்கத்தைக் கோரலாம். மேலே தெரிவிக்கப்பட்ட சட்டபூர்வ வைத்திருத்தல் தேவைகளுக்கு உட்பட்டு, கணக்கு நீக்கம் தொடர்புடைய பயனர் தரவையும் நீக்கும்."],
    },
    {
      intro: "AGRHI மொபைல் செயலி உலாவிக் குக்கீகளைப் பயன்படுத்துவதில்லை. உள்ளூர் சாதனச் சேமிப்பு பின்வருவனவற்றுக்குப் பயன்படுத்தப்படலாம்:",
      items: ["நீங்கள் தேர்ந்தெடுத்த மொழி விருப்பம்.", "பதிவிறக்கிய மொழித் தொகுப்புத் தரவு.", "பாதுகாக்கப்பட்ட சாதனச் சேமிப்பில் வைக்கப்படும் அமர்வு அங்கீகாரத் தரவு."],
      outro: ["தற்போதைய செயலி தனியுரிமை நடைமுறையில் விளக்கப்பட்டபடி, AGRHI கண்காணிப்புக் குக்கீகள் அல்லது விளம்பர அடையாளங்களைப் பயன்படுத்துவதில்லை."],
    },
    {
      outro: [
        "எங்கள் சேவைகள், சட்டக் கடமைகள் அல்லது தரவு நடைமுறைகள் மாறும்போது இந்தத் தனியுரிமைக் கொள்கையைப் புதுப்பிக்கலாம். பொருந்தும் இடங்களில், திருத்தப்பட்ட கொள்கை அமலுக்கு வருவதற்கு முன்போ வரும்போதோ முக்கிய மாற்றங்கள் உரிய செயலி அறிவிப்பு மூலம் தெரிவிக்கப்படும்.",
        "சமீபத்திய நடைமுறை தேதி எப்போதும் இந்தப் பக்கத்தின் மேலே காட்டப்படும்.",
      ],
    },
    {
      outro: [
        "செயலி: AGRHI — ஸ்மார்ட் பண்ணை உதவியாளர்\nஇணைய அடையாளம்: Farmlead\nதிட்டம்: Erasmus+ AGRHI திட்டம்\nதனியுரிமை மின்னஞ்சல்: {email}",
        "தனியுரிமைக் கேள்விகள், அணுகல், திருத்தம் அல்லது நீக்கக் கோரிக்கைகளுக்கு AGRHI உதவி மற்றும் ஆதரவு அம்சம் அல்லது மேலுள்ள மின்னஞ்சல் முகவரி மூலம் எங்களைத் தொடர்புகொள்ளவும்.",
      ],
    },
  ],
  hi: [
    { intro: "हम निम्न श्रेणियों का व्यक्तिगत डेटा एकत्र करते हैं:", items: [
      "पंजीकरण डेटा: पूरा नाम, फोन नंबर, ईमेल, जन्मतिथि, पता, डाक कोड और भूमिका श्रेणी।",
      "स्थान डेटा: फार्म स्टोर बनाते या मानचित्र मॉड्यूल उपयोग करते समय GPS निर्देशांक; अनुमति केवल आवश्यकता के समय माँगी जाती है।",
      "चित्र: प्लांट डॉक्टर में अपलोड की गई फसल की तस्वीरें, जिन्हें रोग पहचान के लिए संसाधित और मॉडल की सटीकता सुधारने हेतु संग्रहीत किया जा सकता है।",
      "सहायता संदेश: सहायता अनुभाग से भेजे गए सुझाव और समस्या रिपोर्ट।",
      "मार्केटप्लेस डेटा: उत्पाद सूचियाँ, दुकान विवरण और विक्रेता संपर्क नंबर।",
      "उपयोग डेटा: ऐप गतिविधि, सुविधा-उपयोग पैटर्न, क्रैश लॉग और ऐप सुधारने वाला निदान डेटा।",
    ]},
    { intro: "आपके व्यक्तिगत डेटा का उपयोग इन उद्देश्यों के लिए होता है:", items: [
      "खाता बनाना, प्रमाणित करना और प्रोफाइल संभालना।",
      "प्लांट डॉक्टर, मार्केटप्लेस, फार्म स्टोर, सब्सिडी और मानचित्र सुविधाएँ देना।",
      "एडमिन सत्यापन के बाद विक्रेता दुकान प्रोफाइल संसाधित और प्रदर्शित करना।",
      "GPS-आधारित फार्म स्टोर स्थान और आस-पास की मार्केटप्लेस सुविधाएँ चालू करना।",
      "रोग पहचान के लिए फसल चित्र संसाधित करना और महत्वपूर्ण ऐप व नीति सूचनाएँ भेजना।",
      "सहायता अनुरोधों का उत्तर देना और समेकित, अनाम उपयोग विश्लेषण से प्रदर्शन सुधारना।",
      "केवल समेकित और अनाम डेटा से Erasmus+ कार्यक्रम की रिपोर्टिंग पूरी करना।",
    ]},
    { intro: "हम आपका व्यक्तिगत डेटा नहीं बेचते। डेटा केवल इन आवश्यक उद्देश्यों के लिए साझा होता है:", items: [
      "AI प्रसंस्करण: चित्र AGRHI के डिवाइस या सर्वर ML मॉडल द्वारा संसाधित हो सकते हैं। AI चैटबॉट सक्रिय होने पर प्रश्न का पाठ उत्तर बनाने के लिए Groq API (LLaMA 3.1) और Google AI (Gemma 3) को भेजा जा सकता है।",
      "Google Maps: Directions चुनने पर आप Google Maps पर जाते हैं और उस उपयोग पर Google की गोपनीयता शर्तें लागू होती हैं।",
      "Erasmus+ कार्यक्रम: अनुदान समझौते की आवश्यकता पर समेकित और अनाम आँकड़े कार्यक्रम मूल्यांकनकर्ताओं से साझा हो सकते हैं।",
      "कानूनी आवश्यकता: कानून, वैध न्यायालय आदेश या उपयोगकर्ताओं और मंच की सुरक्षा हेतु जानकारी दी जा सकती है।",
    ]},
    { intro: "डेटा सुरक्षित प्रणालियों में रखा जाता है। AGRHI के तकनीकी और संगठनात्मक उपाय:", items: [
      "HTTPS/TLS से एन्क्रिप्टेड संचार; पासवर्ड हैश के रूप में, कभी साधारण पाठ में नहीं; अधिकृत कर्मियों के लिए पहुँच नियंत्रण; और नियमित सुरक्षा समीक्षा।",
    ], outro: ["कोई प्रणाली पूरी तरह सुरक्षित होने की गारंटी नहीं दे सकती। अधिकारों को प्रभावित करने वाले व्यक्तिगत-डेटा उल्लंघन की सूचना कानूनन आवश्यक होने पर AGRHI उचित सूचना देगा।"]},
    { intro: "स्थान अनुमति केवल स्थान-निर्भर सुविधाओं के लिए उपयोग होती है:", items: [
      "फार्म स्टोर सेटअप: बिक्री स्थान तय करने के लिए GPS निर्देशांक लिए जाते हैं, जो आस-पास के AGRHI उपयोगकर्ताओं को दिख सकते हैं।",
      "मानचित्र मॉड्यूल: आस-पास की दुकानें दिखाने के लिए वर्तमान स्थान उपयोग हो सकता है।",
    ], outro: ["AGRHI पृष्ठभूमि में लगातार स्थान ट्रैक नहीं करता; अनुमति आवश्यकता वाली सुविधा उपयोग करते समय ही माँगी जाती है।"]},
    { intro: "प्लांट डॉक्टर से ली या अपलोड की गई तस्वीरें:", items: [
      "डिवाइस या सर्वर ML मॉडल पर संसाधित हो सकती हैं; मॉडल की सटीकता सुधारने हेतु सीमित अवधि तक अनाम रूप में रखी जा सकती हैं; और व्यावसायिक उद्देश्य से तीसरे पक्ष को नहीं दी जातीं।",
    ], outro: ["अपलोड किए चित्रों का स्वामित्व आपका रहता है। अपलोड करके आप इस नीति के अनुसार रोग पहचान और मॉडल सुधार के लिए AGRHI को उनके उपयोग की अनुमति देते हैं।"]},
    { outro: [
      "AGRHI 13 वर्ष से कम बच्चों, अथवा EU क्षेत्र में अधिक न्यूनतम आयु लागू होने पर 16 वर्ष से कम बच्चों, के लिए नहीं है। हम लागू आयु से छोटे बच्चों का डेटा जानबूझकर एकत्र नहीं करते।",
      "यदि अभिभावक को लगता है कि बच्चे ने उचित सहमति के बिना पंजीकरण किया है, तो समीक्षा और विलोपन के लिए {email} पर संपर्क कर सकते हैं।",
    ]},
    { intro: "लागू कानून के अनुसार आप अनुरोध कर सकते हैं:", items: [
      "अपने व्यक्तिगत डेटा तक पहुँच; गलत या अधूरा डेटा सुधारना; खाता और संबंधित डेटा हटाना; कुछ प्रसंस्करण सीमित करना; जहाँ लागू हो डेटा पोर्टेबिलिटी; और कानून द्वारा उपलब्ध प्रसंस्करण पर आपत्ति।",
    ], outro: [
      "EU/EEA उपयोगकर्ताओं को GDPR और भारतीय उपयोगकर्ताओं को लागू भारतीय गोपनीयता कानून, जिसमें लागू रूप से डिजिटल व्यक्तिगत डेटा संरक्षण अधिनियम 2023 शामिल है, के अंतर्गत अधिकार मिल सकते हैं।",
      "अनुरोध सहायता अनुभाग या {email} पर भेजें।",
    ]},
    { intro: "डेटा केवल AGRHI सेवाएँ देने या वैध कानूनी, सुरक्षा, धोखाधड़ी-रोकथाम, नियामक या अनुपालन आवश्यकताएँ पूरी करने तक रखा जाता है।", items: [
      "खाता डेटा: सक्रिय खाते तक; विलोपन पूरा होने पर कानूनी रूप से रखना आवश्यक डेटा छोड़कर हटाया जाता है।",
      "फसल चित्र: मॉडल सुधार के लिए अधिकतम 12 माह, फिर लागू रूप से अनाम या हटाए जाते हैं।",
      "सहायता संदेश: सहायता गुणवत्ता और समाधान के लिए अधिकतम 24 माह।",
      "उपयोग विश्लेषण: 6 माह बाद समेकित और अनाम किया जाता है।",
    ], outro: ["ऐप के बाहर हमारी {deletion} से अनुरोध करें। ऊपर बताई वैध प्रतिधारण आवश्यकताओं को छोड़कर संबंधित उपयोगकर्ता डेटा भी हटाया जाता है।"]},
    { intro: "AGRHI मोबाइल ऐप ब्राउज़र कुकी उपयोग नहीं करता। स्थानीय डिवाइस संग्रहण में ये रखे जा सकते हैं:", items: [
      "चुनी हुई भाषा, डाउनलोड किए भाषा-पैक और सुरक्षित डिवाइस संग्रहण में सत्र प्रमाणीकरण डेटा।",
    ], outro: ["वर्तमान ऐप गोपनीयता कार्यान्वयन के अनुसार AGRHI ट्रैकिंग कुकी या विज्ञापन पहचानकर्ता उपयोग नहीं करता।"]},
    { outro: [
      "सेवाओं, कानूनी दायित्वों या डेटा व्यवहार में बदलाव पर यह नीति अपडेट हो सकती है। जहाँ आवश्यक हो, महत्वपूर्ण बदलाव संशोधित नीति लागू होने से पहले या उसी समय उचित ऐप सूचना से बताए जाएँगे।",
      "नवीनतम प्रभावी तिथि हमेशा इस पृष्ठ के ऊपर रहेगी।",
    ]},
    { outro: [
      "ऐप: AGRHI — स्मार्ट फार्म सहायक\nवेब पहचान: Farmlead\nकार्यक्रम: Erasmus+ AGRHI कार्यक्रम\nगोपनीयता ईमेल: {email}",
      "गोपनीयता, पहुँच, सुधार या विलोपन अनुरोध के लिए AGRHI सहायता सुविधा या ऊपर दिए ईमेल से संपर्क करें।",
    ]},
  ],
  te: [
    { intro: "మేము ఈ వ్యక్తిగత డేటాను సేకరిస్తాము:", items: [
      "నమోదు డేటా: పూర్తి పేరు, ఫోన్, ఇమెయిల్, పుట్టిన తేదీ, చిరునామా, పోస్టల్ కోడ్, పాత్ర వర్గం.",
      "స్థాన డేటా: ఫార్మ్ స్టోర్ ఏర్పాటు లేదా మ్యాప్ వినియోగంలో GPS నిర్దేశాంకాలు; అవసరమైనప్పుడే అనుమతి కోరబడుతుంది.",
      "చిత్రాలు: ప్లాంట్ డాక్టర్‌కు అప్‌లోడ్ చేసిన పంట చిత్రాలు వ్యాధి గుర్తింపుకు ప్రాసెస్ చేయబడి, మోడల్ ఖచ్చితత్వం కోసం నిల్వ కావచ్చు.",
      "సహాయ సందేశాలు, సమస్య నివేదికలు; మార్కెట్ ఉత్పత్తులు, దుకాణ వివరాలు, విక్రేత నంబర్లు; యాప్ పరస్పర చర్యలు, వినియోగ నమూనాలు, క్రాష్ లాగ్‌లు, నిర్ధారణ డేటా.",
    ]},
    { intro: "మీ డేటాను ఈ అవసరాలకు ఉపయోగిస్తాము:", items: [
      "ఖాతా సృష్టి, ధృవీకరణ, ప్రొఫైల్ నిర్వహణ; ప్లాంట్ డాక్టర్, మార్కెట్, ఫార్మ్ స్టోర్, సబ్సిడీలు, మ్యాప్ ఫీచర్లు; అడ్మిన్ ధృవీకరణ తర్వాత విక్రేత ప్రొఫైళ్లు.",
      "GPS ఆధారిత దుకాణం, సమీప మార్కెట్; వ్యాధి గుర్తింపుకు చిత్రాలు; ముఖ్యమైన యాప్/విధాన నోటీసులు; సహాయ అభ్యర్థనలు; అనామక సమగ్ర విశ్లేషణతో పనితీరు మెరుగుదల.",
      "సమగ్ర, అనామక డేటాతో మాత్రమే Erasmus+ నివేదిక బాధ్యతలు.",
    ]},
    { intro: "మీ వ్యక్తిగత డేటాను మేము అమ్మము. అవసరమైనప్పుడు మాత్రమే ఇలా పంచుతాము:", items: [
      "AI: చిత్రాలు పరికర లేదా సర్వర్ ML మోడళ్లలో ప్రాసెస్ కావచ్చు; చాట్‌బాట్ ప్రశ్నలు సమాధానాల కోసం Groq API (LLaMA 3.1), Google AI (Gemma 3)కు వెళ్లవచ్చు.",
      "Directions ఎంచుకుంటే Google Maps గోప్యతా నిబంధనలు వర్తిస్తాయి. గ్రాంట్ అవసరమైతే అనామక సమగ్ర గణాంకాలు Erasmus+ మదింపుదారులతో పంచవచ్చు. చట్టం, కోర్టు ఆదేశం లేదా వినియోగదారులు/వేదిక రక్షణ కోసం సమాచారం వెల్లడించవచ్చు.",
    ]},
    { intro: "డేటా సురక్షిత వ్యవస్థల్లో నిల్వ అవుతుంది.", items: ["HTTPS/TLS గుప్తీకరణ, హాష్ చేసిన పాస్‌వర్డ్‌లు (సాధారణ పాఠం కాదు), అధీకృత సిబ్బంది యాక్సెస్ నియంత్రణలు, క్రమమైన భద్రతా సమీక్షలు."], outro: ["ఏ వ్యవస్థకూ సంపూర్ణ భద్రత హామీ లేదు. మీ హక్కులను ప్రభావితం చేసే డేటా ఉల్లంఘనకు చట్టం కోరితే AGRHI అవసరమైన సమాచారం ఇస్తుంది."]},
    { intro: "స్థాన ఆధారిత ఫీచర్లకే స్థానాన్ని ఉపయోగిస్తాము:", items: ["ఫార్మ్ స్టోర్ విక్రయ స్థానానికి GPS తీసుకుని సమీప AGRHI వినియోగదారులకు చూపవచ్చు; మ్యాప్‌లో సమీప దుకాణాల కోసం ప్రస్తుత స్థానాన్ని ఉపయోగించవచ్చు."], outro: ["AGRHI నేపథ్యంగా స్థానాన్ని నిరంతరం ట్రాక్ చేయదు; అవసరమైన ఫీచర్ వాడినప్పుడే అనుమతి కోరుతుంది."]},
    { intro: "ప్లాంట్ డాక్టర్ చిత్రాలు:", items: ["పరికరంలో లేదా సర్వర్ ML మోడల్‌లో ప్రాసెస్ కావచ్చు; ఖచ్చితత్వం కోసం పరిమితకాలం అనామకంగా ఉండవచ్చు; వాణిజ్య అవసరాలకు మూడవ పక్షాలకు ఇవ్వబడవు."], outro: ["చిత్రాల యాజమాన్యం మీదే. అప్‌లోడ్ ద్వారా ఈ విధానం ప్రకారం వ్యాధి గుర్తింపు, మోడల్ మెరుగుదలకు AGRHIకి అనుమతిస్తారు."]},
    { outro: ["AGRHI 13 ఏళ్లలోపు పిల్లలకు కాదు; EU ప్రాంతంలో అధిక కనీస వయస్సు ఉంటే 16 ఏళ్లలోపు వారికి కాదు. వర్తించే వయస్సులోపు పిల్లల డేటాను తెలిసి సేకరించము.", "సరైన సమ్మతి లేకుండా పిల్లలు నమోదు చేశారని భావించే తల్లిదండ్రులు సమీక్ష, తొలగింపు కోసం {email}ను సంప్రదించవచ్చు."]},
    { intro: "వర్తించే చట్టం ప్రకారం మీరు కోరగలవి:", items: ["మీ డేటా యాక్సెస్; తప్పు/అసంపూర్ణ డేటా సవరణ; ఖాతా, సంబంధిత డేటా తొలగింపు; కొన్ని ప్రాసెసింగ్ పరిమితి; వర్తిస్తే డేటా పోర్టబిలిటీ; చట్టం ఇచ్చిన చోట ప్రాసెసింగ్‌కు అభ్యంతరం."], outro: ["EU/EEA వినియోగదారులకు GDPR హక్కులు; భారత వినియోగదారులకు వర్తించే డిజిటల్ వ్యక్తిగత డేటా రక్షణ చట్టం 2023 సహా భారత చట్ట హక్కులు ఉండవచ్చు.", "అభ్యర్థనను సహాయ విభాగం లేదా {email}కు పంపండి."]},
    { intro: "సేవలు లేదా చట్ట, భద్రత, మోస నిరోధం, నియంత్రణ, అనుసరణ అవసరాల వరకు మాత్రమే డేటాను ఉంచుతాము.", items: ["ఖాతా డేటా: ఖాతా క్రియాశీలంగా ఉన్నంతవరకు; చట్టబద్ధంగా ఉంచాల్సింది మినహా తొలగింపు పూర్తయ్యాక తీసివేస్తాము.", "పంట చిత్రాలు: మోడల్ మెరుగుదలకు 12 నెలల వరకు, తరువాత అనామకం లేదా తొలగింపు.", "సహాయ సందేశాలు: నాణ్యత, పరిష్కారానికి 24 నెలల వరకు. వినియోగ విశ్లేషణ: 6 నెలల తరువాత సమగ్రంగా అనామకం."], outro: ["యాప్ వెలుపల మా {deletion} ద్వారా కోరవచ్చు; పై చట్టబద్ధ నిలుపుదల మినహా సంబంధిత డేటా తొలగించబడుతుంది."]},
    { intro: "AGRHI యాప్ బ్రౌజర్ కుకీలను ఉపయోగించదు.", items: ["ఎంచుకున్న భాష, డౌన్‌లోడ్ భాషా ప్యాక్‌లు, రక్షిత పరికర నిల్వలో సెషన్ ధృవీకరణ డేటా స్థానికంగా ఉండవచ్చు."], outro: ["ట్రాకింగ్ కుకీలు లేదా ప్రకటన గుర్తింపులను AGRHI ఉపయోగించదు."]},
    { outro: ["సేవలు, చట్ట బాధ్యతలు లేదా డేటా పద్ధతులు మారితే విధానాన్ని నవీకరించవచ్చు. అవసరమైతే ముఖ్య మార్పులను అమలుకు ముందు లేదా సమయంలో యాప్ నోటీసుతో తెలియజేస్తాము.", "తాజా అమలు తేదీ పేజీ పైభాగంలో ఉంటుంది."]},
    { outro: ["యాప్: AGRHI — స్మార్ట్ ఫార్మ్ అసిస్టెంట్\nవెబ్ గుర్తింపు: Farmlead\nకార్యక్రమం: Erasmus+ AGRHI\nగోప్యతా ఇమెయిల్: {email}", "గోప్యత, యాక్సెస్, సవరణ లేదా తొలగింపు కోసం AGRHI సహాయ ఫీచర్ లేదా పై ఇమెయిల్ ద్వారా సంప్రదించండి."]},
  ],
};

function renderPolicyText(text, language) {
  return text.split(/(\{email\}|\{deletion\})/).map((part, index) => {
    if (part === "{email}") {
      return <a key={index} href="mailto:support@farmlead.in">support@farmlead.in</a>;
    }
    if (part === "{deletion}") {
      const labels = {
        ta: "கணக்கு நீக்கப் பக்கம்",
        hi: "खाता विलोपन पृष्ठ",
        te: "ఖాతా తొలగింపు పేజీ",
      };
      return <a key={index} href="/delete-account">{labels[language]}</a>;
    }
    return part;
  });
}

function LocalizedPolicyContent({ content, language }) {
  return (
    <>
      {content.intro && <p>{renderPolicyText(content.intro, language)}</p>}
      {content.items && (
        <ul>{content.items.map((item) => <li key={item}>{renderPolicyText(item, language)}</li>)}</ul>
      )}
      {content.outro?.map((paragraph) => (
        <p key={paragraph} style={{ whiteSpace: "pre-line" }}>{renderPolicyText(paragraph, language)}</p>
      ))}
    </>
  );
}

export default function Privacy() {
  usePageMetadata({
    title: "Privacy Policy — AGRHI Farm Management",
    description: "Learn how the AGRHI Farm Management Application collects, uses, protects and manages personal and device data.",
    path: "/privacy",
  });
  const navigate = useNavigate();
  const [language, setLanguage] = useState(getInitialLanguage);
  const [activePolicy, setActivePolicy] = useState(policySections[0].id);
  const [readingProgress, setReadingProgress] = useState(0);
  const t = PRIVACY_TRANSLATIONS[language];

  useEffect(() => {
    document.documentElement.lang = language;

    try {
      localStorage.setItem(LANGUAGE_STORAGE_KEY, language);
    } catch {
      // Continue without browser storage.
    }
  }, [language]);

  useEffect(() => {
    const syncLanguageFromStorage = () => {
      const storedLanguage = getInitialLanguage();
      setLanguage((currentLanguage) =>
        currentLanguage === storedLanguage ? currentLanguage : storedLanguage,
      );
    };

    window.addEventListener("pageshow", syncLanguageFromStorage);
    window.addEventListener("popstate", syncLanguageFromStorage);
    window.addEventListener("storage", syncLanguageFromStorage);

    return () => {
      window.removeEventListener("pageshow", syncLanguageFromStorage);
      window.removeEventListener("popstate", syncLanguageFromStorage);
      window.removeEventListener("storage", syncLanguageFromStorage);
    };
  }, []);

  const handleLanguageChange = (nextLanguage) => {
    try {
      localStorage.setItem(LANGUAGE_STORAGE_KEY, nextLanguage);
    } catch {
      // Continue without browser storage.
    }

    setLanguage(nextLanguage);
  };

  useEffect(() => {
    const updateProgress = () => {
      const content = document.querySelector(".privacy-content");
      if (!content) return;
      const start = content.offsetTop - 100;
      const distance = Math.max(content.offsetHeight - window.innerHeight, 1);
      setReadingProgress(Math.min(100, Math.max(0, ((window.scrollY - start) / distance) * 100)));
    };
    const observer = new IntersectionObserver((entries) => {
      const visible = entries.filter(entry => entry.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (visible) setActivePolicy(visible.target.id);
    }, { rootMargin: "-18% 0px -62% 0px", threshold: [0, 0.15, 0.4] });
    policySections.forEach(section => {
      const node = document.getElementById(section.id);
      if (node) observer.observe(node);
    });
    updateProgress();
    window.addEventListener("scroll", updateProgress, { passive: true });
    window.addEventListener("resize", updateProgress);
    return () => {
      observer.disconnect();
      window.removeEventListener("scroll", updateProgress);
      window.removeEventListener("resize", updateProgress);
    };
  }, []);

  return (
    <>
      <style>{`
        @import url("https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap");

        :root {
          --green-950: #003f14;
          --green-900: #00551b;
          --green-800: #086925;
          --green-700: #2f7d1f;
          --green-600: #3f8f21;
          --green-100: #eaf5e6;
          --green-50: #f6faf3;
          --text: #111811;
          --muted: #667066;
          --line: #dfe5dd;
          --white: #ffffff;
          --page-pad: clamp(20px, 4vw, 64px);
          --shadow-soft: 0 16px 45px rgba(25, 60, 22, 0.11);
          --shadow-green: 0 14px 28px rgba(0, 88, 28, 0.2);
        }

        * {
          box-sizing: border-box;
        }

        html {
          margin: 0;
          padding: 0;
          background: #f6f7f4;
          scroll-behavior: smooth;
        }

        body {
          margin: 0;
          font-family: "Inter", Arial, sans-serif;
          color: var(--text);
          background: #f6f7f4;
        }

        button,
        a {
          font: inherit;
        }

        .privacy-page {
          width: 100vw;
          min-height: 100vh;
          margin-left: calc(50% - 50vw);
          margin-right: calc(50% - 50vw);
          padding-top: 82px;
          background:
            radial-gradient(
              circle at 88% 17%,
              rgba(130, 187, 79, 0.19),
              transparent 22%
            ),
            linear-gradient(
              180deg,
              #f7faf4 0%,
              #ffffff 38%,
              #f7faf4 100%
            );
        }

        /* NAVBAR */

        .privacy-nav {
          height: 82px;
          background: rgba(243, 242, 242, 0.96);
          border-bottom: 1px solid #dfe5dd;
          box-shadow: 0 2px 12px rgba(0, 0, 0, 0.05);
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          z-index: 50;
          backdrop-filter: blur(12px);
        }

        .privacy-nav-inner {
          width: calc(100% - (var(--page-pad) * 2));
          height: 100%;
          margin: 0 auto;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 20px;
        }

        .privacy-logo {
          display: inline-flex;
          align-items: center;
          gap: 13px;
          cursor: pointer;
          border: 0;
          background: transparent;
          padding: 0;
          color: inherit;
        }

        .privacy-logo-mark {
          width: 58px;
          height: 58px;
          flex: 0 0 58px;
          border-radius: 50%;
          overflow: hidden;
          background: white;
          border: 1px solid #dfe5dd;
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06);
        }

        .privacy-logo-mark img {
          width: 100%;
          height: 100%;
          object-fit: cover;
          display: block;
        }

        .privacy-logo-copy {
          display: flex;
          flex-direction: column;
          text-align: left;
        }

        .privacy-logo-name {
          color: #397d21;
          font-size: 30px;
          line-height: 0.9;
          font-weight: 900;
        }

        .privacy-logo-tag {
          margin-top: 6px;
          color: #777d76;
          font-size: 10px;
          white-space: nowrap;
        }

        .home-button {
          height: 44px;
          border: 1px solid #cfd8cc;
          border-radius: 999px;
          padding: 0 20px;
          background: white;
          color: var(--green-900);
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 9px;
          font-weight: 700;
          cursor: pointer;
          transition:
            transform 0.2s ease,
            box-shadow 0.2s ease,
            border-color 0.2s ease;
        }

        .home-button:hover {
          transform: translateY(-1px);
          border-color: var(--green-700);
          box-shadow: 0 7px 18px rgba(30, 80, 25, 0.12);
        }

        .privacy-nav-actions {
          display: flex;
          align-items: center;
          gap: 10px;
        }

        .language-dropdown { position: relative; }

        .language-trigger {
          min-height: 42px;
          padding: 0 12px;
          border: 1px solid #d6e2d2;
          border-radius: 999px;
          color: var(--green-900);
          background: rgba(255, 255, 255, 0.9);
          display: inline-flex;
          align-items: center;
          gap: 8px;
          font: inherit;
          font-size: 13px;
          font-weight: 700;
          cursor: pointer;
          transition: border-color 180ms ease, box-shadow 180ms ease, background 180ms ease;
        }

        .language-trigger:hover,
        .language-dropdown.open .language-trigger {
          border-color: #9fc294;
          background: white;
          box-shadow: 0 8px 22px rgba(24, 73, 32, 0.1);
        }

        .language-trigger:focus-visible,
        .language-option:focus-visible {
          outline: 2px solid var(--green-600);
          outline-offset: 2px;
        }

        .language-menu {
          position: absolute;
          z-index: 50;
          top: calc(100% + 10px);
          right: 0;
          width: 190px;
          padding: 7px;
          border: 1px solid #dbe7d7;
          border-radius: 15px;
          background: rgba(255, 255, 255, 0.98);
          box-shadow: 0 18px 45px rgba(20, 62, 27, 0.16);
          animation: language-menu-in 160ms ease-out;
        }

        @keyframes language-menu-in {
          from { opacity: 0; transform: translateY(-6px) scale(0.98); }
          to { opacity: 1; transform: translateY(0) scale(1); }
        }

        .language-option {
          width: 100%;
          min-height: 42px;
          padding: 0 10px;
          border: 0;
          border-radius: 10px;
          color: #314a34;
          background: transparent;
          display: grid;
          grid-template-columns: 32px 1fr 16px;
          align-items: center;
          gap: 8px;
          text-align: left;
          font: inherit;
          font-size: 13px;
          font-weight: 700;
          cursor: pointer;
        }

        .language-option:hover,
        .language-option.selected { color: var(--green-900); background: #eef7e9; }
        .language-option svg { justify-self: end; }
        .language-code { color: #7b8e7d; font-size: 9px; letter-spacing: 0.08em; }

        /* HERO */

        .privacy-hero {
          position: relative;
          overflow: hidden;
          padding: 72px var(--page-pad) 120px;
          background:
            linear-gradient(
              90deg,
              rgba(255, 255, 255, 0.98) 0%,
              rgba(255, 255, 255, 0.91) 43%,
              rgba(245, 250, 240, 0.76) 100%
            ),
            linear-gradient(
              180deg,
              #fbfcfa 0%,
              #eef4e9 55%,
              #dcebd0 100%
            );
        }

        .privacy-hero::before {
          content: "";
          position: absolute;
          width: 520px;
          height: 520px;
          right: -110px;
          top: -190px;
          border-radius: 50%;
          background: rgba(86, 152, 48, 0.12);
        }

        .privacy-hero::after {
          content: "";
          position: absolute;
          width: 380px;
          height: 380px;
          right: 115px;
          bottom: -270px;
          border-radius: 50%;
          background: rgba(0, 85, 27, 0.08);
        }

        .privacy-hero-inner {
          max-width: 1160px;
          margin: 0 auto;
          position: relative;
          z-index: 2;
          display: grid;
          grid-template-columns: minmax(0, 1.25fr) minmax(280px, 0.75fr);
          gap: 70px;
          align-items: center;
        }

        .privacy-badge {
          width: max-content;
          display: inline-flex;
          align-items: center;
          gap: 9px;
          padding: 8px 14px;
          border-radius: 999px;
          background: #e9f5e4;
          border: 1px solid #d1e8c8;
          color: var(--green-800);
          font-size: 13px;
          font-weight: 800;
          margin-bottom: 22px;
        }

        .privacy-title {
          margin: 0;
          max-width: 700px;
          color: var(--green-950);
          font-size: clamp(42px, 5vw, 68px);
          line-height: 0.98;
          font-weight: 900;
          letter-spacing: -1.8px;
        }

        .privacy-title span {
          display: block;
          color: #377f20;
        }

        .privacy-description {
          max-width: 690px;
          margin: 24px 0 0;
          color: #425042;
          font-size: 16px;
          line-height: 1.75;
          font-weight: 500;
        }

        .effective-date {
          display: inline-flex;
          margin-top: 20px;
          padding: 8px 12px;
          border: 1px solid #d6e5d0;
          background: rgba(255, 255, 255, 0.8);
          color: #61705f;
          border-radius: 999px;
          font-size: 12px;
          font-weight: 700;
        }

        .hero-security-card {
          padding: 30px;
          border-radius: 24px;
          color: white;
          background: linear-gradient(145deg, #087027, #004c18);
          box-shadow: 0 24px 55px rgba(0, 78, 23, 0.24);
          position: relative;
          overflow: hidden;
        }

        .hero-security-card::after {
          content: "";
          position: absolute;
          width: 170px;
          height: 170px;
          right: -70px;
          bottom: -75px;
          border-radius: 50%;
          background: rgba(255, 255, 255, 0.09);
        }

        .hero-security-icon {
          width: 62px;
          height: 62px;
          border-radius: 18px;
          background: rgba(255, 255, 255, 0.15);
          display: grid;
          place-items: center;
          margin-bottom: 22px;
        }

        .hero-security-card h3 {
          margin: 0 0 10px;
          font-size: 21px;
          line-height: 1.2;
        }

        .hero-security-card p {
          margin: 0;
          color: rgba(255, 255, 255, 0.85);
          font-size: 14px;
          line-height: 1.7;
        }

        /* MAIN */

        .privacy-content {
          max-width: 1160px;
          margin: -62px auto 0;
          padding: 0 var(--page-pad) 75px;
          position: relative;
          z-index: 5;
        }

        .privacy-main-grid {
          display: grid;
          grid-template-columns: minmax(0, 1.45fr) minmax(280px, 0.55fr);
          gap: 28px;
          align-items: start;
        }

        .policy-column {
          display: flex;
          flex-direction: column;
          gap: 18px;
        }

        .policy-card,
        .side-card {
          background: rgba(255, 255, 255, 0.97);
          border: 1px solid #e1e7df;
          box-shadow: var(--shadow-soft);
        }

        .policy-card {
          border-radius: 18px;
          padding: 30px 32px;
          scroll-margin-top: 102px;
        }

        .policy-heading {
          display: flex;
          align-items: flex-start;
          gap: 15px;
          margin-bottom: 18px;
        }

        .policy-icon {
          width: 46px;
          height: 46px;
          flex: 0 0 46px;
          border-radius: 13px;
          display: grid;
          place-items: center;
          color: var(--green-800);
          background: var(--green-100);
        }

        .policy-card h2 {
          margin: 3px 0 0;
          color: var(--green-950);
          font-size: 21px;
          line-height: 1.3;
        }

        .policy-body {
          color: #526052;
          font-size: 14px;
          line-height: 1.75;
        }

        .policy-body p {
          margin: 0 0 14px;
        }

        .policy-body p:last-child {
          margin-bottom: 0;
        }

        .policy-body ul {
          margin: 0 0 14px;
          padding-left: 21px;
        }

        .policy-body li {
          margin-bottom: 8px;
        }

        .policy-body strong {
          color: #29482a;
        }

        .policy-body a {
          color: var(--green-800);
          font-weight: 700;
          text-decoration: none;
        }

        .policy-body a:hover {
          text-decoration: underline;
        }

        /* SIDE */

        .side-column {
          display: flex;
          flex-direction: column;
          gap: 18px;
          position: sticky;
          top: 98px;
          max-height: calc(100vh - 114px);
          overflow-y: auto;
          overscroll-behavior: contain;
          padding-right: 5px;
          scrollbar-width: thin;
          scrollbar-color: #b8cdb2 transparent;
        }

        .side-column::-webkit-scrollbar { width: 5px; }
        .side-column::-webkit-scrollbar-thumb {
          border-radius: 999px;
          background: #b8cdb2;
        }

        .quick-links-card { order: -1; }

        .side-card {
          border-radius: 18px;
          padding: 26px;
        }

        .side-title {
          display: flex;
          align-items: center;
          gap: 11px;
          color: var(--green-950);
          margin-bottom: 16px;
        }

        .side-title-icon {
          width: 38px;
          height: 38px;
          border-radius: 11px;
          display: grid;
          place-items: center;
          color: var(--green-700);
          background: var(--green-100);
        }

        .side-title h3 {
          margin: 0;
          font-size: 17px;
        }

        .summary-list {
          list-style: none;
          padding: 0;
          margin: 0;
          display: flex;
          flex-direction: column;
          gap: 11px;
        }

        .summary-list li {
          display: flex;
          align-items: flex-start;
          gap: 9px;
          color: #586458;
          font-size: 13px;
          line-height: 1.5;
        }

        .summary-check {
          width: 21px;
          height: 21px;
          flex: 0 0 21px;
          border-radius: 50%;
          margin-top: 1px;
          color: var(--green-700);
          background: #edf7e9;
          display: grid;
          place-items: center;
        }

        .quick-links {
          display: flex;
          flex-direction: column;
          gap: 4px;
        }

        .quick-links a {
          padding: 10px 11px;
          border-radius: 9px;
          color: #4f5d4f;
          font-size: 12px;
          font-weight: 700;
          text-decoration: none;
          transition:
            background 0.2s ease,
            color 0.2s ease;
        }

        .quick-links a:hover {
          background: #eef6ea;
          color: var(--green-800);
        }

        .deletion-card {
          background: linear-gradient(145deg, #f5faf2, #ffffff);
        }

        .deletion-card p {
          margin: 0 0 16px;
          color: #5e685e;
          font-size: 13px;
          line-height: 1.65;
        }

        .deletion-link {
          min-height: 42px;
          width: 100%;
          border-radius: 10px;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          padding: 0 14px;
          background: var(--green-800);
          color: white;
          text-decoration: none;
          font-size: 13px;
          font-weight: 800;
          box-shadow: var(--shadow-green);
        }

        /* SUPPORT */

        .support-card {
          margin-top: 28px;
          padding: 28px 32px;
          border-radius: 18px;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 30px;
          background: linear-gradient(135deg, #006123, #004b19);
          color: white;
          box-shadow: 0 16px 36px rgba(0, 73, 24, 0.18);
        }

        .support-copy {
          display: flex;
          align-items: center;
          gap: 17px;
        }

        .support-icon {
          width: 50px;
          height: 50px;
          flex: 0 0 50px;
          border-radius: 14px;
          background: rgba(255, 255, 255, 0.14);
          display: grid;
          place-items: center;
        }

        .support-card h3 {
          margin: 0 0 4px;
          font-size: 17px;
        }

        .support-card p {
          margin: 0;
          color: rgba(255, 255, 255, 0.78);
          font-size: 13px;
        }

        .support-link {
          flex: 0 0 auto;
          min-height: 43px;
          padding: 0 18px;
          border-radius: 999px;
          background: white;
          color: #00551b;
          font-size: 13px;
          font-weight: 800;
          text-decoration: none;
          display: inline-flex;
          align-items: center;
          gap: 7px;
        }

        /* FOOTER */

        .privacy-footer {
          padding: 28px var(--page-pad);
          border-top: 1px solid #e1e6df;
          background: #f4f6f2;
          text-align: center;
          color: #737c72;
          font-size: 12px;
          line-height: 1.6;
        }

        .privacy-footer strong {
          color: var(--green-800);
        }

        /* RESPONSIVE */

        @media (max-width: 950px) {
          .privacy-hero-inner,
          .privacy-main-grid {
            grid-template-columns: 1fr;
          }

          .privacy-hero {
            padding-bottom: 105px;
          }

          .hero-security-card {
            max-width: 520px;
          }

          .side-column {
            position: static;
            max-height: none;
            overflow: visible;
            padding-right: 0;
          }

          .quick-links-card {
            display: none;
          }
        }

        @media (max-width: 640px) {
          :root {
            --page-pad: 16px;
          }

          .privacy-nav {
            height: 74px;
          }

          .privacy-logo-mark {
            width: 48px;
            height: 48px;
            flex-basis: 48px;
          }

          .privacy-logo-name {
            font-size: 25px;
          }

          .privacy-logo-tag {
            display: none;
          }

          .home-button {
            width: 43px;
            height: 43px;
            min-width: 43px;
            padding: 0;
          }

          .home-button span {
            display: none;
          }

          .privacy-nav-actions {
            gap: 7px;
          }

          .language-trigger { padding: 0 10px; font-size: 12px; }
          .language-trigger > svg { display: none; }
          .language-menu { right: -42px; width: 180px; }

          .privacy-hero {
            padding-top: 48px;
            padding-bottom: 92px;
          }

          .privacy-title {
            font-size: 42px;
            letter-spacing: -1px;
          }

          .privacy-description {
            font-size: 14px;
          }

          .privacy-content {
            margin-top: -48px;
          }

          .policy-card {
            padding: 23px 18px;
            border-radius: 16px;
          }

          .policy-card h2 {
            font-size: 19px;
          }

          .side-card {
            padding: 22px 19px;
          }

          .support-card {
            padding: 24px 20px;
            flex-direction: column;
            align-items: flex-start;
          }

          .support-link {
            width: 100%;
            justify-content: center;
          }
        }
      `}</style>

      <style>{`
        .privacy-v2 { background: #f4f7f2; }
        .privacy-v2 .privacy-nav { background: rgba(249,251,248,.96); border-bottom-color: #dce6da; box-shadow: none; backdrop-filter: blur(18px); }
        .privacy-progress { position: absolute; left: 0; right: 0; bottom: -1px; height: 3px; overflow: hidden; }
        .privacy-progress span { display: block; height: 100%; background: linear-gradient(90deg,#74b94a,#0d6b2b); transition: width 100ms linear; }
        .privacy-v2 .privacy-hero { min-height: 520px; padding: clamp(72px,9vw,122px) 0 118px; color: white; background: radial-gradient(circle at 78% 28%,rgba(150,202,91,.28),transparent 26%),linear-gradient(135deg,#063f1a,#08702b); }
        .privacy-v2 .privacy-hero-inner { grid-template-columns: minmax(0,1.2fr) minmax(310px,.65fr); gap: clamp(50px,8vw,110px); }
        .privacy-v2 .privacy-badge { color: #d8efc1; border-color: rgba(255,255,255,.22); background: rgba(255,255,255,.1); }
        .privacy-v2 .privacy-title { max-width: 760px; color: white; font-size: clamp(46px,6.4vw,82px); line-height: .98; letter-spacing: -3px; }
        .privacy-v2 .privacy-title span { color: #b9dd91; }
        .privacy-v2 .privacy-description { color: rgba(255,255,255,.78); font-size: 17px; }
        .privacy-v2 .effective-date { color: white; border-color: rgba(255,255,255,.2); background: rgba(255,255,255,.1); }
        .privacy-v2 .hero-security-card { padding: 34px; border: 1px solid rgba(255,255,255,.2); background: rgba(255,255,255,.1); box-shadow: none; backdrop-filter: blur(14px); }
        .privacy-v2 .privacy-content { max-width: 1500px; margin: 0 auto; padding-top: clamp(65px,8vw,105px); }
        .privacy-v2 .privacy-main-grid { grid-template-columns: 260px minmax(0,1fr) 300px; gap: clamp(22px,3vw,44px); }
        .privacy-v2 .policy-column { gap: 22px; min-width: 0; }
        .privacy-v2 .policy-card { padding: clamp(25px,4vw,42px); border-color: #dbe5d8; border-radius: 20px; background: white; box-shadow: 0 8px 28px rgba(24,63,27,.055); }
        .privacy-v2 .policy-heading { padding-bottom: 20px; margin-bottom: 24px; border-bottom: 1px solid #e5ece3; align-items: center; }
        .privacy-v2 .policy-icon { width: 48px; height: 48px; flex-basis: 48px; border-radius: 14px; }
        .privacy-v2 .policy-heading h2 { font-size: clamp(19px,2vw,24px); }
        .privacy-v2 .policy-body { max-width: 760px; font-size: 15px; line-height: 1.85; }
        .privacy-v2 .policy-toc { align-self: stretch; position: relative; min-width: 0; }
        .privacy-v2 .policy-toc .quick-links-card { position: sticky; top: 102px; overflow: visible; }
        .privacy-v2 .side-column { position: sticky; top: 102px; align-self: start; max-height: none; overflow: visible; padding-right: 0; gap: 14px; }
        .privacy-v2 .side-card { padding: 22px; border-radius: 18px; box-shadow: 0 8px 25px rgba(24,63,27,.06); }
        .privacy-v2 .quick-links-card { overflow: visible; }
        .privacy-v2 .quick-links a { position: relative; padding: 10px 12px 10px 34px; line-height: 1.35; }
        .privacy-v2 .quick-links a::before { content: ''; position: absolute; left: 13px; top: 16px; width: 7px; height: 7px; border: 1px solid #9eb698; border-radius: 50%; }
        .privacy-v2 .quick-links a.active { color: #07551f; background: #edf6e9; }
        .privacy-v2 .quick-links a.active::before { border-color: #2f7d1f; background: #2f7d1f; box-shadow: 0 0 0 4px #deedd8; }
        .privacy-v2 .support-card { margin-top: 42px; padding: 34px 38px; border-radius: 20px; }
        .privacy-v2 .privacy-footer { background: #eef2ec; }
        @media (max-width: 1180px) {
          .privacy-v2 .privacy-main-grid { grid-template-columns: 245px minmax(0,1fr); }
          .privacy-v2 .policy-toc { grid-column: 1; grid-row: 1; }
          .privacy-v2 .policy-column { grid-column: 2; grid-row: 1; }
          .privacy-v2 .side-column { position: static; grid-column: 1 / -1; grid-row: 2; display: grid; grid-template-columns: 1fr 1fr; }
        }
        @media (max-width: 760px) {
          .privacy-v2 .privacy-hero { min-height: auto; padding-bottom: 80px; }
          .privacy-v2 .privacy-main-grid { grid-template-columns: 1fr; }
          .privacy-v2 .policy-toc { grid-column: 1; grid-row: 1; }
          .privacy-v2 .policy-toc .quick-links-card { display: block; position: static; max-height: none; overflow: visible; }
          .privacy-v2 .policy-column { grid-column: 1; grid-row: 2; }
          .privacy-v2 .side-column { grid-column: 1; grid-row: 3; display: grid; grid-template-columns: 1fr; }
          .privacy-v2 .quick-links { display: grid; grid-template-columns: 1fr 1fr; }
        }
        @media (max-width: 640px) {
          .privacy-v2 { padding-top: 74px; }
          .privacy-v2 .privacy-title { font-size: 43px; letter-spacing: -1.8px; }
          .privacy-v2 .privacy-hero { padding-top: 55px; }
          .privacy-v2 .privacy-content { padding-top: 34px; }
          .privacy-v2 .quick-links { grid-template-columns: 1fr; max-height: 260px; overflow-y: auto; }
          .privacy-v2 .policy-card { padding: 24px 19px; }
        }
      `}</style>

      <main className="privacy-page privacy-v2">
        <nav className="privacy-nav">
          <div className="privacy-nav-inner">
            <button
              type="button"
              className="privacy-logo"
              onClick={() => navigate("/")}
              aria-label={t.homeAria}
            >
              <div className="privacy-logo-mark">
                <img src={LOGO_SRC} alt="AGRHI logo" />
              </div>

              <div className="privacy-logo-copy">
                <span className="privacy-logo-name">Farmlead</span>
                <span className="privacy-logo-tag">{t.logoTag}</span>
              </div>
            </button>

            <div className="privacy-nav-actions">
              <LanguageDropdown
                language={language}
                label={t.language}
                onChange={handleLanguageChange}
              />

              <button
                type="button"
                className="home-button"
                onClick={() => navigate("/")}
              >
                <Icon name="home" size={18} />
                <span>{t.backHome}</span>
              </button>
            </div>
          </div>
          <div className="privacy-progress" aria-hidden="true"><span style={{ width: `${readingProgress}%` }} /></div>
        </nav>

        <section className="privacy-hero">
          <div className="privacy-hero-inner">
            <div>
              <div className="privacy-badge">
                <Icon name="leaf" size={16} />
                {t.badge}
              </div>

              <h1 className="privacy-title">
                {t.title[0]}
                <span>{t.title[1]}</span>
              </h1>

              <p className="privacy-description">{t.description}</p>

              <div className="effective-date">{t.effectiveDate}</div>
            </div>

            <div className="hero-security-card">
              <div className="hero-security-icon">
                <Icon name="shield" size={31} />
              </div>

              <h3>{t.transparencyTitle}</h3>

              <p>{t.transparencyText}</p>
            </div>
          </div>
        </section>

        <section className="privacy-content">
          <div className="privacy-main-grid">
            <aside className="policy-toc" aria-label={t.policySections}>
              <div className="side-card quick-links-card">
                <div className="side-title">
                  <div className="side-title-icon"><Icon name="database" size={20} /></div>
                  <h3>{t.policySections}</h3>
                </div>
                <div className="quick-links">
                  {policySections.map((section, index) => (
                    <a className={activePolicy === section.id ? "active" : ""} aria-current={activePolicy === section.id ? "location" : undefined} key={section.id} href={`#${section.id}`}>
                      {t.sectionTitles[index]}
                    </a>
                  ))}
                </div>
              </div>
            </aside>

            <div className="policy-column">
              {policySections.map((section, index) => (
                <AnimatedContent key={section.id} delay={Math.min(index, 3) * 0.035}>
                <article className="policy-card" id={section.id}>
                  <div className="policy-heading">
                    <div className="policy-icon">
                      <Icon name={section.icon} size={23} />
                    </div>

                    <h2>{t.sectionTitles[index]}</h2>
                  </div>

                  <div className="policy-body">
                    {language === "en" ? (
                      section.content
                    ) : (
                      <LocalizedPolicyContent
                        content={POLICY_CONTENT_TRANSLATIONS[language][index]}
                        language={language}
                      />
                    )}
                  </div>
                </article>
                </AnimatedContent>
              ))}
            </div>

            <aside className="side-column">
              <div className="side-card">
                <div className="side-title">
                  <div className="side-title-icon">
                    <Icon name="shield" size={20} />
                  </div>
                  <h3>{t.glance}</h3>
                </div>

                <ul className="summary-list">
                  {t.summary.map((item) => (
                    <li key={item}>
                      <span className="summary-check">
                        <Icon name="check" size={12} />
                      </span>
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              </div>

              <div className="side-card deletion-card">
                <div className="side-title">
                  <div className="side-title-icon">
                    <Icon name="trash" size={20} />
                  </div>
                  <h3>{t.deleteTitle}</h3>
                </div>

                <p>{t.deleteText}</p>

                <a className="deletion-link" href="/delete-account">
                  {t.deleteLink}
                  <Icon name="arrow" size={15} />
                </a>
              </div>
            </aside>
          </div>

          <div className="support-card">
            <div className="support-copy">
              <div className="support-icon">
                <Icon name="mail" size={23} />
              </div>

              <div>
                <h3>{t.supportTitle}</h3>
                <p>{t.supportText}</p>
              </div>
            </div>

            <a className="support-link" href="mailto:support@farmlead.in">
              support@farmlead.in
              <Icon name="arrow" size={15} />
            </a>
          </div>
        </section>

        <footer className="privacy-footer">
          <strong>AGRHI by Farmlead</strong>
          <br />
          {t.footer}
        </footer>
      </main>
    </>
  );
}

function LanguageDropdown({ language, label, onChange }) {
  const [open, setOpen] = useState(false);
  const rootRef = useRef(null);
  const optionRefs = useRef([]);
  const selected = LANGUAGES.find((item) => item.code === language) ?? LANGUAGES[0];

  useEffect(() => {
    if (!open) return undefined;

    const handlePointerDown = (event) => {
      if (!rootRef.current?.contains(event.target)) setOpen(false);
    };
    const handleKeyDown = (event) => {
      if (event.key === "Escape") {
        setOpen(false);
        rootRef.current?.querySelector("button")?.focus();
      }
    };

    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("pointerdown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [open]);

  const moveFocus = (direction) => {
    const current = optionRefs.current.indexOf(document.activeElement);
    const next = (current + direction + LANGUAGES.length) % LANGUAGES.length;
    optionRefs.current[next]?.focus();
  };

  return (
    <div className={`language-dropdown ${open ? "open" : ""}`} ref={rootRef}>
      <button
        type="button"
        className="language-trigger"
        aria-label={label}
        aria-haspopup="listbox"
        aria-expanded={open}
        onClick={() => setOpen((value) => !value)}
        onKeyDown={(event) => {
          if (["ArrowDown", "ArrowUp"].includes(event.key)) {
            event.preventDefault();
            setOpen(true);
            requestAnimationFrame(() => optionRefs.current[language === "en" ? 0 : LANGUAGES.findIndex((item) => item.code === language)]?.focus());
          }
        }}
      >
        <Icon name="globe" size={17} />
        <span>{selected.label}</span>
      </button>

      {open && (
        <div className="language-menu" role="listbox" aria-label={label}>
          {LANGUAGES.map((item, index) => (
            <button
              type="button"
              role="option"
              aria-selected={item.code === language}
              className={`language-option ${item.code === language ? "selected" : ""}`}
              key={item.code}
              ref={(node) => { optionRefs.current[index] = node; }}
              onKeyDown={(event) => {
                if (event.key === "ArrowDown" || event.key === "ArrowUp") {
                  event.preventDefault();
                  moveFocus(event.key === "ArrowDown" ? 1 : -1);
                }
              }}
              onClick={() => {
                onChange(item.code);
                setOpen(false);
              }}
            >
              <span className="language-code">{item.code.toUpperCase()}</span>
              <span>{item.label}</span>
              {item.code === language && <Icon name="check" size={15} />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
