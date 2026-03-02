# Existing Repository Runbook (Install Both Kits)

Use this runbook when a repository does not yet have bootstrap/taskflow kits.

## 1. One-Click Install
From the target repository root, run:

```bash
bash -lc 'set -euo pipefail; tmp_dir="$(mktemp -d)"; trap '\''rm -rf "$tmp_dir"'\'' EXIT; git clone --depth 1 https://github.com/nakazanie-ton/codex-bootstrap-kit.git "$tmp_dir/bootstrap"; bash "$tmp_dir/bootstrap/bin/install.sh" --target "$PWD" --force; git clone --depth 1 https://github.com/nakazanie-ton/codex-taskflow-kit.git "$tmp_dir/taskflow"; bash "$tmp_dir/taskflow/bin/install.sh" --target "$PWD" --force; CODEX_BOOTSTRAP_REQUIRED=1 bash scripts/codex_verify_session.sh'
```

## 2. CLI Connection
Primary command:

```bash
bash scripts/codex_session.sh
```

Taskflow command:

```bash
bash scripts/codex_task.sh
```

## 3. Codex App Connection
Set Local Environment setup script:

```bash
set -euo pipefail
CODEX_BOOTSTRAP_REQUIRED=1 bash scripts/codex_verify_session.sh
```

Recommended App actions:

1. `Verify Context`
```bash
bash scripts/codex_verify_session.sh --skip-bootstrap
```

2. `Start Taskflow`
```bash
bash scripts/codex_task.sh
```

## 4. AGENTS/Skills Connection
Add this mandatory startup sequence to `AGENTS.md`:

1. `bash scripts/codex_bootstrap.sh`
2. `cat .local_codex/CODEX_LOCAL_CHECKLIST.md`
3. Continue only if `status: PASS`

Also keep a dedicated `required skills` list in `AGENTS.md` to stabilize process behavior between sessions.

## 5. Post-Install Verification
Run:

```bash
bash scripts/codex_verify_session.sh
```

Expected result:
- Strict verification passes.
- Local artifacts are ignored by git via managed `.gitignore` blocks.
