import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../docs/capsomnia.js", import.meta.url), "utf8");

function renderWithStoredLanguage(storedLanguage) {
  let savedLanguage = storedLanguage;
  const description = {
    content: "",
    setAttribute(name, value) {
      if (name === "content") this.content = value;
    }
  };
  const document = {
    documentElement: { lang: "" },
    title: "",
    querySelector(selector) {
      return selector === 'meta[name="description"]' ? description : null;
    },
    querySelectorAll() {
      return [];
    },
    addEventListener() {}
  };
  const window = {
    localStorage: {
      getItem() {
        return savedLanguage;
      },
      setItem(_key, value) {
        savedLanguage = value;
      }
    }
  };

  vm.runInNewContext(source, { console, document, window });

  return {
    description: description.content,
    language: document.documentElement.lang,
    savedLanguage,
    title: document.title
  };
}

test("a fresh visit renders the canonical Japanese page", () => {
  const result = renderWithStoredLanguage(null);

  assert.equal(result.language, "ja");
  assert.match(result.title, /Caps LockをMacの物理スリープ防止スイッチに/);
  assert.match(result.description, /蓋を閉じたMacBook/);
});

test("an explicit English choice remains available", () => {
  const result = renderWithStoredLanguage("en");

  assert.equal(result.language, "en");
  assert.match(result.title, /physical keep-awake switch for macOS/);
});
