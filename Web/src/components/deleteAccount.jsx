import React, { useState } from "react";
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

    trash: (
      <>
        <path d="M3 6h18" />
        <path d="M8 6V4h8v2" />
        <path d="M19 6l-1 14H6L5 6" />
        <path d="M10 11v5" />
        <path d="M14 11v5" />
      </>
    ),

    shield: (
      <>
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" />
        <path d="m9 12 2 2 4-5" />
      </>
    ),

    mail: (
      <>
        <rect x="3" y="5" width="18" height="14" rx="2" />
        <path d="m3 7 9 6 9-6" />
      </>
    ),

    database: (
      <>
        <ellipse cx="12" cy="5" rx="8" ry="3" />
        <path d="M4 5v6c0 1.7 3.6 3 8 3s8-1.3 8-3V5" />
        <path d="M4 11v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6" />
      </>
    ),

    check: <path d="m5 12 4 4L19 6" />,

    arrow: <path d="m9 18 6-6-6-6" />,

    home: (
      <>
        <path d="m3 11 9-8 9 8" />
        <path d="M5 10v10h14V10" />
        <path d="M9 20v-6h6v6" />
      </>
    ),
  };

  return <svg {...props}>{icons[name]}</svg>;
}

export default function DeleteAccount() {
  const navigate = useNavigate();

  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState({
    type: "",
    message: "",
  });

  const handleSubmit = async (e) => {
    e.preventDefault();

    setStatus({
      type: "",
      message: "",
    });

    try {
      setLoading(true);

      const response = await fetch("/api/users/delete-account-request", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email: email.trim(),
        }),
      });

      let data = {};

      try {
        data = await response.json();
      } catch {
        data = {};
      }

      if (!response.ok) {
        throw new Error(
          data.message || "Unable to submit your account deletion request.",
        );
      }

      setStatus({
        type: "success",
        message:
          data.message ||
          "Your account deletion request has been submitted successfully.",
      });

      setEmail("");
    } catch (error) {
      setStatus({
        type: "error",
        message:
          error.message ||
          "Something went wrong while submitting your request.",
      });
    } finally {
      setLoading(false);
    }
  };

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
          --danger: #b42318;
          --danger-bg: #fff4f2;
          --success: #176b2c;
          --success-bg: #edf9ee;
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
        }

        body {
          margin: 0;
          font-family: "Inter", Arial, sans-serif;
          color: var(--text);
          background: #f6f7f4;
        }

        button,
        input {
          font: inherit;
        }

        .delete-page {
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

        /* ---------------- NAVBAR ---------------- */

        .delete-nav {
          height: 82px;
          background: rgba(243, 242, 242, 0.96);
          border-bottom: 1px solid #dfe5dd;
          box-shadow: 0 2px 12px rgba(0, 0, 0, 0.05);
          position: sticky;
          top: 0;
          z-index: 50;
          backdrop-filter: blur(12px);
        }

        .delete-nav-inner {
          width: calc(100% - (var(--page-pad) * 2));
          height: 100%;
          margin: 0 auto;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 20px;
        }

        .delete-logo {
          display: inline-flex;
          align-items: center;
          gap: 13px;
          cursor: pointer;
          border: 0;
          background: transparent;
          padding: 0;
          color: inherit;
        }

        .delete-logo-mark {
          width: 58px;
          height: 58px;
          flex: 0 0 58px;
          border-radius: 50%;
          overflow: hidden;
          background: white;
          border: 1px solid #dfe5dd;
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06);
        }

        .delete-logo-mark img {
          width: 100%;
          height: 100%;
          object-fit: cover;
          display: block;
        }

        .delete-logo-copy {
          display: flex;
          flex-direction: column;
          text-align: left;
        }

        .delete-logo-name {
          color: #397d21;
          font-size: 30px;
          line-height: 0.9;
          font-weight: 900;
        }

        .delete-logo-tag {
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

        /* ---------------- HERO ---------------- */

        .delete-hero {
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

        .delete-hero::before {
          content: "";
          position: absolute;
          width: 520px;
          height: 520px;
          right: -110px;
          top: -190px;
          border-radius: 50%;
          background: rgba(86, 152, 48, 0.12);
        }

        .delete-hero::after {
          content: "";
          position: absolute;
          width: 380px;
          height: 380px;
          right: 115px;
          bottom: -270px;
          border-radius: 50%;
          background: rgba(0, 85, 27, 0.08);
        }

        .delete-hero-inner {
          max-width: 1160px;
          margin: 0 auto;
          position: relative;
          z-index: 2;
          display: grid;
          grid-template-columns: minmax(0, 1.25fr) minmax(280px, 0.75fr);
          gap: 70px;
          align-items: center;
        }

        .delete-badge {
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

        .delete-title {
          margin: 0;
          max-width: 700px;
          color: var(--green-950);
          font-size: clamp(42px, 5vw, 68px);
          line-height: 0.98;
          font-weight: 900;
          letter-spacing: -1.8px;
        }

        .delete-title span {
          display: block;
          color: #377f20;
        }

        .delete-description {
          max-width: 670px;
          margin: 24px 0 0;
          color: #425042;
          font-size: 16px;
          line-height: 1.75;
          font-weight: 500;
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

        /* ---------------- MAIN CONTENT ---------------- */

        .delete-content {
          max-width: 1160px;
          margin: -62px auto 0;
          padding: 0 var(--page-pad) 75px;
          position: relative;
          z-index: 5;
        }

        .delete-main-grid {
          display: grid;
          grid-template-columns: minmax(0, 1.15fr) minmax(300px, 0.85fr);
          gap: 28px;
          align-items: start;
        }

        .request-card,
        .info-card {
          background: rgba(255, 255, 255, 0.97);
          border: 1px solid #e1e7df;
          box-shadow: var(--shadow-soft);
        }

        .request-card {
          padding: 38px;
          border-radius: 20px;
        }

        .card-heading {
          display: flex;
          align-items: flex-start;
          gap: 16px;
          margin-bottom: 28px;
        }

        .card-heading-icon {
          width: 52px;
          height: 52px;
          border-radius: 15px;
          flex: 0 0 52px;
          display: grid;
          place-items: center;
          background: var(--green-100);
          color: var(--green-800);
        }

        .card-heading h2 {
          margin: 0;
          color: var(--green-950);
          font-size: 25px;
          line-height: 1.2;
        }

        .card-heading p {
          margin: 7px 0 0;
          color: var(--muted);
          line-height: 1.6;
          font-size: 14px;
        }

        .steps {
          display: grid;
          grid-template-columns: repeat(3, 1fr);
          gap: 12px;
          margin-bottom: 32px;
        }

        .step {
          min-height: 116px;
          padding: 18px;
          border-radius: 14px;
          background: #f8faf7;
          border: 1px solid #e3e9e1;
        }

        .step-number {
          width: 29px;
          height: 29px;
          border-radius: 50%;
          background: var(--green-800);
          color: white;
          display: grid;
          place-items: center;
          font-size: 12px;
          font-weight: 800;
          margin-bottom: 12px;
        }

        .step strong {
          display: block;
          margin-bottom: 5px;
          color: #173d18;
          font-size: 13px;
        }

        .step span {
          color: #647064;
          font-size: 12px;
          line-height: 1.5;
        }

        .form-section {
          padding-top: 4px;
        }

        .form-label {
          display: block;
          margin-bottom: 9px;
          color: #253526;
          font-size: 13px;
          font-weight: 800;
        }

        .input-wrap {
          position: relative;
        }

        .input-icon {
          position: absolute;
          left: 15px;
          top: 50%;
          transform: translateY(-50%);
          color: #718071;
          pointer-events: none;
        }

        .email-input {
          width: 100%;
          min-height: 54px;
          padding: 0 16px 0 48px;
          border-radius: 11px;
          border: 1px solid #ced8cb;
          outline: none;
          color: #182318;
          background: white;
          font-size: 15px;
          transition:
            border-color 0.2s ease,
            box-shadow 0.2s ease;
        }

        .email-input::placeholder {
          color: #9ba49a;
        }

        .email-input:focus {
          border-color: var(--green-700);
          box-shadow: 0 0 0 4px rgba(47, 125, 31, 0.1);
        }

        .privacy-note {
          margin: 12px 0 20px;
          color: #788278;
          font-size: 12px;
          line-height: 1.55;
        }

        .submit-button {
          width: 100%;
          min-height: 53px;
          border: 0;
          border-radius: 11px;
          padding: 0 22px;
          background: linear-gradient(135deg, #087027, #00551b);
          color: white;
          font-size: 15px;
          font-weight: 800;
          cursor: pointer;
          box-shadow: var(--shadow-green);
          display: flex;
          justify-content: center;
          align-items: center;
          gap: 9px;
          transition:
            transform 0.2s ease,
            opacity 0.2s ease;
        }

        .submit-button:hover:not(:disabled) {
          transform: translateY(-1px);
        }

        .submit-button:disabled {
          opacity: 0.65;
          cursor: not-allowed;
        }

        .status-message {
          margin-top: 18px;
          padding: 14px 16px;
          border-radius: 10px;
          display: flex;
          align-items: flex-start;
          gap: 10px;
          font-size: 13px;
          line-height: 1.5;
        }

        .status-message.success {
          color: var(--success);
          background: var(--success-bg);
          border: 1px solid #cce9d0;
        }

        .status-message.error {
          color: var(--danger);
          background: var(--danger-bg);
          border: 1px solid #f1cfca;
        }

        /* ---------------- RIGHT SIDE ---------------- */

        .side-column {
          display: flex;
          flex-direction: column;
          gap: 20px;
        }

        .info-card {
          border-radius: 18px;
          padding: 27px;
        }

        .info-title {
          display: flex;
          align-items: center;
          gap: 12px;
          color: var(--green-950);
          margin-bottom: 18px;
        }

        .info-title-icon {
          width: 39px;
          height: 39px;
          border-radius: 11px;
          display: grid;
          place-items: center;
          color: var(--green-700);
          background: var(--green-100);
        }

        .info-title h3 {
          margin: 0;
          font-size: 17px;
        }

        .data-list {
          list-style: none;
          padding: 0;
          margin: 0;
          display: flex;
          flex-direction: column;
          gap: 13px;
        }

        .data-list li {
          display: flex;
          align-items: flex-start;
          gap: 10px;
          color: #505b50;
          font-size: 13px;
          line-height: 1.55;
        }

        .list-check {
          width: 22px;
          height: 22px;
          flex: 0 0 22px;
          border-radius: 50%;
          margin-top: 1px;
          color: var(--green-700);
          background: #edf7e9;
          display: grid;
          place-items: center;
        }

        .retention-card {
          background: #fbfcfa;
        }

        .retention-card p {
          margin: 0;
          color: #5e685e;
          font-size: 13px;
          line-height: 1.7;
        }

        /* ---------------- SUPPORT ---------------- */

        .support-card {
          max-width: 1160px;
          margin: 28px auto 0;
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
          display: inline-flex;
          align-items: center;
          gap: 7px;
        }

        /* ---------------- FOOTER ---------------- */

        .delete-footer {
          padding: 28px var(--page-pad);
          border-top: 1px solid #e1e6df;
          background: #f4f6f2;
          text-align: center;
          color: #737c72;
          font-size: 12px;
          line-height: 1.6;
        }

        .delete-footer strong {
          color: var(--green-800);
        }

        /* ---------------- RESPONSIVE ---------------- */

        @media (max-width: 950px) {
          .delete-hero-inner,
          .delete-main-grid {
            grid-template-columns: 1fr;
          }

          .delete-hero {
            padding-bottom: 105px;
          }

          .hero-security-card {
            max-width: 520px;
          }

          .steps {
            grid-template-columns: 1fr;
          }
        }

        @media (max-width: 640px) {
          :root {
            --page-pad: 16px;
          }

          .delete-nav {
            height: 74px;
          }

          .delete-logo-mark {
            width: 48px;
            height: 48px;
            flex-basis: 48px;
          }

          .delete-logo-name {
            font-size: 25px;
          }

          .delete-logo-tag {
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

          .delete-hero {
            padding-top: 48px;
            padding-bottom: 92px;
          }

          .delete-title {
            font-size: 42px;
            letter-spacing: -1px;
          }

          .delete-description {
            font-size: 14px;
          }

          .delete-content {
            margin-top: -48px;
          }

          .request-card {
            padding: 23px 18px;
            border-radius: 16px;
          }

          .card-heading h2 {
            font-size: 21px;
          }

          .info-card {
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

      <main className="delete-page">
        {/* HEADER */}
        <nav className="delete-nav">
          <div className="delete-nav-inner">
            <button
              type="button"
              className="delete-logo"
              onClick={() => navigate("/")}
              aria-label="Go to AGRHI home"
            >
              <div className="delete-logo-mark">
                <img src={LOGO_SRC} alt="AGRHI logo" />
              </div>

              <div className="delete-logo-copy">
                <span className="delete-logo-name">Farmlead</span>
                <span className="delete-logo-tag">
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

        {/* HERO */}
        <section className="delete-hero">
          <div className="delete-hero-inner">
            <div>
              <div className="delete-badge">
                <Icon name="leaf" size={16} />
                AGRHI Account Management
              </div>

              <h1 className="delete-title">
                Delete your
                <span>AGRHI account.</span>
              </h1>

              <p className="delete-description">
                You can request permanent deletion of your AGRHI account and the
                personal information associated with it. We may verify your
                identity before processing the request to protect your account
                from unauthorized deletion.
              </p>
            </div>

            <div className="hero-security-card">
              <div className="hero-security-icon">
                <Icon name="shield" size={31} />
              </div>

              <h3>Your account security matters</h3>

              <p>
                AGRHI may contact you using your registered contact details to
                verify that the deletion request was submitted by the account
                owner.
              </p>
            </div>
          </div>
        </section>

        {/* CONTENT */}
        <section className="delete-content">
          <div className="delete-main-grid">
            {/* FORM */}
            <div className="request-card">
              <div className="card-heading">
                <div className="card-heading-icon">
                  <Icon name="trash" size={25} />
                </div>

                <div>
                  <h2>Request account deletion</h2>
                  <p>
                    Submit the email address registered with your AGRHI account.
                  </p>
                </div>
              </div>

              <div className="steps">
                <div className="step">
                  <div className="step-number">1</div>
                  <strong>Submit request</strong>
                  <span>
                    Enter the email address associated with your AGRHI account.
                  </span>
                </div>

                <div className="step">
                  <div className="step-number">2</div>
                  <strong>Verify ownership</strong>
                  <span>
                    We may contact you to confirm that you own the account.
                  </span>
                </div>

                <div className="step">
                  <div className="step-number">3</div>
                  <strong>Account deletion</strong>
                  <span>
                    After verification, your account and applicable data are
                    deleted.
                  </span>
                </div>
              </div>

              <form className="form-section" onSubmit={handleSubmit}>
                <label className="form-label" htmlFor="deletion-email">
                  Registered email address
                </label>

                <div className="input-wrap">
                  <span className="input-icon">
                    <Icon name="mail" size={19} />
                  </span>

                  <input
                    id="deletion-email"
                    type="email"
                    className="email-input"
                    placeholder="example@email.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    autoComplete="email"
                    required
                  />
                </div>

                <p className="privacy-note">
                  Your email address will only be used to identify and verify
                  the AGRHI account related to this deletion request.
                </p>

                <button
                  type="submit"
                  className="submit-button"
                  disabled={loading}
                >
                  <Icon name="trash" size={19} />

                  {loading
                    ? "Submitting Request..."
                    : "Request Account Deletion"}
                </button>

                {status.message && (
                  <div
                    className={`status-message ${
                      status.type === "success" ? "success" : "error"
                    }`}
                  >
                    {status.type === "success" && (
                      <Icon name="check" size={19} />
                    )}

                    <span>{status.message}</span>
                  </div>
                )}
              </form>
            </div>

            {/* INFORMATION */}
            <aside className="side-column">
              <div className="info-card">
                <div className="info-title">
                  <div className="info-title-icon">
                    <Icon name="database" size={21} />
                  </div>

                  <h3>Data that will be deleted</h3>
                </div>

                <ul className="data-list">
                  {[
                    "AGRHI user account",
                    "Name and profile information",
                    "Registered email address",
                    "Registered phone number",
                    "Farm and account-related personal information",
                    "Other personal information associated with your account",
                  ].map((item) => (
                    <li key={item}>
                      <span className="list-check">
                        <Icon name="check" size={13} />
                      </span>

                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              </div>

              <div className="info-card retention-card">
                <div className="info-title">
                  <div className="info-title-icon">
                    <Icon name="shield" size={21} />
                  </div>

                  <h3>Data that may be retained</h3>
                </div>

                <p>
                  Certain information may be retained when required for legal,
                  regulatory, security, fraud-prevention, accounting, or
                  compliance purposes. Any retained information will only be
                  kept for the applicable retention period and will not be used
                  for unrelated purposes.
                </p>
              </div>
            </aside>
          </div>

          {/* SUPPORT */}
          <div className="support-card">
            <div className="support-copy">
              <div className="support-icon">
                <Icon name="mail" size={23} />
              </div>

              <div>
                <h3>Need help with account deletion?</h3>
                <p>
                  Contact the AGRHI support team if you are unable to submit
                  your request.
                </p>
              </div>
            </div>

            <a className="support-link" href="mailto:support@farmlead.in">
              support@farmlead.in
              <Icon name="arrow" size={15} />
            </a>
          </div>
        </section>

        <footer className="delete-footer">
          <strong>AGRHI by Farmlead</strong>
          <br />
          Account deletion and privacy request portal
        </footer>
      </main>
    </>
  );
}
