#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="$ROOT_DIR/.local_codex"
GENERATOR="$ROOT_DIR/.codex_bootstrap/bootstrap/generate_codex_state.py"
CONFIG_FILE="${CODEX_BOOTSTRAP_CONFIG:-$ROOT_DIR/.codex_bootstrap/config.json}"
CHECKLIST_FILE="$STATE_DIR/CODEX_LOCAL_CHECKLIST.md"
LOG_LEVEL="${CODEX_BOOTSTRAP_LOG_LEVEL:-full}"
CONTEXT_BUDGET_BYTES="${CODEX_CONTEXT_BUDGET_BYTES:-1048576}"
CONTEXT_AUTO_COMPACT="${CODEX_CONTEXT_AUTO_COMPACT:-1}"
CONTEXT_ARCHIVE_KEEP_RUNS="${CODEX_CONTEXT_ARCHIVE_KEEP_RUNS:-8}"
CONTEXT_HISTORY_MAX_LINES="${CODEX_CONTEXT_HISTORY_MAX_LINES:-200}"
CONTEXT_HISTORY_KEEP_LINES="${CODEX_CONTEXT_HISTORY_KEEP_LINES:-60}"
ARCHIVE_ROOT="$STATE_DIR/archive"
SESSION_HISTORY_FILE="$STATE_DIR/SESSION_HISTORY.log"
CONTEXT_COMPACT_FILE="$STATE_DIR/CONTEXT_COMPACT.md"
CONTEXT_BUDGET_FILE="$STATE_DIR/CONTEXT_BUDGET.json"
CONTEXT_TOTAL_BYTES=0
CONTEXT_STATE_BYTES=0
CONTEXT_TASKFLOW_BYTES=0
CONTEXT_HISTORY_BYTES=0
CONTEXT_STATE_FILES=0
CONTEXT_TASKFLOW_FILES=0

mkdir -p "$STATE_DIR"

case "$LOG_LEVEL" in
  full|summary|quiet) ;;
  *)
    echo "[codex-bootstrap] ERROR: invalid CODEX_BOOTSTRAP_LOG_LEVEL='$LOG_LEVEL' (expected: full|summary|quiet)" >&2
    exit 1
    ;;
esac

log() {
  [[ "$LOG_LEVEL" == "quiet" ]] && return
  echo "$1"
}

fail() {
  echo "[codex-bootstrap] ERROR: $1" >&2
  exit 1
}

require_non_negative_int() {
  local value="$1"
  local name="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || fail "$name must be a non-negative integer"
}

require_positive_int() {
  local value="$1"
  local name="$2"
  require_non_negative_int "$value" "$name"
  (( value > 0 )) || fail "$name must be greater than zero"
}

dir_bytes() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "0"
    return
  fi
  du -sk "$dir" | awk '{print $1 * 1024}'
}

dir_file_count() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "0"
    return
  fi
  find "$dir" -type f | wc -l | tr -d ' '
}

capture_context_metrics() {
  local session_history_size archive_bytes
  CONTEXT_STATE_BYTES="$(dir_bytes "$STATE_DIR")"
  CONTEXT_TASKFLOW_BYTES="$(dir_bytes "$ROOT_DIR/work/taskflow")"
  session_history_size="0"
  if [[ -f "$SESSION_HISTORY_FILE" ]]; then
    session_history_size="$(wc -c < "$SESSION_HISTORY_FILE" | tr -d ' ')"
  fi
  archive_bytes="$(dir_bytes "$ARCHIVE_ROOT")"
  CONTEXT_HISTORY_BYTES=$(( session_history_size + archive_bytes ))
  # .local_codex already includes archive/session history files; don't count history twice.
  CONTEXT_TOTAL_BYTES=$(( CONTEXT_STATE_BYTES + CONTEXT_TASKFLOW_BYTES ))
  CONTEXT_STATE_FILES="$(dir_file_count "$STATE_DIR")"
  CONTEXT_TASKFLOW_FILES="$(dir_file_count "$ROOT_DIR/work/taskflow")"
}

prune_context_archives() {
  local archive_runs=()
  local remove_count i

  [[ -d "$ARCHIVE_ROOT" ]] || return
  while IFS= read -r run_path; do
    archive_runs+=("$run_path")
  done < <(find "$ARCHIVE_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'context-*' | sort)
  if (( ${#archive_runs[@]} <= CONTEXT_ARCHIVE_KEEP_RUNS )); then
    return
  fi

  remove_count=$(( ${#archive_runs[@]} - CONTEXT_ARCHIVE_KEEP_RUNS ))
  for (( i = 0; i < remove_count; i++ )); do
    rm -rf "${archive_runs[$i]}"
  done
}

archive_previous_context_files() {
  local stamp="$1"
  local archive_run="$ARCHIVE_ROOT/context-$stamp"
  local moved=0
  local rel src

  mkdir -p "$archive_run"
  for rel in \
    "CODEX_LOCAL_CHECKLIST.md" \
    "PROJECT_AGENT_STATE.json" \
    "PROJECT_TREE.txt" \
    "PROJECT_NAVIGATION.md" \
    "PROJECT_DEPENDENCY_GRAPH.md" \
    "CONTEXT_COMPACT.md" \
    "CONTEXT_BUDGET.json"; do
    src="$STATE_DIR/$rel"
    if [[ -f "$src" ]]; then
      mv "$src" "$archive_run/$rel"
      moved=1
    fi
  done

  if (( moved == 0 )); then
    rmdir "$archive_run" 2>/dev/null || true
    return
  fi

  prune_context_archives
  log "[codex-bootstrap] context compact: archived previous snapshot to ${archive_run#"$ROOT_DIR"/}"
}

trim_session_history_if_needed() {
  local stamp="$1"
  local line_count cut_lines archive_log

  [[ -f "$SESSION_HISTORY_FILE" ]] || return
  line_count="$(wc -l < "$SESSION_HISTORY_FILE" | tr -d ' ')"
  if (( line_count <= CONTEXT_HISTORY_MAX_LINES )); then
    return
  fi

  cut_lines=$(( line_count - CONTEXT_HISTORY_KEEP_LINES ))
  if (( cut_lines < 1 )); then
    return
  fi

  mkdir -p "$ARCHIVE_ROOT"
  archive_log="$ARCHIVE_ROOT/session-history-$stamp.log"
  sed -n "1,${cut_lines}p" "$SESSION_HISTORY_FILE" >"$archive_log"
  tail -n "$CONTEXT_HISTORY_KEEP_LINES" "$SESSION_HISTORY_FILE" >"$SESSION_HISTORY_FILE.tmp"
  mv "$SESSION_HISTORY_FILE.tmp" "$SESSION_HISTORY_FILE"
  log "[codex-bootstrap] context compact: archived session history to ${archive_log#"$ROOT_DIR"/}"
}

write_context_compact_file() {
  local generated_at="$1"
  local scope_block status_line bootstrap_line state_files_line

  scope_block=""
  if [[ -f "$STATE_DIR/AGENT_STATE.md" ]] && grep -Eq '^## Scope$' "$STATE_DIR/AGENT_STATE.md"; then
    scope_block="$(sed -n '/^## Scope$/,/^## /p' "$STATE_DIR/AGENT_STATE.md" | sed '$d')"
  fi
  if [[ -z "$scope_block" ]] && [[ -f "$STATE_DIR/AGENT_STATE.md" ]]; then
    scope_block="$(sed -n '1,20p' "$STATE_DIR/AGENT_STATE.md")"
  fi

  status_line="$(grep -E '^- status:' "$CHECKLIST_FILE" | tail -n 1 | sed 's/^- //' || true)"
  bootstrap_line="$(grep -E '^- bootstrap_at:' "$CHECKLIST_FILE" | head -n 1 | sed 's/^- //' || true)"
  state_files_line="$(grep -E '^- state_files:' "$CHECKLIST_FILE" | head -n 1 | sed 's/^- //' || true)"

  cat >"$CONTEXT_COMPACT_FILE" <<EOF
# Codex Context Compact

- generated_at: $generated_at
- source: scripts/codex_bootstrap.sh
- purpose: key AGENT_STATE + VERIFICATION blocks for low-noise context loading

## AGENT_STATE Key Block
${scope_block:-Scope section unavailable}

## VERIFICATION Key Block
- ${status_line:-status: UNKNOWN}
- ${bootstrap_line:-bootstrap_at: UNKNOWN}
- ${state_files_line:-state_files: UNKNOWN}
EOF
}

write_context_budget_file() {
  local generated_at="$1"
  local compacted="$2"
  local before_total="$3"
  local after_total="$4"
  local compacted_json="false"

  if [[ "$compacted" == "1" ]]; then
    compacted_json="true"
  fi

  cat >"$CONTEXT_BUDGET_FILE" <<EOF
{
  "generated_at": "$generated_at",
  "budget_bytes": $CONTEXT_BUDGET_BYTES,
  "total_bytes_before": $before_total,
  "total_bytes_after": $after_total,
  "state_bytes_after": $CONTEXT_STATE_BYTES,
  "taskflow_bytes_after": $CONTEXT_TASKFLOW_BYTES,
  "history_bytes_after": $CONTEXT_HISTORY_BYTES,
  "state_files_after": $CONTEXT_STATE_FILES,
  "taskflow_files_after": $CONTEXT_TASKFLOW_FILES,
  "compacted": $compacted_json
}
EOF
}

require_non_negative_int "$CONTEXT_BUDGET_BYTES" "CODEX_CONTEXT_BUDGET_BYTES"
require_positive_int "$CONTEXT_ARCHIVE_KEEP_RUNS" "CODEX_CONTEXT_ARCHIVE_KEEP_RUNS"
require_positive_int "$CONTEXT_HISTORY_MAX_LINES" "CODEX_CONTEXT_HISTORY_MAX_LINES"
require_positive_int "$CONTEXT_HISTORY_KEEP_LINES" "CODEX_CONTEXT_HISTORY_KEEP_LINES"
if (( CONTEXT_HISTORY_KEEP_LINES > CONTEXT_HISTORY_MAX_LINES )); then
  fail "CODEX_CONTEXT_HISTORY_KEEP_LINES cannot exceed CODEX_CONTEXT_HISTORY_MAX_LINES"
fi

case "$CONTEXT_AUTO_COMPACT" in
  0|1) ;;
  *)
    fail "CODEX_CONTEXT_AUTO_COMPACT must be 0 or 1"
    ;;
esac

if [[ ! -f "$GENERATOR" ]]; then
  echo "[codex-bootstrap] ERROR: generator not found: $GENERATOR" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "[codex-bootstrap] ERROR: python3 is required" >&2
  exit 1
fi

RUN_STAMP="$(date -u +%Y%m%d-%H%M%S)"
capture_context_metrics
TOTAL_BYTES_BEFORE="$CONTEXT_TOTAL_BYTES"
COMPACTED=0

if [[ "$CONTEXT_AUTO_COMPACT" == "1" ]] && (( TOTAL_BYTES_BEFORE > CONTEXT_BUDGET_BYTES )); then
  COMPACTED=1
  archive_previous_context_files "$RUN_STAMP"
fi

python3 "$GENERATOR" --root "$ROOT_DIR" --config "$CONFIG_FILE"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
write_context_compact_file "$GENERATED_AT"
capture_context_metrics

history_entry="generated_at=$GENERATED_AT total_before=$TOTAL_BYTES_BEFORE budget=$CONTEXT_BUDGET_BYTES compacted=$([[ "$COMPACTED" == "1" ]] && echo "true" || echo "false") state_files=$CONTEXT_STATE_FILES taskflow_files=$CONTEXT_TASKFLOW_FILES"
printf "%s\n" "$history_entry" >>"$SESSION_HISTORY_FILE"
trim_session_history_if_needed "$RUN_STAMP"

capture_context_metrics
write_context_budget_file "$GENERATED_AT" "$COMPACTED" "$TOTAL_BYTES_BEFORE" "$CONTEXT_TOTAL_BYTES"

log "Status checklist saved: CODEX_LOCAL_CHECKLIST.md"
if [[ -f "$CHECKLIST_FILE" && "$LOG_LEVEL" != "quiet" ]]; then
  sed -n '1,40p' "$CHECKLIST_FILE"
fi

log "=================================================="
log "Codex Agent Bootstrap"
log "=================================================="
log "This script restores project context at every start."
log "Loaded state files:"
log ""

for file in \
  "$STATE_DIR/AGENT_STATE.md" \
  "$STATE_DIR/PROJECT_AGENT_STATE.json" \
  "$STATE_DIR/PROJECT_TREE.txt" \
  "$STATE_DIR/PROJECT_NAVIGATION.md" \
  "$STATE_DIR/PROJECT_DEPENDENCY_GRAPH.md"; do
  if [[ -f "$file" ]]; then
    if [[ "$LOG_LEVEL" == "full" ]]; then
      echo "===== $(basename "$file") ====="
      sed -n '1,80p' "$file"
      echo ""
    elif [[ "$LOG_LEVEL" == "summary" ]]; then
      echo "- loaded: $(basename "$file")"
    fi
  fi
done

log "Done."
