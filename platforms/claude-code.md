---
platform: claude-code
description: "Interaction adapter for Claude Code. Maps generic SKILL.md interaction patterns to Claude Code tools."
---

# Claude Code Platform Adapter

## Detection

This adapter applies when running inside Claude Code CLI. Claude Code provides:
- `AskUserQuestion` for user decisions
- `TaskCreate` / `TaskUpdate` for progress tracking
- `Read` / `Edit` / `Write` for file operations
- `Bash` for command execution
- `Skill` for invoking other skills

## Interaction Mapping

### Decision Points

When SKILL.md defines a decision point:

```
[PLATFORM:INTERACT]
question: <question text>
options:
  A) <option A text> [(recommended)]
  B) <option B text>
  C) <option C text>
recommendation: <A/B/C>
[/PLATFORM:INTERACT]
```

Translate to `AskUserQuestion`:

```json
{
  "questions": [{
    "header": "<short label>",
    "multiSelect": false,
    "options": [
      {"label": "<option A label>", "description": "<option A description>"},
      {"label": "<option B label>", "description": "<option B description>"},
      {"label": "<option C label>", "description": "<option C description>"}
    ],
    "question": "<question text>"
  }]
}
```

- If an option is marked `(recommended)`, append " (Recommended)" to its label.
- Limit options to 4 per question. If more exist, group or filter.

### Progress Tracking

Use `TaskCreate` at the start of each phase:

```json
{
  "subject": "Phase N: <phase name>",
  "description": "<what this phase does>",
  "activeForm": "<present continuous verb>"
}
```

Use `TaskUpdate` with `status: "in_progress"` when starting a phase, `status: "completed"` when done.

### Security Block

When Phase 2 finds P0 issues, use `AskUserQuestion` with a single blocking question:

```json
{
  "questions": [{
    "header": "Blocked",
    "multiSelect": false,
    "options": [
      {"label": "Stop and fix", "description": "Fix P0 issues before continuing"},
      {"label": "Skip (dangerous)", "description": "Continue despite P0 issues — not recommended"}
    ],
    "question": "P0 security issues found: <summary>. Deployment is blocked."
  }]
}
```

### File Operations

- Read files: use `Read` tool
- Edit files: use `Edit` tool
- Write files: use `Write` tool
- Output directory defaults: `releases/<date>/`

### Shell Commands

Use `Bash` tool. For long-running commands, use `run_in_background: true`.

### Skill Invocation

When SKILL.md references another skill (e.g., writing-plans), use `Skill` tool.