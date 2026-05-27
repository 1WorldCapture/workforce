#!/usr/bin/env python3
"""Merge multiple chunk result JSON files into final subtitle outputs.

Each result_XX.json should contain a JSON array of segment objects:
  {"index": <original_index>, "start": <seconds>, "end": <seconds>,
   "en": "<English text>", "zh": "<Chinese translation>"}

Outputs:
  - final_subtitles.json  (merged, sorted by timestamp)
  - subtitles_bilingual.srt (English + Chinese)
  - subtitles_zh.srt       (Chinese only)
  - subtitles_en.srt       (English only)

Usage:
    python merge-chunks.py <output_dir> [result_00.json result_01.json ...]
    python merge-chunks.py <output_dir>           # auto-discovers result_*.json in cwd
"""

import json
import os
import re
import sys


def find_chunk_files(directory: str) -> list[str]:
    """Auto-discover result_*.json files in directory."""
    files = []
    for name in sorted(os.listdir(directory)):
        if re.match(r"result_\d+\.json$", name):
            files.append(os.path.join(directory, name))
    return files


def load_chunks(file_paths: list[str]) -> list[dict]:
    """Load and merge all chunk files into one list."""
    all_segments = []
    for fp in file_paths:
        with open(fp, "r", encoding="utf-8") as f:
            segs = json.load(f)
            print(f"  {os.path.basename(fp)}: {len(segs)} segments", file=sys.stderr)
            all_segments.extend(segs)
    return all_segments


def fmt_srt_time(seconds: float) -> str:
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int((seconds - int(seconds)) * 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def sanitize_text(value: str) -> str:
    """Remove characters that render badly or conflict with ASS syntax."""
    value = str(value or "")
    value = value.replace("\\", "")
    value = value.replace("{", "").replace("}", "")
    value = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", value)
    value = re.sub(r"[ \t]+", " ", value)
    return value.strip()


def write_srt(segments: list[dict], path: str, mode: str = "bilingual"):
    """Write segments to SRT file.

    mode: 'bilingual' (en+zh), 'zh', 'en'
    """
    lines = []
    for i, seg in enumerate(segments, 1):
        start = fmt_srt_time(seg["start"])
        end = fmt_srt_time(seg["end"])
        lines.append(str(i))
        lines.append(f"{start} --> {end}")
        if mode == "bilingual":
            lines.append(sanitize_text(seg.get("en", "")))
            lines.append(sanitize_text(seg.get("zh", "")))
        elif mode == "zh":
            lines.append(sanitize_text(seg.get("zh", seg.get("en", ""))))
        else:
            lines.append(sanitize_text(seg.get("en", "")))
        lines.append("")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main():
    if len(sys.argv) < 2:
        print("Usage: merge-chunks.py <output_dir> [result_XX.json ...]", file=sys.stderr)
        sys.exit(1)

    output_dir = sys.argv[1]

    if len(sys.argv) > 2:
        chunk_files = sys.argv[2:]
    else:
        chunk_files = find_chunk_files(output_dir)
        if not chunk_files:
            print(f"No result_*.json files found in {output_dir}", file=sys.stderr)
            sys.exit(1)

    print(f"Merging {len(chunk_files)} chunk files...", file=sys.stderr)
    segments = load_chunks(chunk_files)

    # Sort by start timestamp (NOT by original index)
    segments.sort(key=lambda x: x["start"])

    total_chars_en = sum(len(s.get("en", "")) for s in segments)
    total_chars_zh = sum(len(s.get("zh", "")) for s in segments)
    time_range = f"{segments[0]['start']:.1f}s -> {segments[-1]['end']:.1f}s" if segments else "N/A"

    print(f"\nTotal merged: {len(segments)} segments", file=sys.stderr)
    print(f"Time range: {time_range}", file=sys.stderr)
    print(f"EN chars: ~{total_chars_en}, ZH chars: ~{total_chars_zh}", file=sys.stderr)

    # Validate: check for abnormal durations (parallel agent corruption)
    MAX_DUR = 120  # seconds
    bad = [s for s in segments if s["end"] - s["start"] > MAX_DUR]
    if bad:
        print(f"\nWARNING: {len(bad)} entries have abnormal duration > {MAX_DUR}s:", file=sys.stderr)
        print("This is likely from parallel agent timestamp corruption. Auto-fixing...", file=sys.stderr)
        for s in bad:
            dur = s["end"] - s["start"]
            print(f"  [{s['index']}] {s['start']:.1f}->{s['end']:.1f} ({dur:.0f}s) | {s.get('en','')[:50]}", file=sys.stderr)
            s["end"] = s["start"] + 6.0
        print(f"  Fixed all {len(bad)} entries (capped at 6s)", file=sys.stderr)

    for s in segments:
        s["en"] = sanitize_text(s.get("en", ""))
        s["zh"] = sanitize_text(s.get("zh", ""))

    # Save merged JSON
    json_path = os.path.join(output_dir, "final_subtitles.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(segments, f, ensure_ascii=False, indent=2)
    print(f"Saved: {json_path}", file=sys.stderr)

    # Generate SRT files
    write_srt(segments, os.path.join(output_dir, "subtitles_bilingual.srt"), "bilingual")
    print(f"Saved: subtitles_bilingual.srt", file=sys.stderr)

    write_srt(segments, os.path.join(output_dir, "subtitles_zh.srt"), "zh")
    print(f"Saved: subtitles_zh.srt", file=sys.stderr)

    write_srt(segments, os.path.join(output_dir, "subtitles_en.srt"), "en")
    print(f"Saved: subtitles_en.srt", file=sys.stderr)

    print("\nDone!", file=sys.stderr)


if __name__ == "__main__":
    main()
