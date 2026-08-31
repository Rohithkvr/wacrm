// ============================================================
// /api/account/custom-roles/[id]
//
//   PATCH  — update a custom role's name/permissions.  Admin+.
//   DELETE — delete a custom role.                     Admin+.
//
// Deleting a role that's currently assigned to members falls those
// members back to unrestricted agent access — `profiles.custom_role_id`
// has ON DELETE SET NULL (migration 040), so nothing extra to do here.
// ============================================================

import { NextResponse } from "next/server";

import { requireRole, toErrorResponse } from "@/lib/auth/account";
import {
  checkRateLimit,
  rateLimitResponse,
  RATE_LIMITS,
} from "@/lib/rate-limit";

const MAX_NAME_LENGTH = 60;

interface UpdateBody {
  name?: unknown;
  can_inbox?: unknown;
  can_contacts_pipelines?: unknown;
  can_broadcasts_automations?: unknown;
}

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const ctx = await requireRole("admin");

    const limit = checkRateLimit(
      `admin:customRoleUpdate:${ctx.userId}`,
      RATE_LIMITS.adminAction,
    );
    if (!limit.success) return rateLimitResponse(limit);

    const { id } = await params;
    const body = (await request.json().catch(() => null)) as UpdateBody | null;
    if (!body) {
      return NextResponse.json({ error: "Invalid request body" }, { status: 400 });
    }

    const patch: Record<string, string | boolean> = {};
    if (body.name !== undefined) {
      const name = typeof body.name === "string" ? body.name.trim() : "";
      if (!name) {
        return NextResponse.json({ error: "Name cannot be empty" }, { status: 400 });
      }
      if (name.length > MAX_NAME_LENGTH) {
        return NextResponse.json(
          { error: `Name must be ${MAX_NAME_LENGTH} characters or fewer` },
          { status: 400 },
        );
      }
      patch.name = name;
    }
    if (typeof body.can_inbox === "boolean") patch.can_inbox = body.can_inbox;
    if (typeof body.can_contacts_pipelines === "boolean")
      patch.can_contacts_pipelines = body.can_contacts_pipelines;
    if (typeof body.can_broadcasts_automations === "boolean")
      patch.can_broadcasts_automations = body.can_broadcasts_automations;

    if (Object.keys(patch).length === 0) {
      return NextResponse.json({ error: "Nothing to update" }, { status: 400 });
    }

    // RLS scopes this to the caller's account already; the explicit
    // .eq("account_id", ...) makes a cross-account id guess a 404
    // (zero rows matched) instead of relying on RLS alone.
    const { data, error } = await ctx.supabase
      .from("custom_roles")
      .update(patch)
      .eq("id", id)
      .eq("account_id", ctx.accountId)
      .select(
        "id, name, can_inbox, can_contacts_pipelines, can_broadcasts_automations, created_at",
      )
      .maybeSingle();

    if (error) {
      if (error.code === "23505") {
        return NextResponse.json(
          { error: "A role with this name already exists" },
          { status: 409 },
        );
      }
      console.error("[PATCH /api/account/custom-roles/:id] update error:", error);
      return NextResponse.json(
        { error: "Failed to update custom role" },
        { status: 500 },
      );
    }
    if (!data) {
      return NextResponse.json({ error: "Custom role not found" }, { status: 404 });
    }

    return NextResponse.json({ role: data });
  } catch (err) {
    return toErrorResponse(err);
  }
}

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const ctx = await requireRole("admin");

    const limit = checkRateLimit(
      `admin:customRoleDelete:${ctx.userId}`,
      RATE_LIMITS.adminAction,
    );
    if (!limit.success) return rateLimitResponse(limit);

    const { id } = await params;

    const { data, error } = await ctx.supabase
      .from("custom_roles")
      .delete()
      .eq("id", id)
      .eq("account_id", ctx.accountId)
      .select("id")
      .maybeSingle();

    if (error) {
      console.error("[DELETE /api/account/custom-roles/:id] delete error:", error);
      return NextResponse.json(
        { error: "Failed to delete custom role" },
        { status: 500 },
      );
    }
    if (!data) {
      return NextResponse.json({ error: "Custom role not found" }, { status: 404 });
    }

    return NextResponse.json({ ok: true });
  } catch (err) {
    return toErrorResponse(err);
  }
}
