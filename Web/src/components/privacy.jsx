import React from "react";
import { useNavigate } from "react-router-dom";

const LOGO_SRC = "/logo.png";

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

export default function Privacy() {
  const navigate = useNavigate();

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
          position: sticky;
          top: 0;
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
          top: 100px;
        }

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

      <main className="privacy-page">
        <nav className="privacy-nav">
          <div className="privacy-nav-inner">
            <button
              type="button"
              className="privacy-logo"
              onClick={() => navigate("/")}
              aria-label="Go to AGRHI home"
            >
              <div className="privacy-logo-mark">
                <img src={LOGO_SRC} alt="AGRHI logo" />
              </div>

              <div className="privacy-logo-copy">
                <span className="privacy-logo-name">Farmlead</span>
                <span className="privacy-logo-tag">
                  Leading the Future of Agriculture.
                </span>
              </div>
            </button>

            <button
              type="button"
              className="home-button"
              onClick={() => navigate("/")}
            >
              <Icon name="home" size={18} />
              <span>Back to Home</span>
            </button>
          </div>
        </nav>

        <section className="privacy-hero">
          <div className="privacy-hero-inner">
            <div>
              <div className="privacy-badge">
                <Icon name="leaf" size={16} />
                AGRHI Privacy & Data Protection
              </div>

              <h1 className="privacy-title">
                Your privacy
                <span>matters to AGRHI.</span>
              </h1>

              <p className="privacy-description">
                This Privacy Policy explains how the AGRHI mobile application
                collects, uses, stores, shares, and protects personal and device
                data when you use our services.
              </p>

              <div className="effective-date">
                Effective Date: April 2026&nbsp;&nbsp;•&nbsp;&nbsp;Last
                reviewed: August 2026
              </div>
            </div>

            <div className="hero-security-card">
              <div className="hero-security-icon">
                <Icon name="shield" size={31} />
              </div>

              <h3>Privacy built around transparency</h3>

              <p>
                AGRHI explains what data is needed, why it is used, when it may
                be shared, how long it may be retained, and how you can request
                deletion or other privacy actions.
              </p>
            </div>
          </div>
        </section>

        <section className="privacy-content">
          <div className="privacy-main-grid">
            <div className="policy-column">
              {policySections.map((section) => (
                <article
                  className="policy-card"
                  id={section.id}
                  key={section.id}
                >
                  <div className="policy-heading">
                    <div className="policy-icon">
                      <Icon name={section.icon} size={23} />
                    </div>

                    <h2>{section.title}</h2>
                  </div>

                  <div className="policy-body">{section.content}</div>
                </article>
              ))}
            </div>

            <aside className="side-column">
              <div className="side-card">
                <div className="side-title">
                  <div className="side-title-icon">
                    <Icon name="shield" size={20} />
                  </div>
                  <h3>Privacy at a glance</h3>
                </div>

                <ul className="summary-list">
                  {[
                    "We do not sell personal data.",
                    "HTTPS/TLS protects data in transit.",
                    "Passwords are stored as hashes.",
                    "Location is used only for location-based features.",
                    "No continuous background location tracking.",
                    "No tracking cookies or advertising identifiers.",
                    "Account and data deletion can be requested.",
                  ].map((item) => (
                    <li key={item}>
                      <span className="summary-check">
                        <Icon name="check" size={12} />
                      </span>
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              </div>

              <div className="side-card quick-links-card">
                <div className="side-title">
                  <div className="side-title-icon">
                    <Icon name="database" size={20} />
                  </div>
                  <h3>Policy sections</h3>
                </div>

                <div className="quick-links">
                  {policySections.map((section) => (
                    <a key={section.id} href={`#${section.id}`}>
                      {section.title}
                    </a>
                  ))}
                </div>
              </div>

              <div className="side-card deletion-card">
                <div className="side-title">
                  <div className="side-title-icon">
                    <Icon name="trash" size={20} />
                  </div>
                  <h3>Delete your account</h3>
                </div>

                <p>
                  AGRHI users can request deletion of their account and
                  associated data through the dedicated web deletion page.
                </p>

                <a className="deletion-link" href="/delete-account">
                  Open Account Deletion
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
                <h3>Questions about your privacy?</h3>
                <p>
                  Contact AGRHI for privacy questions, data requests, or
                  concerns.
                </p>
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
          Privacy Policy • Erasmus+ AGRHI Programme
        </footer>
      </main>
    </>
  );
}
