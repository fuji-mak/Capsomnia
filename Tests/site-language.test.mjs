import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const siteUrl = "https://capsomnia.com/";
const pages = [
  {
    code: "en",
    file: "../docs/index.html",
    path: "",
    currentHref: "/?lang=en",
    title: "Capsomnia — Caps Lock as a physical keep-awake switch for macOS",
    content: "Give Caps Lock"
  },
  {
    code: "ja",
    file: "../docs/ja/index.html",
    path: "ja/",
    currentHref: "/ja/?lang=ja",
    title: "Capsomnia — Caps LockをMacの物理スリープ防止スイッチに",
    content: "Macの<span class=\"catch-accent\">最も無駄なキー</span>"
  },
  {
    code: "zh-Hans",
    file: "../docs/zh-hans/index.html",
    path: "zh-hans/",
    currentHref: "/zh-hans/?lang=zh-hans",
    title: "Capsomnia — 把 Caps Lock 变成 macOS 实体防休眠开关",
    content: "让 Caps Lock"
  }
];

const expectedAlternates = [
  '<link rel="alternate" hreflang="en" href="https://capsomnia.com/" />',
  '<link rel="alternate" hreflang="ja" href="https://capsomnia.com/ja/" />',
  '<link rel="alternate" hreflang="zh-Hans" href="https://capsomnia.com/zh-hans/" />',
  '<link rel="alternate" hreflang="x-default" href="https://capsomnia.com/" />'
];

for (const page of pages) {
  test(`${page.code} is a complete, self-canonical static page`, () => {
    const pageFileUrl = new URL(page.file, import.meta.url);
    const html = readFileSync(pageFileUrl, "utf8");
    const pageUrl = `${siteUrl}${page.path}`;

    assert.ok(html.includes(`<html lang="${page.code}">`));
    assert.ok(html.includes(`<title>${page.title}</title>`));
    assert.ok(html.includes(`rel="canonical" href="${pageUrl}"`));
    assert.ok(html.includes(`property="og:url" content="${pageUrl}"`));
    assert.ok(html.includes(page.content));
    assert.doesNotMatch(html, /data-i18n|capsomnia\.js/);
    assert.ok(html.includes('<details class="language-menu relative shrink-0">'));
    assert.ok(html.includes("<span>Capsomnia</span>"));
    assert.equal((html.match(/class="language-option /g) ?? []).length, pages.length);
    assert.doesNotMatch(html, /lang-switch|lang-btn|hidden sm:inline">Capsomnia/);

    for (const alternate of expectedAlternates) assert.ok(html.includes(alternate));
    for (const localePage of pages) {
      assert.ok(html.includes(`href="${localePage.currentHref}"`));
    }

    const currentLink = [...html.matchAll(/<a\b[^>]*>/g)]
      .map((match) => match[0])
      .find((tag) => tag.includes(`href="${page.currentHref}"`) && tag.includes("aria-current=\"page\""));
    assert.ok(currentLink);
    assert.equal((html.match(/aria-current="page"/g) ?? []).length, 1);

    const jsonLdSource = html.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)?.[1];
    assert.ok(jsonLdSource);
    const jsonLd = JSON.parse(jsonLdSource);
    for (const entity of jsonLd["@graph"]) {
      assert.equal(entity.inLanguage, page.code);
      assert.equal(entity.url, pageUrl);
    }

    for (const match of html.matchAll(/\s(?:href|src)="([^"]+)"/g)) {
      const reference = match[1];
      if (reference.startsWith("#") || /^https?:/.test(reference)) continue;

      const path = reference.split("?")[0];
      const target = path.startsWith("/")
        ? new URL(`../docs${path}`, import.meta.url)
        : new URL(path, pageFileUrl);
      const resolvedTarget = path.endsWith("/") ? new URL("index.html", target) : target;
      assert.ok(existsSync(resolvedTarget), `${page.code} references missing asset ${reference}`);
    }
  });
}

const readmes = [
  "../README.md",
  "../README.ja.md",
  "../README.zh-Hans.md"
];

for (const readme of readmes) {
  test(`${readme} keeps download prominent and language links secondary`, () => {
    const markdown = readFileSync(new URL(readme, import.meta.url), "utf8");

    assert.ok(markdown.includes("img.shields.io/badge/Download-Capsomnia.pkg-"));
    assert.doesNotMatch(markdown, /img\.shields\.io\/badge\/README-(?:EN|JA|ZH)-/);
  });
}

test("the sitemap lists every localized URL and alternate", () => {
  const sitemap = readFileSync(new URL("../docs/sitemap.xml", import.meta.url), "utf8");

  for (const page of pages) {
    assert.ok(sitemap.includes(`<loc>${siteUrl}${page.path}</loc>`));
    assert.ok(sitemap.includes(`hreflang="${page.code}" href="${siteUrl}${page.path}"`));
  }
  assert.ok(sitemap.includes(`hreflang="x-default" href="${siteUrl}"`));
});
