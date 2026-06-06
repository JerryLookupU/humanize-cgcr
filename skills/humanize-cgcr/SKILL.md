---
name: humanize-cgcr
description: Codex-side launcher for Humanize CGCR. Creates the two-tmux Codex /goal plus Claude monitor topology and prepares the monitored goal prompt.
type: flow
argument-hint: "<long task prompt>"
user-invocable: false
disable-model-invocation: true
---

# Humanize CGCR Launcher

Use this flow from Codex to start Humanize CGCR: Codex Goal with Claude Review.

Repo-native Codex command:

```text
/flow:humanize-cgcr <long task prompt>
```

If a Codex client provides a `/humanize:cgcr` alias, it must delegate to this
same Codex flow. Do not implement `/humanize:cgcr` as a Claude Code command.

## Role Boundary

CGCR is not a dual-executor system:

- Codex is the only implementation agent.
- Claude Code is only a read-only reviewer/monitor.
- Claude Code must not edit files, run builds, run tests, commit, reset,
  install packages, or repair code directly.
- Claude feedback may enter Codex only as a gated `[MONITOR]` prompt through
  tmux.

If any approach would require Claude Code to mutate the repository, reject that
approach and keep feedback routed through the monitor protocol.

## What This Flow Starts

The setup script creates:

- a Humanize-owned resource directory under `.humanize/cgcr/<run-id>/`;
- one tmux window named `codex-goal` running `codex`;
- one tmux window named `claude-monitor` running `claude`;
- a prepared Codex `/goal` prompt with the CGCR monitor contract;
- a prepared Claude monitor command using `/humanize:monitor-codex-goal`.

The current Codex session only launches the topology. The new Codex tmux window
owns implementation.

## Execution

Run the setup script with the user's task text:

```bash
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/setup-cgcr.sh" --task "$ARGUMENTS"
```

If setup exits non-zero, report the error and do not continue with
implementation in the launcher session.

This flow treats the full argument string as the task prompt. Advanced options
such as `--goal-id`, `--session`, `--cadence`, `--principles`, and
`--notify-only` remain script-level options for manual shell use.

## Resource Files

The run directory contains:

- `task.md`
- `codex-goal-prompt.md`
- `claude-monitor-command.txt`
- `resources.json`
- `README.md`

Use `resources.json` as the local record of the `MONITOR_TARGET_ID`, tmux
session name, Codex tmux target, Claude monitor tmux target, and prompt files.

## Examples

```text
/flow:humanize-cgcr implement the billing export described in docs/export-plan.md
```

```text
"{{HUMANIZE_RUNTIME_ROOT}}/scripts/setup-cgcr.sh" --goal-id billing-export-20260606 --cadence 30m --principles "no fake data; no stubs; do not broaden scope" --task "implement the billing export"
```

## Notes

- Use `/flow:humanize-codex-goal` only when you want to run the execution
  contract manually in an existing Codex `/goal` session.
- Use `/humanize:monitor-codex-goal` only inside Claude Code, in the separate
  monitor tmux window.
- RLCR remains `/flow:humanize-rlcr` on Codex and
  `/humanize:start-rlcr-loop` on Claude Code.
