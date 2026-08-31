// ============================================================
// /api/account/custom-roles
//
//   GET   — list every custom role in the caller's account. Admin+.
//   POST  — create a new custom role.                       Admin+.
//
// RLS on `custom_roles` (migration 040) already scopes reads/writes
// to the caller's account and requires admin+ for writes — this
// layer just validates the request shape and maps Postgres errors.
// ============================================================

import { NextResponse } from "next/server";

import { requireRole, toErrorResponse } from "@/lib/auth/account";
import {
  checkRateLimit,
  rateLimitResponse,
  RATE_LIMITS,
} from "@/lib/rate-limit";

const MAX_NAME_LENGTH = 60;

interface CreateBody {
  name?: unknown;
  can_inbox?: unknown;
  can_contacts_pipelines?: unknown;
  can_broadcasts_automations?: unknown;
}

function parseBool(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

export async function GET() {
  try {
    const ctx = await requireRole("admin");

    const { data, error } = await ctx.supabase
      .from("custom_roles")
      .select(
        "id, name, can_inbox, can_contacts_pipelines, can_broadcasts_automations, created_at",
      )
      .eq("account_id", ctx.accountId)
      .order("created_at", { ascending: true });

    if (error) {
      console.error("[GET /api/account/custom-roles] fetch error:", error);
      return NextResponse.json(
        { error: "Failed to load custom roles" },
        { status: 500 },
      );
    }

    return NextResponse.json({ roles: data ?? [] });
  } catch (err) {
    return toErrorResponse(err);
  }
}

export async function POST(request: Request) {
  try {
    const ctx = await requireRole("admin");

    const limit = checkRateLimit(
      `admin:customRoleCreate:${ctx.userId}`,
      RATE_LIMITS.adminAction,
    );
    if (!limit.success) return rateLimitResponse(limit);

    const body = (await request.json().catch(() => null)) as CreateBody | null;
    const name = typeof body?.name === "string" ? body.name.trim() : "";

    if (!name) {
      return NextResponse.json({ error: "Name is required" }, { status: 400 });
    }
    if (name.length > MAX_NAME_LENGTH) {
      return NextResponse.json(
        { error: `Name must be ${MAX_NAME_LENGTH} characters or fewer` },
        { status: 400 },
      );
    }

    const { data, error } = await ctx.supabase
      .from("custom_roles")
      .insert({
        account_id: ctx.accountId,
        name,
        can_inbox: parseBool(body?.can_inbox, true),
        can_contacts_pipelines: parseBool(body?.can_contacts_pipelines, true),
        can_broadcasts_automations: parseBool(
          body?.can_broadcasts_automations,
          true,
        ),
      })
      .select(
        "id, name, can_inbox, can_contacts_pipelines, can_broadcasts_automations, created_at",
      )
      .single();

    if (error) {
      // 23505 = unique_violation — the (account_id, name) constraint.
      if (error.code === "23505") {
        return NextResponse.json(
          { error: "A role with this name already exists" },
          { status: 409 },
        );
      }
      console.error("[POST /api/account/custom-roles] insert error:", error);
      return NextResponse.json(
        { error: "Failed to create custom role" },
        { status: 500 },
      );
    }

    return NextResponse.json({ role: data }, { status: 201 });
  } catch (err) {
    return toErrorResponse(err);
  }
}
