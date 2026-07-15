import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../docs/capsomnia.js", import.meta.url), "utf8");
const html = readFileSync(new URL("../docs/index.html", import.meta.url), "utf8");

function renderWithStoredLanguage(storedLanguage) {
  let savedLanguage = storedLanguage;
  const listeners = {};
  const languageButtons = ["en", "ko", "ja"].map((language) => {
    const attributes = { "data-lang-option": language, "aria-pressed": "false" };
    return {
      getAttribute(name) {
        return attributes[name];
      },
      setAttribute(name, value) {
        attributes[name] = value;
      }
    };
  });
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
    querySelectorAll(selector) {
      return selector === "[data-lang-option]" ? languageButtons : [];
    },
    addEventListener(event, handler) {
      listeners[event] = handler;
    },
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

  function snapshot() {
    return {
      description: description.content,
      language: document.documentElement.lang,
      savedLanguage,
      title: document.title
    };
  }

  return {
    ...snapshot(),
    clickLanguage(language) {
      const button = languageButtons.find((candidate) => candidate.getAttribute("data-lang-option") === language);
      listeners.click({
        target: {
          closest(selector) {
            return selector === "[data-lang-option]" ? button : null;
          }
        }
      });
      return snapshot();
    }
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

test("an explicit Korean choice remains available", () => {
  const result = renderWithStoredLanguage("ko");

  assert.equal(result.language, "ko");
  assert.match(result.title, /Caps Lock을 macOS 잠자기 방지 스위치로/);
  assert.match(result.description, /MacBook 덮개를 닫은 채/);
  assert.equal(result.savedLanguage, "ko");
});

test("the language switch applies and saves Korean", () => {
  const page = renderWithStoredLanguage("ja");
  const result = page.clickLanguage("ko");

  assert.equal(result.language, "ko");
  assert.equal(result.savedLanguage, "ko");
  assert.match(result.title, /Caps Lock을 macOS 잠자기 방지 스위치로/);
});

test("every page translation key exists in every language", () => {
  const exposedSource = source.replace("var translations = {", "var translations = globalThis.translations = {");
  const context = {
    console,
    document: {
      documentElement: { lang: "" },
      title: "",
      querySelector() {
        return null;
      },
      querySelectorAll() {
        return [];
      },
      addEventListener() {}
    },
    window: {
      localStorage: {
        getItem() {
          return null;
        },
        setItem() {}
      }
    }
  };

  vm.runInNewContext(exposedSource, context);

  const keys = new Set(Array.from(html.matchAll(/data-i18n(?:-[\w-]+)?="([^"]+)"/g), (match) => match[1]));
  for (const language of ["en", "ko", "ja"]) {
    for (const key of keys) {
      assert.ok(key in context.translations[language], `${language} is missing ${key}`);
    }
  }
});
