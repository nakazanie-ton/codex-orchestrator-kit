# codex-orchestrator-kit

Orchestrator repository for connecting and operating two reusable kits together:
- `codex-bootstrap-kit`
- `codex-taskflow-kit`

This repo contains operator-grade instructions for three integration surfaces:
- Codex CLI
- Codex App
- AGENTS/Skills flow

## Runbooks
- `docs/NEW_REPO_WITH_PREINSTALLED_KITS.md`
- `docs/EXISTING_REPO_ADD_KITS.md`

## One-click installer (for existing repositories)
```bash
bash scripts/one_click_install.sh /absolute/path/to/target-repo
```

Installer behavior:
- installs both kits
- rewrites `.codex_bootstrap/config.json` to project-agnostic defaults (no framework-specific entry points/routing)
- runs strict verification
