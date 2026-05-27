# Workforce Skills

Personal Agent Skills repository for Codex, Claude Code, and Pi.

## Skills

- `create-npx-skill` — create, publish, validate, install, and update npx-installable Agent Skills repositories.
- `youtube-subtitle-translate` — download YouTube videos, extract or transcribe subtitles, proofread and translate them, generate SRT/ASS outputs, and optionally burn subtitles into the video.

## Install

List available skills:

```bash
npx skills add <github-owner>/<repo> --list
```

Install a skill for supported agents:

```bash
npx skills add <github-owner>/<repo> \
  --skill youtube-subtitle-translate \
  --agent codex \
  --agent claude-code \
  --agent pi
```

Update installed skills:

```bash
npx skills update --project -y
npx skills update --global -y
```
