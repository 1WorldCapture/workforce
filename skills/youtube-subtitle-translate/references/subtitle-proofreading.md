# Subtitle Proofreading & Translation Guide

This document serves as the prompt template for parallel agents processing subtitle chunks. Each agent receives a chunk of raw ASR segments and must produce proofread, punctuated, and translated output.

## Input Format

Each chunk file (`chunk_XX.json`) contains:

```json
{
  "chunk_id": 0,
  "start_idx": 0,
  "end_idx": 290,
  "segments": [
    {"text": "hello world", "offset": 7.205, "duration": 2.02},
    ...
  ]
}
```

## Output Format

Save result as `result_XX.json` — a JSON array where each element is:

```json
{
  "index": <original_segment_index>,
  "start": <offset_in_seconds>,
  "end": <offset + duration>,
  "en": "<proofread English with punctuation>",
  "zh": "<Chinese translation>"
}
```

## Rules

### 1. Proofreading (English)

- **Fix ASR errors**: Common patterns include homophone swaps ("their"/"there"/"they're"), missing words, word boundaries split incorrectly
- **Clean filler words**: Remove meaningless "um", "uh", "er" that add nothing. Keep them only when they serve as natural discourse markers (hesitation before important point, thinking pause)
- **Fix cross-segment fragments**: Raw ASR often splits sentences mid-word across segments. Merge fragments to make each segment's text self-contained and readable
- **Preserve technical terms**: AI, API, GitHub, TypeScript, PRD, TDD, Kanban, etc. stay in English
- **Sound tags**: Keep `[music]`, `[applause]`, `[laughter]` etc. Translate descriptively: `[音乐]`, `[掌声]`

### 2. Punctuation

- Add periods, commas, question marks, exclamation points naturally
- Use em-dashes (—) for abrupt breaks or parenthetical asides
- Use quotation marks for quoted speech or terms
- Don't over-punctuate — conversational speech needs less punctuation than written prose
- Each segment should read as a complete thought unit

### 3. Translation (Chinese)

- **Natural Simplified Chinese**, not word-for-word literal translation
- Match the tone: casual/conversational for spoken content, formal for presentation sections
- **Preserve technical terms in English**: AI, API, GitHub, PRD, TDD, Claude Code, etc.
- Handle idioms and cultural references appropriately
- Sound tags get descriptive translations: `[音乐]`, `[掌声]`, `[喷鼻息声]`
- For bilingual output, the Chinese line should align meaning with the English line above it

### 4. Consolidation

Raw ASR produces many tiny fragments (1-3 words). It's acceptable and encouraged to:
- Merge 2-3 consecutive micro-fragments into one coherent segment
- Skip segments that contain only filler sounds with no semantic content
- The output typically has 30-50% fewer segments than the raw input

## Example

**Raw ASR input:**
```
{"text": "so um i think", "offset": 12.3, "duration": 1.5}
{"text": "the thing about", "offset": 14.1, "duration": 1.0}
{"text": "ai coding is", "offset": 15.3, "duration": 0.8}
{"text": "you need to plan", "offset": 16.3, "duration": 1.2}
```

**Proofread output:**
```json
{
  "index": 5,
  "start": 12.3,
  "end": 17.5,
  "en": "So, I think the thing about AI coding is—you need to plan.",
  "zh": "所以我觉得，AI 编程的关键在于——你需要先做规划。"
}
```

## Quality Checklist

Before saving, verify:

- [ ] All required fields present: index, start, end, en, zh
- [ ] Valid JSON (no trailing commas, properly escaped quotes)
- [ ] Timestamps preserved from original (start/end in seconds)
- [ ] English has proper punctuation
- [ ] Chinese reads naturally, not machine-translated
- [ ] Technical terms kept in English
- [ ] No segments skipped without reason (unless pure filler)
