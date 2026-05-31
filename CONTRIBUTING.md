# Contributing to Cloud Release

Thank you for your interest in contributing! Cloud Release is designed to be extensible — adding a new tech stack or deployment target is as simple as creating a new markdown file.

## How to Add a New Tech Stack

1. Create `stacks/<stack-name>.md` following this template:

```markdown
---
stack: <stack-name>
description: "<short description>"
---

# <Stack Name> Stack Guide

## Detection Signals
### Primary indicators
- <file or directory that indicates this stack>

### Framework detection
| Framework | Detection signal |
|-----------|-----------------|
| <Framework> | <how to detect> |

### Detection commands
<shell commands to detect this stack>

## Build Verification
### Testing
<test commands>
### Build
<build commands>

## Database Migration
### Migration tool detection
| Tool | Detection signal | Command |
|------|-----------------|---------|
| <Tool> | <signal> | <command> |

## Dependency Management
<dependency install commands>

## Service Start
<how to start the service in production>

## Common Issues
1. <most common deployment issue and fix>
```

2. Test by running cloud-release on a project that uses this stack
3. Submit a PR

## How to Add a New Deployment Target

1. Create `targets/<target-name>.md` following this template:

```markdown
---
target: <target-name>
description: "<short description>"
---

# <Target Name> Deployment Target

## Detection Signals
### Project layer signals
<local file patterns>

### Cloud environment signals
<cloud provider indicators>

## Applicable Scenarios
<when to use this target>

## Prerequisites
<what's needed before using>

## Deployment Steps Template
<step-by-step deployment commands>

## Configuration Generation
<how to generate config files from scratch>

## Rollback Plan
<how to roll back>

## Post-Deployment Verification
<verification commands>

## Cost/Complexity
<cost and complexity assessment>

## Common Issues
<deployment-specific problems>
```

2. Add recommendation rules to `targets/recommendation.md` if applicable
3. Test by running cloud-release on a project that deploys to this target
4. Submit a PR

## How to Add a New Platform Adapter

1. Create `platforms/<platform-name>.md` following this template:

```markdown
---
platform: <platform-name>
description: "<short description>"
---

# <Platform Name> Platform Adapter

## Detection
<how to detect this platform>

## Interaction Mapping
### Decision Points
<how to translate [PLATFORM:INTERACT] blocks>

### Progress Tracking
<how to show phase progress>

### File Operations
<tool equivalents for Read/Edit/Write>

### Shell Commands
<tool equivalent for Bash>

### Skill Invocation
<how to handle skill references>
```

2. Test on the target platform
3. Submit a PR

## Guidelines

- **No hardcoded values** — Use template variables (`{backend_dir}`, `{service_name}`, etc.) or auto-detection commands
- **No project-specific references** — Do not include any company names, private domains, or absolute paths
- **Follow the template** — Keep the section structure consistent with existing modules
- **Test on real projects** — Verify detection signals work on at least one real project
- **Keep it concise** — 100-200 lines per module; cover common cases, not every edge case

## PR Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Verify no hardcoded project info
5. Submit a PR with a description of what you added/changed
