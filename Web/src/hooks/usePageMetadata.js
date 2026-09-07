import { useEffect } from "react";

export default function usePageMetadata({ title, description, path }) {
  useEffect(() => {
    document.title = title;
    const ensureMeta = (selector, attributes) => {
      let element = document.head.querySelector(selector);
      if (!element) {
        element = document.createElement(attributes.rel ? "link" : "meta");
        document.head.appendChild(element);
      }
      Object.entries(attributes).forEach(([name, value]) => element.setAttribute(name, value));
    };
    ensureMeta('meta[name="description"]', { name: "description", content: description });
    ensureMeta('meta[property="og:title"]', { property: "og:title", content: title });
    ensureMeta('meta[property="og:description"]', { property: "og:description", content: description });
    ensureMeta('meta[property="og:type"]', { property: "og:type", content: "website" });
    ensureMeta('meta[property="og:url"]', { property: "og:url", content: `https://farmlead.in${path}` });
    ensureMeta('meta[property="og:image"]', { property: "og:image", content: "https://farmlead.in/AGRHI_LOGO.png" });
    ensureMeta('meta[name="twitter:card"]', { name: "twitter:card", content: "summary_large_image" });
    ensureMeta('meta[name="twitter:title"]', { name: "twitter:title", content: title });
    ensureMeta('meta[name="twitter:description"]', { name: "twitter:description", content: description });
    ensureMeta('link[rel="canonical"]', { rel: "canonical", href: `https://farmlead.in${path}` });
  }, [description, path, title]);
}
