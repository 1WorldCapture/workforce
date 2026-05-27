#!/bin/bash
# ensure-yt-dlp.sh — Ensure yt-dlp is installed and current enough for YouTube HD formats.
#
# Usage:
#   bash scripts/ensure-yt-dlp.sh
#   yt-dlp -F "<url>"
#
# This is a prerequisite check/update step. Later workflow commands should still
# call `yt-dlp` normally.

set -euo pipefail

find_ytdlp() {
    command -v yt-dlp 2>/dev/null || true
}

YTDLP_BIN="$(find_ytdlp)"

if [ -z "$YTDLP_BIN" ]; then
    echo "yt-dlp not found; attempting install..." >&2

    if command -v brew >/dev/null 2>&1; then
        echo "Installing yt-dlp with Homebrew..." >&2
        brew install yt-dlp >&2
    elif command -v pipx >/dev/null 2>&1; then
        echo "Installing yt-dlp with pipx..." >&2
        pipx install yt-dlp >&2
    elif command -v python3 >/dev/null 2>&1; then
        echo "Installing yt-dlp with Python/pip user install..." >&2
        python3 -m pip install --user -U yt-dlp >&2
    else
        echo "ERROR: yt-dlp is not installed and no supported installer was found." >&2
        echo "Install yt-dlp with Homebrew, pipx, or Python/pip, then rerun." >&2
        exit 1
    fi

    YTDLP_BIN="$(find_ytdlp)"
fi

if [ -z "$YTDLP_BIN" ]; then
    echo "ERROR: yt-dlp install completed but yt-dlp is still not on PATH." >&2
    echo "Open a new shell or add the installer's bin directory to PATH." >&2
    exit 1
fi

echo "Using yt-dlp: $YTDLP_BIN" >&2
echo "Current version: $("$YTDLP_BIN" --version)" >&2

UPDATED=0

if "$YTDLP_BIN" -U >/tmp/ensure-ytdlp-update.log 2>&1; then
    cat /tmp/ensure-ytdlp-update.log >&2
    UPDATED=1
else
    cat /tmp/ensure-ytdlp-update.log >&2 || true
fi
rm -f /tmp/ensure-ytdlp-update.log

if [ "$UPDATED" -eq 0 ] && command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
    if [ -n "$BREW_PREFIX" ] && [[ "$YTDLP_BIN" == "$BREW_PREFIX"* ]]; then
        echo "Attempting Homebrew yt-dlp upgrade..." >&2
        brew upgrade yt-dlp >&2 || true
        UPDATED=1
    fi
fi

if [ "$UPDATED" -eq 0 ] && command -v pipx >/dev/null 2>&1; then
    echo "Attempting pipx yt-dlp upgrade..." >&2
    pipx upgrade yt-dlp >&2 || true
    UPDATED=1
fi

if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "ERROR: yt-dlp disappeared from PATH after update attempt." >&2
    exit 1
fi

echo "yt-dlp ready: $(yt-dlp --version)" >&2
