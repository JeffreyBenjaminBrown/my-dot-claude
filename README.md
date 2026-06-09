# my-dot-claude

A standalone, version-controlled `CLAUDE_CONFIG_DIR` — the shared, user-level
Claude Code config for every project in this workspace (skg, midi, ...). Point
Claude Code at it with:

    CLAUDE_CONFIG_DIR=/home/ubuntu/host/my-dot-claude

Then every project inherits the hooks/settings here automatically, and Claude's
own state (history, sessions, credentials) persists across container rebuilds,
because this dir lives on the host bind-mount (`/home/ubuntu/host`).

## What's tracked

- `settings.json` — user-level Claude settings: the beep hooks + global toggles.
- `hooks/beep-if-main-agent.sh` — robust Stop/PreToolUse beep. Stays silent when
  a *subagent* finishes; sets `XDG_RUNTIME_DIR` and detaches via `setsid`+`timeout`
  so it actually sounds from Claude's stripped hook environment.

Everything else Claude writes here (`.credentials.json`, `.claude.json`,
`history.jsonl`, `sessions/`, `projects/`, ...) is volatile and/or secret and is
ignored by the whitelist in `.gitignore`.

## Wiring

- Container launch sets `CLAUDE_CONFIG_DIR=/home/ubuntu/host/my-dot-claude`
  (see skg's `bash/docker.sh`). Because this dir is inside the
  `/home/ubuntu/host` mount, no separate `.claude` mount is needed.
- Per-project `.claude/settings.json` (skg, midi) also call the same beep script
  by absolute path, so the beep works even before `CLAUDE_CONFIG_DIR` is
  repointed. **Once you relaunch with `CLAUDE_CONFIG_DIR` set to this dir, delete
  the `hooks` block from those project settings to avoid a double beep** — the
  beep then comes from here, for every project, with zero per-project config.

## Sounds

`beep-soothing` (turn done), `beep-harsh` (needs attention: ExitPlanMode,
AskUserQuestion), `beep-glorious` — all `/home/sound/*.wav`, provided by the image.
