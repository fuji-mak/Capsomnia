"""Select CI jobs from the complete push or pull-request merge diff."""

import os
from pathlib import Path
import subprocess


def affected_jobs(paths):
    app = site = False
    for path in paths:
        if (
            path.startswith(("docs/", "worker/", "README"))
            or path in ("package.json", "package-lock.json", "wrangler.jsonc")
            or (path.startswith("Tests/") and path.endswith(".mjs"))
        ):
            site = True
        elif path.startswith(("Sources/", "Vendor/", "resources/", "Tests/")) or path in (
            "Package.swift", "Package.resolved",
        ):
            app = True
        else:
            # CI, shared scripts, and unfamiliar paths must keep both checks.
            app = site = True
    return app, site


def changed_paths(base):
    if not base or set(base) == {"0"}:
        return None
    try:
        subprocess.run(
            ["git", "cat-file", "-e", f"{base}^{{commit}}"],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        subprocess.run(
            ["git", "fetch", "--no-tags", "--depth=1", "origin", base],
            check=True,
        )
    # No rename detection: a move across areas must select both old and new.
    result = subprocess.check_output(
        ["git", "diff", "--name-only", "--no-renames", "-z", base, "HEAD", "--"],
    )
    return [os.fsdecode(path) for path in result.split(b"\0") if path]


def main():
    try:
        paths = changed_paths(os.environ.get("BASE_SHA", ""))
        app, site = (True, True) if paths is None else affected_jobs(paths)
    except subprocess.CalledProcessError:
        print("::warning::Could not determine changes; running all CI jobs.")
        app = site = True
    output = f"app={str(app).lower()}\nsite={str(site).lower()}\n"
    print(output, end="")
    with Path(os.environ["GITHUB_OUTPUT"]).open("a") as handle:
        handle.write(output)


if __name__ == "__main__":
    main()
