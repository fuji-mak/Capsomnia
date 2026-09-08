#!/bin/zsh
# Compatibility entry point. The Tools installer is maintained by cpsm.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CPSM_REPO="${CPSM_REPO:-$ROOT_DIR/../cpsm}"
export DIST_DIR="${CAPSOMNIA_DIST_DIR:-${DIST_DIR:-${1:-$CPSM_REPO/dist}}}"
exec "$CPSM_REPO/scripts/build-tools-pkg.sh"
