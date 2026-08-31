import type { MetadataRoute } from "next";

// Next.js auto-serves this at /manifest.webmanifest and injects the
// <link rel="manifest"> tag into every page — no manual wiring needed.
// Icons point at the dynamic PNG routes in src/app/pwa-icon/, which
// render the same purple-square + chat-bubble mark as the favicon
// (src/app/icon.tsx) and the sidebar logo.
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "WhatsApp CRM",
    short_name: "WhatsApp CRM",
    description: "Self-hostable CRM template for WhatsApp.",
    start_url: "/",
    display: "standalone",
    background_color: "#020617",
    theme_color: "#7c3aed",
    icons: [
      { src: "/pwa-icon/192", sizes: "192x192", type: "image/png" },
      { src: "/pwa-icon/512", sizes: "512x512", type: "image/png" },
    ],
  };
}
