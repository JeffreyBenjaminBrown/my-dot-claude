#!/usr/bin/env bash
# Stop/SubagentStop/PreToolUse beep for Claude Code hooks. Three jobs:
#
# (a) Stay silent for events inside a subagent, except its own finish.
#     Claude delivers a JSON payload on stdin; payloads from a subagent carry
#     an "agent_id" field that a main-agent payload lacks. SubagentStop
#     carries one too, but it is the event that announces a subagent
#     finishing, so it beeps (settings.json gives it beep-soothing-octave-up)
#     -- unless its "agent_type" is empty. Claude Code runs untyped internal
#     helpers (e.g. one guessing the user's next prompt, about 2 seconds after
#     each main-agent Stop) that fire SubagentStop too; agents the main agent
#     launches have a type ("general-purpose", "Explore", ...).
#     Note: when a background subagent finishes, the main agent wakes up,
#     relays the result, and stops again -- an ordinary Stop, so the main
#     agent's sound follows the subagent's.
#
# (b) Stay silent when the main agent's turn ends with a subagent still
#     running. Subagents always run in the background, so the launching turn
#     ends at once; beeping then would announce a finish that hasn't happened.
#     The Stop payload's "background_tasks" lists them, e.g.
#     {"type":"subagent","status":"running",...}.
#
# (c) Actually make sound from Claude's stripped hook environment. Lessons
#     learned the hard way (see ../../midi/.claude/hooks/beep.sh):
#       - Hooks run without XDG_RUNTIME_DIR, so pw-play can't find the PipeWire
#         socket and dies "Host is down" -- silently. Point it at the known
#         runtime dir explicitly.
#       - setsid is not on the hook PATH on this NixOS-in-docker box; resolve it
#         by absolute path, with a plain-detached fallback.
#       - Fire detached under a hard timeout so a stuck player never blocks the
#         hook (which would stall Claude).
#
# Arg 1 is the sound basename (no extension), looked up next to this script,
# then under /home/sound; default beep-soothing. Available: beep-soothing,
# beep-harsh, beep-glorious (/home/sound), beep-soothing-octave-up (here).

payload="$(cat)"

# Event inside a subagent, other than its finish -> stay silent.
event="$(printf '%s' "$payload" | jq -r '.hook_event_name // empty')"
if [ "$event" != SubagentStop ] && printf '%s' "$payload" | grep -q '"agent_id"'; then
  exit 0
fi

# Finish of an untyped internal helper, not a launched subagent -> stay silent.
if [ "$event" = SubagentStop ] \
   && [ -z "$(printf '%s' "$payload" | jq -r '.agent_type // empty')" ]; then
  exit 0
fi

name="${1:-beep-soothing}"

# Main-agent turn ending with a subagent still running -> silent.
if [ "$event" = Stop ] && printf '%s' "$payload" | jq -e \
     'any(.background_tasks[]?; .type == "subagent" and .status == "running")' >/dev/null; then
  exit 0
fi

sound="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${name}.wav"
[ -f "$sound" ] || sound="/home/sound/${name}.wav"

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
  "$setsid_bin" -f timeout -s KILL 5 pw-play "$sound" >/dev/null 2>&1
else
  # No setsid anywhere: best-effort detach so a stuck player can't block the hook.
  timeout -s KILL 5 pw-play "$sound" >/dev/null 2>&1 &
  disown
fi
exit 0
