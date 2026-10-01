#!/usr/bin/env bash
# Compatible entry point. V2 builds isolated candidates; install_asset.py promotes reviewed results.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/build_asset.py" "$@"
