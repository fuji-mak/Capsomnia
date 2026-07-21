import assert from "node:assert/strict";
import test from "node:test";

import {
  handleRequest,
  localeFromAcceptLanguage,
  normalizeLocale,
  readCookie
} from "../worker/index.mjs";

function originRecorder() {
  const requests = [];
  return {
    requests,
    fetch: async (request) => {
      requests.push(request);
      return new Response("origin", {
        headers: {
          "Content-Type": "text/plain",
          Vary: "Accept-Encoding"
        }
      });
    }
  };
}

test("locale helpers normalize supported values", () => {
  assert.equal(normalizeLocale("EN"), "en");
  assert.equal(normalizeLocale("ja"), "ja");
  assert.equal(normalizeLocale("zh-Hans"), "zh-hans");
  assert.equal(normalizeLocale("ko"), "ko");
  assert.equal(normalizeLocale("fr"), null);
  assert.equal(readCookie("theme=dark; capsomnia_locale=ja", "capsomnia_locale"), "ja");
});

test("Accept-Language respects quality and supported-language order", () => {
  assert.equal(localeFromAcceptLanguage("en-US,en;q=0.9,ja;q=0.8"), "en");
  assert.equal(localeFromAcceptLanguage("fr-FR,ja;q=0.8,en;q=0.7"), "ja");
  assert.equal(localeFromAcceptLanguage("zh-CN,zh;q=0.9,en;q=0.8"), "zh-hans");
  assert.equal(localeFromAcceptLanguage("ko-KR,ko;q=0.9,en;q=0.8"), "ko");
  assert.equal(localeFromAcceptLanguage("ja;q=0,en;q=0.5"), "en");
  assert.equal(localeFromAcceptLanguage(null), null);
});

test("root stays English when no supported preference is present", async () => {
  const origin = originRecorder();
  const response = await handleRequest(
    new Request("https://capsomnia.com/", {
      headers: { "Accept-Language": "fr-FR,fr;q=0.9" }
    }),
    origin.fetch
  );

  assert.equal(response.status, 200);
  assert.equal(await response.text(), "origin");
  assert.equal(origin.requests.length, 1);
  assert.equal(response.headers.get("Vary"), "Accept-Encoding, Accept-Language, Cookie");
});

test("root redirects Japanese, Chinese, and Korean preferences temporarily", async () => {
  for (const [acceptLanguage, expectedPath] of [
    ["ja-JP,ja;q=0.9,en;q=0.8", "/ja/"],
    ["zh-TW,zh;q=0.9,en;q=0.8", "/zh-hans/"],
    ["ko-KR,ko;q=0.9,en;q=0.8", "/ko/"]
  ]) {
    const origin = originRecorder();
    const response = await handleRequest(
      new Request(`https://capsomnia.com/?utm_source=test`, {
        headers: { "Accept-Language": acceptLanguage }
      }),
      origin.fetch
    );

    assert.equal(response.status, 302);
    assert.equal(
      response.headers.get("Location"),
      `https://capsomnia.com${expectedPath}?utm_source=test`
    );
    assert.equal(response.headers.get("Cache-Control"), "private, no-store");
    assert.equal(response.headers.get("Vary"), "Accept-Language, Cookie");
    assert.equal(response.headers.get("Set-Cookie"), null);
    assert.equal(origin.requests.length, 0);
  }
});

test("remembered manual choice overrides Accept-Language", async () => {
  const japaneseOrigin = originRecorder();
  const japaneseResponse = await handleRequest(
    new Request("https://capsomnia.com/", {
      headers: {
        "Accept-Language": "en-US",
        Cookie: "capsomnia_locale=ja"
      }
    }),
    japaneseOrigin.fetch
  );
  assert.equal(japaneseResponse.headers.get("Location"), "https://capsomnia.com/ja/");

  const englishOrigin = originRecorder();
  const englishResponse = await handleRequest(
    new Request("https://capsomnia.com/", {
      headers: {
        "Accept-Language": "ja-JP",
        Cookie: "capsomnia_locale=en"
      }
    }),
    englishOrigin.fetch
  );
  assert.equal(englishResponse.status, 200);
  assert.equal(englishOrigin.requests.length, 1);

  const koreanOrigin = originRecorder();
  const koreanResponse = await handleRequest(
    new Request("https://capsomnia.com/", {
      headers: {
        "Accept-Language": "ja-JP",
        Cookie: "capsomnia_locale=ko"
      }
    }),
    koreanOrigin.fetch
  );
  assert.equal(koreanResponse.headers.get("Location"), "https://capsomnia.com/ko/");
  assert.equal(koreanOrigin.requests.length, 0);
});

test("explicit language choice sets a cookie and cleans the URL", async () => {
  const origin = originRecorder();
  const response = await handleRequest(
    new Request(
      "https://capsomnia.com/ja/?lang=en&utm_campaign=language-menu",
      { headers: { "Accept-Language": "ja-JP" } }
    ),
    origin.fetch
  );

  assert.equal(response.status, 302);
  assert.equal(
    response.headers.get("Location"),
    "https://capsomnia.com/?utm_campaign=language-menu"
  );
  assert.match(
    response.headers.get("Set-Cookie"),
    /^capsomnia_locale=en; Path=\/; Max-Age=31536000; HttpOnly; Secure; SameSite=Lax$/
  );
  assert.equal(origin.requests.length, 0);
});

test("explicit Korean choice sets a Korean cookie and cleans the URL", async () => {
  const origin = originRecorder();
  const response = await handleRequest(
    new Request(
      "https://capsomnia.com/?lang=ko&utm_campaign=language-menu",
      { headers: { "Accept-Language": "en-US" } }
    ),
    origin.fetch
  );

  assert.equal(response.status, 302);
  assert.equal(
    response.headers.get("Location"),
    "https://capsomnia.com/ko/?utm_campaign=language-menu"
  );
  assert.match(
    response.headers.get("Set-Cookie"),
    /^capsomnia_locale=ko; Path=\/; Max-Age=31536000; HttpOnly; Secure; SameSite=Lax$/
  );
  assert.equal(origin.requests.length, 0);
});

test("legacy English paths redirect permanently and remember English", async () => {
  for (const path of ["/en", "/en/"]) {
    const origin = originRecorder();
    const response = await handleRequest(
      new Request(`https://capsomnia.com${path}?utm_source=legacy`, {
        headers: { "Accept-Language": "ja-JP" }
      }),
      origin.fetch
    );

    assert.equal(response.status, 301);
    assert.equal(
      response.headers.get("Location"),
      "https://capsomnia.com/?utm_source=legacy"
    );
    assert.equal(response.headers.get("Cache-Control"), "private, no-store");
    assert.match(
      response.headers.get("Set-Cookie"),
      /^capsomnia_locale=en; Path=\/; Max-Age=31536000; HttpOnly; Secure; SameSite=Lax$/
    );
    assert.equal(origin.requests.length, 0);
  }
});

test("localized paths and non-navigation methods pass through", async () => {
  const localizedOrigin = originRecorder();
  const localizedResponse = await handleRequest(
    new Request("https://capsomnia.com/ja/", {
      headers: { "Accept-Language": "en-US" }
    }),
    localizedOrigin.fetch
  );
  assert.equal(localizedResponse.status, 200);
  assert.equal(localizedOrigin.requests.length, 1);

  const postOrigin = originRecorder();
  const postResponse = await handleRequest(
    new Request("https://capsomnia.com/", {
      method: "POST",
      body: "payload"
    }),
    postOrigin.fetch
  );
  assert.equal(postResponse.status, 200);
  assert.equal(postOrigin.requests.length, 1);
});
