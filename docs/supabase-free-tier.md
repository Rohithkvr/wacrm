# Running this CRM on Supabase's free tier

This CRM stores everything in Supabase (Postgres database, Auth, file
Storage, and Realtime). All four sit inside Supabase's **Free plan**,
so the question isn't "does it cost money" — it's "which free-plan
limit will I hit first, and how do I stay under it."

> **These numbers change.** Supabase updates plan limits from time to
> time. Treat the figures here as "what to watch," and confirm the
> live numbers at <https://supabase.com/pricing> before making a
> decision based on a specific threshold.

---

## The free-plan limits, ranked by how likely *this app* is to hit them

| Resource | Free-plan limit | How this CRM uses it | Risk |
|---|---|---|---|
| **File Storage** | **1 GB** | Every image / audio / video sent or received on WhatsApp is mirrored into Storage (chat media), plus user avatars. | **Highest** — media piles up fast |
| **Database size** | **500 MB** | Every message row, conversation, contact, deal, automation log, broadcast recipient. | **High** — the `messages` and `automation_logs` tables grow forever |
| **Egress (bandwidth)** | **5 GB / month** | Serving media back to the browser, API responses, Realtime traffic. | Medium |
| **Project inactivity pause** | Pauses after **7 days** with no requests | A staging/backup project you forget about gets paused. | Medium (easy to avoid) |
| **Realtime** | **200 concurrent connections**, ~2M messages/mo | One connection per open Inbox browser tab. | Low for a small team |
| **Monthly Active Users (Auth)** | **50,000 MAU** | Team members signing in. | Effectively never, for a CRM team |
| **Edge Functions** | 500K invocations/mo | This app doesn't use Edge Functions (logic runs in Next.js). | None |

**Bottom line:** for a WhatsApp CRM, you run out of **Storage first,
then database size** — both because of *accumulated history* (media
and message rows), not because of how many people use it. A 3-person
team and a 300-person team hit these limits at roughly the same time
if they handle the same message volume.

---

## Rough capacity, in plain terms

These are ballpark figures to build intuition, not guarantees:

- **500 MB database** ≈ **300,000–800,000 message rows** (text
  messages are tiny; the spread depends on how much metadata and how
  many automation logs / broadcast-recipient rows ride alongside).
- **1 GB Storage** ≈ **1,000–5,000 media files** (one WhatsApp photo
  is ~100–500 KB; a voice note ~20–100 KB; a video can be several MB
  and will eat the budget far faster).
- **5 GB egress/month** is generous for text but **media re-downloads
  are the drain** — if agents repeatedly reopen media-heavy threads,
  each view re-serves the file.

A small team doing mostly-text support can run for **many months to a
year+** on free. A team pushing lots of image/video/voice will feel
the Storage limit in **weeks to a couple of months**.

---

## How to stay on the free tier (in priority order)

### 1. Control media — this is the #1 lever
Media is what fills the 1 GB Storage bucket.

- **Prune old media on a schedule.** Media older than N months is
  rarely reopened. Deleting old files from the Storage bucket frees
  the most space for the least effort. (Keep the message *text* rows —
  they're tiny — just drop the heavy media blobs.)
- **Decide whether you even need inbound media mirrored.** The
  inbound-media mirror (migrations 023 / 039) copies media into your
  Storage so it survives Meta's expiry. If you don't need long-term
  media retention, not mirroring it keeps Storage near-empty.
- **Watch video especially.** A handful of forwarded videos can be
  more MB than thousands of text messages.

### 2. Keep the `messages` and log tables from growing forever
These are the tables that silently consume the 500 MB database.

- **Archive or delete old messages** past your retention need (e.g.
  older than 12 months). A dashboard SQL query or a scheduled job that
  deletes `messages` and `automation_logs` older than a cutoff keeps
  the database flat instead of ever-growing.
- **`automation_logs` and broadcast-recipient rows** accumulate one
  row per automation run / per recipient. If you run large broadcasts
  or busy automations, prune these periodically too.
- After a big delete, run `VACUUM` (Supabase Dashboard → SQL Editor:
  `VACUUM;`) so Postgres actually reclaims the freed space — a plain
  `DELETE` marks rows dead but doesn't shrink the file until vacuumed.

### 3. Don't let the project pause
Free projects **pause after 7 days of no activity**, which takes the
whole CRM offline until you un-pause it in the dashboard.

- If the CRM is used regularly, normal traffic keeps it awake — no
  action needed.
- If you have a *second* project (a staging copy, an old experiment),
  either delete it or hit it occasionally so it doesn't pause. The
  free plan allows 2 active projects per organization; a forgotten
  third or a paused primary is the usual trap.

### 4. Reduce egress (only if you approach 5 GB/month)
- The app already sets sensible cache headers (`next.config.ts`), so
  static assets aren't re-fetched constantly.
- The biggest egress source is media downloads — the same pruning in
  step 1 reduces both Storage *and* egress.

### 5. Watch the numbers before they bite
- **Supabase Dashboard → Settings → Usage** shows live database size,
  storage, egress, and MAU against the plan caps. Check it monthly.
- **Supabase Dashboard → Reports** breaks down what's growing.
- Set a calendar reminder to glance at Usage once a month — hitting a
  limit unexpectedly is worse than a 2-minute monthly check.

---

## What happens if you cross a limit

- **Database over 500 MB / Storage over 1 GB:** Supabase restricts the
  project (it can go read-only or block new writes) until you either
  free space or upgrade. Your data isn't deleted — but the CRM stops
  accepting new messages/contacts until you're back under.
- **Egress over 5 GB:** Supabase may throttle or bill overage
  depending on current policy — check the pricing page.
- **The fix is always the same two choices:** free up space (prune
  media + old rows, then `VACUUM`), or upgrade to the Pro plan (paid,
  which raises every limit and adds daily backups).

---

## One thing the free tier does NOT give you: backups

The free plan has **no automatic daily backups** and no
point-in-time recovery. If keeping this data matters:

- Periodically export a backup yourself — Supabase Dashboard →
  Database → Backups, or a `pg_dump` via the connection string.
- Keep the export somewhere off Supabase (your machine, cloud drive).
- This is the single most important habit on free tier: a monthly
  manual export means an accidental bad delete or a project problem
  isn't catastrophic.

---

## Quick monthly checklist

- [ ] Dashboard → Settings → Usage: database, storage, egress all
      comfortably under the caps?
- [ ] Storage bucket not filling with old media? (prune if >70% of 1 GB)
- [ ] `messages` / `automation_logs` not ballooning? (prune old rows +
      `VACUUM` if the database is >70% of 500 MB)
- [ ] Took a manual backup this month?
- [ ] No forgotten second project about to pause (or already paused)?

Do these five things once a month and a small-to-mid WhatsApp CRM
stays on the free tier comfortably. The day your *media retention* or
*message history* genuinely needs to outgrow 1 GB / 500 MB is the day
the Pro plan is worth it — not before.
