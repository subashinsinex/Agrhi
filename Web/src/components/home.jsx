import React, {
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
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

const APP_DOWNLOAD_URL =
  "https://play.google.com/apps/testing/app.agrhi.com";

const USER_MANUAL_URL = "/user_manual.pptx";
const LOGO_SRC = "/logo.png";

const features = [
  {
    icon: "leaf",
    title: "AI Disease Detection",
    text: "Identify crop diseases from plant images with AGRHI's AI-powered Plant Doctor.",
  },
  {
    icon: "tractor",
    title: "Crop & Farm Management",
    text: "Organize farms, crops, irrigation, soil and water information in one place.",
  },
  {
    icon: "cloud",
    title: "Weather Intelligence",
    text: "Use local weather conditions and forecasts to support better farm decisions.",
  },
  {
    icon: "store",
    title: "Agricultural Marketplace",
    text: "Connect farmers, retailers and consumers through nearby product listings.",
  },
  {
    icon: "book",
    title: "7-Language Support",
    text: "Use AGRHI in multiple languages with downloadable offline language support.",
  },
  {
    icon: "wifi",
    title: "Offline-First Experience",
    text: "Keep working in low-connectivity areas and synchronize important data later.",
  },
];

const stats = [
  { icon: "brain", value: "10+", label: "Crop AI Models" },
  { icon: "globe", value: "7", label: "Supported Languages" },
  { icon: "wifi", value: "Offline", label: "First Architecture" },
  { icon: "shield", value: "Secure", label: "Privacy Focused" },
];

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

function Logo({ onNavClick }) {
  return (
    <a
      href="#home"
      className="logo"
      aria-label="AGRHI home"
      onClick={(e) => onNavClick(e, "home")}
    >
      <div className="logo-mark">
        <img src={LOGO_SRC} alt="AGRHI logo" className="logo-img" />
      </div>

      <div className="logo-copy">
        <span className="logo-name">Farmlead</span>
        <span className="logo-tag">Leading the Future of Agriculture.</span>
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
  return [`/screenshots/${fileName}`, `/${fileName}`, fileName];
}

function PhoneImage({ src, active, index, onBroken }) {
  const candidates = useMemo(() => screenshotCandidates(src), [src]);
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
      alt={`AGRHI app screenshot ${index + 1}`}
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

function PhoneFallback() {
  return (
    <div className="phone-fallback">
      <div className="fallback-logo">
        <img src={LOGO_SRC} alt="" />
        <div>
          <strong>AGRHI</strong>
          <span>Smart Farm Assistant</span>
        </div>
      </div>

      <div className="weather-card">
        <div>
          <span>Today's weather</span>
          <strong>28°C</strong>
          <small>Partly cloudy · Chennai</small>
        </div>
        <Icon name="cloud" size={34} />
      </div>

      <div className="fallback-section-title">Smart tools</div>

      <div className="mini-grid">
        <div>
          <Icon name="leaf" size={22} />
          <strong>Plant Doctor</strong>
          <span>Disease Detection</span>
        </div>
        <div>
          <Icon name="tractor" size={22} />
          <strong>Crop Care</strong>
          <span>Farm Manager</span>
        </div>
        <div>
          <Icon name="store" size={22} />
          <strong>Marketplace</strong>
          <span>Buy & Sell</span>
        </div>
        <div>
          <Icon name="cloud" size={22} />
          <strong>Weather</strong>
          <span>Forecast</span>
        </div>
      </div>

      <div className="fallback-note">
        <Icon name="wifi" size={18} />
        <span>Offline-first for low connectivity areas</span>
      </div>
    </div>
  );
}

function PhoneMockup({ screenshots }) {
  const [active, setActive] = useState(0);
  const [broken, setBroken] = useState({});

  const visibleScreenshots = screenshots.filter((src) => src && !broken[src]);

  useEffect(() => {
    if (!visibleScreenshots.length) return undefined;

    const timer = window.setInterval(() => {
      setActive((index) => (index + 1) % visibleScreenshots.length);
    }, 3000);

    return () => window.clearInterval(timer);
  }, [visibleScreenshots.length]);

  useEffect(() => {
    if (active >= visibleScreenshots.length) {
      setActive(0);
    }
  }, [active, visibleScreenshots.length]);

  return (
    <div className="phone-stage" aria-label="AGRHI mobile app preview">
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
                onBroken={(brokenSrc) =>
                  setBroken((current) => ({
                    ...current,
                    [brokenSrc]: true,
                  }))
                }
              />
            ))
          ) : (
            <PhoneFallback />
          )}
        </div>
      </div>

      {!!visibleScreenshots.length && (
        <div className="phone-dots" aria-hidden="true">
          {visibleScreenshots.map((src, index) => (
            <span key={src} className={index === active ? "active" : ""} />
          ))}
        </div>
      )}
    </div>
  );
}

export default function Home() {
  const navigate = useNavigate();
  const [activeSection, setActiveSection] = useState("home");
  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  const phoneScreenshots = useMemo(
    () => PHONE_SCREENSHOTS.map((src) => String(src).trim()).filter(Boolean),
    [],
  );

  const handleNavClick = useCallback((e, id) => {
    e.preventDefault();

    const el = document.getElementById(id);
    if (!el) return;

    el.scrollIntoView({ behavior: "smooth", block: "start" });
    setActiveSection(id);
    setMobileNavOpen(false);
  }, []);

  useLayoutEffect(() => {
    const el = document.getElementById("home");
    if (!el) return;

    window.scrollTo({ top: 0, left: 0, behavior: "auto" });
    el.scrollIntoView({ behavior: "auto", block: "start" });
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

    sections.forEach((el) => observer.observe(el));

    return () => observer.disconnect();
  }, []);

  const navItems = [
    ["home", "Home"],
    ["about", "About"],
    ["features", "Features"],
    ["contact", "Contact"],
  ];

  return (
    <>
      <style>{`
        @import url("https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap");

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
          --shadow-soft: 0 18px 50px rgba(25, 68, 29, 0.10);
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
          font-family: "Inter", Arial, sans-serif;
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

        /* NAV */

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
          width: min(1440px, calc(100% - (var(--page-pad) * 2)));
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

        .admin-button {
          min-height: 44px;
          padding: 0 20px;
          border: 0;
          border-radius: 999px;
          color: white;
          background: linear-gradient(135deg, #0a7130, #07511f);
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

        /* HERO */

        .hero {
          position: relative;
          overflow: hidden;
          scroll-margin-top: 82px;
          background:
            radial-gradient(circle at 83% 18%, rgba(141, 198, 88, 0.24), transparent 23%),
            radial-gradient(circle at 64% 90%, rgba(76, 150, 46, 0.11), transparent 28%),
            linear-gradient(135deg, #fbfdf9 0%, #f3f9ee 44%, #e8f4dd 100%);
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
          width: min(1440px, calc(100% - (var(--page-pad) * 2)));
          min-height: 620px;
          margin: 0 auto;
          padding: 64px 0;
          display: grid;
          grid-template-columns: minmax(0, 1.15fr) minmax(290px, 0.6fr);
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
          background: linear-gradient(135deg, #08752e, #07531f);
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

        /* PHONE */

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
          background: radial-gradient(circle, rgba(113, 181, 72, 0.32), rgba(113, 181, 72, 0));
          filter: blur(3px);
        }

        .phone {
          width: 258px;
          height: 518px;
          padding: 9px;
          border-radius: 38px;
          background: linear-gradient(145deg, #181818, #020202);
          position: relative;
          z-index: 2;
          box-shadow:
            inset 0 0 0 1px #3a3a3a,
            0 32px 65px rgba(20, 53, 18, 0.23),
            0 8px 20px rgba(0, 0, 0, 0.20);
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
          background:
            linear-gradient(180deg, #f5faf2, #ffffff);
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
          background: linear-gradient(135deg, #55aadd, #2274b5);
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

        /* ABOUT */

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

        /* FEATURES */

        .why {
          padding: 78px var(--page-pad) 88px;
          background:
            linear-gradient(180deg, #f8fbf6 0%, #f3f8ef 100%);
          scroll-margin-top: 82px;
        }

        .feature-grid {
          margin-top: 38px;
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
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
          background: linear-gradient(145deg, #e9f5e3, #f7fbf4);
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

        /* STATS */

        .stats {
          padding: 30px var(--page-pad);
          background: linear-gradient(135deg, #086226, #034519);
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
          border-right: 1px solid rgba(255, 255, 255, 0.18);
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

        /* CONTACT */

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
            radial-gradient(circle at 100% 0, rgba(125, 190, 80, 0.18), transparent 26%),
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

        /* FOOTER */

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

        /* RESPONSIVE */

        @media (max-width: 1120px) {
          .hero-inner {
            grid-template-columns: minmax(0, 1fr) 300px;
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
            grid-template-columns: repeat(2, minmax(0, 1fr));
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
            border-bottom: 1px solid rgba(255, 255, 255, 0.14);
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
            border-bottom: 1px solid rgba(255, 255, 255, 0.14);
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
      `}</style>

      <main className="page">
        <nav className="nav">
          <div className="nav-inner">
            <Logo onNavClick={handleNavClick} />

            <div className="nav-right">
              <div className={`nav-links ${mobileNavOpen ? "open" : ""}`}>
                {navItems.map(([id, label]) => (
                  <a
                    key={id}
                    className={activeSection === id ? "active" : ""}
                    href={`#${id}`}
                    onClick={(e) => handleNavClick(e, id)}
                  >
                    {label}
                  </a>
                ))}
              </div>

              <button
                type="button"
                className="admin-button"
                onClick={() => navigate("/login")}
              >
                <Icon name="user" size={17} />
                <span>Admin Portal</span>
              </button>

              <button
                type="button"
                className="mobile-toggle"
                aria-label="Toggle navigation"
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
                Smart agriculture for real farm decisions
              </div>

              <h1 className="hero-title">
                AGRHI
                <span>Your Smart Farm Assistant</span>
              </h1>

              <p>
                Bring crop care, AI disease detection, local weather, farm
                management and agricultural marketplace tools together in one
                multilingual, offline-first mobile experience.
              </p>

              <div className="hero-highlights">
                {[
                  "AI-powered Plant Doctor",
                  "7 languages",
                  "Offline-first",
                  "Farmer-focused",
                ].map((item) => (
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
                    <strong>Get AGRHI App</strong>
                    <small>Android application</small>
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
                    <strong>User Manual</strong>
                    <small>View documentation</small>
                  </span>
                </a>

                <button
                  type="button"
                  className="action-card ghost"
                  onClick={(e) => handleNavClick(e, "features")}
                >
                  <Icon name="leaf" size={20} />
                  <span className="action-label">
                    <strong>Explore Features</strong>
                    <small>See what AGRHI offers</small>
                  </span>
                </button>
              </div>
            </div>

            <PhoneMockup screenshots={phoneScreenshots} />
          </div>
        </section>

        <section className="about" id="about">
          <div className="section-shell">
            <div className="section-kicker">About AGRHI</div>
            <h2 className="section-title">
              Agriculture, technology and accessibility in one platform
            </h2>

            <p className="section-copy">
              AGRHI is designed to help farmers and agricultural stakeholders
              make faster, data-informed decisions. It combines practical farm
              tools with AI-assisted crop disease detection, local weather,
              multilingual support and an integrated marketplace—while keeping
              low-connectivity rural use in mind.
            </p>

            <div className="about-points">
              <div className="about-point">
                <div className="about-point-icon">
                  <Icon name="leaf" size={21} />
                </div>
                <div>
                  <strong>Built around farm workflows</strong>
                  <span>
                    Crop care, farms, irrigation and plant-health tools are
                    organized around practical agricultural use.
                  </span>
                </div>
              </div>

              <div className="about-point">
                <div className="about-point-icon">
                  <Icon name="globe" size={21} />
                </div>
                <div>
                  <strong>Designed for accessibility</strong>
                  <span>
                    Multilingual support and offline-first behavior help AGRHI
                    remain useful across different regions and connectivity
                    levels.
                  </span>
                </div>
              </div>

              <div className="about-point">
                <div className="about-point-icon">
                  <Icon name="shield" size={21} />
                </div>
                <div>
                  <strong>Responsible data handling</strong>
                  <span>
                    AGRHI provides privacy controls, secure authentication and
                    clear account-deletion options for users.
                  </span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="why" id="features">
          <div className="section-shell">
            <div className="section-kicker">Core Capabilities</div>
            <h2 className="section-title">
              Everything farmers need, in one app
            </h2>

            <p className="section-copy">
              AGRHI connects everyday farm management with intelligent
              assistance so users can move from information to action quickly.
            </p>

            <div className="feature-grid">
              {features.map((feature) => (
                <article className="feature-card" key={feature.title}>
                  <div className="feature-icon">
                    <Icon name={feature.icon} size={27} />
                  </div>
                  <h3>{feature.title}</h3>
                  <p>{feature.text}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="stats">
          <div className="stats-inner">
            {stats.map((stat) => (
              <div className="stat" key={stat.label}>
                <div className="stat-icon">
                  <Icon name={stat.icon} size={23} />
                </div>
                <div>
                  <b>{stat.value}</b>
                  <span>{stat.label}</span>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="contact" id="contact">
          <div className="section-shell">
            <div className="section-kicker">Contact & Support</div>
            <h2 className="section-title">Need help with AGRHI?</h2>

            <div className="contact-wrap">
              <div className="contact-copy">
                <h3>We're here to help</h3>
                <p>
                  For app support, privacy questions, account requests or
                  general enquiries, contact the AGRHI support team.
                </p>
              </div>

              <div className="contact-actions">
                <a className="contact-action" href="mailto:support@farmlead.in">
                  <Icon name="mail" size={19} />
                  support@farmlead.in
                </a>

                <div className="contact-action">
                  <Icon name="pin" size={19} />
                  Chennai, Tamil Nadu, India
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
                <strong>AGRHI by Farmlead</strong>
                <span>Leading the Future of Agriculture.</span>
              </div>
            </div>

            <div className="footer-links">
              <a href="/privacy">Privacy Policy</a>
              <a href="/delete-account">Delete Account</a>
              <a href="mailto:support@farmlead.in">Support</a>
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
                Admin Login
              </button>
            </div>
          </div>

          <div className="footer-bottom">
            © {new Date().getFullYear()} AGRHI • Erasmus+ AGRHI Programme
          </div>
        </footer>
      </main>
    </>
  );
}
