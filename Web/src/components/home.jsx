import React, {
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { useNavigate } from "react-router-dom";

const PHONE_SCREENSHOTS = [
  "1.png",
  "2.png",
  "3.png",
  "4.png",
  "5.png",
  "6.jpg",
  "7.jpg",
  "8.png",
];

const APP_DOWNLOAD_URL = "https://play.google.com/apps/testing/app.agrhi.com";

const USER_MANUAL_URL = "/user_manual.pptx";
const LOGO_SRC = "/logo.png";
const LANGUAGE_STORAGE_KEY = "agrhi-website-language";

const LANGUAGES = [
  { code: "en", label: "English" },
  { code: "ta", label: "தமிழ்" },
  { code: "hi", label: "हिन्दी" },
  { code: "te", label: "తెలుగు" },
];

const FEATURE_ICONS = ["leaf", "tractor", "cloud", "store", "book", "wifi"];

const STAT_ICONS = ["brain", "globe", "wifi", "shield"];

const TRANSLATIONS = {
  en: {
    logoTag: "Leading the Future of Agriculture.",

    nav: {
      home: "Home",
      about: "About",
      features: "Features",
      contact: "Contact",
    },

    language: "Language",
    adminPortal: "Admin Portal",
    toggleNavigation: "Toggle navigation",

    hero: {
      eyebrow: "Smart agriculture for real farm decisions",
      title: "Your Smart Farm Assistant",
      description:
        "Bring crop care, AI disease detection, local weather, farm management and agricultural marketplace tools together in one multilingual, offline-first mobile experience.",
      highlights: [
        "AI-powered Plant Doctor",
        "7 languages in the mobile app",
        "Offline-first",
        "Farmer-focused",
      ],
      app: "Get AGRHI App",
      appNote: "Android application",
      manual: "User Manual",
      manualNote: "View documentation",
      explore: "Explore Features",
      exploreNote: "See what AGRHI offers",
    },

    about: {
      kicker: "About AGRHI",
      title: "Agriculture, technology and accessibility in one platform",
      description:
        "AGRHI helps farmers and agricultural stakeholders make faster, data-informed decisions. It combines practical farm tools, AI-assisted crop disease detection, local weather, multilingual support and an integrated marketplace for low-connectivity rural use.",
      points: [
        [
          "Built around farm workflows",
          "Crop care, farms, irrigation and plant-health tools are organized around practical agricultural use.",
        ],
        [
          "Designed for accessibility",
          "Multilingual support and offline-first behavior keep AGRHI useful across regions and connectivity levels.",
        ],
        [
          "Responsible data handling",
          "AGRHI provides privacy controls, secure authentication and clear account-deletion options.",
        ],
      ],
    },

    featureSection: {
      kicker: "Core Capabilities",
      title: "Everything farmers need, in one app",
      description:
        "AGRHI connects everyday farm management with intelligent assistance so users can move from information to action quickly.",
    },

    features: [
      [
        "AI Disease Detection",
        "Identify crop diseases from plant images with AGRHI's AI-powered Plant Doctor.",
      ],
      [
        "Crop & Farm Management",
        "Organize farms, crops, irrigation, soil and water information in one place.",
      ],
      [
        "Weather Intelligence",
        "Use local weather conditions and forecasts to support better farm decisions.",
      ],
      [
        "Agricultural Marketplace",
        "Connect farmers, retailers and consumers through nearby product listings.",
      ],
      [
        "7-Language Mobile App",
        "Use AGRHI in English, Hindi, Tamil, Telugu, Turkish, Malay or Greek.",
      ],
      [
        "Offline-First Experience",
        "Keep working in low-connectivity areas and synchronize important data later.",
      ],
    ],

    stats: [
      ["10+", "Crop AI Models"],
      ["7", "Mobile App Languages"],
      ["Offline", "First Architecture"],
      ["Secure", "Privacy Focused"],
    ],

    contact: {
      kicker: "Contact & Support",
      title: "Need help with AGRHI?",
      heading: "We're here to help",
      description:
        "For app support, privacy questions, account requests or general enquiries, contact the AGRHI support team.",
      location: "Chennai, Tamil Nadu, India",
    },

    footer: {
      brand: "AGRHI by Farmlead",
      privacy: "Privacy Policy",
      deleteAccount: "Delete Account",
      support: "Support",
      adminLogin: "Admin Login",
      programme: "Erasmus+ AGRHI Programme",
    },

    preview: {
      label: "AGRHI mobile app preview",
      screenshot: "AGRHI app screenshot",
      assistant: "Smart Farm Assistant",
      weather: "Today's weather",
      condition: "Partly cloudy · Chennai",
      tools: "Smart tools",
      cards: [
        ["Plant Doctor", "Disease Detection"],
        ["Crop Care", "Farm Manager"],
        ["Marketplace", "Buy & Sell"],
        ["Weather", "Forecast"],
      ],
      offline: "Offline-first for low connectivity areas",
    },
  },

  ta: {
    logoTag: "வேளாண்மையின் எதிர்காலத்தை வழிநடத்துகிறோம்.",

    nav: {
      home: "முகப்பு",
      about: "AGRHI பற்றி",
      features: "அம்சங்கள்",
      contact: "தொடர்பு",
    },

    language: "மொழி",
    adminPortal: "நிர்வாக தளம்",
    toggleNavigation: "வழிசெலுத்தலை மாற்று",

    hero: {
      eyebrow: "சிறந்த பண்ணை முடிவுகளுக்கான ஸ்மாரார்ட் வேளாண்மை",
      title: "உங்கள் ஸ்மார்ட் பண்ணை உதவியாளர்",
      description:
        "பயிர் பராமரிப்பு, AI நோய் கண்டறிதல், உள்ளூர் வானிலை, பண்ணை மேலாண்மை மற்றும் வேளாண் சந்தை வசதிகளை பலமொழி, இணையமின்றியும் செயல்படும் ஒரே மொபைல் அனுபவத்தில் பெறுங்கள்.",
      highlights: [
        "AI தாவர மருத்துவர்",
        "மொபைல் செயலியில் 7 மொழிகள்",
        "இணையமின்றியும் செயல்படும்",
        "விவசாயி மையப்படுத்தப்பட்டது",
      ],
      app: "AGRHI செயலியைப் பெறுங்கள்",
      appNote: "Android செயலி",
      manual: "பயனர் கையேடு",
      manualNote: "ஆவணத்தைப் பார்க்கவும்",
      explore: "அம்சங்களை ஆராயுங்கள்",
      exploreNote: "AGRHI வழங்குவதைப் பாருங்கள்",
    },

    about: {
      kicker: "AGRHI பற்றி",
      title: "வேளாண்மை, தொழில்நுட்பம் மற்றும் அணுகல்தன்மை ஒரே தளத்தில்",
      description:
        "விவசாயிகள் மற்றும் வேளாண் பங்குதாரர்கள் விரைவான, தரவு சார்ந்த முடிவுகளை எடுக்க AGRHI உதவுகிறது. பண்ணைக் கருவிகள், AI பயிர் நோய் கண்டறிதல், உள்ளூர் வானிலை, பலமொழி ஆதரவு மற்றும் ஒருங்கிணைந்த சந்தை ஆகியவற்றை குறைந்த இணைய இணைப்புள்ள கிராமப்புற பயன்பாட்டிற்காக இணைக்கிறது.",
      points: [
        [
          "பண்ணைப் பணிகளுக்கேற்ப உருவாக்கப்பட்டது",
          "பயிர் பராமரிப்பு, பண்ணை, நீர்ப்பாசனம் மற்றும் தாவர ஆரோக்கியக் கருவிகள் நடைமுறை வேளாண் பயன்பாட்டிற்கேற்ப அமைக்கப்பட்டுள்ளன.",
        ],
        [
          "அனைவரும் அணுகும் வகையில் வடிவமைப்பு",
          "பலமொழி ஆதரவும் இணையமின்றி செயல்படும் வசதியும் பல்வேறு பகுதிகளில் AGRHI-ஐ பயனுள்ளதாக வைத்திருக்கின்றன.",
        ],
        [
          "பொறுப்பான தரவு கையாளுதல்",
          "AGRHI தனியுரிமைக் கட்டுப்பாடுகள், பாதுகாப்பான உள்நுழைவு மற்றும் தெளிவான கணக்கு நீக்க வசதிகளை வழங்குகிறது.",
        ],
      ],
    },

    featureSection: {
      kicker: "முக்கிய திறன்கள்",
      title: "விவசாயிகளுக்குத் தேவையான அனைத்தும் ஒரே செயலியில்",
      description:
        "தினசரி பண்ணை மேலாண்மையையும் அறிவார்ந்த உதவியையும் இணைத்து தகவலிலிருந்து செயலுக்கு விரைவாக செல்ல AGRHI உதவுகிறது.",
    },

    features: [
      [
        "AI நோய் கண்டறிதல்",
        "தாவரப் படங்களிலிருந்து AGRHI-யின் AI தாவர மருத்துவர் மூலம் பயிர் நோய்களைக் கண்டறியுங்கள்.",
      ],
      [
        "பயிர் மற்றும் பண்ணை மேலாண்மை",
        "பண்ணைகள், பயிர்கள், நீர்ப்பாசனம், மண் மற்றும் நீர் தகவல்களை ஒரே இடத்தில் நிர்வகியுங்கள்.",
      ],
      [
        "வானிலை நுண்ணறிவு",
        "சிறந்த பண்ணை முடிவுகளுக்கு உள்ளூர் வானிலை மற்றும் முன்னறிவிப்புகளைப் பயன்படுத்துங்கள்.",
      ],
      [
        "வேளாண் சந்தை",
        "அருகிலுள்ள பொருள் பட்டியல்கள் மூலம் விவசாயிகள், விற்பனையாளர்கள் மற்றும் நுகர்வோரை இணைக்கிறது.",
      ],
      [
        "செயலியில் 7 மொழிகள்",
        "ஆங்கிலம், இந்தி, தமிழ், தெலுங்கு, துருக்கியம், மலாய் அல்லது கிரேக்கம் ஆகிய மொழிகளில் AGRHI-ஐப் பயன்படுத்துங்கள்.",
      ],
      [
        "இணையமின்றியும் செயல்படும் அனுபவம்",
        "குறைந்த இணைய இணைப்பிலும் தொடர்ந்து பணியாற்றி, முக்கிய தரவை பின்னர் ஒத்திசையுங்கள்.",
      ],
    ],

    stats: [
      ["10+", "பயிர் AI மாதிரிகள்"],
      ["7", "மொபைல் செயலி மொழிகள்"],
      ["இணையமின்றி", "முதன்மை கட்டமைப்பு"],
      ["பாதுகாப்பானது", "தனியுரிமை மையம்"],
    ],

    contact: {
      kicker: "தொடர்பு மற்றும் உதவி",
      title: "AGRHI உதவி தேவையா?",
      heading: "உங்களுக்கு உதவ நாங்கள் இருக்கிறோம்",
      description:
        "செயலி உதவி, தனியுரிமைக் கேள்விகள், கணக்கு கோரிக்கைகள் அல்லது பொதுவான விசாரணைகளுக்கு AGRHI உதவிக் குழுவைத் தொடர்புகொள்ளுங்கள்.",
      location: "சென்னை, தமிழ்நாடு, இந்தியா",
    },

    footer: {
      brand: "Farmlead வழங்கும் AGRHI",
      privacy: "தனியுரிமைக் கொள்கை",
      deleteAccount: "கணக்கை நீக்கு",
      support: "உதவி",
      adminLogin: "நிர்வாக உள்நுழைவு",
      programme: "Erasmus+ AGRHI திட்டம்",
    },

    preview: {
      label: "AGRHI மொபைல் செயலி முன்னோட்டம்",
      screenshot: "AGRHI செயலி திரைப்பிடிப்பு",
      assistant: "ஸ்மார்ட் பண்ணை உதவியாளர்",
      weather: "இன்றைய வானிலை",
      condition: "ஓரளவு மேகமூட்டம் · சென்னை",
      tools: "ஸ்மார்ட் கருவிகள்",
      cards: [
        ["தாவர மருத்துவர்", "நோய் கண்டறிதல்"],
        ["பயிர் பராமரிப்பு", "பண்ணை மேலாளர்"],
        ["சந்தை", "வாங்கவும் விற்கவும்"],
        ["வானிலை", "முன்னறிவிப்பு"],
      ],
      offline: "குறைந்த இணைய இணைப்புள்ள பகுதிகளிலும் செயல்படும்",
    },
  },

  hi: {
    logoTag: "कृषि के भविष्य का नेतृत्व।",

    nav: {
      home: "होम",
      about: "AGRHI के बारे में",
      features: "विशेषताएँ",
      contact: "संपर्क",
    },

    language: "भाषा",
    adminPortal: "एडमिन पोर्टल",
    toggleNavigation: "नेविगेशन खोलें या बंद करें",

    hero: {
      eyebrow: "बेहतर कृषि निर्णयों के लिए स्मार्ट खेती",
      title: "आपका स्मार्ट कृषि सहायक",
      description:
        "फसल देखभाल, AI रोग पहचान, स्थानीय मौसम, कृषि प्रबंधन और कृषि बाज़ार को एक बहुभाषी, ऑफलाइन-फर्स्ट मोबाइल अनुभव में पाएँ।",
      highlights: [
        "AI प्लांट डॉक्टर",
        "मोबाइल ऐप में 7 भाषाएँ",
        "ऑफलाइन-फर्स्ट",
        "किसान-केंद्रित",
      ],
      app: "AGRHI ऐप प्राप्त करें",
      appNote: "Android ऐप",
      manual: "उपयोगकर्ता पुस्तिका",
      manualNote: "दस्तावेज़ देखें",
      explore: "विशेषताएँ देखें",
      exploreNote: "जानें AGRHI क्या प्रदान करता है",
    },

    about: {
      kicker: "AGRHI के बारे में",
      title: "कृषि, तकनीक और सुगम्यता—एक ही मंच पर",
      description:
        "AGRHI किसानों और कृषि हितधारकों को तेज़, डेटा-आधारित निर्णय लेने में मदद करता है। यह कम इंटरनेट वाले ग्रामीण क्षेत्रों के लिए कृषि उपकरण, AI फसल रोग पहचान, स्थानीय मौसम, बहुभाषी सहायता और एकीकृत बाज़ार को जोड़ता है।",
      points: [
        [
          "कृषि कार्यप्रवाह के अनुरूप",
          "फसल देखभाल, खेत, सिंचाई और पौध-स्वास्थ्य उपकरण व्यावहारिक कृषि उपयोग के अनुसार व्यवस्थित हैं।",
        ],
        [
          "सुगम उपयोग के लिए डिज़ाइन",
          "बहुभाषी सहायता और ऑफलाइन-फर्स्ट व्यवहार AGRHI को अलग-अलग क्षेत्रों में उपयोगी बनाए रखते हैं।",
        ],
        [
          "ज़िम्मेदार डेटा प्रबंधन",
          "AGRHI गोपनीयता नियंत्रण, सुरक्षित प्रमाणीकरण और स्पष्ट खाता हटाने के विकल्प देता है।",
        ],
      ],
    },

    featureSection: {
      kicker: "मुख्य क्षमताएँ",
      title: "किसानों की हर ज़रूरत, एक ही ऐप में",
      description:
        "AGRHI रोज़मर्रा के कृषि प्रबंधन को बुद्धिमान सहायता से जोड़ता है, ताकि उपयोगकर्ता जानकारी से कार्रवाई तक तेज़ी से पहुँच सकें।",
    },

    features: [
      [
        "AI रोग पहचान",
        "AGRHI के AI प्लांट डॉक्टर से पौधों की तस्वीरों द्वारा फसल रोग पहचानें।",
      ],
      [
        "फसल और कृषि प्रबंधन",
        "खेत, फसल, सिंचाई, मिट्टी और पानी की जानकारी एक ही स्थान पर व्यवस्थित करें।",
      ],
      [
        "मौसम जानकारी",
        "बेहतर कृषि निर्णयों के लिए स्थानीय मौसम और पूर्वानुमान का उपयोग करें।",
      ],
      [
        "कृषि बाज़ार",
        "आस-पास की उत्पाद सूचियों से किसानों, विक्रेताओं और उपभोक्ताओं को जोड़ें।",
      ],
      [
        "ऐप में 7 भाषाओं का समर्थन",
        "AGRHI का उपयोग अंग्रेज़ी, हिंदी, तमिल, तेलुगु, तुर्की, मलय या यूनानी भाषा में करें।",
      ],
      [
        "ऑफलाइन-फर्स्ट अनुभव",
        "कम इंटरनेट वाले क्षेत्रों में काम जारी रखें और महत्वपूर्ण डेटा बाद में सिंक करें।",
      ],
    ],

    stats: [
      ["10+", "फसल AI मॉडल"],
      ["7", "मोबाइल ऐप भाषाएँ"],
      ["ऑफलाइन", "फर्स्ट आर्किटेक्चर"],
      ["सुरक्षित", "गोपनीयता केंद्रित"],
    ],

    contact: {
      kicker: "संपर्क और सहायता",
      title: "AGRHI में सहायता चाहिए?",
      heading: "हम आपकी सहायता के लिए हैं",
      description:
        "ऐप सहायता, गोपनीयता प्रश्न, खाता अनुरोध या सामान्य पूछताछ के लिए AGRHI सहायता टीम से संपर्क करें।",
      location: "चेन्नई, तमिलनाडु, भारत",
    },

    footer: {
      brand: "Farmlead द्वारा AGRHI",
      privacy: "गोपनीयता नीति",
      deleteAccount: "खाता हटाएँ",
      support: "सहायता",
      adminLogin: "एडमिन लॉगिन",
      programme: "Erasmus+ AGRHI कार्यक्रम",
    },

    preview: {
      label: "AGRHI मोबाइल ऐप पूर्वावलोकन",
      screenshot: "AGRHI ऐप स्क्रीनशॉट",
      assistant: "स्मार्ट कृषि सहायक",
      weather: "आज का मौसम",
      condition: "आंशिक बादल · चेन्नई",
      tools: "स्मार्ट उपकरण",
      cards: [
        ["प्लांट डॉक्टर", "रोग पहचान"],
        ["फसल देखभाल", "कृषि प्रबंधक"],
        ["बाज़ार", "खरीदें और बेचें"],
        ["मौसम", "पूर्वानुमान"],
      ],
      offline: "कम इंटरनेट वाले क्षेत्रों के लिए ऑफलाइन-फर्स्ट",
    },
  },

  te: {
    logoTag: "వ్యవసాయ భవిష్యత్తుకు నాయకత్వం.",

    nav: {
      home: "హోమ్",
      about: "AGRHI గురించి",
      features: "ఫీచర్లు",
      contact: "సంప్రదించండి",
    },

    language: "భాష",
    adminPortal: "అడ్మిన్ పోర్టల్",
    toggleNavigation: "నావిగేషన్‌ను మార్చండి",

    hero: {
      eyebrow: "మెరుగైన వ్యవసాయ నిర్ణయాల కోసం స్మార్ట్ వ్యవసాయం",
      title: "మీ స్మార్ట్ వ్యవసాయ సహాయకుడు",
      description:
        "పంట సంరక్షణ, AI వ్యాధి గుర్తింపు, స్థానిక వాతావరణం, వ్యవసాయ నిర్వహణ మరియు వ్యవసాయ మార్కెట్ సాధనాలను బహుభాషా, ఆఫ్‌లైన్-ఫస్ట్ మొబైల్ అనుభవంలో పొందండి.",
      highlights: [
        "AI ప్లాంట్ డాక్టర్",
        "మొబైల్ యాప్‌లో 7 భాషలు",
        "ఆఫ్‌లైన్-ఫస్ట్",
        "రైతు కేంద్రితం",
      ],
      app: "AGRHI యాప్ పొందండి",
      appNote: "Android యాప్",
      manual: "వినియోగదారు మార్గదర్శిని",
      manualNote: "డాక్యుమెంట్ చూడండి",
      explore: "ఫీచర్లను చూడండి",
      exploreNote: "AGRHI అందించే సేవలను చూడండి",
    },

    about: {
      kicker: "AGRHI గురించి",
      title: "వ్యవసాయం, సాంకేతికత మరియు సులభ ప్రాప్యత—ఒకే వేదికలో",
      description:
        "రైతులు మరియు వ్యవసాయ భాగస్వాములు వేగంగా, డేటా ఆధారిత నిర్ణయాలు తీసుకోవడానికి AGRHI సహాయపడుతుంది. తక్కువ ఇంటర్నెట్ ఉన్న గ్రామీణ ప్రాంతాల కోసం వ్యవసాయ సాధనాలు, AI పంట వ్యాధి గుర్తింపు, స్థానిక వాతావరణం, బహుభాషా మద్దతు మరియు సమగ్ర మార్కెట్‌ను కలుపుతుంది.",
      points: [
        [
          "వ్యవసాయ పనులకు అనుగుణంగా రూపొందించబడింది",
          "పంట సంరక్షణ, పొలాలు, నీటిపారుదల మరియు మొక్కల ఆరోగ్య సాధనాలు ఆచరణాత్మక వ్యవసాయ వినియోగానికి అనుగుణంగా ఏర్పాటు చేయబడ్డాయి.",
        ],
        [
          "సులభ ప్రాప్యత కోసం రూపకల్పన",
          "బహుభాషా మద్దతు మరియు ఆఫ్‌లైన్-ఫస్ట్ విధానం వివిధ ప్రాంతాల్లో AGRHIని ఉపయోగకరంగా ఉంచుతాయి.",
        ],
        [
          "బాధ్యతాయుతమైన డేటా నిర్వహణ",
          "AGRHI గోప్యత నియంత్రణలు, సురక్షిత ప్రమాణీకరణ మరియు స్పష్టమైన ఖాతా తొలగింపు ఎంపికలను అందిస్తుంది.",
        ],
      ],
    },

    featureSection: {
      kicker: "ప్రధాన సామర్థ్యాలు",
      title: "రైతులకు కావాల్సినవన్నీ ఒకే యాప్‌లో",
      description:
        "రోజువారీ వ్యవసాయ నిర్వహణను తెలివైన సహాయంతో అనుసంధానించి, సమాచారం నుంచి చర్యకు వేగంగా వెళ్లేందుకు AGRHI సహాయపడుతుంది.",
    },

    features: [
      [
        "AI వ్యాధి గుర్తింపు",
        "AGRHI AI ప్లాంట్ డాక్టర్‌తో మొక్కల చిత్రాల ద్వారా పంట వ్యాధులను గుర్తించండి.",
      ],
      [
        "పంట మరియు వ్యవసాయ నిర్వహణ",
        "పొలాలు, పంటలు, నీటిపారుదల, నేల మరియు నీటి సమాచారాన్ని ఒకే చోట నిర్వహించండి.",
      ],
      [
        "వాతావరణ సమాచారం",
        "మెరుగైన వ్యవసాయ నిర్ణయాలకు స్థానిక వాతావరణం మరియు సూచనలను ఉపయోగించండి.",
      ],
      [
        "వ్యవసాయ మార్కెట్",
        "సమీపంలోని ఉత్పత్తి జాబితాల ద్వారా రైతులు, విక్రేతలు మరియు వినియోగదారులను అనుసంధానించండి.",
      ],
      [
        "యాప్‌లో 7 భాషల మద్దతు",
        "AGRHIని ఇంగ్లీష్, హిందీ, తమిళం, తెలుగు, టర్కిష్, మలయ్ లేదా గ్రీక్ భాషల్లో ఉపయోగించండి.",
      ],
      [
        "ఆఫ్‌లైన్-ఫస్ట్ అనుభవం",
        "తక్కువ ఇంటర్నెట్ ఉన్న ప్రాంతాల్లో పని కొనసాగించి, ముఖ్యమైన డేటాను తరువాత సమకాలీకరించండి.",
      ],
    ],

    stats: [
      ["10+", "పంట AI మోడళ్లు"],
      ["7", "మొబైల్ యాప్ భాషలు"],
      ["ఆఫ్‌లైన్", "ఫస్ట్ ఆర్కిటెక్చర్"],
      ["సురక్షితం", "గోప్యత కేంద్రితం"],
    ],

    contact: {
      kicker: "సంప్రదింపు మరియు సహాయం",
      title: "AGRHI సహాయం కావాలా?",
      heading: "మీకు సహాయం చేయడానికి మేమున్నాం",
      description:
        "యాప్ సహాయం, గోప్యత ప్రశ్నలు, ఖాతా అభ్యర్థనలు లేదా సాధారణ విచారణల కోసం AGRHI సహాయ బృందాన్ని సంప్రదించండి.",
      location: "చెన్నై, తమిళనాడు, భారతదేశం",
    },

    footer: {
      brand: "Farmlead అందించే AGRHI",
      privacy: "గోప్యతా విధానం",
      deleteAccount: "ఖాతాను తొలగించండి",
      support: "సహాయం",
      adminLogin: "అడ్మిన్ లాగిన్",
      programme: "Erasmus+ AGRHI కార్యక్రమం",
    },

    preview: {
      label: "AGRHI మొబైల్ యాప్ ప్రివ్యూ",
      screenshot: "AGRHI యాప్ స్క్రీన్‌షాట్",
      assistant: "స్మార్ట్ వ్యవసాయ సహాయకుడు",
      weather: "నేటి వాతావరణం",
      condition: "పాక్షిక మేఘావృతం · చెన్నై",
      tools: "స్మార్ట్ సాధనాలు",
      cards: [
        ["ప్లాంట్ డాక్టర్", "వ్యాధి గుర్తింపు"],
        ["పంట సంరక్షణ", "వ్యవసాయ నిర్వాహకుడు"],
        ["మార్కెట్", "కొనండి మరియు అమ్మండి"],
        ["వాతావరణం", "సూచన"],
      ],
      offline: "తక్కువ ఇంటర్నెట్ ప్రాంతాల కోసం ఆఫ్‌లైన్-ఫస్ట్",
    },
  },
};
function Icon({ name, size = 28 }) {
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
    user: (
      <>
        <path d="M20 21a8 8 0 0 0-16 0" />
        <circle cx="12" cy="7" r="4" />
      </>
    ),
    android: (
      <>
        <path d="M5 8h14v9a3 3 0 0 1-3 3H8a3 3 0 0 1-3-3V8Z" />
        <path d="M8 8 6.5 5.5" />
        <path d="M16 8l1.5-2.5" />
        <path d="M9 12h.01" />
        <path d="M15 12h.01" />
      </>
    ),
    file: (
      <>
        <path d="M14 2H7a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7Z" />
        <path d="M14 2v5h5" />
        <path d="M9 13h6" />
        <path d="M9 17h6" />
      </>
    ),
    arrow: <path d="m9 18 6-6-6-6" />,
    leaf: (
      <>
        <path d="M20 4c-7.3.6-12.3 4.2-14.2 11C10.7 15.7 16.4 12.1 20 4Z" />
        <path d="M5 20c2.1-5.4 5.7-9.2 10.7-11.3" />
      </>
    ),
    tractor: (
      <>
        <circle cx="7" cy="17" r="3" />
        <circle cx="17" cy="17" r="2" />
        <path d="M10 17h5" />
        <path d="M5 14h6l2-6h3l2 6" />
        <path d="M9 8h3" />
      </>
    ),
    cloud: (
      <>
        <path d="M17.5 18H8a4 4 0 1 1 .8-7.9 5.5 5.5 0 0 1 10.7 1.8A3.1 3.1 0 0 1 17.5 18Z" />
        <path d="M16 3v2" />
        <path d="m20.2 5.8-1.4 1.4" />
      </>
    ),
    store: (
      <>
        <path d="M4 10h16" />
        <path d="m5 10 1-5h12l1 5" />
        <path d="M6 10v9h12v-9" />
        <path d="M9 19v-5h6v5" />
      </>
    ),
    book: (
      <>
        <path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v17H6.5A2.5 2.5 0 0 1 4 17.5Z" />
        <path d="M4 17.5A2.5 2.5 0 0 1 6.5 15H20" />
      </>
    ),
    wifi: (
      <>
        <path d="M12 20h.01" />
        <path d="M8.5 16.5a5 5 0 0 1 7 0" />
        <path d="M5 13a10 10 0 0 1 14 0" />
        <path d="M2 9.5a15 15 0 0 1 20 0" />
      </>
    ),
    brain: (
      <>
        <path d="M9 4a3 3 0 0 0-3 3v1a3 3 0 0 0 0 6v1a3 3 0 0 0 3 3" />
        <path d="M15 4a3 3 0 0 1 3 3v1a3 3 0 0 1 0 6v1a3 3 0 0 1-3 3" />
        <path d="M9 4v16" />
        <path d="M15 4v16" />
      </>
    ),
    globe: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M3 12h18" />
        <path d="M12 3c3 3.4 3 14.6 0 18" />
        <path d="M12 3c-3 3.4-3 14.6 0 18" />
      </>
    ),
    shield: (
      <>
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" />
        <path d="m9 12 2 2 4-5" />
      </>
    ),
    check: <path d="m5 12 4 4L19 6" />,
    mail: (
      <>
        <rect x="3" y="5" width="18" height="14" rx="2" />
        <path d="m3 7 9 6 9-6" />
      </>
    ),
    pin: (
      <>
        <path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z" />
        <circle cx="12" cy="10" r="2.5" />
      </>
    ),
  };

  return <svg {...props}>{icons[name]}</svg>;
}

function Logo({ onNavClick, tagLine }) {
  return (
    <a
      href="#home"
      className="logo"
      aria-label="AGRHI home"
      onClick={(event) => onNavClick(event, "home")}
    >
      <div className="logo-mark">
        <img src={LOGO_SRC} alt="AGRHI logo" className="logo-img" />
      </div>

      <div className="logo-copy">
        <span className="logo-name">Farmlead</span>
        <span className="logo-tag">{tagLine}</span>
      </div>
    </a>
  );
}

function screenshotCandidates(src) {
  if (!src) return [];

  const clean = String(src).trim();

  if (/^(https?:|data:|blob:|\/)/i.test(clean)) {
    return [clean];
  }

  if (/^[a-zA-Z]:[\\/]/.test(clean)) {
    return [clean.replace(/\\/g, "/")];
  }

  const fileName = clean.replace(/^\.?\//, "");

  return [
    `/screenshots/${fileName}`,
    `/${fileName}`,
    fileName,
  ];
}

function PhoneImage({
  src,
  active,
  index,
  onBroken,
  screenshotLabel,
}) {
  const candidates = useMemo(
    () => screenshotCandidates(src),
    [src],
  );

  const [candidateIndex, setCandidateIndex] = useState(0);

  useEffect(() => {
    setCandidateIndex(0);
  }, [src]);

  if (!candidates.length) return null;

  const currentSrc =
    candidates[Math.min(candidateIndex, candidates.length - 1)];

  return (
    <img
      src={currentSrc}
      alt={`${screenshotLabel} ${index + 1}`}
      className={active ? "phone-shot active" : "phone-shot"}
      onError={() => {
        if (candidateIndex < candidates.length - 1) {
          setCandidateIndex((value) => value + 1);
        } else {
          onBroken(src);
        }
      }}
    />
  );
}

function PhoneFallback({ copy }) {
  return (
    <div className="phone-fallback">
      <div className="fallback-logo">
        <img src={LOGO_SRC} alt="" />

        <div>
          <strong>AGRHI</strong>
          <span>{copy.assistant}</span>
        </div>
      </div>

      <div className="weather-card">
        <div>
          <span>{copy.weather}</span>
          <strong>28°C</strong>
          <small>{copy.condition}</small>
        </div>

        <Icon name="cloud" size={34} />
      </div>

      <div className="fallback-section-title">
        {copy.tools}
      </div>

      <div className="mini-grid">
        <div>
          <Icon name="leaf" size={22} />
          <strong>{copy.cards[0][0]}</strong>
          <span>{copy.cards[0][1]}</span>
        </div>

        <div>
          <Icon name="tractor" size={22} />
          <strong>{copy.cards[1][0]}</strong>
          <span>{copy.cards[1][1]}</span>
        </div>

        <div>
          <Icon name="store" size={22} />
          <strong>{copy.cards[2][0]}</strong>
          <span>{copy.cards[2][1]}</span>
        </div>

        <div>
          <Icon name="cloud" size={22} />
          <strong>{copy.cards[3][0]}</strong>
          <span>{copy.cards[3][1]}</span>
        </div>
      </div>

      <div className="fallback-note">
        <Icon name="wifi" size={18} />
        <span>{copy.offline}</span>
      </div>
    </div>
  );
}

function PhoneMockup({ screenshots, copy }) {
  const [active, setActive] = useState(0);
  const [broken, setBroken] = useState({});
  const [paused, setPaused] = useState(false);

  const visibleScreenshots = useMemo(
    () => screenshots.filter((src) => src && !broken[src]),
    [screenshots, broken],
  );

  useEffect(() => {
    if (visibleScreenshots.length < 2 || paused) return undefined;

    const timer = window.setInterval(() => {
      setActive(
        (index) => (index + 1) % visibleScreenshots.length,
      );
    }, 3000);

    return () => window.clearInterval(timer);
  }, [visibleScreenshots.length, paused]);

  useEffect(() => {
    const handleVisibility = () => setPaused(document.hidden);
    document.addEventListener("visibilitychange", handleVisibility);
    return () => document.removeEventListener("visibilitychange", handleVisibility);
  }, []);

  useEffect(() => {
    if (active >= visibleScreenshots.length) {
      setActive(0);
    }
  }, [active, visibleScreenshots.length]);

  return (
    <div
      className="phone-stage"
      aria-label={copy.label}
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
    >
      <div className="phone-glow" />

      <div className="phone">
        <div className="speaker" />
        <div className="camera" />

        <div className="phone-screen">
          {visibleScreenshots.length ? (
            visibleScreenshots.map((src, index) => (
              <PhoneImage
                key={`${src}-${index}`}
                src={src}
                index={index}
                active={index === active}
                screenshotLabel={copy.screenshot}
                onBroken={(brokenSrc) =>
                  setBroken((current) => ({
                    ...current,
                    [brokenSrc]: true,
                  }))
                }
              />
            ))
          ) : (
            <PhoneFallback copy={copy} />
          )}
        </div>
      </div>

      {!!visibleScreenshots.length && (
        <div className="phone-dots" aria-hidden="true">
          {visibleScreenshots.map((src, index) => (
            <span
              key={src}
              className={index === active ? "active" : ""}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function getInitialLanguage() {
  try {
    const savedLanguage = localStorage.getItem(LANGUAGE_STORAGE_KEY);

    return TRANSLATIONS[savedLanguage]
      ? savedLanguage
      : "en";
  } catch {
    return "en";
  }
}

export default function Home() {
  const navigate = useNavigate();

  const [activeSection, setActiveSection] = useState("home");

  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  const [language, setLanguage] = useState(getInitialLanguage);

  const t = TRANSLATIONS[language];

  const phoneScreenshots = useMemo(
    () => PHONE_SCREENSHOTS.map((src) => String(src).trim()).filter(Boolean),
    [],
  );

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

  const handleLanguageChange = useCallback((nextLanguage) => {
    try {
      localStorage.setItem(LANGUAGE_STORAGE_KEY, nextLanguage);
    } catch {
      // Continue without browser storage.
    }

    setLanguage(nextLanguage);
  }, []);

  const handleNavClick = useCallback((event, id) => {
    event.preventDefault();

    const element = document.getElementById(id);

    if (!element) return;

    element.scrollIntoView({
      behavior: "smooth",
      block: "start",
    });

    setActiveSection(id);
    setMobileNavOpen(false);
  }, []);

  useLayoutEffect(() => {
    const element = document.getElementById("home");

    if (!element) return;

    window.scrollTo({
      top: 0,
      left: 0,
      behavior: "auto",
    });

    element.scrollIntoView({
      behavior: "auto",
      block: "start",
    });

    setActiveSection("home");
  }, []);

  useEffect(() => {
    const sectionIds = ["home", "about", "features", "contact"];

    const sections = sectionIds
      .map((id) => document.getElementById(id))
      .filter(Boolean);

    if (!sections.length) return undefined;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setActiveSection(entry.target.id);
          }
        });
      },
      {
        rootMargin: "-38% 0px -55% 0px",
        threshold: 0,
      },
    );

    sections.forEach((element) => observer.observe(element));

    return () => observer.disconnect();
  }, []);

  const navItems = [
    ["home", t.nav.home],
    ["about", t.nav.about],
    ["features", t.nav.features],
    ["contact", t.nav.contact],
  ];

  return (
    <>
      <style>{`
        @import url("https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&family=Noto+Sans+Devanagari:wght@400;500;600;700;800;900&family=Noto+Sans+Tamil:wght@400;500;600;700;800;900&family=Noto+Sans+Telugu:wght@400;500;600;700;800;900&display=swap");

        :root {
          --green-950: #053d18;
          --green-900: #07551f;
          --green-800: #0d6b2b;
          --green-700: #2f7d1f;
          --green-600: #4c962e;
          --green-500: #74b94a;
          --green-100: #e9f5e3;
          --green-50: #f4faf1;
          --lime-100: #eef8dc;
          --text: #132017;
          --muted: #617064;
          --line: #dce6da;
          --white: #ffffff;
          --page-pad: clamp(20px, 4.2vw, 68px);
          --radius: 22px;
          --shadow-soft: 0 18px 50px rgba(25, 68, 29, 0.1);
          --shadow-card: 0 10px 28px rgba(20, 61, 24, 0.08);
          --shadow-green: 0 16px 32px rgba(4, 99, 34, 0.22);
        }

        * {
          box-sizing: border-box;
        }

        html {
          margin: 0;
          padding: 0;
          scroll-behavior: smooth;
          background: #f7faf5;
        }

        body {
          margin: 0;
          overflow-x: hidden;
          font-family:
            "Inter",
            "Noto Sans Tamil",
            "Noto Sans Devanagari",
            "Noto Sans Telugu",
            Arial,
            sans-serif;
          color: var(--text);
          background: #f7faf5;
        }

        button,
        a {
          font: inherit;
        }

        a {
          color: inherit;
          text-decoration: none;
        }

        .page {
          width: 100%;
          min-height: 100vh;
          background: #ffffff;
        }

        .nav {
          height: 82px;
          position: sticky;
          top: 0;
          z-index: 100;
          background: rgba(249, 251, 248, 0.92);
          border-bottom: 1px solid rgba(207, 221, 204, 0.82);
          backdrop-filter: blur(18px);
          -webkit-backdrop-filter: blur(18px);
        }

        .nav-inner {
          width: min(
            1440px,
            calc(100% - (var(--page-pad) * 2))
          );
          height: 100%;
          margin: 0 auto;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 26px;
        }

        .logo {
          display: inline-flex;
          align-items: center;
          gap: 12px;
          flex: 0 0 auto;
        }

        .logo-mark {
          width: 56px;
          height: 56px;
          flex: 0 0 56px;
          border-radius: 50%;
          overflow: hidden;
          background: white;
          border: 1px solid #d9e4d6;
          box-shadow: 0 5px 15px rgba(18, 55, 20, 0.07);
        }

        .logo-img {
          width: 100%;
          height: 100%;
          display: block;
          object-fit: cover;
        }

        .logo-copy {
          display: flex;
          flex-direction: column;
          min-width: 0;
        }

        .logo-name {
          color: #397d21;
          font-size: 29px;
          line-height: 0.95;
          font-weight: 900;
        }

        .logo-tag {
          margin-top: 5px;
          color: #778078;
          font-size: 9.5px;
          white-space: nowrap;
        }

        .nav-right {
          display: flex;
          align-items: center;
          gap: clamp(26px, 3vw, 55px);
        }

        .nav-links {
          display: flex;
          align-items: center;
          gap: clamp(18px, 2vw, 30px);
        }

        .nav-links a {
          position: relative;
          padding: 31px 0 27px;
          color: #37453a;
          font-size: 14px;
          font-weight: 700;
          transition: color 180ms ease;
        }

        .nav-links a:hover,
        .nav-links a.active {
          color: var(--green-800);
        }

        .nav-links a::after {
          content: "";
          position: absolute;
          left: 50%;
          bottom: 0;
          width: 0;
          height: 3px;
          border-radius: 999px;
          background: var(--green-700);
          transform: translateX(-50%);
          transition: width 180ms ease;
        }

        .nav-links a.active::after {
          width: 38px;
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

        .admin-button {
          min-height: 44px;
          padding: 0 20px;
          border: 0;
          border-radius: 999px;
          color: white;
          background: linear-gradient(
            135deg,
            #0a7130,
            #07511f
          );
          box-shadow: var(--shadow-green);
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 9px;
          font-size: 14px;
          font-weight: 800;
          cursor: pointer;
          transition:
            transform 180ms ease,
            box-shadow 180ms ease;
        }

        .admin-button:hover {
          transform: translateY(-2px);
          box-shadow: 0 19px 35px rgba(4, 99, 34, 0.27);
        }

        .mobile-toggle {
          display: none;
          width: 44px;
          height: 44px;
          border-radius: 12px;
          border: 1px solid #d8e2d5;
          background: white;
          color: var(--green-900);
          cursor: pointer;
        }

        .mobile-toggle-lines,
        .mobile-toggle-lines::before,
        .mobile-toggle-lines::after {
          display: block;
          width: 19px;
          height: 2px;
          border-radius: 99px;
          background: currentColor;
          position: relative;
          margin: auto;
        }

        .mobile-toggle-lines::before,
        .mobile-toggle-lines::after {
          content: "";
          position: absolute;
          left: 0;
        }

        .mobile-toggle-lines::before {
          top: -6px;
        }

        .mobile-toggle-lines::after {
          top: 6px;
        }

        .hero {
          position: relative;
          overflow: hidden;
          scroll-margin-top: 82px;
          background:
            radial-gradient(
              circle at 83% 18%,
              rgba(141, 198, 88, 0.24),
              transparent 23%
            ),
            radial-gradient(
              circle at 64% 90%,
              rgba(76, 150, 46, 0.11),
              transparent 28%
            ),
            linear-gradient(
              135deg,
              #fbfdf9 0%,
              #f3f9ee 44%,
              #e8f4dd 100%
            );
        }

        .hero::before {
          content: "";
          position: absolute;
          width: 540px;
          height: 540px;
          right: -250px;
          top: -240px;
          border-radius: 50%;
          border: 70px solid rgba(73, 148, 45, 0.07);
        }

        .hero::after {
          content: "";
          position: absolute;
          width: 360px;
          height: 360px;
          left: -220px;
          bottom: -220px;
          border-radius: 50%;
          background: rgba(115, 184, 73, 0.09);
        }

        .hero-inner {
          width: min(
            1440px,
            calc(100% - (var(--page-pad) * 2))
          );
          min-height: 620px;
          margin: 0 auto;
          padding: 64px 0;
          display: grid;
          grid-template-columns:
            minmax(0, 1.15fr)
            minmax(290px, 0.6fr);
          gap: clamp(54px, 6vw, 105px);
          align-items: center;
          position: relative;
          z-index: 2;
        }

        .hero-copy {
          max-width: 810px;
        }

        .hero-eyebrow {
          width: max-content;
          max-width: 100%;
          display: inline-flex;
          align-items: center;
          gap: 9px;
          padding: 8px 13px;
          margin-bottom: 21px;
          border-radius: 999px;
          border: 1px solid #cfe6c4;
          background: rgba(255, 255, 255, 0.76);
          color: var(--green-800);
          font-size: 12px;
          font-weight: 800;
          box-shadow: 0 7px 20px rgba(32, 92, 29, 0.06);
        }

        .hero-title {
          margin: 0;
          max-width: 780px;
          color: var(--green-950);
          font-size: clamp(54px, 5.1vw, 78px);
          line-height: 0.98;
          letter-spacing: -2.8px;
          font-weight: 900;
        }

        .hero-title span {
          display: block;
          margin-top: 9px;
          color: #4b922d;
          font-size: clamp(34px, 3vw, 46px);
          letter-spacing: -1.5px;
          line-height: 1.05;
        }

        .hero-copy > p {
          width: min(680px, 100%);
          margin: 24px 0 0;
          color: #435045;
          font-size: 16px;
          line-height: 1.75;
          font-weight: 500;
        }

        .hero-highlights {
          margin: 25px 0 29px;
          display: flex;
          flex-wrap: wrap;
          gap: 10px;
        }

        .highlight {
          display: inline-flex;
          align-items: center;
          gap: 7px;
          padding: 8px 11px;
          border-radius: 10px;
          color: #395039;
          background: rgba(255, 255, 255, 0.72);
          border: 1px solid #dbe9d5;
          font-size: 12px;
          font-weight: 700;
        }

        .highlight-icon {
          width: 20px;
          height: 20px;
          border-radius: 50%;
          color: var(--green-700);
          background: #edf7e9;
          display: grid;
          place-items: center;
        }

        .actions {
          display: flex;
          flex-wrap: wrap;
          gap: 12px;
        }

        .action-card {
          min-height: 58px;
          padding: 0 18px;
          border-radius: 13px;
          border: 1px solid #d8e5d3;
          display: inline-flex;
          align-items: center;
          gap: 12px;
          cursor: pointer;
          transition:
            transform 180ms ease,
            box-shadow 180ms ease,
            border-color 180ms ease;
        }

        .action-card:hover {
          transform: translateY(-2px);
        }

        .action-card.primary {
          border-color: transparent;
          color: white;
          background: linear-gradient(
            135deg,
            #08752e,
            #07531f
          );
          box-shadow: var(--shadow-green);
        }

        .action-card.secondary {
          color: var(--green-900);
          background: rgba(255, 255, 255, 0.9);
          box-shadow: 0 8px 22px rgba(26, 70, 27, 0.07);
        }

        .action-card.ghost {
          color: #415343;
          background: transparent;
          border-color: transparent;
          box-shadow: none;
        }

        .action-card.ghost:hover {
          background: rgba(255, 255, 255, 0.65);
        }

        .action-label {
          display: flex;
          flex-direction: column;
          align-items: flex-start;
          line-height: 1.2;
        }

        .action-label strong {
          font-size: 13px;
          font-weight: 800;
        }

        .action-label small {
          margin-top: 3px;
          font-size: 10px;
          opacity: 0.78;
          font-weight: 600;
        }

        .phone-stage {
          min-height: 520px;
          display: flex;
          align-items: center;
          justify-content: center;
          position: relative;
        }

        .phone-glow {
          position: absolute;
          width: 340px;
          height: 340px;
          border-radius: 50%;
          background: radial-gradient(
            circle,
            rgba(113, 181, 72, 0.32),
            rgba(113, 181, 72, 0)
          );
          filter: blur(3px);
        }

        .phone {
          width: 258px;
          height: 518px;
          padding: 9px;
          border-radius: 38px;
          background: linear-gradient(
            145deg,
            #181818,
            #020202
          );
          position: relative;
          z-index: 2;
          box-shadow:
            inset 0 0 0 1px #3a3a3a,
            0 32px 65px rgba(20, 53, 18, 0.23),
            0 8px 20px rgba(0, 0, 0, 0.2);
          transform: rotate(1.4deg);
        }

        .phone::before {
          content: "";
          position: absolute;
          left: -3px;
          top: 105px;
          width: 3px;
          height: 74px;
          border-radius: 2px 0 0 2px;
          background: #2d2d2d;
        }

        .speaker {
          position: absolute;
          left: 68px;
          top: 9px;
          width: 122px;
          height: 25px;
          border-radius: 0 0 18px 18px;
          background: #040404;
          z-index: 6;
        }

        .camera {
          position: absolute;
          right: 59px;
          top: 17px;
          width: 6px;
          height: 6px;
          border-radius: 50%;
          background: #142236;
          z-index: 7;
        }

        .phone-screen {
          width: 100%;
          height: 100%;
          overflow: hidden;
          border-radius: 30px;
          background: #f7fbf5;
          position: relative;
        }

        .phone-shot {
          position: absolute;
          inset: 0;
          width: 100%;
          height: 100%;
          object-fit: cover;
          object-position: center top;
          opacity: 0;
          transform: scale(1.015);
          transition:
            opacity 520ms ease,
            transform 700ms ease;
          background: #f8fbf7;
        }

        .phone-shot.active {
          opacity: 1;
          transform: scale(1);
        }

        .phone-dots {
          position: absolute;
          bottom: 10px;
          z-index: 4;
          display: flex;
          gap: 5px;
        }

        .phone-dots span {
          width: 5px;
          height: 5px;
          border-radius: 50%;
          background: #b9cbb4;
          transition:
            width 180ms ease,
            background 180ms ease;
        }

        .phone-dots span.active {
          width: 17px;
          border-radius: 999px;
          background: var(--green-700);
        }

        .phone-fallback {
          height: 100%;
          padding: 48px 15px 24px;
          color: #172019;
          background: linear-gradient(
            180deg,
            #f5faf2,
            #ffffff
          );
        }

        .fallback-logo {
          display: flex;
          align-items: center;
          gap: 9px;
          margin-bottom: 17px;
        }

        .fallback-logo img {
          width: 34px;
          height: 34px;
          border-radius: 50%;
          object-fit: cover;
        }

        .fallback-logo strong,
        .fallback-logo span {
          display: block;
        }

        .fallback-logo strong {
          color: var(--green-900);
          font-size: 14px;
        }

        .fallback-logo span {
          margin-top: 2px;
          color: #768176;
          font-size: 7px;
        }

        .weather-card {
          min-height: 96px;
          padding: 13px;
          border-radius: 14px;
          color: white;
          background: linear-gradient(
            135deg,
            #55aadd,
            #2274b5
          );
          display: flex;
          align-items: center;
          justify-content: space-between;
          box-shadow: 0 9px 18px rgba(20, 105, 161, 0.18);
        }

        .weather-card span,
        .weather-card small {
          display: block;
          font-size: 8px;
        }

        .weather-card strong {
          display: block;
          margin: 4px 0;
          font-size: 28px;
        }

        .fallback-section-title {
          margin: 16px 0 9px;
          color: #273229;
          font-size: 10px;
          font-weight: 800;
        }

        .mini-grid {
          display: grid;
          grid-template-columns: repeat(2, 1fr);
          gap: 8px;
        }

        .mini-grid > div {
          min-height: 75px;
          padding: 9px 6px;
          border: 1px solid #e2eadf;
          border-radius: 12px;
          background: white;
          color: var(--green-700);
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          text-align: center;
              box-shadow: 0 5px 12px rgba(27, 71, 27, 0.05);
        }

        .mini-grid strong {
          margin-top: 5px;
          color: #1c281e;
          font-size: 8px;
        }

        .mini-grid span {
          margin-top: 2px;
          color: #7a847b;
          font-size: 6px;
        }

        .fallback-note {
          margin-top: 11px;
          padding: 9px;
          border-radius: 10px;
          color: #4d604f;
          background: #eef7e9;
          display: flex;
          align-items: center;
          gap: 7px;
          font-size: 7px;
          font-weight: 700;
        }

        .about {
          padding: 88px var(--page-pad) 72px;
          background: white;
          scroll-margin-top: 82px;
        }

        .section-shell {
          width: min(1180px, 100%);
          margin: 0 auto;
        }

        .section-kicker {
          margin-bottom: 10px;
          color: var(--green-700);
          text-align: center;
          font-size: 12px;
          font-weight: 900;
          letter-spacing: 1.6px;
          text-transform: uppercase;
        }

        .section-title {
          margin: 0;
          color: var(--green-950);
          text-align: center;
          font-size: clamp(30px, 3vw, 42px);
          line-height: 1.15;
          letter-spacing: -1.2px;
          font-weight: 900;
        }

        .section-copy {
          width: min(820px, 100%);
          margin: 18px auto 0;
          color: #556258;
          text-align: center;
          font-size: 15px;
          line-height: 1.8;
          font-weight: 500;
        }

        .about-points {
          margin-top: 38px;
          display: grid;
          grid-template-columns: repeat(3, 1fr);
          gap: 18px;
        }

        .about-point {
          padding: 22px;
          border: 1px solid var(--line);
          border-radius: 17px;
          background: #fbfdf9;
          display: flex;
          gap: 13px;
        }

        .about-point-icon {
          width: 42px;
          height: 42px;
          flex: 0 0 42px;
          border-radius: 12px;
          color: var(--green-700);
          background: var(--green-100);
          display: grid;
          place-items: center;
        }

        .about-point strong {
          display: block;
          margin-bottom: 5px;
          color: #254526;
          font-size: 13px;
        }

        .about-point span {
          display: block;
          color: #6b776d;
          font-size: 12px;
          line-height: 1.55;
        }

        .why {
          padding: 78px var(--page-pad) 88px;
          background: linear-gradient(
            180deg,
            #f8fbf6 0%,
            #f3f8ef 100%
          );
          scroll-margin-top: 82px;
        }

        .feature-grid {
          margin-top: 38px;
          display: grid;
          grid-template-columns: repeat(
            3,
            minmax(0, 1fr)
          );
          gap: 20px;
        }

        .feature-card {
          min-height: 225px;
          padding: 26px;
          border: 1px solid #dce7d8;
          border-radius: 20px;
          background: rgba(255, 255, 255, 0.93);
          box-shadow: 0 7px 22px rgba(25, 67, 25, 0.055);
          transition:
            transform 180ms ease,
            box-shadow 180ms ease,
            border-color 180ms ease;
        }

        .feature-card:hover {
          transform: translateY(-5px);
          border-color: #c9dfc1;
          box-shadow: var(--shadow-card);
        }

        .feature-icon {
          width: 52px;
          height: 52px;
          border-radius: 15px;
          color: var(--green-700);
          background: linear-gradient(
            145deg,
            #e9f5e3,
            #f7fbf4
          );
          display: grid;
          place-items: center;
          margin-bottom: 22px;
        }

        .feature-card h3 {
          margin: 0 0 10px;
          color: var(--green-950);
          font-size: 16px;
          line-height: 1.3;
          font-weight: 800;
        }

        .feature-card p {
          margin: 0;
          color: #637064;
          font-size: 13px;
          line-height: 1.7;
        }

        .stats {
          padding: 30px var(--page-pad);
          background: linear-gradient(
            135deg,
            #086226,
            #034519
          );
          color: white;
        }

        .stats-inner {
          width: min(1180px, 100%);
          margin: 0 auto;
          display: grid;
          grid-template-columns: repeat(4, 1fr);
        }

        .stat {
          min-height: 92px;
          padding: 10px 22px;
          border-right: 1px solid
            rgba(255, 255, 255, 0.18);
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 14px;
        }

        .stat:last-child {
          border-right: 0;
        }

        .stat-icon {
          width: 45px;
          height: 45px;
          border-radius: 14px;
          background: rgba(255, 255, 255, 0.11);
          display: grid;
          place-items: center;
        }

        .stat b,
        .stat span {
          display: block;
        }

        .stat b {
          font-size: 20px;
          line-height: 1.05;
        }

        .stat span {
          margin-top: 5px;
          color: rgba(255, 255, 255, 0.72);
          font-size: 11px;
        }

        .contact {
          padding: 88px var(--page-pad);
          background: white;
          scroll-margin-top: 82px;
        }

        .contact-wrap {
          width: min(1080px, 100%);
          margin: 38px auto 0;
          padding: 34px;
          border: 1px solid #dce7d9;
          border-radius: 24px;
          background:
            radial-gradient(
              circle at 100% 0,
              rgba(125, 190, 80, 0.18),
              transparent 26%
            ),
            linear-gradient(145deg, #fbfdf9, #f3f9ef);
          display: grid;
          grid-template-columns: minmax(0, 1fr) auto;
          gap: 32px;
          align-items: center;
          box-shadow: var(--shadow-soft);
        }

        .contact-copy h3 {
          margin: 0;
          color: var(--green-950);
          font-size: 24px;
        }

        .contact-copy p {
          margin: 9px 0 0;
          max-width: 650px;
          color: #647166;
          font-size: 13px;
          line-height: 1.7;
        }

        .contact-actions {
          display: flex;
          flex-direction: column;
          gap: 10px;
          min-width: 240px;
        }

        .contact-action {
          min-height: 48px;
          padding: 0 15px;
          border-radius: 12px;
          border: 1px solid #d8e4d4;
          background: white;
          color: #314a34;
          display: flex;
          align-items: center;
          gap: 10px;
          font-size: 12px;
          font-weight: 700;
        }

        .contact-action svg {
          color: var(--green-700);
        }

        .footer {
          padding: 34px var(--page-pad) 28px;
          color: #69746b;
          background: #f3f6f1;
          border-top: 1px solid #e0e7dd;
        }

        .footer-inner {
          width: min(1180px, 100%);
          margin: 0 auto;
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 24px;
        }

        .footer-brand {
          display: flex;
          align-items: center;
          gap: 10px;
        }

        .footer-brand img {
          width: 38px;
          height: 38px;
          border-radius: 50%;
          object-fit: cover;
        }

        .footer-brand strong {
          display: block;
          color: var(--green-900);
          font-size: 13px;
        }

        .footer-brand span {
          display: block;
          margin-top: 2px;
          font-size: 10px;
        }

        .footer-links {
          display: flex;
          align-items: center;
          flex-wrap: wrap;
          justify-content: flex-end;
          gap: 17px;
          font-size: 11px;
          font-weight: 700;
        }

        .footer-links a:hover {
          color: var(--green-800);
        }

        .footer-bottom {
          width: min(1180px, 100%);
          margin: 22px auto 0;
          padding-top: 18px;
          border-top: 1px solid #dde5da;
          text-align: center;
          font-size: 10px;
        }

        @media (max-width: 1120px) {
          .hero-inner {
            grid-template-columns:
              minmax(0, 1fr)
              300px;
            gap: 38px;
          }

          .phone {
            width: 238px;
            height: 478px;
          }

          .phone-stage {
            min-height: 480px;
          }

          .feature-grid {
            grid-template-columns: repeat(
              2,
              minmax(0, 1fr)
            );
          }
        }

        @media (max-width: 880px) {
          .nav {
            height: 74px;
          }

          .nav-inner {
            width: calc(100% - 32px);
          }

          .logo-mark {
            width: 48px;
            height: 48px;
            flex-basis: 48px;
          }

          .logo-name {
            font-size: 25px;
          }

          .logo-tag {
            display: none;
          }

          .nav-right {
            gap: 10px;
          }

          .language-trigger { min-height: 40px; }

          .nav-links {
            position: absolute;
            left: 16px;
            right: 16px;
            top: 68px;
            padding: 14px;
            border: 1px solid #dbe5d8;
            border-radius: 16px;
            background: rgba(255, 255, 255, 0.98);
            box-shadow: var(--shadow-soft);
            display: none;
            flex-direction: column;
            align-items: stretch;
            gap: 2px;
          }

          .nav-links.open {
            display: flex;
          }

          .nav-links a {
            padding: 12px 13px;
            border-radius: 10px;
          }

          .nav-links a.active {
            background: #eef7e9;
          }

          .nav-links a::after {
            display: none;
          }

          .mobile-toggle {
            display: block;
          }

          .admin-button {
            min-height: 42px;
            padding: 0 14px;
          }

          .admin-button span {
            display: none;
          }

          .hero {
            scroll-margin-top: 74px;
          }

          .hero-inner {
            min-height: auto;
            padding: 52px 0 62px;
            grid-template-columns: 1fr;
          }

          .hero-copy {
            max-width: none;
          }

          .phone-stage {
            order: -1;
            min-height: 430px;
          }

          .phone {
            width: 218px;
            height: 438px;
            transform: rotate(0);
          }

          .speaker {
            left: 58px;
            width: 104px;
          }

          .camera {
            right: 51px;
          }

          .about,
          .why,
          .contact {
            scroll-margin-top: 74px;
          }

          .about-points {
            grid-template-columns: 1fr;
          }

          .stats-inner {
            grid-template-columns: repeat(2, 1fr);
          }

          .stat:nth-child(2) {
            border-right: 0;
          }

          .stat:nth-child(-n + 2) {
            border-bottom: 1px solid
              rgba(255, 255, 255, 0.14);
          }

          .contact-wrap {
            grid-template-columns: 1fr;
          }

          .contact-actions {
            min-width: 0;
          }
        }

        @media (max-width: 620px) {
          :root {
            --page-pad: 16px;
          }

          .hero-inner {
            width: calc(100% - 32px);
          }

          .language-trigger { padding: 0 10px; font-size: 12px; }
          .language-trigger > svg { display: none; }
          .language-menu { right: -42px; width: 180px; }

          .hero-eyebrow {
            font-size: 10px;
          }

          .hero-title {
            font-size: 46px;
            letter-spacing: -2px;
          }

          .hero-title span {
            font-size: 29px;
          }

          .hero-copy > p {
            font-size: 14px;
          }

          .hero-highlights {
            gap: 7px;
          }

          .highlight {
            font-size: 10px;
          }

          .actions {
            flex-direction: column;
          }

          .action-card {
            width: 100%;
            justify-content: flex-start;
          }

          .about,
          .why,
          .contact {
            padding-top: 66px;
            padding-bottom: 66px;
          }

          .feature-grid {
            grid-template-columns: 1fr;
          }

          .feature-card {
            min-height: 0;
          }

          .stats {
            padding-left: 16px;
            padding-right: 16px;
          }

          .stats-inner {
            grid-template-columns: 1fr;
          }

          .stat {
            border-right: 0;
            border-bottom: 1px solid
              rgba(255, 255, 255, 0.14);
            justify-content: flex-start;
          }

          .stat:last-child {
            border-bottom: 0;
          }

          .contact-wrap {
            padding: 24px 18px;
          }

          .footer-inner {
            flex-direction: column;
            align-items: flex-start;
          }

          .footer-links {
            justify-content: flex-start;
          }
        }

        @media (prefers-reduced-motion: reduce) {
          html { scroll-behavior: auto; }
          *, *::before, *::after {
            scroll-behavior: auto !important;
            animation-duration: 0.01ms !important;
            animation-iteration-count: 1 !important;
            transition-duration: 0.01ms !important;
          }
        }
      `}</style>
      <main className="page">
        <nav className="nav">
          <div className="nav-inner">
            <Logo onNavClick={handleNavClick} tagLine={t.logoTag} />

            <div className="nav-right">
              <div className={`nav-links ${mobileNavOpen ? "open" : ""}`}>
                {navItems.map(([id, label]) => (
                  <a
                    key={id}
                    className={activeSection === id ? "active" : ""}
                    href={`#${id}`}
                    onClick={(event) => handleNavClick(event, id)}
                  >
                    {label}
                  </a>
                ))}
              </div>

              <LanguageDropdown
                language={language}
                label={t.language}
                onChange={handleLanguageChange}
              />

              <button
                type="button"
                className="admin-button"
                onClick={() => navigate("/login")}
              >
                <Icon name="user" size={17} />
                <span>{t.adminPortal}</span>
              </button>

              <button
                type="button"
                className="mobile-toggle"
                aria-label={t.toggleNavigation}
                aria-expanded={mobileNavOpen}
                onClick={() => setMobileNavOpen((value) => !value)}
              >
                <span className="mobile-toggle-lines" />
              </button>
            </div>
          </div>
        </nav>

        <section className="hero" id="home">
          <div className="hero-inner">
            <div className="hero-copy">
              <div className="hero-eyebrow">
                <Icon name="leaf" size={15} />
                {t.hero.eyebrow}
              </div>

              <h1 className="hero-title">
                AGRHI
                <span>{t.hero.title}</span>
              </h1>

              <p>{t.hero.description}</p>

              <div className="hero-highlights">
                {t.hero.highlights.map((item) => (
                  <div className="highlight" key={item}>
                    <span className="highlight-icon">
                      <Icon name="check" size={12} />
                    </span>

                    {item}
                  </div>
                ))}
              </div>

              <div className="actions">
                <a
                  className="action-card primary"
                  href={APP_DOWNLOAD_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <Icon name="android" size={22} />

                  <span className="action-label">
                    <strong>{t.hero.app}</strong>
                    <small>{t.hero.appNote}</small>
                  </span>

                  <Icon name="arrow" size={16} />
                </a>

                <a
                  className="action-card secondary"
                  href={USER_MANUAL_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <Icon name="file" size={21} />

                  <span className="action-label">
                    <strong>{t.hero.manual}</strong>
                    <small>{t.hero.manualNote}</small>
                  </span>
                </a>

                <button
                  type="button"
                  className="action-card ghost"
                  onClick={(event) => handleNavClick(event, "features")}
                >
                  <Icon name="leaf" size={20} />

                  <span className="action-label">
                    <strong>{t.hero.explore}</strong>
                    <small>{t.hero.exploreNote}</small>
                  </span>
                </button>
              </div>
            </div>

            <PhoneMockup screenshots={phoneScreenshots} copy={t.preview} />
          </div>
        </section>

        <section className="about" id="about">
          <div className="section-shell">
            <div className="section-kicker">{t.about.kicker}</div>

            <h2 className="section-title">{t.about.title}</h2>

            <p className="section-copy">{t.about.description}</p>

            <div className="about-points">
              {t.about.points.map(([title, text], index) => (
                <div className="about-point" key={title}>
                  <div className="about-point-icon">
                    <Icon name={["leaf", "globe", "shield"][index]} size={21} />
                  </div>

                  <div>
                    <strong>{title}</strong>
                    <span>{text}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="why" id="features">
          <div className="section-shell">
            <div className="section-kicker">{t.featureSection.kicker}</div>

            <h2 className="section-title">{t.featureSection.title}</h2>

            <p className="section-copy">{t.featureSection.description}</p>

            <div className="feature-grid">
              {t.features.map(([title, text], index) => (
                <article className="feature-card" key={title}>
                  <div className="feature-icon">
                    <Icon name={FEATURE_ICONS[index]} size={27} />
                  </div>

                  <h3>{title}</h3>
                  <p>{text}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="stats">
          <div className="stats-inner">
            {t.stats.map(([value, label], index) => (
              <div className="stat" key={label}>
                <div className="stat-icon">
                  <Icon name={STAT_ICONS[index]} size={23} />
                </div>

                <div>
                  <b>{value}</b>
                  <span>{label}</span>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="contact" id="contact">
          <div className="section-shell">
            <div className="section-kicker">{t.contact.kicker}</div>

            <h2 className="section-title">{t.contact.title}</h2>

            <div className="contact-wrap">
              <div className="contact-copy">
                <h3>{t.contact.heading}</h3>
                <p>{t.contact.description}</p>
              </div>

              <div className="contact-actions">
                <a className="contact-action" href="mailto:support@farmlead.in">
                  <Icon name="mail" size={19} />
                  support@farmlead.in
                </a>

                <div className="contact-action">
                  <Icon name="pin" size={19} />
                  {t.contact.location}
                </div>
              </div>
            </div>
          </div>
        </section>

        <footer className="footer">
          <div className="footer-inner">
            <div className="footer-brand">
              <img src={LOGO_SRC} alt="AGRHI logo" />

              <div>
                <strong>{t.footer.brand}</strong>
                <span>{t.logoTag}</span>
              </div>
            </div>

            <div className="footer-links">
              <a href="/privacy">{t.footer.privacy}</a>

              <a href="/delete-account">{t.footer.deleteAccount}</a>

              <a href="mailto:support@farmlead.in">{t.footer.support}</a>

              <button
                type="button"
                onClick={() => navigate("/login")}
                style={{
                  border: 0,
                  background: "transparent",
                  padding: 0,
                  color: "inherit",
                  cursor: "pointer",
                  fontWeight: 700,
                }}
              >
                {t.footer.adminLogin}
              </button>
            </div>
          </div>

          <div className="footer-bottom">
            © {new Date().getFullYear()} AGRHI • {t.footer.programme}
          </div>
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
