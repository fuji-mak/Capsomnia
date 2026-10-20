import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from ci_changes import affected_jobs, changed_paths


class ChangesTests(unittest.TestCase):
    def test_site_and_router_inputs_do_not_build_app(self):
        for path in (
            "docs/ja/index.html", "docs/styles.input.css", "docs/new image.png",
            "README.ko.md", "worker/index.mjs", "wrangler.jsonc",
            "package-lock.json", "Tests/worker-language-router.test.mjs",
        ):
            with self.subTest(path=path):
                self.assertEqual(affected_jobs([path]), (False, True))

    def test_swift_inputs_do_not_build_site(self):
        for path in (
            "Sources/Capsomnia/App.swift", "Vendor/MacStateCore/Package.swift",
            "resources/Info.plist", "Tests/CapsomniaTests/AppTests.swift",
            "Package.swift", "Package.resolved",
        ):
            with self.subTest(path=path):
                self.assertEqual(affected_jobs([path]), (True, False))

    def test_shared_unknown_and_mixed_changes_run_both(self):
        for paths in (
            [".github/workflows/ci.yml"], [".github/scripts/ci_changes.py"],
            ["scripts/build-app.sh"], ["new-config.toml"],
            ["docs/index.html", "Sources/Capsomnia/App.swift"],
        ):
            with self.subTest(paths=paths):
                self.assertEqual(affected_jobs(paths), (True, True))

    def test_new_branch_and_empty_diff(self):
        self.assertIsNone(changed_paths("0" * 40))
        self.assertIsNone(changed_paths(""))
        self.assertEqual(affected_jobs([]), (False, False))

    def test_complete_push_diff_includes_deletions_and_cross_area_moves(self):
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                return subprocess.check_output(["git", "-C", directory, *args]).decode().strip()

            git("init", "-q")
            git("config", "user.email", "ci@example.invalid")
            git("config", "user.name", "CI test")
            root = Path(directory)
            (root / "docs").mkdir()
            (root / "Sources").mkdir()
            (root / "docs/old page.html").write_text("page")
            git("add", ".")
            git("commit", "-qm", "base")
            base = git("rev-parse", "HEAD")
            git("mv", "docs/old page.html", "Sources/page.html")
            git("commit", "-qm", "move")
            (root / "docs/new.html").write_text("new")
            git("add", ".")
            git("commit", "-qm", "second commit")
            previous = os.getcwd()
            try:
                os.chdir(directory)
                paths = changed_paths(base)
            finally:
                os.chdir(previous)
            self.assertEqual(set(paths), {"docs/old page.html", "Sources/page.html", "docs/new.html"})
            self.assertEqual(affected_jobs(paths), (True, True))


if __name__ == "__main__":
    unittest.main()
