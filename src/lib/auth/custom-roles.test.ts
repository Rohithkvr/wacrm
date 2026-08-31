import { describe, expect, it } from "vitest";
import { canAccessFeature, type CustomRole } from "./custom-roles";

const restrictedToInbox: CustomRole = {
  id: "role-1",
  name: "Caller",
  can_inbox: true,
  can_contacts_pipelines: false,
  can_broadcasts_automations: false,
};

describe("canAccessFeature", () => {
  it("denies everything without a role", () => {
    expect(canAccessFeature(null, null, "inbox")).toBe(false);
  });

  it("owner and admin always have full access, custom role or not", () => {
    for (const role of ["owner", "admin"] as const) {
      expect(canAccessFeature(role, restrictedToInbox, "contacts_pipelines")).toBe(true);
      expect(canAccessFeature(role, null, "broadcasts_automations")).toBe(true);
    }
  });

  it("viewer always has access regardless of any custom role", () => {
    expect(canAccessFeature("viewer", restrictedToInbox, "contacts_pipelines")).toBe(true);
    expect(canAccessFeature("viewer", null, "broadcasts_automations")).toBe(true);
  });

  it("an agent with no custom role gets unrestricted access", () => {
    expect(canAccessFeature("agent", null, "inbox")).toBe(true);
    expect(canAccessFeature("agent", null, "contacts_pipelines")).toBe(true);
    expect(canAccessFeature("agent", null, "broadcasts_automations")).toBe(true);
  });

  it("an agent with a custom role is narrowed to exactly its flags", () => {
    expect(canAccessFeature("agent", restrictedToInbox, "inbox")).toBe(true);
    expect(canAccessFeature("agent", restrictedToInbox, "contacts_pipelines")).toBe(false);
    expect(canAccessFeature("agent", restrictedToInbox, "broadcasts_automations")).toBe(false);
  });
});
