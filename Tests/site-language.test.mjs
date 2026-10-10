import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const siteUrl = "https://capsomnia.com/";
const downloadUrl = "https://github.com/fuji-mak/Capsomnia/releases/latest/download/Capsomnia.pkg";
const pages = [
  {
    code: "en",
    file: "../docs/index.html",
    path: "",
    currentHref: "/?lang=en",
    title: "Capsomnia — Caps Lock as a physical keep-awake switch for macOS",
    shortcutHeading: "Use the key that works for you",
    shortcutPreview: "/app-preview-shortcut-en.png",
    productHuntAria: "View Capsomnia on Product Hunt",
    productHuntAlt: "Capsomnia — Caps Lock keeps your Mac awake, even with the lid closed | Product Hunt"
  },
  {
    code: "ja",
    file: "../docs/ja/index.html",
    path: "ja/",
    currentHref: "/ja/?lang=ja",
    title: "Capsomnia — Caps LockをMacの物理スリープ防止スイッチに",
    shortcutHeading: "自由にキー設定",
    shortcutPreview: "/app-preview-shortcut-ja.png",
    productHuntAria: "Product HuntでCapsomniaを見る",
    productHuntAlt: "Capsomnia — 蓋を閉じてもMacを起こしておく | Product Hunt"
  },
  {
    code: "zh-Hans",
    file: "../docs/zh-hans/index.html",
    path: "zh-hans/",
    currentHref: "/zh-hans/?lang=zh-hans",
    title: "Capsomnia — 把 Caps Lock 变成 macOS 实体防休眠开关",
    shortcutHeading: "自由设置按键",
    shortcutPreview: "/app-preview-shortcut-en.png",
    productHuntAria: "在 Product Hunt 上查看 Capsomnia",
    productHuntAlt: "Capsomnia — 即使合盖也能让 Mac 保持唤醒 | Product Hunt"
  },
  {
    code: "ko",
    file: "../docs/ko/index.html",
    path: "ko/",
    currentHref: "/ko/?lang=ko",
    title: "Capsomnia — Caps Lock을 macOS 잠자기 방지 스위치로",
    shortcutHeading: "원하는 키로 자유롭게",
    shortcutPreview: "/app-preview-shortcut-en.png",
    productHuntAria: "Product Hunt에서 Capsomnia 보기",
    productHuntAlt: "Capsomnia — 덮개를 닫아도 Mac을 깨워 두기 | Product Hunt"
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
    assert.ok(html.includes(page.shortcutHeading));
    assert.ok(html.includes(`src="${page.shortcutPreview}"`));
    assert.ok(html.includes(`aria-label="${page.productHuntAria}"`));
    assert.ok(html.includes(`alt="${page.productHuntAlt}"`));
    assert.equal((html.match(/aria-labelledby="custom-shortcut-title"/g) ?? []).length, 1);
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
    const application = jsonLd["@graph"].find((entity) => entity["@type"] === "SoftwareApplication");
    assert.ok(application, "Missing SoftwareApplication metadata");
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
  test(`${readme} links to the current installer`, () => {
    const markdown = readFileSync(new URL(readme, import.meta.url), "utf8");

    assert.ok(markdown.includes(downloadUrl));
  });
}

test("site discovery and ownership files match the published domain", () => {
  const domain = readFileSync(new URL("../docs/CNAME", import.meta.url), "utf8").trim();
  assert.equal(domain, new URL(siteUrl).hostname);

  const robots = readFileSync(new URL("../docs/robots.txt", import.meta.url), "utf8");
  assert.ok(robots.includes(`Sitemap: ${siteUrl}sitemap.xml`));

  const verificationFile = "googlee5de8ad27617297a.html";
  const verification = readFileSync(new URL(`../docs/${verificationFile}`, import.meta.url), "utf8").trim();
  assert.equal(verification, `google-site-verification: ${verificationFile}`);
});

test("the sitemap lists every localized URL and alternate", () => {
  const sitemap = readFileSync(new URL("../docs/sitemap.xml", import.meta.url), "utf8");

  for (const page of pages) {
    assert.ok(sitemap.includes(`<loc>${siteUrl}${page.path}</loc>`));
    assert.ok(sitemap.includes(`hreflang="${page.code}" href="${siteUrl}${page.path}"`));
  }
  assert.ok(sitemap.includes(`hreflang="x-default" href="${siteUrl}"`));
});

const localizedReadmes = {
  en: "README.md",
  ja: "README.ja.md",
  "zh-Hans": "README.zh-Hans.md",
  ko: "README.ko.md",
};

test("each page links to its own-language README and the author site", () => {
  for (const page of pages) {
    const html = readFileSync(new URL(page.file, import.meta.url), "utf8");

    assert.ok(html.includes(`/blob/main/${localizedReadmes[page.code]}`));
    for (const [code, readme] of Object.entries(localizedReadmes)) {
      if (code !== page.code) {
        assert.ok(
          !html.includes(`/blob/main/${readme}`),
          `${page.code} page links to ${readme}`
        );
      }
    }

    assert.ok(html.includes('href="https://fuji-maki.me/'));
    assert.ok(html.includes('rel="me noopener noreferrer"'));
  }
});
