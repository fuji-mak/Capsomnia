const COOKIE_NAME = "capsomnia_locale";
const COOKIE_MAX_AGE = 60 * 60 * 24 * 365;
const LANGUAGE_QUERY = "lang";

const LOCALES = {
  en: { path: "/" },
  ja: { path: "/ja/" },
  "zh-hans": { path: "/zh-hans/" }
};

export function normalizeLocale(value) {
  if (!value) return null;

  const normalized = value.trim().toLowerCase();
  if (normalized === "en") return "en";
  if (normalized === "ja") return "ja";
  if (normalized === "zh" || normalized === "zh-hans") return "zh-hans";
  return null;
}

function localeForLanguageTag(value) {
  const tag = value.trim().toLowerCase();
  if (tag === "*") return "en";
  if (tag === "en" || tag.startsWith("en-")) return "en";
  if (tag === "ja" || tag.startsWith("ja-")) return "ja";
  if (tag === "zh" || tag.startsWith("zh-")) return "zh-hans";
  return null;
}

export function localeFromAcceptLanguage(value) {
  if (!value) return null;

  const candidates = value
    .split(",")
    .map((entry, index) => {
      const [tag, ...parameters] = entry.trim().split(";");
      let quality = 1;

      for (const parameter of parameters) {
        const match = parameter.trim().match(/^q=(0(?:\.\d{0,3})?|1(?:\.0{0,3})?)$/i);
        if (match) quality = Number(match[1]);
      }

      return { tag, quality, index };
    })
    .filter(({ tag, quality }) => tag && quality > 0)
    .sort((a, b) => b.quality - a.quality || a.index - b.index);

  for (const candidate of candidates) {
    const locale = localeForLanguageTag(candidate.tag);
    if (locale) return locale;
  }

  return null;
}

export function readCookie(cookieHeader, name) {
  if (!cookieHeader) return null;

  for (const entry of cookieHeader.split(";")) {
    const separator = entry.indexOf("=");
    if (separator === -1) continue;

    const key = entry.slice(0, separator).trim();
    if (key === name) return entry.slice(separator + 1).trim();
  }

  return null;
}

function addLanguageVary(headers) {
  const existing = headers.get("Vary");
  if (existing?.trim() === "*") return;

  const values = new Map();
  for (const value of (existing ?? "").split(",")) {
    const trimmed = value.trim();
    if (trimmed) values.set(trimmed.toLowerCase(), trimmed);
  }
  values.set("accept-language", "Accept-Language");
  values.set("cookie", "Cookie");
  headers.set("Vary", [...values.values()].join(", "));
}

function languageCookie(locale) {
  return [
    `${COOKIE_NAME}=${locale}`,
    "Path=/",
    `Max-Age=${COOKIE_MAX_AGE}`,
    "HttpOnly",
    "Secure",
    "SameSite=Lax"
  ].join("; ");
}

function redirectToLocale(sourceUrl, locale, rememberChoice = false) {
  const destination = new URL(sourceUrl);
  destination.pathname = LOCALES[locale].path;
  destination.searchParams.delete(LANGUAGE_QUERY);

  const headers = new Headers({
    "Cache-Control": "private, no-store",
    Location: destination.toString()
  });
  addLanguageVary(headers);
  if (rememberChoice) headers.set("Set-Cookie", languageCookie(locale));

  return new Response(null, {
    status: 302,
    headers
  });
}

async function fetchRootWithVary(request, fetchOrigin) {
  const response = await fetchOrigin(request);
  const headers = new Headers(response.headers);
  addLanguageVary(headers);

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers
  });
}

export async function handleRequest(request, fetchOrigin = fetch) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return fetchOrigin(request);
  }

  const url = new URL(request.url);
  const requestedLocale = normalizeLocale(url.searchParams.get(LANGUAGE_QUERY));

  if (requestedLocale) {
    return redirectToLocale(url, requestedLocale, true);
  }

  if (url.pathname !== "/") {
    return fetchOrigin(request);
  }

  const cookieLocale = normalizeLocale(
    readCookie(request.headers.get("Cookie"), COOKIE_NAME)
  );
  const preferredLocale =
    cookieLocale ??
    localeFromAcceptLanguage(request.headers.get("Accept-Language")) ??
    "en";

  if (preferredLocale !== "en") {
    return redirectToLocale(url, preferredLocale);
  }

  return fetchRootWithVary(request, fetchOrigin);
}

export default {
  fetch(request, _env, ctx) {
    ctx.passThroughOnException();
    return handleRequest(request, (originRequest) => fetch(originRequest));
  }
};
