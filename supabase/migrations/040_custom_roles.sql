-- ============================================================
-- 040_custom_roles.sql — Admin-defined custom roles for agents
--
-- The fixed owner/admin/agent/viewer hierarchy (017) stays exactly
-- as-is — owner/admin keep full authority, viewer stays read-only.
-- This migration adds a SECOND, narrower layer that only applies to
-- 'agent'-tier members: an admin can define named custom roles
-- (e.g. "Caller") that hide specific feature areas, and assign one
-- to any agent.
--
-- Deliberately NOT covered: Settings & members access. That's
-- gated admin+ throughout the schema (see is_account_member calls
-- across every settings-class table) — making it grantable to a
-- restricted role would mean reworking RLS on every one of those
-- tables. Custom roles here only ever narrow what an agent can
-- already do at the RLS layer (agent-level data access is
-- unchanged) — they never grant anything new. A member with a
-- custom role is still an 'agent' in `profiles.account_role`; the
-- three feature flags below are enforced at the application layer
-- (sidebar + route guards), not by rewriting per-table RLS.
--
-- Idempotent — safe to run multiple times.
-- ============================================================

-- ============================================================
-- CUSTOM_ROLES
-- ============================================================
CREATE TABLE IF NOT EXISTS custom_roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(trim(name)) > 0),
  can_inbox BOOLEAN NOT NULL DEFAULT true,
  can_contacts_pipelines BOOLEAN NOT NULL DEFAULT true,
  can_broadcasts_automations BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (account_id, name)
);

ALTER TABLE custom_roles ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS set_updated_at ON custom_roles;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON custom_roles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Any account member can read the roles (needed so an agent's own
-- client can resolve their assigned role's permissions, and so the
-- admin UI can list roles to assign). Only admin+ may write.
DROP POLICY IF EXISTS "custom_roles_select" ON custom_roles;
CREATE POLICY "custom_roles_select" ON custom_roles FOR SELECT
  USING (is_account_member(account_id, 'viewer'));

DROP POLICY IF EXISTS "custom_roles_insert" ON custom_roles;
CREATE POLICY "custom_roles_insert" ON custom_roles FOR INSERT
  WITH CHECK (is_account_member(account_id, 'admin'));

DROP POLICY IF EXISTS "custom_roles_update" ON custom_roles;
CREATE POLICY "custom_roles_update" ON custom_roles FOR UPDATE
  USING (is_account_member(account_id, 'admin'))
  WITH CHECK (is_account_member(account_id, 'admin'));

DROP POLICY IF EXISTS "custom_roles_delete" ON custom_roles;
CREATE POLICY "custom_roles_delete" ON custom_roles FOR DELETE
  USING (is_account_member(account_id, 'admin'));

-- ============================================================
-- PROFILES — assignment column
--
-- Nullable: an agent with no custom_role_id keeps today's full
-- agent access (backward compatible). ON DELETE SET NULL — deleting
-- a custom role falls its members back to unrestricted agent access
-- rather than leaving a dangling reference.
-- ============================================================
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS custom_role_id UUID REFERENCES custom_roles(id) ON DELETE SET NULL;

-- ============================================================
-- Extend the privilege-column guard from 034 to cover custom_role_id
-- too — it's an access-control column just like account_role /
-- account_id, so the same "browser client can't self-write it"
-- guard applies. Legitimate writers (the RPC below, SECURITY
-- DEFINER as postgres) are unaffected — see 034's header for why
-- `current_user = 'authenticated'` is the right discriminator.
-- ============================================================
CREATE OR REPLACE FUNCTION public.enforce_profile_privilege_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF (NEW.account_role IS DISTINCT FROM OLD.account_role
      OR NEW.account_id IS DISTINCT FROM OLD.account_id
      OR NEW.custom_role_id IS DISTINCT FROM OLD.custom_role_id)
     AND current_user = 'authenticated'
  THEN
    RAISE EXCEPTION
      'account_role, account_id, and custom_role_id cannot be changed directly; use the account member RPCs'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.enforce_profile_privilege_columns() OWNER TO postgres;

-- Trigger already exists from 034 and fires the (now updated)
-- function body — no need to re-create it.

-- ============================================================
-- set_member_custom_role(p_user_id, p_custom_role_id)
--
-- Admin+ assigns (or clears, with NULL) a custom role on a
-- teammate. Only valid for 'agent'-tier members — owner/admin stay
-- full-authority and viewer stays read-only by design, so narrowing
-- either with a custom role would be meaningless. Cannot target
-- self, mirroring set_member_role (018).
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_member_custom_role(
  p_user_id UUID,
  p_custom_role_id UUID
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_account_id UUID;
  v_caller_role account_role_enum;
  v_target_account_id UUID;
  v_target_role account_role_enum;
  v_role_account_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT account_id, account_role
  INTO v_caller_account_id, v_caller_role
  FROM profiles
  WHERE user_id = auth.uid();

  IF v_caller_account_id IS NULL THEN
    RAISE EXCEPTION 'Caller has no account' USING ERRCODE = '42501';
  END IF;

  IF v_caller_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'This action requires the admin role or higher'
      USING ERRCODE = '42501';
  END IF;

  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot change your own custom role'
      USING ERRCODE = '22023';
  END IF;

  SELECT account_id, account_role
  INTO v_target_account_id, v_target_role
  FROM profiles
  WHERE user_id = p_user_id;

  IF v_target_account_id IS NULL THEN
    RAISE EXCEPTION 'Target user not found' USING ERRCODE = '22023';
  END IF;

  IF v_target_account_id <> v_caller_account_id THEN
    RAISE EXCEPTION 'Target user is not a member of your account'
      USING ERRCODE = '42501';
  END IF;

  IF v_target_role <> 'agent' THEN
    RAISE EXCEPTION 'Custom roles can only be assigned to agents'
      USING ERRCODE = '22023';
  END IF;

  IF p_custom_role_id IS NOT NULL THEN
    SELECT account_id INTO v_role_account_id
    FROM custom_roles
    WHERE id = p_custom_role_id;

    IF v_role_account_id IS NULL THEN
      RAISE EXCEPTION 'Custom role not found' USING ERRCODE = '22023';
    END IF;

    IF v_role_account_id <> v_caller_account_id THEN
      RAISE EXCEPTION 'Custom role does not belong to your account'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  UPDATE profiles
  SET custom_role_id = p_custom_role_id
  WHERE user_id = p_user_id;
END;
$$;

ALTER FUNCTION public.set_member_custom_role(UUID, UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.set_member_custom_role(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_member_custom_role(UUID, UUID) TO authenticated;
