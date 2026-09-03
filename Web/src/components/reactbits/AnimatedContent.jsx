import React from "react";
import { motion, useReducedMotion } from "framer-motion";

// React Bits-style viewport reveal, adapted to the AGRHI motion language.
export default function AnimatedContent({ children, className = "", delay = 0, distance = 24 }) {
  const reducedMotion = useReducedMotion();
  return <motion.div className={className} initial={reducedMotion ? false : { opacity: 0, y: distance }} whileInView={reducedMotion ? undefined : { opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.16 }} transition={{ duration: 0.55, delay, ease: [0.22, 1, 0.36, 1] }}>{children}</motion.div>;
}
