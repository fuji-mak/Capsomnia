# Library snapshots

Capsomnia builds from a single checkout, without fetching unpublished repositories.
Only the libraries it uses are copied here; the CLI executables, Skills, tests and
release tooling live in their own repositories.

| Library | Source repository | Directory |
| --- | --- | --- |
| CapsomniaControl | `fuji-mak/cpsm` | `Sources/CapsomniaControl` |
| MacStateCore | `fuji-mak/MacReady` | `Sources/MacStateCore` |

These repositories are private during review; public access and first releases
are pending the author's approval. Each `snapshot.json` records its candidate version
and exact file hashes. Licenses are preserved. Edit in the source repository and
run `python3 scripts/sync-vendor.py` with sibling `cpsm` and `MacReady` checkouts
(or pass `--cpsm PATH --macready PATH`). Review and commit the refreshed snapshot
alongside the app change. `--check` verifies the snapshot without those checkouts.
