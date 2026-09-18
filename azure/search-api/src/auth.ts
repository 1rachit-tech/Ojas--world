import { cert, getApps, initializeApp, type App } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { config } from "./config";
import type { AuthenticatedUser } from "./types";

let firebaseApp: App | null = null;

function firebaseAdmin(): App {
  if (firebaseApp) return firebaseApp;

  const existing = getApps()[0];
  if (existing) {
    firebaseApp = existing;
    return existing;
  }

  if (!config.firebaseServiceAccountJson) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON is not configured.");
  }

  const parsed = JSON.parse(config.firebaseServiceAccountJson);
  firebaseApp = initializeApp({
    credential: cert(parsed),
    projectId: config.firebaseProjectId || parsed.project_id,
  });
  return firebaseApp;
}

export async function authenticate(
  authorizationHeader: string | undefined,
): Promise<AuthenticatedUser | null> {
  const raw = authorizationHeader ?? "";
  const match = raw.match(/^Bearer\\s+(.+)$/i);

  if (!match) {
    return config.allowAnonymousDev ? { uid: "anonymous-dev" } : null;
  }

  try {
    const token = match[1].trim();
    const decoded = await getAuth(firebaseAdmin()).verifyIdToken(token);
    return { uid: decoded.uid };
  } catch {
    return null;
  }
}
