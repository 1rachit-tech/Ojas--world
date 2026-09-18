import { getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { config } from "./config";
import type { AuthenticatedUser } from "./types";

function firestore() {
  if (getApps().length === 0) {
    throw new Error("Firebase Admin is not initialized.");
  }
  return getFirestore();
}

async function loadBlockedIds(uid: string): Promise<Set<string>> {
  const output = new Set<string>();

  const own = await firestore()
    .collection("userBlocks")
    .doc(uid)
    .collection("blocked")
    .limit(5000)
    .get();

  for (const doc of own.docs) {
    const value = doc.data().blockedUserId;
    output.add(
      typeof value === "string" && value.trim()
        ? value.trim()
        : doc.id,
    );
  }

  const inbound = await firestore()
    .collectionGroup("blocked")
    .where("blockedUserId", "==", uid)
    .limit(5000)
    .get();

  for (const doc of inbound.docs) {
    const owner = doc.ref.parent.parent?.id;
    if (owner) output.add(owner);
  }

  return output;
}

export async function loadSafetyContext(
  user: AuthenticatedUser,
): Promise<{ blockedCreatorIds: Set<string> }> {
  if (user.uid === "anonymous-dev") {
    return { blockedCreatorIds: new Set<string>() };
  }

  if (!config.firebaseServiceAccountJson) {
    throw new Error("Production safety requires Firebase Admin credentials.");
  }

  return {
    blockedCreatorIds: await loadBlockedIds(user.uid),
  };
}

export function odataFilterForSafety(
  blocked: Set<string>,
  tab: string,
): string {
  const clauses: string[] = [
    "eligible eq true",
    "visibility eq 'public'",
  ];

  if (tab === "people") {
    clauses.push("entityType eq 'person'");
  }

  if (tab === "videos" || tab === "posts") {
    clauses.push("entityType eq 'content'");
  }

  if (tab === "live") {
    clauses.push("entityType eq 'content'", "isLive eq true");
  }

  if (blocked.size > 0) {
    const values = Array.from(blocked)
      .slice(0, 1000)
      .map((value) => value.replace(/'/g, "''"))
      .join(",");

    clauses.push("not search.in(creatorId, '" + values + "', ',')");
  }

  return clauses.join(" and ");
}

export function ensureSafetyConfiguration(): void {
  if (!config.allowAnonymousDev && !config.firebaseServiceAccountJson) {
    throw new Error("Production Search requires Firebase Admin credentials.");
  }
}
