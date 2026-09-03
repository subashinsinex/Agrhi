import React, { useRef } from "react";

// React Bits-style pointer spotlight, kept dependency-free and accessible.
export default function SpotlightCard({ children, className = "" }) {
  const ref = useRef(null);
  const move = event => {
    const card = ref.current;
    if (!card) return;
    const bounds = card.getBoundingClientRect();
    card.style.setProperty("--spot-x", `${event.clientX - bounds.left}px`);
    card.style.setProperty("--spot-y", `${event.clientY - bounds.top}px`);
  };
  return <article ref={ref} onPointerMove={move} className={`rb-spotlight ${className}`}>{children}</article>;
}
