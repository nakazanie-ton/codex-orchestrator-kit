#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PRIME_CONTEXT="${CODEX_SESSION_PRIME_CONTEXT:-1}"
PRIMER_FILE="$ROOT_DIR/.local_codex/SESSION_PRIMER.md"
export CODEX_BOOTSTRAP_REQUIRED="${CODEX_BOOTSTRAP_REQUIRED:-1}"

is_codex_command() {
  local cmd="${1:-}"
  [[ "$cmd" == "codex" ]] && return 0
  [[ "${cmd##*/}" == "codex" ]] && return 0
  return 1
}

default_primer() {
  cat <<'PRIMER'
Before coding, load and summarize these local context files in order:
1) .local_codex/CODEX_LOCAL_CHECKLIST.md (confirm status: PASS)
2) .local_codex/PROJECT_AGENT_STATE.json
3) .local_codex/PROJECT_NAVIGATION.md
4) .local_codex/PROJECT_DEPENDENCY_GRAPH.md
5) .local_codex/PROJECT_TREE.txt

Then continue with the user task.
PRIMER
}

resolve_primer() {
  if [[ -n "${CODEX_SESSION_PRIMER_TEXT:-}" ]]; then
    printf "%s" "$CODEX_SESSION_PRIMER_TEXT"
    return
  fi

  if [[ -s "$PRIMER_FILE" ]]; then
    cat "$PRIMER_FILE"
    return
  fi

  default_primer
}

if (( $# > 0 )); then
  # Explicit command was passed by caller (for example: acodex -> codex_session.sh codex ...)
  "$SCRIPT_DIR/codex_bootstrap.sh" "$@"
  exit 0
fi

if [[ -n "${CODEX_SESSION_SH:-}" && -n "${CODEX_SESSION_CMD:-}" ]]; then
  echo "[session] WARNING: both CODEX_SESSION_SH and CODEX_SESSION_CMD are set; using CODEX_SESSION_SH" >&2
fi

if [[ -n "${CODEX_SESSION_SH:-}" ]]; then
  # Full shell command mode (supports quoted args and command chains).
  SESSION_CMD=(bash -lc "$CODEX_SESSION_SH")
elif [[ -n "${CODEX_SESSION_CMD:-}" ]]; then
  # Treat as a single executable path/name (safe for paths that contain spaces).
  SESSION_CMD=("$CODEX_SESSION_CMD")
else
  # Use codex by default to avoid recursion with wrappers that call codex_session.sh.
  SESSION_CMD=(codex)
fi

if [[ "$PRIME_CONTEXT" == "1" && -z "${CODEX_SESSION_SH:-}" ]] && is_codex_command "${SESSION_CMD[0]}"; then
  SESSION_CMD+=("$(resolve_primer)")
fi

"$SCRIPT_DIR/codex_bootstrap.sh" "${SESSION_CMD[@]}"
