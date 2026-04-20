type JWTPayload = { readonly aud: string, readonly exp: number, readonly sub: string }

type Auth =
  { readonly emailAddr: string
  , readonly expiry:    number
  , readonly rawToken:  string
  };

let authM: Auth | null = null;

const amLoggedInSimple = (): boolean => {
  return Date.now() < (authM?.expiry ?? -1); // TODO?
};

const amLoggedIn = async (): Promise<boolean> => {
  if (!amLoggedInSimple()) {
    await refreshAuth();
  }
  return amLoggedInSimple();
};

const clearAuth = (): void => {
  authM = null;
};

const getAuthToken = async (): Promise<string | null> => {
  if (!amLoggedInSimple()) {
    await refreshAuth();
  }
  return (authM !== null) ? authM.rawToken : null;
};

const logout = async (): Promise<void> => {
  await fetch("/api/auth/teacher/logout", { method: "POST" , credentials: "include" });
  clearAuth();
};

const refreshAuth = async (): Promise<boolean> => {
  const res = await fetch("/api/auth/teacher/refresh", { method: "POST" , credentials: "include" });
  if (res.ok) {
    storeToken(await res.text());
  } else {
    clearAuth();
    console.error("Auth refresh failed", await res.text());
  }
  return res.ok;
};

const storeToken = (compactToken: string): void => {
  const [emailAddr, expiry] = decodeJWT(compactToken);
  authM = { emailAddr, expiry, rawToken: compactToken };
};

const decodeJWT = (compactToken: string): [string, number] => {

  const decodeBase64URL =
    (str: string): string => {
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

};

export { amLoggedIn, getAuthToken, logout, refreshAuth, storeToken };
