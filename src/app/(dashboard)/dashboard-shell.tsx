"use client";

import { useCallback, useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import { AuthProvider, useAuth } from "@/hooks/use-auth";
import { Sidebar } from "@/components/layout/sidebar";
import { Header } from "@/components/layout/header";
import { AccountAccessAlert } from "@/components/layout/account-access-alert";
import { PresenceHeartbeat } from "@/components/presence/presence-heartbeat";
import { canAccessFeature, type FeatureArea } from "@/lib/auth/custom-roles";

// Auth-gated dashboard shell. Extracted from the layout so the layout
// itself can stay a server component and export metadata (noindex) —
// client components can't export Next's metadata object.

// Route → feature area, mirroring the sidebar's per-item `feature`
// (src/components/layout/sidebar.tsx) — kept as a prefix match here
// since sub-routes (e.g. /pipelines/<id>) don't need their own entry.
// Routes with no entry (dashboard, settings, join, etc.) are always
// reachable — custom roles only ever narrow the three feature areas.
const ROUTE_FEATURES: { prefix: string; feature: FeatureArea }[] = [
  { prefix: "/inbox", feature: "inbox" },
  { prefix: "/notifications", feature: "inbox" },
  { prefix: "/contacts", feature: "contacts_pipelines" },
  { prefix: "/pipelines", feature: "contacts_pipelines" },
  { prefix: "/broadcasts", feature: "broadcasts_automations" },
  { prefix: "/automations", feature: "broadcasts_automations" },
  { prefix: "/flows", feature: "broadcasts_automations" },
  { prefix: "/agents", feature: "broadcasts_automations" },
];

function routeFeature(pathname: string): FeatureArea | null {
  return ROUTE_FEATURES.find((r) => pathname.startsWith(r.prefix))?.feature ?? null;
}

function DashboardShellInner({ children }: { children: React.ReactNode }) {
  const { user, loading, profileLoading, accountRole, customRole } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  // Sidebar drawer state — only used on mobile. On lg+ the sidebar is
  // always visible and this stays at `false` (ignored by the component).
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const closeSidebar = useCallback(() => setSidebarOpen(false), []);

  useEffect(() => {
    if (!loading && !user) {
      router.push("/login");
    }
  }, [user, loading, router]);

  // Custom-role route guard (migration 040) — the sidebar already
  // hides links a restricted agent can't use, but a typed-in URL or
  // a stale bookmark would still render the page without this. Bounce
  // to /dashboard rather than showing a broken/half-loaded page.
  useEffect(() => {
    if (profileLoading || !user) return;
    const feature = routeFeature(pathname);
    if (!feature) return;
    if (!canAccessFeature(accountRole, customRole, feature)) {
      router.replace("/dashboard");
    }
  }, [pathname, profileLoading, user, accountRole, customRole, router]);

  // Re-checked below (not just via the effect above) so the gated
  // page's content never flashes for even one render while the
  // effect's redirect is in flight.
  const currentFeature = routeFeature(pathname);
  const blockedByFeatureGuard =
    !!currentFeature &&
    !profileLoading &&
    !canAccessFeature(accountRole, customRole, currentFeature);

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center bg-background">
        <div className="flex flex-col items-center gap-3">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          <p className="text-sm text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  if (!user) return null;

  return (
    <div className="aurora-bg flex h-dvh overflow-hidden bg-background">
      {/* Reports this tab's online/away presence once we know a user is
          signed in. Headless — renders nothing. */}
      <PresenceHeartbeat />
      <Sidebar open={sidebarOpen} onClose={closeSidebar} />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header onOpenSidebar={() => setSidebarOpen(true)} />
        {/* Thinner horizontal padding on mobile so cards have room to breathe. */}
        <main className="flex-1 overflow-y-auto p-4 animate-in fade-in-0 duration-500 sm:p-6">
          {/* Above every page: writes are being rejected and here's why.
              Renders nothing unless the account/role failed to resolve. */}
          <AccountAccessAlert />
          {/* While the redirect effect above is in flight, render
              nothing rather than the gated page — avoids a one-frame
              flash of content a restricted agent shouldn't see. */}
          {blockedByFeatureGuard ? null : children}
        </main>
      </div>
    </div>
  );
}

export function DashboardShell({ children }: { children: React.ReactNode }) {
  return (
    <AuthProvider>
      <DashboardShellInner>{children}</DashboardShellInner>
    </AuthProvider>
  );
}
