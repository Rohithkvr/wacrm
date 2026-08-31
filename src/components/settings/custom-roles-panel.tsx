'use client';

// ============================================================
// CustomRolesPanel — Settings → Custom roles
//
// Admin+ defines named roles that narrow what an 'agent' can see:
// Inbox, Contacts/Pipelines, Broadcasts/Automations — each an
// independent on/off switch. Owner/admin stay full-authority and
// viewer stays read-only regardless (see `@/lib/auth/custom-roles`);
// this panel only ever creates roles that *restrict* an agent, never
// grant anything beyond agent-level access.
//
// Assigning a role to a specific teammate happens in the Members
// tab (a "Restrict to" picker next to any agent-tier row), not here
// — this panel only manages the role definitions themselves.
// ============================================================

import { useCallback, useEffect, useState } from 'react';
import { toast } from 'sonner';
import { Loader2, Lock, Plus, Trash2 } from 'lucide-react';
import { useTranslations } from 'next-intl';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { useAuth } from '@/hooks/use-auth';
import type { CustomRole } from '@/lib/auth/custom-roles';
import { SettingsPanelHead } from './settings-panel-head';

type PermissionKey =
  | 'can_inbox'
  | 'can_contacts_pipelines'
  | 'can_broadcasts_automations';

const PERMISSION_KEYS: PermissionKey[] = [
  'can_inbox',
  'can_contacts_pipelines',
  'can_broadcasts_automations',
];

interface FormState {
  name: string;
  can_inbox: boolean;
  can_contacts_pipelines: boolean;
  can_broadcasts_automations: boolean;
}

const EMPTY_FORM: FormState = {
  name: '',
  can_inbox: true,
  can_contacts_pipelines: true,
  can_broadcasts_automations: true,
};

interface CustomRolesPanelProps {
  /** Called after any create/update/delete so a parent embedding this
   *  panel (Team members) can refresh its own copy of the roles list
   *  — e.g. the per-member "Restrict to" picker in the roster. */
  onRolesChanged?: () => void;
}

export function CustomRolesPanel({ onRolesChanged }: CustomRolesPanelProps) {
  const t = useTranslations('Settings.customRoles');
  const { canManageMembers, profileLoading } = useAuth();

  const [roles, setRoles] = useState<CustomRole[]>([]);
  const [loading, setLoading] = useState(true);

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingRole, setEditingRole] = useState<CustomRole | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  const [deletingRole, setDeletingRole] = useState<CustomRole | null>(null);
  const [deleting, setDeleting] = useState(false);

  const loadRoles = useCallback(async () => {
    try {
      const res = await fetch('/api/account/custom-roles', { cache: 'no-store' });
      if (!res.ok) {
        if (res.status !== 403) {
          const payload = await res.json().catch(() => ({}));
          toast.error(payload.error || t('loadError'));
        }
        return;
      }
      const data = (await res.json()) as { roles: CustomRole[] };
      setRoles(data.roles);
    } catch (err) {
      console.error('[CustomRolesPanel] load error:', err);
      toast.error(t('loadError'));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    if (profileLoading) return;
    if (!canManageMembers) {
      setLoading(false);
      return;
    }
    void loadRoles();
  }, [profileLoading, canManageMembers, loadRoles]);

  function openCreate() {
    setEditingRole(null);
    setForm(EMPTY_FORM);
    setDialogOpen(true);
  }

  function openEdit(role: CustomRole) {
    setEditingRole(role);
    setForm({
      name: role.name,
      can_inbox: role.can_inbox,
      can_contacts_pipelines: role.can_contacts_pipelines,
      can_broadcasts_automations: role.can_broadcasts_automations,
    });
    setDialogOpen(true);
  }

  async function handleSave() {
    const name = form.name.trim();
    if (!name) return;
    setSaving(true);
    try {
      const res = await fetch(
        editingRole
          ? `/api/account/custom-roles/${editingRole.id}`
          : '/api/account/custom-roles',
        {
          method: editingRole ? 'PATCH' : 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ...form, name }),
        },
      );
      if (!res.ok) {
        const payload = await res.json().catch(() => ({}));
        toast.error(payload.error || t('saveError'));
        return;
      }
      toast.success(editingRole ? t('updatedToast', { name }) : t('createdToast', { name }));
      setDialogOpen(false);
      await loadRoles();
      onRolesChanged?.();
    } catch (err) {
      console.error('[CustomRolesPanel] save error:', err);
      toast.error(t('saveError'));
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!deletingRole) return;
    setDeleting(true);
    try {
      const res = await fetch(`/api/account/custom-roles/${deletingRole.id}`, {
        method: 'DELETE',
      });
      if (!res.ok) {
        const payload = await res.json().catch(() => ({}));
        toast.error(payload.error || t('deleteError'));
        return;
      }
      toast.success(t('deletedToast', { name: deletingRole.name }));
      setRoles((prev) => prev.filter((r) => r.id !== deletingRole.id));
      setDeletingRole(null);
      onRolesChanged?.();
    } catch (err) {
      console.error('[CustomRolesPanel] delete error:', err);
      toast.error(t('deleteError'));
    } finally {
      setDeleting(false);
    }
  }

  if (profileLoading || loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="size-6 animate-spin text-primary" />
      </div>
    );
  }

  if (!canManageMembers) {
    return (
      <Card>
        <CardContent className="flex flex-col items-center justify-center gap-2 py-12 text-center">
          <Lock className="size-6 text-muted-foreground" />
          <p className="text-sm text-muted-foreground">{t('adminOnly')}</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <section className="animate-in fade-in-50 space-y-6 duration-200">
      <SettingsPanelHead
        title={t('title')}
        description={t('description')}
        action={
          <Button onClick={openCreate}>
            <Plus className="size-4" />
            {t('newRole')}
          </Button>
        }
      />

      {roles.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-10 text-center">
            <Lock className="size-6 text-muted-foreground" />
            <p className="mt-2 text-sm text-muted-foreground">{t('emptyTitle')}</p>
            <p className="mt-1 text-xs text-muted-foreground">{t('emptyDesc')}</p>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="p-0">
            <ul className="divide-y divide-border">
              {roles.map((role) => (
                <li
                  key={role.id}
                  className="flex flex-col gap-3 px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-foreground">{role.name}</p>
                    <p className="mt-0.5 flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-muted-foreground">
                      <span className={role.can_inbox ? '' : 'line-through opacity-60'}>
                        {t('featureInbox')}
                      </span>
                      <span className={role.can_contacts_pipelines ? '' : 'line-through opacity-60'}>
                        {t('featureContactsPipelines')}
                      </span>
                      <span className={role.can_broadcasts_automations ? '' : 'line-through opacity-60'}>
                        {t('featureBroadcastsAutomations')}
                      </span>
                    </p>
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => openEdit(role)}
                      className="border-border text-foreground hover:bg-muted"
                    >
                      {t('edit')}
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setDeletingRole(role)}
                      className="border-red-500/40 bg-red-500/10 text-red-300 hover:border-red-500/60 hover:bg-red-500/20 hover:text-red-200"
                    >
                      <Trash2 className="size-4" />
                    </Button>
                  </div>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      )}

      {/* Create / edit dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="bg-popover border-border sm:max-w-sm">
          <DialogHeader>
            <DialogTitle className="text-popover-foreground">
              {editingRole ? t('editRoleTitle') : t('newRoleTitle')}
            </DialogTitle>
            <DialogDescription className="text-muted-foreground">
              {t('dialogDesc')}
            </DialogDescription>
          </DialogHeader>

          <div className="flex flex-col gap-4 py-2">
            <div className="flex flex-col gap-2">
              <Label className="text-muted-foreground">{t('roleName')}</Label>
              <Input
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                placeholder={t('roleNamePlaceholder')}
                className="bg-muted border-border text-foreground"
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleSave();
                }}
              />
            </div>

            <div className="flex flex-col gap-3">
              {PERMISSION_KEYS.map((key) => (
                <div
                  key={key}
                  className="flex items-center justify-between gap-3 rounded-lg border border-border bg-muted/40 px-3 py-2.5"
                >
                  <span className="text-sm text-foreground">
                    {t(
                      key === 'can_inbox'
                        ? 'featureInbox'
                        : key === 'can_contacts_pipelines'
                          ? 'featureContactsPipelines'
                          : 'featureBroadcastsAutomations',
                    )}
                  </span>
                  <Switch
                    checked={form[key]}
                    onCheckedChange={(checked: boolean) =>
                      setForm((f) => ({ ...f, [key]: checked }))
                    }
                  />
                </div>
              ))}
            </div>
          </div>

          <DialogFooter className="bg-popover/50 border-border">
            <Button
              variant="outline"
              onClick={() => setDialogOpen(false)}
              className="border-border text-muted-foreground hover:bg-muted"
            >
              {t('cancel')}
            </Button>
            <Button onClick={handleSave} disabled={saving || !form.name.trim()}>
              {saving ? t('saving') : editingRole ? t('saveChanges') : t('createRole')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete confirmation */}
      <Dialog
        open={deletingRole !== null}
        onOpenChange={(open) => {
          if (!open) setDeletingRole(null);
        }}
      >
        <DialogContent className="bg-popover border-border sm:max-w-sm">
          <DialogHeader>
            <DialogTitle className="text-popover-foreground">
              {t('deleteDialogTitle')}
            </DialogTitle>
            <DialogDescription className="text-muted-foreground">
              {t('deleteDialogDesc', { name: deletingRole?.name ?? '' })}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="bg-popover border-border">
            <Button
              variant="outline"
              onClick={() => setDeletingRole(null)}
              className="border-border text-muted-foreground hover:bg-muted"
            >
              {t('cancel')}
            </Button>
            <Button
              onClick={handleDelete}
              disabled={deleting}
              className="bg-red-600 hover:bg-red-700 text-white"
            >
              {deleting ? (
                <>
                  <Loader2 className="size-4 animate-spin" />
                  {t('deleting')}
                </>
              ) : (
                t('deleteBtn')
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </section>
  );
}
