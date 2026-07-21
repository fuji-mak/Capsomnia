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
    content: "Give Caps Lock",
    shortcutHeading: "Use the key that works for you"
  },
  {
    code: "ja",
    file: "../docs/ja/index.html",
    path: "ja/",
    currentHref: "/ja/?lang=ja",
    title: "Capsomnia — Caps LockをMacの物理スリープ防止スイッチに",
    content: "Macの<span class=\"catch-accent\">最も無駄なキー</span>",
    shortcutHeading: "自由にキー設定"
  },
  {
    code: "zh-Hans",
    file: "../docs/zh-hans/index.html",
    path: "zh-hans/",
    currentHref: "/zh-hans/?lang=zh-hans",
    title: "Capsomnia — 把 Caps Lock 变成 macOS 实体防休眠开关",
    content: "让 Caps Lock",
    shortcutHeading: "自由设置按键"
  },
  {
    code: "ko",
    file: "../docs/ko/index.html",
    path: "ko/",
    currentHref: "/ko/?lang=ko",
    title: "Capsomnia — Caps Lock을 macOS 잠자기 방지 스위치로",
    content: "Caps Lock에<br><span class=\"catch-accent\">제대로 된 일을 맡기세요</span>",
    shortcutHeading: "원하는 키로 자유롭게"
  }
];

const expectedAlternates = [
  '<link rel="alternate" hreflang="en" href="https://capsomnia.com/" />',
  '<link rel="alternate" hreflang="ja" href="https://capsomnia.com/ja/" />',
  '<link rel="alternate" hreflang="zh-Hans" href="https://capsomnia.com/zh-hans/" />',
  '<link rel="alternate" hreflang="ko" href="https://capsomnia.com/ko/" />',
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
    assert.ok(html.includes(page.shortcutHeading));
    assert.equal((html.match(/aria-labelledby="custom-shortcut-title"/g) ?? []).length, 1);
    assert.doesNotMatch(html, /data-i18n|capsomnia\.js/);
    assert.ok(html.includes('<details class="language-menu relative shrink-0">'));
    assert.ok(html.includes("<span>Capsomnia</span>"));
    assert.equal((html.match(/class="language-option /g) ?? []).length, pages.length);
    assert.doesNotMatch(html, /lang-switch|lang-btn|hidden sm:inline">Capsomnia/);

    const languageSummaryClasses = html.match(
      /<summary\s+class="([^"]+)"/
    )?.[1];
    assert.ok(languageSummaryClasses);
    assert.match(languageSummaryClasses, /min-h-\[44px\]/);
    assert.match(languageSummaryClasses, /min-w-\[68px\]/);
    assert.match(languageSummaryClasses, /px-3/);
    assert.doesNotMatch(
      languageSummaryClasses,
      /rounded-full|border-\[var\(--border-strong\)\]|bg-\[var\(--surface\)\]/
    );

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
  "../README.zh-Hans.md",
  "../README.ko.md"
];

for (const readme of readmes) {
  test(`${readme} keeps download prominent and language links secondary`, () => {
    const markdown = readFileSync(new URL(readme, import.meta.url), "utf8");

    assert.ok(markdown.includes("img.shields.io/badge/Download-Capsomnia.pkg-"));
    assert.doesNotMatch(markdown, /img\.shields\.io\/badge\/README-(?:EN|JA|ZH|KO)-/);
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

test("the Chinese page links to English and Simplified Chinese READMEs", () => {
  const html = readFileSync(
    new URL("../docs/zh-hans/index.html", import.meta.url),
    "utf8"
  );

  assert.ok(html.includes("/blob/main/README.md"));
  assert.ok(html.includes("/blob/main/README.zh-Hans.md"));
  assert.ok(html.includes("README（简体中文）"));
  assert.ok(html.includes("简体中文文档"));
  assert.doesNotMatch(html, /\/blob\/main\/README\.ja\.md/);
});

test("the Korean page links to English and Korean READMEs", () => {
  const html = readFileSync(
    new URL("../docs/ko/index.html", import.meta.url),
    "utf8"
  );

  assert.ok(html.includes("/blob/main/README.md"));
  assert.ok(html.includes("/blob/main/README.ko.md"));
  assert.ok(html.includes("한국어 README"));
  assert.ok(html.includes("한국어 문서"));
  assert.doesNotMatch(html, /\/blob\/main\/README\.ja\.md/);
  assert.doesNotMatch(html, /\/blob\/main\/README\.zh-Hans\.md/);
});
