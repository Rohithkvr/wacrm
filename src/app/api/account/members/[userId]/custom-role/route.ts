// ============================================================
// /api/account/members/[userId]/custom-role
//
//   PATCH — assign (or clear, with null) a custom role on a
//           teammate. Admin+.
//
// Delegates to the SECURITY DEFINER RPC from migration 040:
//   set_member_custom_role(p_user_id, p_custom_role_id)
// The RPC does the real authorisation — caller must be admin+,
// target must be an 'agent' in the caller's account, target can't
// be self, and the role (if any) must belong to the caller's
// account. This layer only forwards the call and maps SQLSTATEs.
// ============================================================

import { NextResponse } from "next/server";
import type { PostgrestError } from "@supabase/supabase-js";

import { requireRole, toErrorResponse } from "@/lib/auth/account";
import {
  checkRateLimit,
  rateLimitResponse,
  RATE_LIMITS,
} from "@/lib/rate-limit";

function rpcErrorToResponse(err: PostgrestError): NextResponse {
  if (err.code === "42501") {
    return NextResponse.json({ error: err.message }, { status: 403 });
  }
  if (err.code === "22023") {
    return NextResponse.json({ error: err.message }, { status: 400 });
  }
  console.error("[members/:userId/custom-role] unexpected RPC error:", err);
  return NextResponse.json(
    { error: "Failed to update member's custom role" },
    { status: 500 },
  );
}

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ userId: string }> },
) {
  try {
    const ctx = await requireRole("admin");

    const limit = checkRateLimit(
      `admin:memberCustomRole:${ctx.userId}`,
      RATE_LIMITS.adminAction,
    );
    if (!limit.success) return rateLimitResponse(limit);

    const { userId } = await params;

    const body = (await request.json().catch(() => null)) as
      | { customRoleId?: unknown }
      | null;
    const customRoleId = body?.customRoleId;

    if (customRoleId !== null && typeof customRoleId !== "string") {
      return NextResponse.json(
        { error: "'customRoleId' must be a string or null" },
        { status: 400 },
      );
    }

    const { error } = await ctx.supabase.rpc("set_member_custom_role", {
      p_user_id: userId,
      p_custom_role_id: customRoleId,
    });

    if (error) return rpcErrorToResponse(error);

    return NextResponse.json({ ok: true });
  } catch (err) {
    return toErrorResponse(err);
  }
}
