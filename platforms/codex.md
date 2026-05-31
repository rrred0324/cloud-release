---
platform: codex
description: "Interaction adapter for OpenAI Codex. Maps generic SKILL.md interaction patterns to Codex text-based interaction."
---

# Codex Platform Adapter

## Detection

This adapter applies when running inside Codex. Codex provides:
- `shell` for command execution and output
- `read_file` for reading files
- `write_file` for writing files
- Text-based stdout for user interaction (no structured UI tools)

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

Translate to text output:

```
━━━ Decision Required ━━━
<question text>

  A) <option A text> [recommended]
  B) <option B text>
  C) <option C text>

Enter your choice (A/B/C):
```

Then wait for the user's text reply. Parse the first character as the choice.

- If user types "a" or "A", select option A.
- If user types something longer, try to match against option labels.
- If unclear, re-prompt with: "Please enter A, B, or C."

### Progress Tracking

Output phase transitions as text:

```
━━━ Phase N: <phase name> ━━━
<brief description of what's happening>
```

No structured task tracking. Use text markers for progress.

### Security Block

When Phase 2 finds P0 issues:

```
━━━ ⛔ BLOCKED — P0 Security Issues ━━━
<issue summary>

Fix these before continuing. Type "skip" to override (dangerous).
```

### File Operations

- Read files: use `read_file`
- Write files: use `write_file`
- Output directory defaults: `releases/<date>/`

### Shell Commands

Use `shell` tool (Codex equivalent of Bash).

### Skill Invocation

Codex does not support the `Skill` tool. When SKILL.md references another skill, inline the relevant guidance directly from the referenced skill's documentation.

### Format Guidelines

- Use `━━━` (box-drawing characters) for section headers
- Use ✅ ❌ ⚠️ for status indicators
- Keep output concise — avoid unnecessary verbosity
- Use numbered lists for sequential steps
- Use bullet lists for options/checks