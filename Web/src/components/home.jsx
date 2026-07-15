import React, { useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import * as THREE from "three";

const MODULES = [
  {
    icon: "⊞",
    name: "Dashboard",
    desc: "Live weather card, profile overview, and quick access to every feature after sign-in.",
  },
  {
    icon: "🔬",
    name: "Plant Doctor",
    desc: "AI disease detection via gallery upload or Smart Camera with real-time plant frame validation.",
  },
  {
    icon: "🌾",
    name: "Crop Care",
    desc: "Create farms with soil type and irrigation data. Manage crops, schedules, and crop history.",
  },
  {
    icon: "📋",
    name: "Subsidies",
    desc: "Browse live government subsidy schemes with direct links to official eligibility portals.",
  },
  {
    icon: "🏪",
    name: "Farm Store",
    desc: "GPS-verified permanent selling location. Add farm products with images, price, and quantity.",
  },
  {
    icon: "🛒",
    name: "Marketplace",
    desc: "Discover local farm and retail products within an adjustable radius, with seller call access.",
  },
  {
    icon: "🗺",
    name: "Map Module",
    desc: "Visual store map with distance controls and one-tap Google Maps directions to any seller.",
  },
  {
    icon: "💬",
    name: "Help & Support",
    desc: "Submit queries with issue tagging, view full feedback history, and admin replies within 24h.",
  },
];

const CROPS = [
  { icon: "🌾", name: "Rice" },
  { icon: "🌿", name: "Wheat" },
  { icon: "🍌", name: "Banana" },
  { icon: "☕", name: "Coffee" },
  { icon: "🍅", name: "Tomato" },
  { icon: "🥜", name: "Groundnut" },
  { icon: "🥥", name: "Coconut" },
  { icon: "🌽", name: "Corn" },
  { icon: "🎋", name: "Sugarcane" },
  { icon: "🌸", name: "Cotton" },
];

const DETECTIONS = [
  { dis: "Leaf Blast Detected", crop: "Rice", conf: "96.4%" },
  { dis: "Brown Spot Detected", crop: "Rice", conf: "93.1%" },
  { dis: "Black Sigatoka Detected", crop: "Banana", conf: "94.7%" },
  { dis: "Early Blight Detected", crop: "Tomato", conf: "91.8%" },
  { dis: "Gray Leaf Spot Detected", crop: "Coconut", conf: "95.2%" },
  { dis: "Leaf Rust Detected", crop: "Coffee", conf: "88.6%" },
  { dis: "Blight Detected", crop: "Corn", conf: "92.3%" },
];

const LANGS = [
  { script: "த", name: "Tamil" },
  { script: "Eng", name: "English" },
  { script: "हि", name: "Hindi" },
  { script: "తె", name: "Telugu" },
  { script: "Ελ.", name: "Greek" },
  { script: "Türkçe", name: "Turkish" },
  { script: "Melayu", name: "Malay" },
];

const STEPS = [
  {
    n: "01",
    title: "Register & Select Role",
    desc: "Sign up with name, phone, and date of birth. Choose your category — Farmer, Expert, Retailer, or Consumer.",
  },
  {
    n: "02",
    title: "Set Up Your Profile",
    desc: "Verify email via OTP, upload a profile photo, and configure your farm or store depending on your role.",
  },
  {
    n: "03",
    title: "Download AI Models",
    desc: "Pick from 10 crop-specific models in the Model Library. Once downloaded, Plant Doctor works fully offline.",
  },
  {
    n: "04",
    title: "Detect & Act",
    desc: "Point Smart Camera at a leaf. Get disease label, confidence score, and remedy recommendations instantly.",
  },
];

const STATS = [
  { to: 10, hi: "+", label: "AI Crop Models" },
  { to: 7, hi: "", label: "Languages" },
  { to: 4, hi: "", label: "User Roles" },
  { to: 8, hi: "", label: "App Modules" },
];

const APP_DOWNLOAD_URL =
  "https://drive.google.com/file/d/1evqNQ1h23RKYOE0sE6F9oQkMPrgbBmJn/view";

export default function Home() {
  const navigate = useNavigate();
  const canvasRef = useRef(null);
  const detDisRef = useRef(null);
  const detConfRef = useRef(null);
  const detCropRef = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(
      65,
      window.innerWidth / window.innerHeight,
      0.1,
      1000,
    );
    camera.position.z = 48;

    const renderer = new THREE.WebGLRenderer({
      canvas,
      alpha: false,
      antialias: true,
    });

    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.8));
    renderer.setClearColor(0x000000, 1);

    const N = 1800;
    const pos = new Float32Array(N * 3);
    const col = new Float32Array(N * 3);
    const vel = [];

    for (let i = 0; i < N; i++) {
      pos[i * 3] = (Math.random() - 0.5) * 140;
      pos[i * 3 + 1] = (Math.random() - 0.5) * 90;
      pos[i * 3 + 2] = (Math.random() - 0.5) * 60;

      const t = Math.random();
      col[i * 3] = 0.06 + t * 0.1;
      col[i * 3 + 1] = 0.32 + t * 0.36;
      col[i * 3 + 2] = 0.06 + t * 0.08;

      vel.push({
        x: (Math.random() - 0.5) * 0.012,
        y: (Math.random() - 0.5) * 0.008,
        z: (Math.random() - 0.5) * 0.004,
      });
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.BufferAttribute(pos, 3));
    geo.setAttribute("color", new THREE.BufferAttribute(col, 3));

    const mat = new THREE.PointsMaterial({
      size: 0.28,
      vertexColors: true,
      transparent: true,
      opacity: 0.65,
      sizeAttenuation: true,
    });

    const pts = new THREE.Points(geo, mat);
    scene.add(pts);

    const THRESH = 12;
    const linePairs = [];

    for (let i = 0; i < N; i += 3) {
      for (let j = i + 1; j < Math.min(i + 18, N); j += 3) {
        const dx = pos[i * 3] - pos[j * 3];
        const dy = pos[i * 3 + 1] - pos[j * 3 + 1];
        const dz = pos[i * 3 + 2] - pos[j * 3 + 2];
        if (Math.sqrt(dx * dx + dy * dy + dz * dz) < THRESH) {
          linePairs.push(i, j);
        }
      }
    }

    const lPos = new Float32Array(linePairs.length * 3);
    for (let k = 0; k < linePairs.length; k += 2) {
      const a = linePairs[k];
      const b = linePairs[k + 1];

      lPos[k * 3] = pos[a * 3];
      lPos[k * 3 + 1] = pos[a * 3 + 1];
      lPos[k * 3 + 2] = pos[a * 3 + 2];

      lPos[k * 3 + 3] = pos[b * 3];
      lPos[k * 3 + 4] = pos[b * 3 + 1];
      lPos[k * 3 + 5] = pos[b * 3 + 2];
    }

    const lGeo = new THREE.BufferGeometry();
    lGeo.setAttribute("position", new THREE.BufferAttribute(lPos, 3));

    const lMat = new THREE.LineBasicMaterial({
      color: 0x2e6e38,
      transparent: true,
      opacity: 0.08,
    });

    const lines = new THREE.LineSegments(lGeo, lMat);
    scene.add(lines);

    let mx = 0;
    let my = 0;

    const onMouse = (e) => {
      mx = (e.clientX / window.innerWidth - 0.5) * 2;
      my = (e.clientY / window.innerHeight - 0.5) * 2;
    };

    const onResize = () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    };

    window.addEventListener("mousemove", onMouse, { passive: true });
    window.addEventListener("resize", onResize, { passive: true });

    let frame = 0;
    let rafId;

    const animate = () => {
      rafId = requestAnimationFrame(animate);
      frame++;

      const p = pts.geometry.attributes.position.array;

      for (let i = 0; i < N; i++) {
        p[i * 3] += vel[i].x;
        p[i * 3 + 1] += vel[i].y;
        p[i * 3 + 2] += vel[i].z;

        if (p[i * 3] > 70) p[i * 3] = -70;
        if (p[i * 3] < -70) p[i * 3] = 70;
        if (p[i * 3 + 1] > 45) p[i * 3 + 1] = -45;
        if (p[i * 3 + 1] < -45) p[i * 3 + 1] = 45;
      }

      pts.geometry.attributes.position.needsUpdate = true;

      camera.position.x += (mx * 4 - camera.position.x) * 0.018;
      camera.position.y += (-my * 3 - camera.position.y) * 0.018;
      camera.position.z = 48 + Math.sin(frame * 0.003) * 2;
      camera.lookAt(0, 0, 0);

      scene.rotation.y += 0.00009;
      renderer.render(scene, camera);
    };

    animate();

    return () => {
      cancelAnimationFrame(rafId);
      window.removeEventListener("mousemove", onMouse);
      window.removeEventListener("resize", onResize);
      geo.dispose();
      mat.dispose();
      lGeo.dispose();
      lMat.dispose();
      renderer.dispose();
    };
  }, []);

  useEffect(() => {
    const nav = document.getElementById("main-nav");

    const onScroll = () => {
      nav?.classList.toggle("on", window.scrollY > 40);
    };

    window.addEventListener("scroll", onScroll, { passive: true });

    const rvObs = new IntersectionObserver(
      (entries) =>
        entries.forEach((entry) => {
          if (entry.isIntersecting) entry.target.classList.add("vi");
        }),
      { threshold: 0.12 },
    );

    document.querySelectorAll(".rv").forEach((el) => rvObs.observe(el));

    const countUp = (el, target) => {
      const step = Math.ceil(target / 40);
      let cur = 0;
      const t = setInterval(() => {
        cur = Math.min(cur + step, target);
        el.textContent = cur;
        if (cur >= target) clearInterval(t);
      }, 22);
    };

    const cuObs = new IntersectionObserver(
      (entries) =>
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            countUp(entry.target, +entry.target.dataset.to);
            cuObs.unobserve(entry.target);
          }
        }),
      { threshold: 0.5 },
    );

    document.querySelectorAll(".cu").forEach((el) => cuObs.observe(el));

    const barObs = new IntersectionObserver(
      (entries) =>
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.style.width = entry.target.dataset.w;
            barObs.unobserve(entry.target);
          }
        }),
      { threshold: 0.4 },
    );

    document.querySelectorAll(".ab-fi").forEach((el) => barObs.observe(el));

    let di = 0;
    const cycle = setInterval(() => {
      di = (di + 1) % DETECTIONS.length;

      const disEl = detDisRef.current;
      const confEl = detConfRef.current;
      const cropEl = detCropRef.current;
      if (!disEl || !confEl || !cropEl) return;

      [disEl, confEl, cropEl].forEach((el) => {
        el.style.opacity = "0";
        el.style.transform = "translateY(4px)";
      });

      setTimeout(() => {
        disEl.textContent = DETECTIONS[di].dis;
        confEl.textContent = DETECTIONS[di].conf;
        cropEl.textContent = DETECTIONS[di].crop;

        [disEl, confEl, cropEl].forEach((el) => {
          el.style.opacity = "1";
          el.style.transform = "translateY(0)";
        });
      }, 240);
    }, 2800);

    return () => {
      window.removeEventListener("scroll", onScroll);
      rvObs.disconnect();
      cuObs.disconnect();
      barObs.disconnect();
      clearInterval(cycle);
    };
  }, []);

  return (
    <>
      <link
        href="https://api.fontshare.com/v2/css?f[]=cabinet-grotesk@700,800,900&f[]=satoshi@400,500,700,900&display=swap"
        rel="stylesheet"
      />

      <style>{`
        :root{
          --fd:'Cabinet Grotesk','DM Sans',sans-serif;
          --fb:'Satoshi','Inter',sans-serif;

          --bg:#000000;
          --bg-soft:#041005;
          --sf:#071507;
          --sf2:#0a1a09;
          --sf3:#0d1f0c;

          --tx:#dbead4;
          --mu:#88a081;
          --fa:#486145;

          --pr:#317a3a;
          --pr-2:#5cc96a;
          --pr-soft:rgba(49,122,58,.12);
          --bdr:rgba(255,255,255,.075);
          --bdr-hi:rgba(255,255,255,.14);

          --text-xs:clamp(.75rem,.7rem + .25vw,.875rem);
          --text-sm:clamp(.875rem,.8rem + .35vw,1rem);
          --text-base:clamp(1rem,.95rem + .25vw,1.125rem);
          --text-lg:clamp(1.125rem,1rem + .75vw,1.5rem);
          --text-xl:clamp(1.5rem,1.2rem + 1.25vw,2.25rem);
          --text-2xl:clamp(2rem,1.2rem + 2.5vw,3.5rem);
          --text-hero:clamp(2.9rem,.7rem + 6vw,7.2rem);

          --space-1:.25rem;
          --space-2:.5rem;
          --space-3:.75rem;
          --space-4:1rem;
          --space-5:1.25rem;
          --space-6:1.5rem;
          --space-8:2rem;
          --space-10:2.5rem;
          --space-12:3rem;
          --space-16:4rem;
          --space-20:5rem;
          --space-24:6rem;

          --r-sm:.375rem;
          --r-md:.625rem;
          --r-lg:1rem;
          --r-xl:1.5rem;
          --r-pill:999px;

          --tr:180ms cubic-bezier(.16,1,.3,1);
          --shadow-sm:0 6px 18px rgba(0,0,0,.22);
          --shadow-md:0 12px 32px rgba(0,0,0,.35);
          --content:1200px;
          --content-wide:1320px;
          --nav-h:84px;
        }

        *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
        html{
          scroll-behavior:smooth;
          -webkit-font-smoothing:antialiased;
          background:var(--bg-soft);
        }
        body{
          min-height:100vh;
          font-family:var(--fb);
          font-size:var(--text-base);
          line-height:1.6;
          color:var(--tx);
          background:var(--bg);
          overflow-x:hidden;
        }
        img,svg,canvas{display:block;max-width:100%}
        a,button{
          transition:
            color var(--tr),
            background var(--tr),
            border-color var(--tr),
            box-shadow var(--tr),
            transform var(--tr);
        }
        button{font:inherit;border:none;background:none;cursor:pointer}
        h1,h2,h3{line-height:1.04;text-wrap:balance}
        p{text-wrap:pretty}
        ::selection{background:rgba(92,201,106,.22);color:var(--tx)}

        #agrhi-canvas{
          position:fixed;
          inset:0;
          z-index:0;
          pointer-events:none;
        }

        .page{
          position:relative;
          z-index:2;
        }

        .wrap{
          width:min(var(--content), calc(100% - 2rem));
          margin-inline:auto;
        }

        .wrap-wide{
          width:min(var(--content-wide), calc(100% - 2rem));
          margin-inline:auto;
        }

        .section-line{
          border-top:1px solid var(--bdr);
        }

        .agrhi-nav{
          position:fixed;
          top:0;
          left:0;
          right:0;
          z-index:1000;
          min-height:var(--nav-h);
          display:flex;
          align-items:center;
          background:rgba(0,0,0,.76);
          backdrop-filter:blur(18px) saturate(1.25);
          border-bottom:1px solid rgba(255,255,255,.05);
        }

        .agrhi-nav.on{
          background:rgba(0,0,0,.92);
          border-bottom-color:var(--bdr);
        }

        .nav-i{
          display:flex;
          align-items:center;
          justify-content:space-between;
          gap:var(--space-6);
          min-height:var(--nav-h);
        }

        .logo{
          display:inline-flex;
          align-items:center;
          gap:.65rem;
          text-decoration:none;
          color:var(--tx);
          flex-shrink:0;
        }

        .logo-txt{
          font-family:var(--fd);
          font-size:var(--text-lg);
          font-weight:800;
          letter-spacing:-.03em;
        }

        .logo-txt em{
          color:var(--pr-2);
          font-style:normal;
        }

        .nav-r{
          display:flex;
          align-items:center;
          gap:1rem;
          flex-wrap:wrap;
          justify-content:flex-end;
        }

        .nl{
          color:var(--mu);
          text-decoration:none;
          font-size:var(--text-sm);
          font-weight:700;
        }

        .nl:hover{color:var(--tx)}

        .btn-nav,
        .btn-p,
        .btn-dl,
        .btn-g{
          display:inline-flex;
          align-items:center;
          justify-content:center;
          gap:.45rem;
          min-height:44px;
          padding:.8rem 1.1rem;
          border-radius:var(--r-md);
          text-decoration:none;
          white-space:nowrap;
          font-size:var(--text-sm);
          font-weight:700;
        }

        .btn-nav{
          background:var(--pr-soft);
          color:var(--pr-2);
          border:1px solid rgba(92,201,106,.24);
        }

        .btn-nav:hover{
          background:rgba(49,122,58,.2);
          border-color:rgba(92,201,106,.38);
          transform:translateY(-1px);
        }

        .btn-p{
          background:var(--pr);
          color:#fff;
          border:1px solid transparent;
          box-shadow:0 10px 24px rgba(49,122,58,.28);
        }

        .btn-p:hover{
          background:var(--pr-2);
          color:#031003;
          transform:translateY(-2px);
          box-shadow:0 16px 34px rgba(49,122,58,.42);
        }

        .btn-dl{
          background:rgba(92,201,106,.07);
          color:var(--pr-2);
          border:1px solid rgba(92,201,106,.28);
        }

        .btn-dl:hover{
          background:rgba(92,201,106,.13);
          border-color:rgba(92,201,106,.48);
          transform:translateY(-2px);
          box-shadow:0 10px 22px rgba(49,122,58,.18);
        }

        .btn-g{
          background:rgba(255,255,255,.02);
          color:var(--mu);
          border:1px solid var(--bdr-hi);
        }

        .btn-g:hover{
          color:var(--tx);
          background:rgba(255,255,255,.05);
          border-color:rgba(255,255,255,.22);
          transform:translateY(-1px);
        }

        .hero{
          min-height:100dvh;
          display:flex;
          align-items:center;
          padding-top:calc(var(--nav-h) + var(--space-8));
          padding-bottom:var(--space-16);
          position:relative;
        }

        .hero-c{
          max-width:860px;
        }

        .badge{
          display:inline-flex;
          align-items:center;
          gap:.45rem;
          padding:.38rem .9rem;
          border-radius:var(--r-pill);
          background:rgba(92,201,106,.07);
          border:1px solid rgba(92,201,106,.16);
          color:var(--pr-2);
          font-size:var(--text-xs);
          font-weight:800;
          letter-spacing:.1em;
          text-transform:uppercase;
          margin-bottom:var(--space-6);
        }

        .badge-dot{
          width:6px;
          height:6px;
          border-radius:50%;
          background:var(--pr-2);
          animation:blink 2.2s ease-in-out infinite;
        }

        @keyframes blink{
          0%,100%{opacity:1;transform:scale(1)}
          50%{opacity:.35;transform:scale(.7)}
        }

        .ht{
          font-family:var(--fd);
          font-size:var(--text-hero);
          font-weight:900;
          line-height:.92;
          letter-spacing:-.06em;
          margin-bottom:var(--space-6);
          max-width:11ch;
        }

        .ht .line{display:block}

        .ht .grd{
          background:linear-gradient(108deg,#6fdb7e 0%,#b4eca0 40%,#5cc96a 70%,#3aa85c 100%);
          background-size:220% auto;
          -webkit-background-clip:text;
          background-clip:text;
          -webkit-text-fill-color:transparent;
          animation:grd-move 5s linear infinite;
        }

        @keyframes grd-move{
          to{background-position:220% center}
        }

        .hd{
          max-width:52ch;
          margin-bottom:var(--space-8);
          color:var(--mu);
          font-size:var(--text-lg);
          line-height:1.7;
        }

        .hd strong{
          color:var(--tx);
          font-weight:700;
        }

        .hero-cta{
          display:flex;
          flex-wrap:wrap;
          gap:.75rem;
          margin-bottom:var(--space-6);
        }

        .chips{
          display:flex;
          flex-wrap:wrap;
          gap:.55rem;
        }

        .chip{
          display:inline-flex;
          align-items:center;
          padding:.35rem .8rem;
          background:rgba(255,255,255,.025);
          border:1px solid var(--bdr);
          border-radius:var(--r-pill);
          color:var(--mu);
          font-size:var(--text-xs);
          font-weight:700;
          letter-spacing:.04em;
        }

        .scroll-cue{
          position:absolute;
          left:50%;
          bottom:var(--space-8);
          transform:translateX(-50%);
          display:flex;
          flex-direction:column;
          align-items:center;
          gap:.45rem;
          color:var(--fa);
          font-size:var(--text-xs);
          text-transform:uppercase;
          letter-spacing:.12em;
          user-select:none;
        }

        .mouse{
          width:20px;
          height:32px;
          border:1px solid rgba(255,255,255,.12);
          border-radius:10px;
          position:relative;
        }

        .mouse::after{
          content:'';
          position:absolute;
          left:50%;
          top:4px;
          transform:translateX(-50%);
          width:2px;
          height:6px;
          border-radius:99px;
          background:var(--pr-2);
          animation:mdrop 1.8s ease-in-out infinite;
        }

        @keyframes mdrop{
          0%,100%{top:4px;opacity:1}
          75%{top:18px;opacity:0}
        }

        .stats-sec{
          padding:var(--space-8) 0;
        }

        .stats-g{
          display:grid;
          grid-template-columns:repeat(4, minmax(0, 1fr));
          gap:1px;
          background:var(--bdr);
          border:1px solid var(--bdr);
          border-radius:var(--r-lg);
          overflow:hidden;
        }

        .sc{
          background:linear-gradient(180deg,var(--sf2),var(--sf));
          padding:var(--space-8) var(--space-6);
          position:relative;
          overflow:hidden;
        }

        .sc::before{
          content:'';
          position:absolute;
          top:0;
          left:0;
          right:0;
          height:1px;
          background:linear-gradient(90deg,transparent,rgba(92,201,106,.3),transparent);
          opacity:0;
          transition:opacity var(--tr);
        }

        .sc:hover::before{opacity:1}

        .sn{
          font-family:var(--fd);
          font-size:var(--text-2xl);
          font-weight:900;
          line-height:1;
          letter-spacing:-.04em;
          margin-bottom:.45rem;
        }

        .sn .hi{color:var(--pr-2)}
        .sl{
          color:var(--mu);
          font-size:var(--text-sm);
        }

        .modules-sec,
        .ai-sec,
        .how-sec,
        .lang-sec,
        .cta-sec{
          padding:clamp(3rem,8vw,5rem) 0;
        }

        .sec-hd{
          margin-bottom:var(--space-10);
          max-width:760px;
        }

        .sec-eye{
          display:inline-flex;
          align-items:center;
          gap:.45rem;
          margin-bottom:.8rem;
          color:var(--pr-2);
          font-size:var(--text-xs);
          font-weight:800;
          letter-spacing:.1em;
          text-transform:uppercase;
        }

        .sec-eye::before{
          content:'';
          width:14px;
          height:1px;
          background:var(--pr-2);
        }

        .sec-ttl{
          font-family:var(--fd);
          font-size:var(--text-2xl);
          font-weight:800;
          letter-spacing:-.035em;
          line-height:1.06;
          margin-bottom:.85rem;
        }

        .sec-dsc{
          max-width:58ch;
          color:var(--mu);
          font-size:var(--text-base);
          line-height:1.72;
        }

        .mod-g{
          display:grid;
          grid-template-columns:repeat(4, minmax(0, 1fr));
          gap:.85rem;
        }

        .mc{
          position:relative;
          overflow:hidden;
          background:linear-gradient(180deg,var(--sf2),var(--sf));
          border:1px solid var(--bdr);
          border-radius:var(--r-lg);
          padding:var(--space-6);
          transition:border-color var(--tr), transform var(--tr), box-shadow var(--tr);
        }

        .mc::after{
          content:'';
          position:absolute;
          inset:0;
          background:radial-gradient(ellipse 80% 60% at 50% -10%,rgba(92,201,106,.065),transparent 65%);
          opacity:0;
          transition:opacity var(--tr);
        }

        .mc:hover{
          transform:translateY(-4px);
          border-color:rgba(92,201,106,.22);
          box-shadow:var(--shadow-md);
        }

        .mc:hover::after{opacity:1}

        .mc-ico{
          width:40px;
          height:40px;
          display:grid;
          place-items:center;
          margin-bottom:.9rem;
          border-radius:.8rem;
          background:rgba(49,122,58,.1);
          border:1px solid rgba(92,201,106,.1);
          font-size:1rem;
        }

        .mc-nm{
          font-family:var(--fd);
          font-size:var(--text-base);
          font-weight:700;
          color:var(--tx);
          margin-bottom:.35rem;
        }

        .mc-ds{
          color:var(--mu);
          font-size:var(--text-sm);
          line-height:1.62;
        }

        .ai-g{
          display:grid;
          grid-template-columns:minmax(0,1fr) minmax(0,1fr);
          gap:clamp(2rem,4vw,4rem);
          align-items:center;
        }

        .crops-g{
          display:grid;
          grid-template-columns:repeat(5, minmax(0, 1fr));
          gap:.45rem;
          margin-bottom:1rem;
        }

        .crop-p{
          display:flex;
          flex-direction:column;
          align-items:center;
          justify-content:center;
          gap:.22rem;
          min-height:72px;
          text-align:center;
          padding:.7rem .35rem;
          background:linear-gradient(180deg,var(--sf2),var(--sf));
          border:1px solid var(--bdr);
          border-radius:var(--r-md);
          color:var(--mu);
          font-size:var(--text-xs);
          transition:all var(--tr);
        }

        .crop-p:hover{
          border-color:rgba(92,201,106,.22);
          color:var(--pr-2);
          background:rgba(49,122,58,.08);
          transform:translateY(-2px);
        }

        .crop-ic{font-size:1rem}

        .det-card{
          background:linear-gradient(180deg,var(--sf2),var(--sf));
          border:1px solid var(--bdr);
          border-radius:var(--r-lg);
          padding:var(--space-6);
          box-shadow:var(--shadow-sm);
        }

        .det-top{
          display:flex;
          align-items:center;
          gap:.5rem;
          margin-bottom:.7rem;
        }

        .det-dot{
          width:6px;
          height:6px;
          border-radius:50%;
          background:var(--pr-2);
          animation:blink 2s infinite;
        }

        .det-lbl{
          color:var(--mu);
          font-size:var(--text-xs);
          font-weight:700;
          letter-spacing:.08em;
          text-transform:uppercase;
        }

        .det-dis{
          font-family:var(--fd);
          font-size:var(--text-lg);
          font-weight:800;
          margin-bottom:.15rem;
          transition:opacity .28s ease, transform .28s ease;
        }

        .det-meta{
          color:var(--mu);
          font-size:var(--text-xs);
        }

        .crop-nm,
        .conf-val{
          transition:opacity .28s ease, transform .28s ease;
        }

        .conf-val{
          color:var(--pr-2);
          font-weight:800;
        }

        .det-foot{
          margin-top:.7rem;
          padding-top:.7rem;
          border-top:1px solid var(--bdr);
          color:var(--fa);
          font-size:var(--text-xs);
        }

        .ab-list{
          display:flex;
          flex-direction:column;
          gap:.8rem;
          margin-top:var(--space-8);
        }

        .ab{
          display:grid;
          grid-template-columns:120px 1fr 48px;
          gap:.75rem;
          align-items:center;
        }

        .ab-lbl{
          color:var(--mu);
          font-size:var(--text-xs);
        }

        .ab-tr{
          height:4px;
          border-radius:999px;
          overflow:hidden;
          background:rgba(255,255,255,.05);
        }

        .ab-fi{
          height:100%;
          width:0;
          border-radius:999px;
          background:linear-gradient(90deg,var(--pr),var(--pr-2));
          transition:width 1.4s cubic-bezier(.16,1,.3,1);
        }

        .ab-pc{
          text-align:right;
          color:var(--pr-2);
          font-size:var(--text-xs);
          font-weight:800;
        }

        .steps{
          display:grid;
          grid-template-columns:repeat(4, minmax(0, 1fr));
          gap:1px;
          background:var(--bdr);
          border:1px solid var(--bdr);
          border-radius:var(--r-lg);
          overflow:hidden;
          margin-top:var(--space-10);
        }

        .step{
          background:linear-gradient(180deg,var(--sf2),var(--sf));
          padding:var(--space-8) var(--space-6);
        }

        .step-n{
          display:block;
          margin-bottom:.8rem;
          color:var(--tx);
          font-family:var(--fd);
          font-size:clamp(2.8rem,4vw,4.8rem);
          font-weight:900;
          line-height:1;
          letter-spacing:-.05em;
        }

        .step-ttl{
          color:var(--tx);
          font-family:var(--fd);
          font-size:var(--text-base);
          font-weight:700;
          margin-bottom:.45rem;
        }

        .step-dsc{
          color:var(--mu);
          font-size:var(--text-sm);
          line-height:1.65;
        }

        .lang-hd{
          display:flex;
          align-items:end;
          justify-content:space-between;
          gap:var(--space-6);
          margin-bottom:var(--space-8);
        }

        .lang-note{
          max-width:24ch;
          color:var(--mu);
          font-size:var(--text-sm);
          line-height:1.5;
          text-align:right;
        }

        .lang-g{
          display:grid;
          grid-template-columns:repeat(7, minmax(0, 1fr));
          gap:.7rem;
        }

        .lc{
          min-height:110px;
          display:flex;
          flex-direction:column;
          justify-content:center;
          align-items:center;
          text-align:center;
          padding:var(--space-4);
          background:linear-gradient(180deg,var(--sf2),var(--sf));
          border:1px solid var(--bdr);
          border-radius:var(--r-lg);
          transition:all var(--tr);
        }

        .lc:hover{
          transform:translateY(-3px);
          border-color:rgba(92,201,106,.18);
          box-shadow:var(--shadow-sm);
        }

        .ls{
          display:block;
          color:var(--tx);
          font-size:var(--text-xl);
          font-weight:800;
          line-height:1.08;
          margin-bottom:.25rem;
        }

        .ln{
          color:var(--fa);
          font-size:var(--text-xs);
          font-weight:700;
          letter-spacing:.06em;
          text-transform:uppercase;
        }

        .cta-b{
          max-width:680px;
          margin-inline:auto;
          text-align:center;
        }

        .cta-b h2{
          font-family:var(--fd);
          font-size:var(--text-2xl);
          font-weight:800;
          letter-spacing:-.03em;
          margin-bottom:.8rem;
        }

        .cta-b p{
          color:var(--mu);
          font-size:var(--text-base);
          line-height:1.72;
          margin-bottom:var(--space-8);
        }

        .cta-btns{
          display:flex;
          flex-wrap:wrap;
          justify-content:center;
          gap:.75rem;
        }

        .foot{
          padding:var(--space-8) 0;
          border-top:1px solid var(--bdr);
        }

        .foot-i{
          display:flex;
          align-items:center;
          justify-content:space-between;
          gap:var(--space-4);
        }

        .foot-br{
          display:flex;
          align-items:center;
          gap:.55rem;
          color:var(--mu);
          font-family:var(--fd);
          font-size:var(--text-sm);
          font-weight:700;
        }

        .foot-cp{
          color:var(--fa);
          font-size:var(--text-xs);
          text-align:center;
        }

        .foot-r{
          display:flex;
          align-items:center;
          gap:.5rem;
          flex-wrap:wrap;
          justify-content:flex-end;
        }

        .rv{
          opacity:0;
          transform:translateY(22px);
        }

        .rv.vi{
          opacity:1;
          transform:translateY(0);
          transition:
            opacity .85s cubic-bezier(.16,1,.3,1),
            transform .85s cubic-bezier(.16,1,.3,1);
        }

        .rv.vi.d1{transition-delay:.05s}
        .rv.vi.d2{transition-delay:.12s}
        .rv.vi.d3{transition-delay:.19s}
        .rv.vi.d4{transition-delay:.26s}
        .rv.vi.d5{transition-delay:.33s}
        .rv.vi.d6{transition-delay:.40s}
        .rv.vi.d7{transition-delay:.47s}
        .rv.vi.d8{transition-delay:.54s}

        @media (max-width: 1180px){
          .lang-g{grid-template-columns:repeat(4, minmax(0, 1fr))}
        }

        @media (max-width: 1060px){
          .mod-g{grid-template-columns:repeat(2, minmax(0, 1fr))}
          .steps{grid-template-columns:repeat(2, minmax(0, 1fr))}
        }

        @media (max-width: 860px){
          .stats-g{grid-template-columns:repeat(2, minmax(0, 1fr))}
          .ai-g{grid-template-columns:1fr;gap:var(--space-10)}
          .lang-g{grid-template-columns:repeat(3, minmax(0, 1fr))}
        }

        @media (max-width: 760px){
          .nav-r .nl{display:none}
          .hero{
            padding-top:calc(var(--nav-h) + var(--space-6));
            padding-bottom:var(--space-16);
          }
          .lang-hd{
            flex-direction:column;
            align-items:flex-start;
          }
          .lang-note{text-align:left}
        }

        @media (max-width: 640px){
          .wrap,.wrap-wide{
            width:min(100% - 1.25rem, var(--content));
          }

          .mod-g,
          .steps,
          .stats-g{
            grid-template-columns:1fr;
          }

          .lang-g{
            grid-template-columns:repeat(2, minmax(0, 1fr));
          }

          .crops-g{
            grid-template-columns:repeat(2, minmax(0, 1fr));
          }

          .ab{
            grid-template-columns:92px 1fr 40px;
          }

          .hero-cta,
          .cta-btns{
            flex-direction:column;
            align-items:stretch;
          }

          .btn-p,
          .btn-dl,
          .btn-g{
            width:100%;
          }

          .foot-i{
            flex-direction:column;
            text-align:center;
          }

          .foot-r{
            justify-content:center;
          }

          .scroll-cue{
            display:none;
          }
        }

        @media (max-width: 400px){
          .lang-g{grid-template-columns:1fr}
        }

        @media (prefers-reduced-motion: reduce){
          *,*::before,*::after{
            animation-duration:.01ms !important;
            animation-iteration-count:1 !important;
            transition-duration:.01ms !important;
            scroll-behavior:auto !important;
          }
        }
      `}</style>

      <canvas ref={canvasRef} id="agrhi-canvas" aria-hidden="true" />

      <div className="page">
        <nav className="agrhi-nav" id="main-nav">
          <div className="wrap-wide">
            <div className="nav-i">
              <a href="/" className="logo" aria-label="AGRHI home">
                <svg
                  width="28"
                  height="28"
                  viewBox="0 0 32 32"
                  fill="none"
                  aria-hidden="true"
                >
                  <rect width="32" height="32" rx="7" fill="#25603a" />
                  <path
                    d="M16 6L26 24H6Z"
                    fill="none"
                    stroke="#5cc96a"
                    strokeWidth="2.2"
                    strokeLinejoin="round"
                  />
                  <path
                    d="M16 6V24"
                    stroke="rgba(255,255,255,.25)"
                    strokeWidth="1"
                  />
                  <circle cx="16" cy="14.5" r="2.5" fill="#fff" />
                </svg>
                <span className="logo-txt">
                  CROP<em>LENS</em>
                </span>
              </a>

              <div className="nav-r">
                <a className="nl" href="#features">
                  Modules
                </a>
                <a className="nl" href="#ai">
                  Plant Doctor
                </a>
                <a className="nl" href="#how">
                  Get Started
                </a>

                <a
                  className="btn-nav"
                  href={APP_DOWNLOAD_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg
                    width="13"
                    height="13"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2.2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                  >
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                    <polyline points="7 10 12 15 17 10" />
                    <line x1="12" y1="15" x2="12" y2="3" />
                  </svg>
                  Download
                </a>

                <button
                  type="button"
                  className="btn-g"
                  onClick={() => navigate("/login")}
                >
                  Admin Portal
                </button>
              </div>
            </div>
          </div>
        </nav>

        <section className="hero" id="home">
          <div className="wrap-wide">
            <div className="hero-c">
              <div className="badge">
                <span className="badge-dot" />
                Now on Android
              </div>

              <h1 className="ht">
                <span className="line">The sixth sense</span>
                <span className="line grd">of every farm.</span>
              </h1>

              <p className="hd">
                AGRHI gives farmers{" "}
                <strong>AI-powered disease detection</strong>, full farm
                management, marketplace access, and government subsidies —{" "}
                <strong>offline capable</strong>, in{" "}
                <strong>seven languages</strong>.
              </p>

              <div className="hero-cta">
                <a href="#features" className="btn-p">
                  Explore the platform
                  <svg
                    width="14"
                    height="14"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2.2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                  >
                    <line x1="5" y1="12" x2="19" y2="12" />
                    <polyline points="12 5 19 12 12 19" />
                  </svg>
                </a>

                <a
                  className="btn-dl"
                  href={APP_DOWNLOAD_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg
                    width="15"
                    height="15"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                  >
                    <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
                    <line x1="12" y1="18" x2="12.01" y2="18" />
                  </svg>
                  Download for Android
                </a>

                <a href="#ai" className="btn-g">
                  See AI Models
                </a>
              </div>

              <div className="chips">
                {["Farmer", "Expert", "Retailer", "Consumer"].map((role) => (
                  <span key={role} className="chip">
                    {role}
                  </span>
                ))}
              </div>
            </div>
          </div>

          <div className="scroll-cue" aria-hidden="true">
            <div className="mouse" />
            <span>Scroll</span>
          </div>
        </section>

        <section className="stats-sec section-line">
          <div className="wrap-wide">
            <div className="stats-g">
              {STATS.map((s, i) => (
                <div className={`sc rv d${i + 1}`} key={s.label}>
                  <div className="sn">
                    <span className="cu" data-to={s.to}>
                      0
                    </span>
                    <span className="hi">{s.hi}</span>
                  </div>
                  <div className="sl">{s.label}</div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="modules-sec section-line" id="features">
          <div className="wrap-wide">
            <div className="sec-hd rv">
              <div className="sec-eye">Platform Modules</div>
              <h2 className="sec-ttl">Everything in one app</h2>
              <p className="sec-dsc">
                Eight purpose-built modules serving farmers, experts, retailers,
                and consumers across the agricultural ecosystem.
              </p>
            </div>

            <div className="mod-g">
              {MODULES.map((m, i) => (
                <div className={`mc rv d${(i % 4) + 1}`} key={m.name}>
                  <div className="mc-ico">{m.icon}</div>
                  <div className="mc-nm">{m.name}</div>
                  <div className="mc-ds">{m.desc}</div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="ai-sec section-line" id="ai">
          <div className="wrap-wide">
            <div className="ai-g">
              <div>
                <div className="sec-eye rv">Plant Doctor AI</div>
                <h2 className="sec-ttl rv d1">
                  Disease detection that works in the field
                </h2>
                <p
                  className="sec-dsc rv d2"
                  style={{ marginBottom: "1.75rem" }}
                >
                  Download crop-specific ML models on demand. Smart Camera
                  validates every frame in real time — captures only when a
                  plant leaf is detected, rejects non-plant images entirely.
                </p>

                <div className="ab-list rv d3">
                  {[
                    { label: "Smart Camera", w: "94%", pct: "94%" },
                    { label: "Gallery Upload", w: "91%", pct: "91%" },
                    { label: "Non-plant guard", w: "97%", pct: "97%" },
                    { label: "Offline ready", w: "100%", pct: "✓" },
                  ].map((b) => (
                    <div className="ab" key={b.label}>
                      <span className="ab-lbl">{b.label}</span>
                      <div className="ab-tr">
                        <div className="ab-fi" data-w={b.w} />
                      </div>
                      <span className="ab-pc">{b.pct}</span>
                    </div>
                  ))}
                </div>
              </div>

              <div className="rv d2">
                <div className="crops-g">
                  {CROPS.map((c, i) => (
                    <div className={`crop-p rv d${(i % 5) + 1}`} key={c.name}>
                      <span className="crop-ic">{c.icon}</span>
                      {c.name}
                    </div>
                  ))}
                </div>

                <div className="det-card">
                  <div className="det-top">
                    <span className="det-dot" />
                    <span className="det-lbl">Live Detection Result</span>
                  </div>

                  <div className="det-dis" ref={detDisRef}>
                    {DETECTIONS[0].dis}
                  </div>

                  <div className="det-meta">
                    Crop:{" "}
                    <span className="crop-nm" ref={detCropRef}>
                      {DETECTIONS[0].crop}
                    </span>
                    {"  "}Confidence:{" "}
                    <span className="conf-val" ref={detConfRef}>
                      {DETECTIONS[0].conf}
                    </span>
                  </div>

                  <div className="det-foot">
                    Remedy recommendations available after detection
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="how-sec section-line" id="how">
          <div className="wrap-wide">
            <div className="sec-hd rv">
              <div className="sec-eye">User Journey</div>
              <h2 className="sec-ttl">From install to insight</h2>
            </div>

            <div className="steps">
              {STEPS.map((s, i) => (
                <div className={`step rv d${i + 1}`} key={s.n}>
                  <span className="step-n">{s.n}</span>
                  <div className="step-ttl">{s.title}</div>
                  <div className="step-dsc">{s.desc}</div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="lang-sec section-line">
          <div className="wrap-wide">
            <div className="lang-hd rv">
              <div>
                <div className="sec-eye">Multilingual</div>
                <h2 className="sec-ttl">Speaks your language</h2>
              </div>

              <p className="lang-note">
                20 MB per language pack. Download and switch anytime.
              </p>
            </div>

            <div className="lang-g">
              {LANGS.map((l, i) => (
                <div className={`lc rv d${i + 1}`} key={l.name}>
                  <span className="ls">{l.script}</span>
                  <span className="ln">{l.name}</span>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="cta-sec section-line">
          <div className="wrap">
            <div className="cta-b rv">
              <h2>Ready to get started?</h2>
              <p>
                Download the AGRHI app on your Android device, or sign in to the
                admin portal to manage users, verify retailers, and oversee the
                full platform.
              </p>

              <div className="cta-btns">
                <a
                  className="btn-dl"
                  href={APP_DOWNLOAD_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                  >
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                    <polyline points="7 10 12 15 17 10" />
                    <line x1="12" y1="15" x2="12" y2="3" />
                  </svg>
                  Download App (Android)
                </a>

                <button
                  type="button"
                  className="btn-nav"
                  onClick={() => navigate("/login")}
                >
                  Open Admin Portal
                </button>
              </div>
            </div>
          </div>
        </section>

        <footer className="foot">
          <div className="wrap-wide">
            <div className="foot-i">
              <div className="foot-br">
                <svg
                  width="20"
                  height="20"
                  viewBox="0 0 32 32"
                  fill="none"
                  aria-hidden="true"
                >
                  <rect width="32" height="32" rx="7" fill="#25603a" />
                  <path
                    d="M16 6L26 24H6Z"
                    fill="none"
                    stroke="#5cc96a"
                    strokeWidth="2.2"
                    strokeLinejoin="round"
                  />
                  <circle cx="16" cy="14.5" r="2.5" fill="#fff" />
                </svg>
                AGRHI Mobile Application
              </div>

              <span className="foot-cp">
                © {new Date().getFullYear()} CROPLENS. Built for agricultural
                ecosystem.
              </span>

              <div className="foot-r">
                <a
                  className="btn-dl"
                  href={APP_DOWNLOAD_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ padding: ".5rem .9rem", fontSize: "var(--text-xs)" }}
                >
                  Download
                </a>

                <button
                  type="button"
                  className="btn-g"
                  onClick={() => navigate("/login")}
                  style={{ padding: ".5rem .9rem", fontSize: "var(--text-xs)" }}
                >
                  Admin Portal
                </button>
              </div>
            </div>
          </div>
        </footer>
      </div>
    </>
  );
}
