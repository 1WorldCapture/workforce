---
name: youtube-subtitle-translate
description: >
  Download YouTube videos, extract source subtitles or transcribe audio, proofread and translate
  subtitles, generate clean SRT files, and package selectable subtitle tracks into MP4/MKV files.
  Use when the user asks to download YouTube videos with subtitles, translate video subtitles,
  extract or generate subtitle files, add selectable subtitles to a video, or process video
  subtitles with ASR fallback.
---

# YouTube Subtitle Translator

Download a YouTube video, produce cleaned translated subtitles, and package the result as selectable subtitle tracks. Packaged subtitles are fast, reversible, selectable in the player, and do not require video re-encoding.

## Defaults

- Output directory: `~/Downloads/youtube-subtitle-translate/<sanitized video title>/`.
- Source subtitle language: English when available; otherwise the video's original spoken language.
- Target subtitle language: the system/user interface language by default. If the user names a target language, use the user's requested language.
- Video quality: 1080p by default. If 1080p is unavailable, download the highest quality below 1080p.
- Delivery: MP4 and MKV with selectable subtitle tracks.
- Concurrency: at most 3 subtitle-processing subagents at a time.

## Hard Rules

- Do not use YouTube-provided target-language or auto-translated captions. Download only the source subtitle track and translate it yourself.
- If available tracks include both `en-orig` and `zh-Hans` or another target-language track, choose only `en-orig`.
- Use current `yt-dlp`; stale builds often expose only 360p.
- For HD downloads, select split video-only plus audio-only streams and let `yt-dlp` merge them.
- Use subagents for translation chunks. Do not use local model helpers for translation.
- Remove subtitle text characters that break subtitle/container behavior: stray backslashes, control characters, and raw `{` / `}` braces.
- Normalize rolling or overlapping captions before producing final SRT files. Ordinary video players stack overlapping SRT entries.
- Do not hard-code any target language. Use the system/user interface language by default, unless the user specified a target language.

## Workflow

```
Phase 1: Download    -> video + source subtitles
Phase 2: Prepare     -> parse subtitles or run ASR fallback
Phase 3: Process     -> chunk, proofread, translate
Phase 4: Merge       -> sanitize, remove empty rows, fix overlaps, write SRTs
Phase 5: Package     -> mux selectable subtitle tracks into MP4/MKV
```

## Prerequisites

Ensure these tools are installed before running the workflow:

- `yt-dlp` for YouTube download and subtitle extraction.
- `ffmpeg` for merging downloaded video/audio streams, ASR audio extraction, and MP4/MKV subtitle packaging.
- Python 3 for parsing, splitting, merging, and validating subtitle files.
- Optional ASR tool such as `qwen3-asr` or a Whisper-compatible CLI when the video has no usable source subtitles.

Before listing formats or downloading, ensure `yt-dlp` exists and is current:

```bash
bash scripts/ensure-yt-dlp.sh
```

## Phase 1: Download

Create the output directory under Downloads:

```bash
mkdir -p "$HOME/Downloads/youtube-subtitle-translate/<Video Title>"
```

Inspect formats when quality is uncertain:

```bash
yt-dlp -F "<url>"
```

If format listing does not show expected HD formats, rerun `scripts/ensure-yt-dlp.sh` and list formats again.

Download 1080p video plus best audio. If 1080p is unavailable, this format expression falls back to the highest available video below 1080p:

```bash
yt-dlp \
  -f "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/bv*[height<=1080]+ba/b[height<=1080]/best" \
  --merge-output-format mp4 \
  -o "<dir>/video.%(ext)s" \
  "<url>"
```

Download source subtitles only:

```bash
yt-dlp --skip-download --write-auto-subs --write-subs \
  --sub-langs "en-orig,en.*" --sub-format "srt/json3" --convert-subs srt \
  -o "<dir>/video.%(ext)s" "<url>"
```

If English is unavailable, replace `en-orig,en.*` with the video's original subtitle language code. Do not add the target language code to this command.

Keep these files in the output directory:

- `video.mp4`
- `raw_segments.json`
- `raw_subtitles.srt`
- `chunk_XX.json`
- `result_XX.json`
- final SRT files
- packaged MP4/MKV outputs

## Phase 2: Prepare

If source subtitles are available, parse them into segment JSON:

```json
{"text": "...", "offset": 12.3, "duration": 2.4}
```

If no subtitles are available, extract audio and run ASR:

```bash
ffmpeg -i video.mp4 -vn -acodec pcm_s16le -ar 16000 -ac 1 audio.wav
qwen3-asr audio.wav --output-format srt > raw_subtitles.srt
```

Then parse the ASR SRT into `raw_segments.json`.

## Phase 3: Process

Split `raw_segments.json` into chunk files:

```python
n = len(segments)
chunk_count = min(10, max(1, (n + 75) // 76))
chunk_size = n // chunk_count + 1
for i in range(0, n, chunk_size):
    save_chunk(i, segments[i:i + chunk_size])
```

Run at most 3 subagents concurrently. Each subagent receives:

- Its `chunk_XX.json` path.
- The target language. Default to the system language unless the user specified another language.
- The proofreading/translation spec: `references/subtitle-proofreading.md`.
- Output path: `result_XX.json`.

Each result entry must contain:

```json
{"index": 0, "start": 12.3, "end": 14.7, "en": "Proofread source text.", "zh": "Translated target text."}
```

Note: the `en` and `zh` field names are retained for current script compatibility. Treat `en` as source text and `zh` as translated target text, regardless of the actual source or target language.

## Phase 4: Merge

Run:

```bash
python3 scripts/merge-chunks.py <output_dir>
```

The merge step must:

- Sort by timestamp.
- Save raw merged data as `final_subtitles_raw.json`.
- Remove empty subtitle rows.
- Sanitize visible text.
- Fix abnormal durations.
- Clamp each subtitle end time before the next subtitle begins.
- Write final non-overlapping SRT files.

Expected outputs:

| File | Content |
|------|---------|
| `final_subtitles_raw.json` | Raw merged subtitle data before cleanup |
| `final_subtitles.json` | Cleaned non-overlapping subtitle data |
| `subtitles_bilingual.srt` | Source + target language |
| `subtitles_zh.srt` | Target language only, historical filename |
| `subtitles_en.srt` | Source language only, historical filename |

Validate before packaging:

```bash
python3 -c "
import json
segs = json.load(open('final_subtitles.json'))
print('segments', len(segs))
print('duration issues', sum(1 for s in segs if s['end'] <= s['start'] or s['end'] - s['start'] > 120))
print('overlaps', sum(1 for a, b in zip(segs, segs[1:]) if a['end'] > b['start']))
print('backslashes', sum(1 for s in segs if '\\\\' in s.get('en','') or '\\\\' in s.get('zh','')))
"
```

All counts except `segments` should be `0`.

## Phase 5: Package

Package selectable subtitle tracks without re-encoding video or audio.

MP4 output:

```bash
ffmpeg -y \
  -i "<dir>/video.mp4" \
  -i "<dir>/subtitles_bilingual.srt" \
  -i "<dir>/subtitles_zh.srt" \
  -i "<dir>/subtitles_en.srt" \
  -map 0:v -map 0:a? -map 1:0 -map 2:0 -map 3:0 \
  -c:v copy -c:a copy -c:s mov_text \
  -metadata:s:s:0 language=und -metadata:s:s:0 title="Source + Target" \
  -metadata:s:s:1 language=und -metadata:s:s:1 title="Target" \
  -metadata:s:s:2 language=und -metadata:s:s:2 title="Source" \
  -disposition:s:0 default -disposition:s:1 0 -disposition:s:2 0 \
  "<dir>/video_with_selectable_subtitles.mp4"
```

MKV output:

```bash
ffmpeg -y \
  -i "<dir>/video.mp4" \
  -i "<dir>/subtitles_bilingual.srt" \
  -i "<dir>/subtitles_zh.srt" \
  -i "<dir>/subtitles_en.srt" \
  -map 0:v -map 0:a? -map 1:0 -map 2:0 -map 3:0 \
  -c copy \
  -metadata:s:s:0 language=und -metadata:s:s:0 title="Source + Target" \
  -metadata:s:s:1 language=und -metadata:s:s:1 title="Target" \
  -metadata:s:s:2 language=und -metadata:s:s:2 title="Source" \
  -disposition:s:0 default -disposition:s:1 0 -disposition:s:2 0 \
  "<dir>/video_with_selectable_subtitles.mkv"
```

Generated files:

| File | Notes |
|------|-------|
| `video_with_selectable_subtitles.mp4` | MP4 with `mov_text` subtitle tracks |
| `video_with_selectable_subtitles.mkv` | MKV with native SRT subtitle tracks |

Default track layout:

1. Source + target language, default
2. Target language only
3. Source language only

Verify tracks:

```bash
ffprobe -v error \
  -show_entries stream=index,codec_type,codec_name:stream_tags=language,title:stream_disposition=default \
  -of json "<dir>/video_with_selectable_subtitles.mkv"
```

Prefer MKV when track titles and original SRT fidelity matter. Prefer MP4 when Apple/QuickTime-style compatibility matters.

## Known Issues

### Rolling YouTube Captions

YouTube auto captions are often rolling-window captions. Raw SRT entries can overlap heavily; this is normal on YouTube but wrong for normal players. Always use the cleaned SRT files from `merge-chunks.py`, not raw SRT files, for packaging.

### yt-dlp Quality Listing

If only 360p appears, run `scripts/ensure-yt-dlp.sh` and list formats again. Current YouTube extraction often needs the latest extractor and JS challenge support. HD formats commonly appear as video-only streams that must be merged with a separate audio-only stream.

### Target Language

Do not assume Chinese. Use the system language by default; use the user-requested language when specified. If the target language is ambiguous, infer it from the system/user interface language and the user's conversation language. Keep technical terms in English when that is natural for the target language or requested by the user.

## Dependencies

- `yt-dlp`
- `ffmpeg`
- Python 3
- Optional ASR tool: `qwen3-asr`, Whisper-compatible CLI, or equivalent
