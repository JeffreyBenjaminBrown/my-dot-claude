#!/usr/bin/env bash
# Run this INSIDE a container, BEFORE you `docker rm` + relaunch it, so you
# don't lose Claude history when you move to a newer image.
#
# It does two things:
#   1. Makes sure /home/ubuntu/host/my-dot-claude is a current checkout of the
#      shared config (clones it via HTTPS if missing, else pulls). The image has
#      no ssh, so we fetch over HTTPS -- works as long as the repo is public
#      (for a private repo, set up a token / credential helper first).
#   2. Copies THIS container's ephemeral Claude state -- session transcripts
#      (`--resume`), prompt history, credentials, config -- into that checkout,
#      which lives on the host bind-mount and therefore survives the rebuild.
#
# After this, `docker rm` the container and relaunch from the new image: it sets
# CLAUDE_CONFIG_DIR=/home/ubuntu/host/my-dot-claude, so the next container picks
# up exactly where this one left off. Safe to run repeatedly.
set -uo pipefail

DEST=/home/ubuntu/host/my-dot-claude
REPO_HTTPS=https://github.com/JeffreyBenjaminBrown/my-dot-claude.git
SRC="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# --- 1) ensure the shared config is present and current -----------------------
if [ -d "$DEST/.git" ]; then
  echo "[1/2] Updating shared config in $DEST ..."
  git -C "$DEST" pull --ff-only "$REPO_HTTPS" main \
    || echo "      WARN: not a fast-forward (local commits?). Keeping local config; continuing."
elif [ -e "$DEST" ]; then
  echo "ERROR: $DEST exists but is not a git checkout. Move it aside and rerun." >&2
  exit 1
else
  echo "[1/2] Cloning shared config into $DEST ..."
  git clone "$REPO_HTTPS" "$DEST" \
    || { echo "ERROR: clone failed (private repo or offline?). Set up HTTPS auth, then rerun." >&2; exit 1; }
fi

# --- 2) preserve this container's ephemeral history into the checkout ---------
if [ "$(readlink -f "$SRC" 2>/dev/null)" = "$(readlink -f "$DEST" 2>/dev/null)" ]; then
  echo "[2/2] Config dir is already my-dot-claude; history is already persistent."
else
  echo "[2/2] Preserving history: $SRC -> $DEST ..."
  mkdir -p "$DEST/projects"
  [ -d "$SRC/projects" ] && cp -a "$SRC/projects/." "$DEST/projects/"
  for f in history.jsonl todos file-history shell-snapshots .credentials.json; do
    [ -e "$SRC/$f" ] && cp -a "$SRC/$f" "$DEST/"
  done
  # .claude.json sits inside the config dir when CLAUDE_CONFIG_DIR is set,
  # otherwise at $HOME.
  cj="$HOME/.claude.json"
  [ -n "${CLAUDE_CONFIG_DIR:-}" ] && cj="$CLAUDE_CONFIG_DIR/.claude.json"
  [ -f "$cj" ] && cp -a "$cj" "$DEST/.claude.json"
fi

echo
echo "Done. Transcripts now preserved on the host mount: $(find "$DEST/projects" -name '*.jsonl' 2>/dev/null | wc -l)"
echo "Next: docker stop/rm this container, then relaunch from the new image."
echo "      (CLAUDE_CONFIG_DIR=$DEST is baked into the image, so --resume just works.)"
