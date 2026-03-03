#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/normalize_bootstrap_config.sh /absolute/path/to/target-repo" >&2
  exit 1
fi

TARGET="$1"
if [[ ! -d "$TARGET" ]]; then
  echo "[orchestrator] ERROR: target directory not found: $TARGET" >&2
  exit 1
fi

CONFIG_PATH="$TARGET/.codex_bootstrap/config.json"
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "[orchestrator] ERROR: bootstrap config not found: $CONFIG_PATH" >&2
  exit 1
fi

cat >"$CONFIG_PATH" <<'JSON'
{
  "project_name": "",
  "required_skills": [],
  "startup_read_order": [
    "scripts/codex_bootstrap.sh",
    ".local_codex/CODEX_LOCAL_CHECKLIST.md",
    "AGENTS.md",
    ".local_codex/PROJECT_AGENT_STATE.json",
    ".local_codex/PROJECT_NAVIGATION.md",
    ".local_codex/PROJECT_DEPENDENCY_GRAPH.md",
    ".local_codex/PROJECT_TREE.txt"
  ],
  "required_files": [
    ".local_codex/AGENT_STATE.md",
    ".local_codex/PROJECT_AGENT_STATE.json",
    ".local_codex/PROJECT_TREE.txt",
    ".local_codex/PROJECT_NAVIGATION.md",
    ".local_codex/PROJECT_DEPENDENCY_GRAPH.md"
  ],
  "exclude_paths": [
    ".git",
    "node_modules",
    ".venv",
    ".cache",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    "dist",
    "build",
    "out",
    "target",
    "coverage"
  ],
  "entry_points": {},
  "task_routing": {}
}
JSON

echo "[orchestrator] applied project-agnostic bootstrap config: $CONFIG_PATH"
