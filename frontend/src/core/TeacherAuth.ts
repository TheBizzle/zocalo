import { ref, watch } from "vue";

type JWTPayload = { readonly aud: string, readonly exp: number, readonly sub: string }

type Auth =
  { readonly emailAddr: string
  , readonly expiry:    number
  , readonly rawToken:  string
  };

const authM                    = ref<Auth | null>(null);
let teacherIDM: number | null  = null;

function amLoggedInSimple(): boolean {
  return Date.now() < (authM.value?.expiry ?? -1); // TODO?
}

async function amLoggedIn(): Promise<boolean> {
  if (!amLoggedInSimple()) {
    await refreshAuth();
  }
  return amLoggedInSimple();
}

async function authorizedFetch(url: string, options: RequestInit = {}): Promise<Response> {
  options.headers = {
    ...options.headers
  , Authorization: `Bearer ${await getAuthToken()}`
  };
  return fetch(url, options);
}

function clearAuth(): void {
  authM.value = null;
  teacherIDM  = null;
}

async function getAuthToken(): Promise<string | null> {
  if (!amLoggedInSimple()) {
    await refreshAuth();
  }
  return (authM.value !== null) ? authM.value.rawToken : null;
}

async function logout():  Promise<void> {
  await fetch("/api/auth/teacher/logout", { method: "POST" , credentials: "include" });
  clearAuth();
}

function onAuthChange(f: () => void): void {
  watch(authM, f);
};

async function refreshAuth(): Promise<boolean> {

  let reason = null;

  const res = await fetch("/api/auth/teacher/refresh", { method: "POST" , credentials: "include" });

  if (res.ok) {
    storeToken(await res.text());
    const res2 = await authorizedFetch("/api/auth/teacher/who-am-i");
    if (res2.ok) {
      const num = parseInt(await res2.text());
      if (!Number.isNaN(num)) {
        teacherIDM = num;
        return true;
      } else {
        reason = `Non-numeric teacher ID: ${num}`;
      }
    } else {
      reason = await res2.text();
    }
  } else {
    reason = await res.text();
  }

  clearAuth();
  console.error("Auth refresh failed", reason);

  return false;

}

function storeToken(compactToken: string): void {
  const [emailAddr, expiry] = decodeJWT(compactToken);
  authM.value = { emailAddr, expiry, rawToken: compactToken };
}

function decodeJWT(compactToken: string): [string, number] {

  function decodeBase64URL(str: string): string {
    const base64 =
      str.replace(/-/g, "+").
        replace(/_/g, "/").
        padEnd(str.length + (4 - str.length % 4) % 4, "=");
    return atob(base64);
  };

  const chunks = compactToken.split(".");
  if (chunks.length === 3) {
    const [_rawHeader, rawPayload, _signature] = chunks;
    const { aud, exp, sub } = JSON.parse(decodeBase64URL(rawPayload!)) as JWTPayload;
    if (aud === "gallery|teacher") {
      return [sub, Math.floor(exp * 1e3)];
    } else {
      throw new Error(`Invalid JWT audience: ${aud}`);
    }
  } else {
    throw new Error("Invalid JWT format");
  }

}

function getTeacherID(): number {
  if (teacherIDM !== null) {
    return teacherIDM;
  } else {
    throw new Error("Illegal state: Requested teacher ID while it was unset.");
  }
}

export { amLoggedIn, amLoggedInSimple, authorizedFetch, getAuthToken, getTeacherID, logout, onAuthChange
       , refreshAuth, storeToken };
