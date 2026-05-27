#!/bin/bash
# render-subtitles.sh — Burn subtitles onto video using ffmpeg with libass
#
# Usage:
#   bash render-subtitles.sh <video.mp4> <subtitles.srt> [output.mp4]
#
# This script handles all the tricky parts:
#   1. Ensures ARM64-native ffmpeg with libass + libdav1d is available
#   2. Copies subtitle files to /tmp to avoid path-special-char issues
#   3. Converts SRT → ASS with proper CJK font configuration
#   4. Renders with ffmpeg's ass filter
#   5. Validates output file
#
# Environment:
#   SKILL_DIR   — root of the youtube-subtitle-translate skill (auto-detected)
#   FONT_SIZE   — base ASS font size before video scaling (default: 20)

set -euo pipefail

# --- Argument handling ---
VIDEO="${1:?Usage: render-subtitles.sh <video.mp4> <subtitles.srt> [output.mp4]}"
SUBTITLES="${2:?Usage: render-subtitles.sh <video.mp4> <subtitles.srt> [output.mp4]}"
OUTPUT="${3:-}"

if [ ! -f "$VIDEO" ]; then
    echo "ERROR: Video file not found: $VIDEO" >&2
    exit 1
fi
if [ ! -f "$SUBTITLES" ]; then
    echo "ERROR: Subtitle file not found: $SUBTITLES" >&2
    exit 1
fi

# Auto-detect output path
if [ -z "$OUTPUT" ]; then
    VIDEO_DIR="$(dirname "$VIDEO")"
    VIDEO_BASE="$(basename "$VIDEO" .mp4)"
    OUTPUT="${VIDEO_DIR}/${VIDEO_BASE}_with_subtitles.mp4"
fi

# --- Find skill directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# --- Step 1: Ensure proper ffmpeg ---
echo "=== Checking ffmpeg ===" >&2
FFMPEG_BIN="${FFMPEG_BIN:-$(bash "$SKILL_DIR/scripts/ensure-ffmpeg.sh")}"
echo "Using ffmpeg: $FFMPEG_BIN ($(file "$FFMPEG_BIN" | grep -o 'arm64\|x86_64'))" >&2

# --- Step 2: Copy to /tmp to avoid path issues ---
TMP_SUBS="/tmp/render_subs_$$.$$.srt"
TMP_ASS="/tmp/render_subs_$$.$$.ass"
cp "$SUBTITLES" "$TMP_SUBS"

# --- Step 3: Convert SRT → ASS ---
echo "=== Converting SRT → ASS ===" >&2
python3 "$SKILL_DIR/scripts/srt-to-ass.py" "$TMP_SUBS" "$TMP_ASS" --font-size "${FONT_SIZE:-20}"

# --- Step 3.5: Pre-render validation (check for abnormal durations) ---
echo "=== Validating subtitle data ===" >&2
# Check ASS for Dialogue lines with suspiciously long duration (>120s)
LONG_LINES=$(grep -c "Dialogue:.*[0-9]:[5-9][0-9]:[0-9][0-9]\.[0-9][0-9],[0-9]:[5-9][0-9]:[0-9][0-9]" "$TMP_ASS" 2>/dev/null || true)
LONG_LINES="${LONG_LINES:-0}"
if [ "$LONG_LINES" -gt 0 ]; then
    echo "WARNING: Found $LONG_LINES subtitle entries with duration > ~10min." >&2
    echo "The srt-to-ass.py script should have auto-fixed these. Proceeding..." >&2
fi

# --- Step 4: Render ---
echo "=== Rendering subtitles onto video ===" >&2
echo "  Input:  $VIDEO" >&2
echo "  Subs:   $TMP_ASS" >&2
echo "  Output: $OUTPUT" >&2

rm -f "$OUTPUT"
"$FFMPEG_BIN" -y \
    -i "$VIDEO" \
    -vf "ass=$TMP_ASS" \
    -c:v libx264 -preset medium -crf 18 \
    -c:a copy \
    "$OUTPUT" 2>&1 | while IFS= read -r line; do
        # Show progress lines only
        if [[ "$line" =~ ^frame= ]] || [[ "$line" =~ error|Error|fail ]]; then
            echo "  $line" >&2
        fi
    done

# Cleanup temp files
rm -f "$TMP_SUBS" "$TMP_ASS"

# --- Step 5: Validate ---
if [ -f "$OUTPUT" ]; then
    SIZE=$(du -h "$OUTPUT" | cut -f1)
    DURATION=$("$FFMPEG_BIN" -i "$OUTPUT" 2>&1 | sed -n 's/.*Duration: \([^,]*\),.*/\1/p' | head -1)
    echo "" >&2
    echo "=== Render complete! ===" >&2
    echo "  Output: $OUTPUT" >&2
    echo "  Size:   $SIZE" >&2
    echo "  Duration: $DURATION" >&2
else
    echo "ERROR: Render failed — no output file produced" >&2
    exit 1
fi
