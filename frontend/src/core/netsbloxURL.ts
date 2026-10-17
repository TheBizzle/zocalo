const NETSBLOX_ORIGIN = "https://editor.netsblox.org";
const DEFAULT_STARTER = `${NETSBLOX_ORIGIN}/`;

function parseStarterURL(urlStr: string | null): URL {

  if (urlStr !== null) {
    try {
      const url     = new URL(urlStr);
      const isValid = url.origin === NETSBLOX_ORIGIN && url.username === "" && url.password === "";
      if (isValid) {
        return url;
      }
    } catch {}
    console.warn(`NetsBlox origin URL was invalid: ${urlStr}`);
  }

  return new URL(DEFAULT_STARTER);

}

function buildNetsBloxURL(rawStarter: string | null, params: Record<string, string>): string {
  const url = parseStarterURL(rawStarter);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }
  return url.href;
}

export { buildNetsBloxURL, NETSBLOX_ORIGIN, parseStarterURL };
