#!/usr/bin/env bash
# Stop/PreToolUse beep for Claude Code hooks. Two jobs:
#
# (a) Stay SILENT when a SUBAGENT finishes. Claude delivers a JSON payload on
#     stdin; subagent-completion payloads carry an "agent_id" field that a
#     main-agent payload lacks. We beep only for the main agent. (PreToolUse
#     payloads have no agent_id either, so those events beep as intended.)
#
# (b) Actually MAKE SOUND from Claude's stripped hook environment. Lessons
#     learned the hard way (see ../../midi/.claude/hooks/beep.sh):
#       - Hooks run without XDG_RUNTIME_DIR, so pw-play can't find the PipeWire
#         socket and dies "Host is down" -- silently. Point it at the known
#         runtime dir explicitly.
#       - setsid is NOT on the hook PATH on this NixOS-in-docker box; resolve it
#         by absolute path, with a plain-detached fallback.
#       - Fire detached under a hard timeout so a stuck player never blocks the
#         hook (which would stall Claude).
#
# Arg 1 is the sound basename under /home/sound (no extension); default
# beep-soothing. Available: beep-soothing, beep-harsh, beep-glorious.

payload="$(cat)"

# Subagent completion -> stay silent.
if printf '%s' "$payload" | grep -q '"agent_id"'; then
  exit 0
fi

name="${1:-beep-soothing}"
export XDG_RUNTIME_DIR=/run/user/1000
export PIPEWIRE_RUNTIME_DIR=/run/user/1000

setsid_bin="$(command -v setsid 2>/dev/null || true)"
if [ -z "$setsid_bin" ]; then
  for c in /run/current-system/sw/bin/setsid /nix/store/*-system-path/bin/setsid; do
    [ -x "$c" ] && { setsid_bin="$c"; break; }
  done
fi

if [ -n "$setsid_bin" ]; then
  # New session (-f) so the player survives the hook runner reaping its group.
  "$setsid_bin" -f timeout -s KILL 5 pw-play "/home/sound/${name}.wav" >/dev/null 2>&1
else
  # No setsid anywhere: best-effort detach so a stuck player can't block the hook.
  timeout -s KILL 5 pw-play "/home/sound/${name}.wav" >/dev/null 2>&1 &
  disown
fi
exit 0
