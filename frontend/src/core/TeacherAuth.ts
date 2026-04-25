type JWTPayload = { readonly aud: string, readonly exp: number, readonly sub: string }

type Auth =
  { readonly emailAddr: string
  , readonly expiry:    number
  , readonly rawToken:  string
  };

let authM: Auth | null = null;

function amLoggedInSimple(): boolean {
  return Date.now() < (authM?.expiry ?? -1); // TODO?
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
  authM = null;
}

async function getAuthToken(): Promise<string | null> {
  if (!amLoggedInSimple()) {
    await refreshAuth();
  }
  return (authM !== null) ? authM.rawToken : null;
}

async function logout():  Promise<void> {
  await fetch("/api/auth/teacher/logout", { method: "POST" , credentials: "include" });
  clearAuth();
}

async function refreshAuth(): Promise<boolean> {
  const res = await fetch("/api/auth/teacher/refresh", { method: "POST" , credentials: "include" });
  if (res.ok) {
    storeToken(await res.text());
  } else {
    clearAuth();
    console.error("Auth refresh failed", await res.text());
  }
  return res.ok;
}

function storeToken(compactToken: string): void {
  const [emailAddr, expiry] = decodeJWT(compactToken);
  authM = { emailAddr, expiry, rawToken: compactToken };
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
    const { aud, exp, sub } = JSON.parse(decodeBase64URL(rawPayload)) as JWTPayload;
    if (aud === "gallery") {
      return [sub, Math.floor(exp * 1e3)];
    } else {
      throw new Error(`Invalid JWT audience: ${aud}`);
    }
  } else {
    throw new Error("Invalid JWT format");
  }

}

export { amLoggedIn, authorizedFetch, getAuthToken, logout, refreshAuth, storeToken };
