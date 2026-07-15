import React, { useEffect, useMemo, useState, useCallback } from "react";
import { useNavigate } from "react-router-dom";

/*
  Put phone screenshots here.

  Recommended folder:
    public/screenshots/Screenshot_1770874638.png

  Then this is enough:
    "Screenshot_1770874638.png"

  You may also use:
    "/screenshots/Screenshot_1770874638.png"

  Do not use Windows local paths like:
    C:\\Users\\...\\image.png
  Browsers cannot safely load those from a React page.
*/
const PHONE_SCREENSHOTS = [
  "Screenshot_1770874638.png",
  "Screenshot_1783914450.png",
  "Screenshot_1770874676.png",
  "Screenshot_20260127_131342.jpg",
  "Screenshot_20260127_131246.jpg",
  "Screenshot_20260127_131426.jpg",
];

const APP_DOWNLOAD_URL =
  "https://drive.google.com/file/d/1evqNQ1h23RKYOE0sE6F9oQkMPrgbBmJn/view";

const USER_MANUAL_URL = "user_manual.pptx";

// Put your logo file inside the public folder, e.g. public/logo.png
const LOGO_SRC = "/logo.png";

const features = [
  {
    icon: "leaf",
    title: "AI Disease Detection",
    text: "Detect crop diseases using AI-powered image recognition models.",
  },
  {
    icon: "tractor",
    title: "Crop & Farm Management",
    text: "Manage farms, crops, irrigation, soil and water resources efficiently.",
  },
  {
    icon: "cloud",
    title: "Weather Updates",
    text: "Get real-time weather updates and forecasts for better decisions.",
  },
  {
    icon: "store",
    title: "Marketplace",
    text: "Buy and sell agricultural products directly from farmers and retailers.",
  },
  {
    icon: "book",
    title: "Multilingual Support",
    text: "Available in 7 languages for a better and inclusive user experience.",
  },
  {
    icon: "wifi",
    title: "Offline First",
    text: "Works seamlessly even in low connectivity areas with offline support.",
  },
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
        <path d="m3 3 18 18" />
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
        <span className="logo-name">CropLens</span>
        <span className="logo-tag">Smart Agriculture for a Better Future</span>
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
      <div className="app-header">
        <strong>AGRHI</strong>
        <span />
      </div>

      <div className="weather-card">
        <div>
          <span>Weather</span>
          <strong>28 C</strong>
          <small>Partly Cloudy</small>
          <small>Coimbatore, India</small>
        </div>
        <div className="weather-symbol">Cloudy</div>
      </div>

      <div className="profile-card">
        <div className="profile-dot" />
        <div>
          <strong>Profile</strong>
          <span>View your profile</span>
        </div>
        <b>{">"}</b>
      </div>

      <h4>Features</h4>

      <div className="mini-grid">
        <div>
          <Icon name="leaf" size={22} />
          <strong>Plant Doctor</strong>
          <span>Disease Detection</span>
        </div>
        <div>
          <Icon name="tractor" size={22} />
          <strong>Crop Care</strong>
          <span>Manager</span>
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
        <div>
          <Icon name="book" size={22} />
          <strong>Farms</strong>
          <span>My Farms</span>
        </div>
        <div>
          <strong className="dots">...</strong>
          <span>More</span>
        </div>
      </div>

      <div className="bottom-nav">
        <span>Home</span>
        <span>Farms</span>
        <b>+</b>
        <span>Alerts</span>
        <span>Profile</span>
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
    }, 2600);

    return () => window.clearInterval(timer);
  }, [visibleScreenshots.length]);

  useEffect(() => {
    if (active >= visibleScreenshots.length) setActive(0);
  }, [active, visibleScreenshots.length]);

  return (
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
                setBroken((current) => ({ ...current, [brokenSrc]: true }))
              }
            />
          ))
        ) : (
          <PhoneFallback />
        )}
      </div>
    </div>
  );
}

export default function Home() {
  const navigate = useNavigate();
  const [activeSection, setActiveSection] = useState("home");

  const phoneScreenshots = useMemo(
    () => PHONE_SCREENSHOTS.map((src) => String(src).trim()).filter(Boolean),
    [],
  );

  const handleNavClick = useCallback((e, id) => {
    e.preventDefault();
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "start" });
      setActiveSection(id);
    }
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
      { rootMargin: "-45% 0px -50% 0px", threshold: 0 },
    );

    sections.forEach((el) => observer.observe(el));

    return () => observer.disconnect();
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
          --text: #111811;
          --muted: #666f65;
          --line: #dfe5dd;
          --white: #ffffff;
          --shadow-soft: 0 14px 34px rgba(30, 55, 24, 0.14);
          --shadow-green: 0 14px 28px rgba(0, 88, 28, 0.22);
          --page-pad: clamp(24px, 4.15vw, 64px);
        }

        * {
          box-sizing: border-box;
        }

        html {
          scroll-behavior: smooth;
          margin: 0;
          padding: 0;
          background: #ffffff;
        }

        body {
          margin: 0;
          font-family: "Inter", Arial, sans-serif;
          color: var(--text);
          background: #ffffff;
          overflow-x: hidden;
          overscroll-behavior-y: none;
        }

        a {
          color: inherit;
          text-decoration: none;
        }

        button {
          font: inherit;
        }

        .page {
          width: 100vw;
          min-height: 100vh;
          margin-left: calc(50% - 50vw);
          margin-right: calc(50% - 50vw);
          background: #ffffff;
          position: relative;
        }

        .nav {
          height: 82px;
          background: #f3f2f2ef;
          border-bottom: 1px solid #dfe5dd;
          box-shadow: 0 2px 12px rgba(0, 0, 0, 0.05);
          position: sticky;
          top: 0;
          z-index: 50;
          isolation: isolate;
        }

        .nav-inner {
          width: calc(100% - (var(--page-pad) * 2));
          height: 82px;
          margin: 0 auto;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 24px;
        }

        .nav-right {
          display: flex;
          align-items: center;
          gap: clamp(24px, 3vw, 100px);
        }

        .logo {
          display: inline-flex;
          align-items: center;
          gap: 13px;
          width: max-content;
        }

        .logo-mark {
          position: relative;
          width: 59px;
          height: 58px;
          flex: 0 0 59px;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .logo-img {
          width: 100%;
          height: 100%;
          object-fit: contain;
          display: block;
        }

        .logo-copy {
          display: flex;
          flex-direction: column;
        }

        .logo-name {
          color: #397d21;
          font-size: 30px;
          font-weight: 900;
          letter-spacing: 0;
          line-height: 0.9;
        }

        .logo-tag {
          margin-top: 6px;
          color: #777d76;
          font-size: 10px;
          white-space: nowrap;
        }

        .nav-links {
          display: flex;
          align-items: center;
          justify-content: flex-end;
          gap: clamp(20px, 2.2vw, 34px);
          height: 100%;
          font-size: 15px;
          font-weight: 700;
          color: #0d120e;
          min-width: 0;
        }

        .nav-links a {
          position: relative;
          display: flex;
          align-items: center;
          height: 100%;
          white-space: nowrap;
          cursor: pointer;
        }

        .nav-links a.active {
          color: var(--green-900);
        }

        .nav-links a.active::after {
          content: "";
          position: absolute;
          left: 50%;
          bottom: 0;
          width: 54px;
          height: 3px;
          border-radius: 999px;
          background: var(--green-700);
          transform: translateX(-50%);
        }

        .admin-button {
          min-height: 44px;
          flex: 0 0 auto;
          border: 0;
          border-radius: 999px;
          padding: 0 24px;
          background: linear-gradient(135deg, #067026, #00551b);
          color: white;
          box-shadow: var(--shadow-green);
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 10px;
          font-size: 15px;
          font-weight: 800;
          cursor: pointer;
          white-space: nowrap;
        }

        .hero {
          min-height: 542px;
          position: relative;
          overflow: hidden;
          scroll-margin-top: 82px;
          background:
            linear-gradient(90deg, rgba(255,255,255,0.98) 0%, rgba(255,255,255,0.91) 31%, rgba(255,255,255,0.43) 57%, rgba(255,255,255,0.72) 100%),
            radial-gradient(circle at 80% 27%, rgba(224, 212, 182, 0.72), transparent 18%),
            linear-gradient(180deg, #fbfcfa 0%, #eef3ea 44%, #dcebcf 45%, #9dcc54 56%, #65a735 71%, #2c7d20 100%);
        }

        .hero::before {
          content: "";
          position: absolute;
          left: -8%;
          right: -8%;
          top: 48%;
          bottom: -19%;
          background:
            repeating-linear-gradient(105deg, rgba(41, 111, 32, 0.28) 0 7px, transparent 7px 48px),
            repeating-linear-gradient(76deg, rgba(255, 255, 255, 0.24) 0 5px, transparent 5px 39px);
          opacity: 0.82;
          filter: blur(1px);
          transform: perspective(580px) rotateX(52deg);
          transform-origin: top;
        }

        .hero::after {
          content: "";
          position: absolute;
          inset: 0;
          background:
            linear-gradient(180deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.01) 72%, #ffffff 100%),
            radial-gradient(circle at 68% 47%, rgba(255,255,255,0.52), transparent 16%);
          pointer-events: none;
        }

        .hero-inner {
          position: relative;
          z-index: 2;
          width: calc(100% - (var(--page-pad) * 2));
          min-height: 542px;
          margin: 0 auto;
          display: grid;
          grid-template-columns: minmax(724px, 760px) 250px minmax(230px, 1fr);
          align-items: center;
          gap: clamp(36px, 3.1vw, 56px);
        }

        .hero-copy {
          padding-top: 8px;
          min-width: 0;
        }

        .hero-title {
          margin: 0;
          color: var(--green-950);
          font-size: clamp(60px, 5.1vw, 78px);
          line-height: 0.94;
          font-weight: 900;
          letter-spacing: 0;
        }

        .hero-title span {
          display: block;
          margin-top: 8px;
          font-size: clamp(34px, 2.55vw, 39px);
          line-height: 1.05;
          font-weight: 800;
        }

        .hero-copy p {
          width: min(580px, 100%);
          margin: 24px 0 27px;
          color: #2c352f;
          font-size: 16.5px;
          line-height: 1.68;
          font-weight: 500;
        }

        .leaf-divider {
          width: 126px;
          margin-bottom: 39px;
          display: flex;
          align-items: center;
          gap: 10px;
          color: var(--green-700);
        }

        .leaf-divider::before,
        .leaf-divider::after {
          content: "";
          height: 2px;
          flex: 1;
          background: var(--green-700);
        }

        .actions {
          display: grid;
          grid-template-columns: repeat(3, 230px);
          gap: 17px;
          align-items: stretch;
        }

        .action-card {
          width: 230px;
          min-height: 108px;
          border-radius: 8px;
          border: 1px solid rgba(0, 0, 0, 0.08);
          padding: 22px 18px;
          display: grid;
          grid-template-columns: 42px minmax(0, 1fr) 18px;
          align-items: center;
          gap: 13px;
          text-align: left;
          box-shadow: var(--shadow-soft);
          cursor: pointer;
          overflow: hidden;
        }

        .action-card svg {
          flex: 0 0 auto;
        }

        .action-copy {
          display: block;
          min-width: 0;
        }

        .action-card h3 {
          margin: 0 0 6px;
          font-size: 16px;
          line-height: 1.12;
          font-weight: 800;
          white-space: normal;
        }

        .action-card p {
          margin: 0;
          font-size: 12px;
          line-height: 1.45;
          font-weight: 500;
          white-space: normal;
          overflow-wrap: anywhere;
        }

        .action-card.dark {
          color: white;
          background: linear-gradient(135deg, #00651f, #004d18);
          border-color: transparent;
        }

        .action-card.mid {
          color: white;
          background: linear-gradient(135deg, #4b9820, #307d16);
          border-color: transparent;
        }

        .action-card.dark h3,
        .action-card.dark p,
        .action-card.mid h3,
        .action-card.mid p {
          color: white;
        }

        .action-card.light {
          color: #103c13;
          background: rgba(255,255,255,0.94);
        }

        .phone-wrap {
          display: flex;
          justify-content: center;
          align-items: center;
          align-self: stretch;
        }

        .phone {
          width: 250px;
          height: 504px;
          border-radius: 34px;
          background: #050505;
          padding: 10px;
          position: relative;
          box-shadow:
            inset 0 0 0 2px #323232,
            0 18px 38px rgba(0, 0, 0, 0.31);
        }

        .speaker {
          position: absolute;
          left: 66px;
          top: 10px;
          width: 118px;
          height: 24px;
          border-radius: 0 0 17px 17px;
          background: #050505;
          z-index: 5;
        }

        .camera {
          position: absolute;
          right: 57px;
          top: 18px;
          width: 5px;
          height: 5px;
          border-radius: 50%;
          background: #1b2430;
          z-index: 6;
        }

        .phone-screen {
          width: 100%;
          height: 100%;
          overflow: hidden;
          border-radius: 26px;
          background: #f8fbf7;
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
          transform: translateX(10px);
          transition: opacity 480ms ease, transform 480ms ease;
          background: #f8fbf7;
        }

        .phone-shot.active {
          opacity: 1;
          transform: translateX(0);
        }

        .phone-fallback {
          height: 100%;
          padding: 42px 14px 44px;
          color: #121812;
          position: relative;
        }

        .app-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 16px;
          font-size: 17px;
        }

        .weather-card {
          min-height: 93px;
          padding: 12px;
          border-radius: 7px;
          color: white;
          background: linear-gradient(135deg, #72c4e5, #1d78b4);
          display: flex;
          justify-content: space-between;
          box-shadow: 0 8px 16px rgba(0,0,0,0.12);
        }

        .weather-card span,
        .weather-card small {
          display: block;
          font-size: 9px;
          line-height: 1.25;
        }

        .weather-card strong {
          display: block;
          margin: 3px 0;
          font-size: 28px;
          line-height: 1;
        }

        .weather-symbol {
          align-self: center;
          font-size: 10px;
          font-weight: 800;
        }

        .profile-card {
          margin-top: 10px;
          padding: 10px;
          border-radius: 8px;
          background: #eef8eb;
          display: flex;
          align-items: center;
          gap: 10px;
          box-shadow: 0 5px 12px rgba(31,64,28,0.1);
        }

        .profile-dot {
          width: 26px;
          height: 26px;
          border-radius: 50%;
          background: #bfe6b8;
          position: relative;
        }

        .profile-dot::after {
          content: "";
          position: absolute;
          inset: 9px;
          border-radius: 50%;
          background: var(--green-700);
        }

        .profile-card div:nth-child(2) {
          flex: 1;
        }

        .profile-card strong,
        .profile-card span {
          display: block;
        }

        .profile-card strong {
          font-size: 11px;
        }

        .profile-card span {
          font-size: 8px;
          color: #536052;
        }

        .phone-fallback h4 {
          margin: 14px 0 8px;
          font-size: 11px;
        }

        .mini-grid {
          display: grid;
          grid-template-columns: repeat(3, 1fr);
          gap: 8px;
        }

        .mini-grid div {
          min-height: 64px;
          padding: 7px 4px;
          border-radius: 7px;
          background: white;
          border: 1px solid #e4e9e2;
          box-shadow: 0 4px 10px rgba(0,0,0,0.07);
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          text-align: center;
          color: var(--green-700);
        }

        .mini-grid strong {
          margin-top: 4px;
          color: #111;
          font-size: 8px;
          line-height: 1.1;
        }

        .mini-grid span {
          margin-top: 2px;
          color: #555;
          font-size: 6px;
          line-height: 1.1;
        }

        .mini-grid .dots {
          margin: 0;
          color: #333;
          font-size: 14px;
        }

        .bottom-nav {
          position: absolute;
          left: 0;
          right: 0;
          bottom: 0;
          height: 42px;
          background: white;
          border-top: 1px solid #e7ebe5;
          display: grid;
          grid-template-columns: repeat(5, 1fr);
          align-items: center;
          text-align: center;
          font-size: 7px;
          color: #263026;
        }

        .bottom-nav b {
          width: 34px;
          height: 34px;
          margin: -14px auto 0;
          border-radius: 50%;
          background: var(--green-700);
          color: white;
          display: grid;
          place-items: center;
          font-size: 15px;
          box-shadow: 0 8px 14px rgba(47,125,31,0.25);
        }

        .hero-side {
          padding-top: 70px;
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 28px;
          text-align: center;
          color: #073f15;
          font-size: 16px;
          font-weight: 800;
          line-height: 1.45;
        }

        .side-icon {
          width: 72px;
          height: 72px;
          border-radius: 50%;
          background: white;
          color: var(--green-700);
          display: grid;
          place-items: center;
          box-shadow: var(--shadow-soft);
        }

        .side-text {
          width: 255px;
        }

        .about {
          background: #ffffff;
          padding: 60px 0 40px;
          scroll-margin-top: 82px;
        }

        .about-text {
          width: min(760px, calc(100% - (var(--page-pad) * 2)));
          margin: 0 auto;
          text-align: center;
          font-size: 15.5px;
          line-height: 1.75;
          color: #2c352f;
          font-weight: 500;
        }

        .why {
          background: #ffffff;
          padding: 20px 0 28px;
          scroll-margin-top: 82px;
        }

        .section-title {
          margin: 0;
          color: var(--green-950);
          text-align: center;
          font-size: 30px;
          line-height: 1.1;
          font-weight: 900;
        }

        .title-divider {
          margin: 10px auto 20px;
          width: 178px;
          color: var(--green-700);
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 9px;
        }

        .title-divider::before,
        .title-divider::after {
          content: "";
          width: 72px;
          height: 1.5px;
          background: var(--green-700);
        }

        .feature-grid {
          width: calc(100% - (var(--page-pad) * 2));
          margin: 0 auto;
          display: grid;
          grid-template-columns: repeat(6, minmax(0, 1fr));
          gap: 24px;
        }

        .feature-card {
          min-height: 194px;
          padding: 24px 18px;
          border: 1px solid var(--line);
          border-radius: 7px;
          background: #ffffff;
          text-align: center;
          box-shadow: 0 6px 18px rgba(0,0,0,0.04);
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
        }

        .feature-card svg {
          color: var(--green-700);
          margin-bottom: 18px;
        }

        .feature-card h3 {
          margin: 0 0 10px;
          color: var(--green-950);
          font-size: 14px;
          line-height: 1.25;
          font-weight: 800;
        }

        .feature-card p {
          margin: 0;
          color: #151915;
          font-size: 13px;
          line-height: 1.55;
        }

        .stats {
          padding: 27px 0;
          background: linear-gradient(135deg, #006123, #004c1a);
          color: white;
        }

        .stats-inner {
          width: min(1080px, calc(100% - 96px));
          margin: 0 auto;
          display: grid;
          grid-template-columns: repeat(4, 1fr);
        }

        .stat {
          min-height: 58px;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 18px;
          border-right: 1px solid rgba(255,255,255,0.28);
        }

        .stat:last-child {
          border-right: 0;
        }

        .stat b {
          display: block;
          font-size: 20px;
          line-height: 1.05;
        }

        .stat span {
          display: block;
          margin-top: 4px;
          font-size: 12px;
        }

        .contact {
          padding: 60px 0 60px;
          background: #ffffff;
          scroll-margin-top: 82px;
        }

        .contact-grid {
          width: calc(100% - (var(--page-pad) * 2));
          margin: 0 auto;
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          gap: 20px;
        }

        .contact-card {
          padding: 22px;
          border: 1px solid var(--line);
          border-radius: 7px;
          text-align: center;
          box-shadow: 0 6px 18px rgba(0,0,0,0.04);
        }

        .contact-card strong {
          display: block;
          color: var(--green-950);
          font-size: 14px;
          margin-bottom: 6px;
        }

        .contact-card span {
          font-size: 13px;
          color: #444;
        }

        @media (max-width: 1350px) {
          .hero-inner {
            grid-template-columns: minmax(0, 1fr) 250px;
          }

          .hero-side {
            display: none;
          }

          .actions {
            grid-template-columns: repeat(3, minmax(0, 1fr));
          }

          .action-card {
            width: 100%;
          }
        }

        @media (max-width: 1120px) {
          .nav-links {
            gap: 20px;
            font-size: 14px;
          }

          .hero-inner {
            grid-template-columns: 1fr;
            padding: 34px 0;
            gap: 28px;
          }

          .phone-wrap {
            order: -1;
          }

          .phone {
            margin: 0 auto;
          }

          .actions {
            max-width: 760px;
          }

          .feature-grid {
            grid-template-columns: repeat(3, 1fr);
          }
        }

        @media (max-width: 900px) {
          .nav {
            height: auto;
          }

          .nav-inner {
            height: auto;
            min-height: 82px;
            flex-wrap: wrap;
            padding: 12px 0;
          }

          .nav-right {
            width: 100%;
            flex-wrap: wrap;
            justify-content: flex-start;
            gap: 14px;
          }

          .nav-links {
            order: 2;
            width: 100%;
            justify-content: flex-start;
            overflow-x: auto;
            height: auto;
            padding-top: 4px;
            scrollbar-width: none;
          }

          .nav-links::-webkit-scrollbar {
            display: none;
          }

          .nav-links a {
            height: auto;
            padding: 8px 0 12px;
          }

          .actions {
            grid-template-columns: 1fr;
            max-width: 440px;
          }

          .stats-inner {
            grid-template-columns: repeat(2, 1fr);
            gap: 20px 0;
          }

          .stat:nth-child(2) {
            border-right: 0;
          }

          .contact-grid {
            grid-template-columns: 1fr;
          }
        }

        @media (max-width: 640px) {
          :root {
            --page-pad: 16px;
          }

          .logo-mark {
            width: 48px;
            height: 48px;
            flex-basis: 48px;
            transform: scale(0.86);
            transform-origin: left center;
          }

          .logo-name {
            font-size: 30px;
          }

          .logo-tag {
            font-size: 8px;
          }

          .admin-button {
            order: 1;
            width: 100%;
          }

          .hero {
            min-height: auto;
          }

          .hero-title {
            font-size: 52px;
          }

          .hero-title span {
            font-size: 30px;
          }

          .hero-copy p {
            font-size: 15px;
          }

          .phone {
            width: 232px;
            height: 468px;
          }

          .speaker {
            left: 61px;
            width: 110px;
          }

          .camera {
            right: 54px;
          }

          .feature-grid,
          .stats-inner {
            grid-template-columns: 1fr;
          }

          .stat {
            border-right: 0;
          }
        }
      `}</style>

      <main className="page">
        <nav className="nav">
          <div className="nav-inner">
            <Logo onNavClick={handleNavClick} />

            <div className="nav-right">
              <div className="nav-links">
                <a
                  className={activeSection === "home" ? "active" : ""}
                  href="#home"
                  onClick={(e) => handleNavClick(e, "home")}
                >
                  Home
                </a>
                <a
                  className={activeSection === "contact" ? "active" : ""}
                  href="#contact"
                  onClick={(e) => handleNavClick(e, "contact")}
                >
                  Contact Us
                </a>
              </div>

              <button
                type="button"
                className="admin-button"
                onClick={() => navigate("/login")}
              >
                <Icon name="user" size={18} />
                Admin Portal
              </button>
            </div>
          </div>
        </nav>

        <section className="hero" id="home">
          <div className="hero-inner">
            <div className="hero-copy">
              <h1 className="hero-title">
                AGRHI
                <span>Mobile Application</span>
              </h1>

              <p>
                Empowering farmers and stakeholders with smart tools, AI-driven
                insights, and real-time information for sustainable agriculture.
              </p>

              <div className="leaf-divider">
                <Icon name="leaf" size={17} />
              </div>

              <div className="actions">
                <button
                  type="button"
                  className="action-card dark"
                  onClick={() => navigate("/login")}
                >
                  <Icon name="user" size={38} />
                  <span className="action-copy">
                    <h3>Admin Portal</h3>
                    <p>Access the AGRHI Administration Portal</p>
                  </span>
                  <Icon name="arrow" size={19} />
                </button>

                <a
                  className="action-card mid"
                  href={APP_DOWNLOAD_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <Icon name="android" size={38} />
                  <span className="action-copy">
                    <h3>Download App</h3>
                    <p>Download AGRHI Mobile App (APK)</p>
                  </span>
                  <Icon name="arrow" size={19} />
                </a>

                <a
                  className="action-card light"
                  href={USER_MANUAL_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <Icon name="file" size={38} />
                  <span className="action-copy">
                    <h3>User Manual</h3>
                    <p>Download User Manual (PDF)</p>
                  </span>
                  <Icon name="arrow" size={19} />
                </a>
              </div>
            </div>

            <div className="phone-wrap">
              <PhoneMockup screenshots={phoneScreenshots} />
            </div>

            <div className="hero-side">
              <div className="side-icon">
                <Icon name="leaf" size={38} />
              </div>

              <div className="side-text">
                Bridging the gap between agriculture, technology and
                sustainability.
              </div>
            </div>
          </div>
        </section>

        <section className="about" id="about">
          <h2 className="section-title">About AGRHI</h2>

          <div className="title-divider">
            <Icon name="leaf" size={15} />
          </div>

          <p className="about-text">
            AGRHI is a smart agriculture platform built to bridge the gap
            between farmers, technology, and sustainability. It combines
            AI-driven crop disease detection, real-time weather intelligence,
            farm and irrigation management tools, and an integrated marketplace
            to help farmers make faster, data-backed decisions even in
            low-connectivity rural regions. With support for multiple languages
            and an offline-first design, AGRHI is built to serve every farmer,
            everywhere.
          </p>
        </section>

        <section className="why" id="features">
          <h2 className="section-title">Why AGRHI?</h2>

          <div className="title-divider">
            <Icon name="leaf" size={15} />
          </div>

          <div className="feature-grid">
            {features.map((feature) => (
              <article className="feature-card" key={feature.title}>
                <Icon name={feature.icon} size={36} />
                <h3>{feature.title}</h3>
                <p>{feature.text}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="stats">
          <div className="stats-inner">
            <div className="stat">
              <Icon name="brain" size={42} />
              <div>
                <b>10+</b>
                <span>AI Models for Crops</span>
              </div>
            </div>

            <div className="stat">
              <Icon name="globe" size={42} />
              <div>
                <b>7</b>
                <span>Supported Languages</span>
              </div>
            </div>

            <div className="stat">
              <Icon name="cloud" size={42} />
              <div>
                <b>Offline</b>
                <span>First Architecture</span>
              </div>
            </div>

            <div className="stat">
              <Icon name="shield" size={42} />
              <div>
                <b>Secure</b>
                <span>& Reliable</span>
              </div>
            </div>
          </div>
        </section>

        <section className="contact" id="contact">
          <h2 className="section-title">Contact Us</h2>

          <div className="title-divider">
            <Icon name="leaf" size={15} />
          </div>

          <div className="contact-grid">
            <div className="contact-card">
              <strong>Email</strong>
              <span>projectagrhi@gmail.com</span>
            </div>

            <div className="contact-card">
              <strong>Phone</strong>
              <span>+91 00000 00000</span>
            </div>

            <div className="contact-card">
              <strong>Location</strong>
              <span>Chennai, Tamil Nadu, India</span>
            </div>
          </div>
        </section>
      </main>
    </>
  );
}
