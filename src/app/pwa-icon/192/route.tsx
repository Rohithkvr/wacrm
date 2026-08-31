import { ImageResponse } from "next/og";

// PWA manifest icon (192x192) — same purple-square + chat-bubble mark
// as the favicon (src/app/icon.tsx) and the sidebar logo, just scaled
// up for home-screen / app-drawer display.

export const runtime = "edge";
export const size = { width: 192, height: 192 };
export const contentType = "image/png";

export async function GET() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "#7c3aed",
          borderRadius: 40,
        }}
      >
        <svg
          width="112"
          height="112"
          viewBox="0 0 24 24"
          fill="none"
          stroke="#ffffff"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
        </svg>
      </div>
    ),
    { ...size },
  );
}
