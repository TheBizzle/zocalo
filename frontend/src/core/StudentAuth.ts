type JWTPayload = { readonly aud: string, readonly exp: number, readonly sub: string }

type Auth =
  { readonly idNum:    number
  , readonly username: string
  , readonly expiry:   number
  , readonly rawToken: string
  };

let authM:      Auth | null = null;
let username: string | null = null;

function amLoggedInSimple(): boolean {
  return Date.now() < (authM?.expiry ?? -1); // TODO?
}

async function amLoggedIn(): Promise<boolean> {
  if (!amLoggedInSimple()) {
    await getAuthorized();
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
    await getAuthorized();
  }
  return (authM !== null) ? authM.rawToken : null;
}

async function logout():  Promise<void> {
  await fetch("/api/auth/student/logout", { method: "POST" , credentials: "include" });
  clearAuth();
}

async function getAuthorized(): Promise<boolean> {
  const hadRefreshCookie = await refreshAuth();
  return hadRefreshCookie ? hadRefreshCookie : getFreshToken(false);
}

async function getFreshToken(isNameRequired: boolean): Promise<boolean> {

  if (!isNameRequired) {

    const res = await fetch( "/api/auth/student/refresh", { method: "POST" , credentials: "include" });

    if (res.ok) {
      storeToken(await res.text());
      return true;
    } else {
      return getFreshToken(true);
    }

  } else {

    const params   = new URLSearchParams({ username: initUsername(null) });
    const url      = `/api/auth/student/fresh-cookies?${params}`;
    const res      = await fetch(url, { method: "POST" , credentials: "include" });

    if (res.ok) {
      storeToken(await res.text());
      return true;
    } else {
      const reason = await res.text();
      clearAuth();
      console.error("Complete auth refresh failed:", reason);
      return false;
    }

  }

}

async function refreshAuth(): Promise<boolean> {

  let reason = null;

  const res = await fetch("/api/auth/student/refresh", { method: "POST" , credentials: "include" });

  if (res.ok) {
    storeToken(await res.text());
    return true;
  } else {
    reason = await res.text();
  }

  clearAuth();
  console.error("Auth refresh failed:", reason);

  return false;

}

function storeToken(compactToken: string): void {
  const [idNum, name, expiry] = decodeJWT(compactToken);
  authM = { idNum, username: name, expiry, rawToken: compactToken };
}

function decodeJWT(compactToken: string): [number, string, number] {

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
    if (aud === "gallery|student") {
      const [idStr, name] = sub.split("|");
      return [parseInt(idStr!), name ?? "Anonymous", Math.floor(exp * 1e3)];
    } else {
      throw new Error(`Invalid JWT audience: ${aud}`);
    }
  } else {
    throw new Error("Invalid JWT format");
  }

}

function getStudentID(): number {
  if (authM !== null) {
    return authM.idNum;
  } else {
    throw new Error("Illegal state: Requested student ID while it was unset.");
  }
}

function getStudentName(): string {
  if (authM !== null) {
    return authM.username;
  } else {
    throw new Error("Illegal state: Requested student name while it was unset.");
  }
}

function initUsername(externalName: string | null): string {
  if (username !== null) {
    username = username;
  } else if (externalName !== null) {
    username = externalName;
  } else {
    let name = prompt("Please enter your name.");
    while ((name?.trim().length ?? 0) < 1) {
      name = prompt("Please enter your name.");
    }
    username = name ?? "Anonymous and impossible";
  }
  return username;
}

export { amLoggedIn, authorizedFetch, getAuthToken, getStudentID, getStudentName, initUsername, logout
       , refreshAuth, storeToken };
