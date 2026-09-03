import React from "react";
import { ArrowLeft, Leaf } from "lucide-react";
import { Link } from "react-router-dom";
import AnimatedContent from "../reactbits/AnimatedContent";
import usePageMetadata from "../../hooks/usePageMetadata";
import "./notFound.css";

export default function NotFound() {
  usePageMetadata({
    title: "Page Not Found — AGRHI Farm Management",
    description: "Return to the AGRHI Farm Management website.",
    path: "/404",
  });
  return <main className="not-found">
    <AnimatedContent className="not-found__card">
      <img src="/logo.png" alt="AGRHI logo" />
      <span><Leaf size={15}/> AGRHI Farm Management</span>
      <strong>404</strong>
      <h1>This field has no page yet.</h1>
      <p>The address may have changed or the link may be incomplete. Return to the AGRHI website to continue exploring smart agriculture and the farm management application.</p>
      <Link to="/"><ArrowLeft size={17}/> Back to home</Link>
    </AnimatedContent>
  </main>;
}
