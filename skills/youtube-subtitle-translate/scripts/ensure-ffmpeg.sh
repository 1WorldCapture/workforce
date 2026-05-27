#!/bin/bash
# ensure-ffmpeg.sh — Detect or build an ARM64-native ffmpeg with subtitle support
#
# Usage:
#   source ensure-ffmpeg.sh          # sets FFMPEG_BIN variable
#   FFMPEG_BIN=$(bash ensure-ffmpeg.sh)  # or capture output
#
# Checks:
#   1. Architecture is ARM64 (not x86_64 via Rosetta)
#   2. ass/subtitles/drawtext filters available (libass + freetype)
#   3. libdav1d decoder available (for AV1 video)
#
# If checks fail, downloads ffmpeg source and compiles with all needed
# libraries to /tmp/ffmpeg-arm64/. Object files are cached so rebuilds
# are fast.
#
# Output: prints the ffmpeg binary path to stdout, or exits with error.

set -euo pipefail

FFMPEG_INSTALL_DIR="/tmp/ffmpeg-arm64"
FFMPEG_SOURCE_DIR="/tmp/ffmpeg-build"
FFMPEG_VERSION="7.1"

check_ffmpeg() {
    local bin="$1"

    # Must exist
    [ -x "$bin" ] || return 1

    # Must be ARM64 native
    local arch
    arch=$(file "$bin" | grep -o 'arm64\|x86_64' | head -1)
    [ "$arch" = "arm64" ] || return 1

    # Must have ass filter
    "$bin" -filters 2>/dev/null | grep -E '\.{3}[[:space:]]+ass[[:space:]]' >/dev/null || return 1

    # Must be able to decode AV1 (libdav1d)
    "$bin" -decoders 2>/dev/null | grep 'libdav1d' >/dev/null || return 1

    return 0
}

# Try system ffmpeg first
SYSTEM_FFMPEG="$(command -v ffmpeg 2>/dev/null)" || true
if [ -n "$SYSTEM_FFMPEG" ]; then
    if check_ffmpeg "$SYSTEM_FFMPEG"; then
        echo "$SYSTEM_FFMPEG"
        exit 0
    fi
fi

# Try previously built ffmpeg
BUILT_FFMPEG="$FFMPEG_INSTALL_DIR/bin/ffmpeg"
if [ -x "$BUILT_FFMPEG" ]; then
    if check_ffmpeg "$BUILT_FFMPEG"; then
        echo "$BUILT_FFMPEG"
        exit 0
    fi
fi

# Need to build. Check for build dependencies.
missing_deps=()
for cmd in gcc make pkg-config; do
    command -v "$cmd" >/dev/null 2>&1 || missing_deps+=("$cmd")
done

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "ERROR: Missing build dependencies: ${missing_deps[*]}" >&2
    echo "Install with: brew install ${missing_deps[*]}" >&2
    exit 1
fi

# Ensure libass, freetype, fontconfig, dav1d are installed via brew
for pkg in libass freetype fontconfig dav1d x264; do
    if ! brew list "$pkg" &>/dev/null; then
        echo "Installing $pkg via brew..." >&2
        brew install "$pkg" >/dev/null 2>&1
    fi
done

echo "Building ARM64-native ffmpeg with subtitle support..." >&2

# Download source if needed
mkdir -p "$FFMPEG_SOURCE_DIR"
SRC_TAR="$FFMPEG_SOURCE_DIR/ffmpeg-${FFMPEG_VERSION}.tar.xz"
SRC_DIR="$FFMPEG_SOURCE_DIR/ffmpeg-${FFMPEG_VERSION}"

if [ ! -f "$SRC_TAR" ]; then
    echo "Downloading ffmpeg ${FFMPEG_VERSION} source..." >&2
    curl -sL "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" -o "$SRC_TAR"
fi

if [ ! -d "$SRC_DIR" ]; then
    cd "$FFMPEG_SOURCE_DIR"
    tar xf "$SRC_TAR"
fi

# Configure and build
cd "$SRC_DIR"

./configure --prefix="$FFMPEG_INSTALL_DIR" \
    --enable-gpl \
    --enable-libass \
    --enable-libfreetype \
    --enable-fontconfig \
    --enable-libx264 \
    --enable-libopus \
    --enable-libmp3lame \
    --enable-libdav1d \
    --enable-videotoolbox \
    --enable-audiotoolbox \
    --extra-cflags="-I$(brew --prefix)/include" \
    --extra-ldflags="-L$(brew --prefix)/lib" \
    --disable-doc \
    >/dev/null 2>&1

make -j"$(sysctl -n hw.ncpu 2>/dev/null || sysctl -n hw.ncpu)" >/dev/null 2>&1
make install >/dev/null 2>&1

# Verify
if check_ffmpeg "$BUILT_FFMPEG"; then
    echo "$BUILT_FFMPEG"
else
    echo "ERROR: Built ffmpeg but it still doesn't pass checks" >&2
    exit 1
fi
