(function () {
  "use strict";

  document.addEventListener("click", function (event) {
    var btn = event.target.closest(".copy-btn");
    if (!btn) return;

    var text = btn.getAttribute("data-copy");
    if (text == null) {
      var block = btn.parentElement.querySelector("pre code");
      text = block ? block.textContent : "";
    }

    function done() {
      var original = btn.dataset.label || btn.textContent;
      btn.dataset.label = original;
      btn.textContent = "Copied";
      btn.classList.add("is-copied");
      window.clearTimeout(btn._copyTimer);
      btn._copyTimer = window.setTimeout(function () {
        btn.textContent = btn.dataset.label;
        btn.classList.remove("is-copied");
      }, 1600);
    }

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, fallback);
    } else {
      fallback();
    }

    function fallback() {
      var ta = document.createElement("textarea");
      ta.value = text;
      ta.setAttribute("readonly", "");
      ta.style.position = "absolute";
      ta.style.left = "-9999px";
      document.body.appendChild(ta);
      ta.select();
      try {
        document.execCommand("copy");
        done();
      } catch (e) {
        /* no-op */
      }
      document.body.removeChild(ta);
    }
  });
})();
