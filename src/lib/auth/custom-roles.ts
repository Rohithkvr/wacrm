// ============================================================
// Custom roles — a second, narrower layer on top of the fixed
// owner/admin/agent/viewer hierarchy (see ./roles.ts).
//
// Owner/admin always have full authority; viewer is always
// read-only. Custom roles only ever narrow what an 'agent' can
// already do — they can never grant more than agent-level RLS
// already allows, so this is safe to enforce purely at the
// application layer (sidebar + route guards), matching migration
// 040's design.
// ============================================================

import type { AccountRole } from "./roles";

/** Mirrors the `custom_roles` row shape from migration 040. */
export interface CustomRole {
  id: string;
  name: string;
  can_inbox: boolean;
  can_contacts_pipelines: boolean;
  can_broadcasts_automations: boolean;
}

/**
 * The three feature areas a custom role can independently toggle.
 * Settings & members is deliberately not here — see migration 040's
 * header for why that stays admin+ only everywhere.
 */
export type FeatureArea =
  | "inbox"
  | "contacts_pipelines"
  | "broadcasts_automations";

/**
 * Whether the current user (role + optional custom role) may access
 * `feature`. Single source of truth for both the sidebar's nav
 * filtering and the route guard in dashboard-shell.tsx — keep them
 * calling this rather than open-coding the same checks twice.
 */
export function canAccessFeature(
  role: AccountRole | null,
  customRole: CustomRole | null,
  feature: FeatureArea,
): boolean {
  if (!role) return false;
  // Full authority — never narrowed by a custom role.
  if (role === "owner" || role === "admin") return true;
  // Always read-only across every feature area, unaffected by
  // custom roles (which only ever narrow agents).
  if (role === "viewer") return true;
  // role === "agent": no custom role assigned → unrestricted agent
  // access, exactly today's behaviour.
  if (!customRole) return true;
  switch (feature) {
    case "inbox":
      return customRole.can_inbox;
    case "contacts_pipelines":
      return customRole.can_contacts_pipelines;
    case "broadcasts_automations":
      return customRole.can_broadcasts_automations;
  }
}
