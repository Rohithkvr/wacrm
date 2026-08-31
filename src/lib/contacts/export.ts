// ============================================================
// Contact/lead CSV export — turns the contacts table (+ tags +
// admin-defined custom fields) into a downloadable CSV so leads can
// be handed to a marketing tool (Mailchimp, Google/Meta Ads audience
// upload, a spreadsheet) without hand-copying rows out of the UI.
//
// Client-side only: contacts / contact_tags / custom_fields /
// contact_custom_values are already readable by the signed-in user
// via RLS (the same tables the Contacts page and detail view already
// query), so this needs no new API route or DB access.
// ============================================================

import type { Contact, Tag } from "@/types";

export interface ExportCustomField {
  id: string;
  field_name: string;
}

export interface ExportContactRow extends Contact {
  tags?: Tag[];
}

/** Escapes one CSV field per RFC 4180 — wraps in quotes and doubles
 *  any embedded quote whenever the value contains a comma, quote, or
 *  newline (a lead's company name or a custom-field note easily can). */
function csvCell(value: string | null | undefined): string {
  const s = value ?? "";
  if (/[",\n\r]/.test(s)) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function fmtDate(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? "" : d.toISOString().slice(0, 10);
}

/**
 * Builds the full CSV text. `customValuesByContact` maps
 * contact id -> (custom_field id -> value), pre-fetched by the
 * caller (one query for however many contacts are being exported).
 */
export function buildContactsCsv(
  contacts: ExportContactRow[],
  customFields: ExportCustomField[],
  customValuesByContact: Record<string, Record<string, string>>,
): string {
  const headers = [
    "Name",
    "Phone",
    "Email",
    "Company",
    "Tags",
    "Created at",
    ...customFields.map((f) => f.field_name),
  ];

  const rows = contacts.map((c) => {
    const tagNames = (c.tags ?? []).map((t) => t.name).join("; ");
    const values = customValuesByContact[c.id] ?? {};
    return [
      c.name ?? "",
      c.phone ?? "",
      c.email ?? "",
      c.company ?? "",
      tagNames,
      fmtDate(c.created_at),
      ...customFields.map((f) => values[f.id] ?? ""),
    ];
  });

  // Leading BOM so Excel (which otherwise guesses the system codepage)
  // renders non-ASCII names/companies correctly instead of as mojibake.
  const bom = "﻿";
  const lines = [headers, ...rows].map((row) => row.map(csvCell).join(","));
  return bom + lines.join("\r\n");
}

/** Triggers a browser download of `content` as `filename`. */
export function downloadCsv(filename: string, content: string): void {
  const blob = new Blob([content], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}
