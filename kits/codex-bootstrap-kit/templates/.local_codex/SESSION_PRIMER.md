Before coding, load and summarize these local context files in order:
1) .local_codex/CODEX_LOCAL_CHECKLIST.md (confirm status: PASS)
2) .local_codex/PROJECT_AGENT_STATE.json
3) .local_codex/PROJECT_NAVIGATION.md
4) .local_codex/PROJECT_DEPENDENCY_GRAPH.md
5) .local_codex/PROJECT_TREE.txt

Taskflow routing (when installed):
- If scripts/codex_task.sh exists and task is non-trivial, start by running:
  bash scripts/codex_task.sh --title "<short task title>" --text "<user request>"
- Treat work/taskflow/<latest>/ as the canonical task record while executing.
- Before finalizing, run:
  bash scripts/codex_task_lint.sh --latest --mode complete

Then continue with the user task.
