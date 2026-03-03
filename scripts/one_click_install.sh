#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/one_click_install.sh /absolute/path/to/target-repo" >&2
  exit 1
fi

TARGET="$1"
if [[ ! -d "$TARGET" ]]; then
  echo "[orchestrator] ERROR: target directory not found: $TARGET" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

git clone --depth 1 https://github.com/nakazanie-ton/codex-bootstrap-kit.git "$tmp_dir/bootstrap"
bash "$tmp_dir/bootstrap/bin/install.sh" --target "$TARGET" --force

git clone --depth 1 https://github.com/nakazanie-ton/codex-taskflow-kit.git "$tmp_dir/taskflow"
bash "$tmp_dir/taskflow/bin/install.sh" --target "$TARGET" --force

bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/normalize_bootstrap_config.sh" "$TARGET"

cd "$TARGET"
CODEX_BOOTSTRAP_REQUIRED=1 bash scripts/codex_verify_session.sh

echo "[orchestrator] done: both kits installed, config normalized, and strict verification passed"
