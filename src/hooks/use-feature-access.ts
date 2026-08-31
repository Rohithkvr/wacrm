"use client";

import { useAuth } from "@/hooks/use-auth";
import { canAccessFeature, type FeatureArea } from "@/lib/auth/custom-roles";

/**
 * Whether the signed-in user may access `feature`, accounting for
 * both their account role and (for agents) any admin-assigned
 * custom role. See `@/lib/auth/custom-roles` for the rules.
 *
 * Returns `false` while the profile is still loading — same
 * fail-closed convention as `useCan` — so a restricted agent never
 * sees a gated nav item / page flash before their custom role
 * resolves.
 */
export function useFeatureAccess(feature: FeatureArea): boolean {
  const { profileLoading, accountRole, customRole } = useAuth();
  if (profileLoading) return false;
  return canAccessFeature(accountRole, customRole, feature);
}
