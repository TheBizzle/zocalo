type JWTPayload = { readonly aud: string, readonly exp: number, readonly sub: string }

type Auth =
  { readonly idNum:    number
  , readonly username: string
  , readonly expiry:   number
  , readonly rawToken: string
  };

let authM:      Auth | null = null;
let username: string | null = null;

const CLOCK_SKEW_MARGIN_MS = 30_000;
const MAX_NAME_LENGTH      = 60;

function amLoggedInSimple(): boolean {
  return Date.now() + CLOCK_SKEW_MARGIN_MS < (authM?.expiry ?? -1); // TODO?
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
  async function helper(): Promise<boolean> {
    if (amLoggedInSimple()) {
      return true;
    } else {
      const hadRefreshCookie = await refreshAuth();
      return hadRefreshCookie ? hadRefreshCookie : getFreshToken(false);
    }
  }
  return exclusively("zocalo-student-auth", helper);
}

async function getFreshToken(isNameRequired: boolean): Promise<boolean> {

  if (!isNameRequired) {

    const url = "/api/auth/student/refresh";
    const res = await fetch(url, { method: "POST" , credentials: "include" });

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
      if (res.status === 422) { // Username rejected by server --Jason B. (10/31/26)
        username = null;
      }
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
  username = name;
  authM = { idNum, username, expiry, rawToken: compactToken };
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
      const [idStr, ...nameComponents] = sub.split("|");
      const name                       = nameComponents.join("|");
      return [parseInt(idStr!, 10), name, Math.floor(exp * 1e3)];
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
  username ??= validateName(externalName);
  if (username === null) {
    let entered = validateName(prompt("Please enter your name."));
    while (entered === null) {
      entered = validateName(prompt(`Please enter a name with no more than ${MAX_NAME_LENGTH} characters.`));
    }
    username = entered;
  }
  return username;
}

function validateName(rawName: string | null): string | null {
  const name = rawName?.trim() ?? "";
  const isOK = name.length > 0 && [...name].length <= MAX_NAME_LENGTH && !/\p{Cc}/u.test(name);
  return isOK ? name : null;
}

async function exclusively<T>(name: string, task: () => Promise<T>): Promise<T> {
  const locks = (navigator as { locks?: LockManager }).locks;
  return (locks === undefined) ? task() : locks.request(name, async () => task());
}

export { amLoggedIn, authorizedFetch, getAuthToken, getStudentID, getStudentName, initUsername, logout
       , refreshAuth, storeToken };
