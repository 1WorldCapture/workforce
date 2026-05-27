---
name: create-npx-skill
description: >
  Create or maintain an npx-installable Agent Skills GitHub repository for Codex,
  Claude Code, Pi, and other agents that support the `npx skills` CLI. Use when
  the user wants to create a skills repo, add a reusable skill to a GitHub repo,
  publish skills so they can be installed with `npx skills add`, document install
  and update commands, or asks "create an npx skill repo", "create npx skill",
  "创建 npx skill 仓库", "创建可用 npx skills add 安装的技能仓库".
---

# Create Npx Skill

Create a GitHub repository that can be installed with `npx skills add`, and add
skills that work across Codex, Claude Code, Pi, and compatible agents.

## Naming Guidance

`create-npx-skill` is acceptable when the user wants a compact invocation name.
For a brand-new repository, describe the work as creating an "npx-installable
skills repository" so the scope is clear.

Use lowercase directory names with hyphens. The skill directory name and
frontmatter `name` should match.

## Repository Layout

Use this minimal structure:

```text
repo/
  README.md
  .gitignore
  skills/
    my-skill/
      SKILL.md
      agents/
        openai.yaml
      references/
      scripts/
      assets/
```

Only `SKILL.md` is required for each skill. Add `references/`, `scripts/`, or
`assets/` only when they directly support the skill.

Avoid extra documentation files inside an individual skill directory. Keep user
documentation at the repository root.

## Skill Metadata

Every `SKILL.md` needs YAML frontmatter:

```md
---
name: my-skill
description: >
  Clear trigger description. Say exactly when the agent should use this skill,
  including common user phrases and target workflows.
---
```

Make `description` specific. Agents use it to decide whether to load the skill.

For Codex UI metadata, optionally add `agents/openai.yaml`:

```yaml
interface:
  display_name: "My Skill"
  short_description: "Short UI description"
  brand_color: "#2563EB"
  default_prompt: "Use $my-skill to perform the workflow."
policy:
  allow_implicit_invocation: true
```

Do not invent dependency URLs. Add dependencies only when they are known and
required.

## Gitignore

At minimum, ignore local install and cache artifacts:

```gitignore
.agents/
.claude/
.pi/
skills-lock.json
__pycache__/
*.pyc
```

## Install Commands

List skills from a GitHub repository:

```bash
npx skills add owner/repo --list
```

Install a specific skill for common agents:

```bash
npx skills add owner/repo \
  --skill my-skill \
  --agent codex \
  --agent claude-code \
  --agent pi
```

Install globally:

```bash
npx skills add owner/repo --skill my-skill --global
```

For a private repository, prefer the SSH URL:

```bash
npx skills add git@github.com:owner/repo.git --list
```

## Update Commands

Update project-level skills from the current project:

```bash
npx skills update --project -y
```

Update global skills:

```bash
npx skills update --global -y
```

Update one skill:

```bash
npx skills update my-skill --global -y
```

If a skill was copied manually and has no recorded source information, reinstall
it with `npx skills add owner/repo --skill my-skill`.

## Validation Workflow

Before publishing:

1. Check the repository structure with `find` or `rg --files`.
2. Validate scripts, if present, with language-specific syntax checks.
3. Run local discovery:

   ```bash
   npx skills add /absolute/path/to/repo --list
   ```

4. If the repo is already pushed to GitHub, run remote discovery:

   ```bash
   npx skills add owner/repo --list
   ```

5. Confirm the expected skill names and descriptions appear.

## GitHub Publishing Workflow

If the user asks to publish:

1. Run `git status -sb` and identify unrelated local changes.
2. Stage only files that belong to the skill repository work.
3. Commit with a concise message.
4. Use `gh repo create owner/repo --public --source <path> --remote origin` for a
   new public repository, or `--private` if the user asks for private.
5. Push `main` with tracking:

   ```bash
   git push -u origin main
   ```

6. Verify with `gh repo view owner/repo --json nameWithOwner,visibility,url`.
7. Run `npx skills add owner/repo --list` after the repository is public.

Respect existing user changes. Do not stage unrelated untracked files or modify
other skills unless the user asks.
