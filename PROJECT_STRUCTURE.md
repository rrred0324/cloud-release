# Cloud Release — Project Structure

```
cloud-release/
├── SKILL.md                        # Core workflow dispatcher
│                                   # Platform detect → project detect → phase execution → output
│
├── platforms/                      # Platform-specific interaction adapters
│   ├── claude-code.md              # Claude Code: AskUserQuestion, TaskCreate, etc.
│   └── codex.md                    # Codex: text-based interaction
│
├── stacks/                         # Tech stack detection and handling
│   ├── python.md                   # Python: FastAPI, Flask, Django
│   ├── nodejs.md                   # Node.js: Express, NestJS, Next.js
│   ├── java.md                     # Java: Spring Boot, Quarkus
│   ├── go.md                       # Go: Gin, Fiber, Echo
│   └── rust.md                     # Rust: Actix, Axum, Rocket
│
├── targets/                        # Deployment target handling
│   ├── recommendation.md           # Three-layer detection + recommendation engine
│   ├── systemd.md                  # systemd service deployment
│   ├── docker.md                   # Docker / Docker Compose
│   ├── kubernetes.md               # Kubernetes / Helm
│   ├── serverless.md               # Vercel, Netlify, Cloudflare Workers
│   └── cicd.md                     # GitHub Actions, GitLab CI, CircleCI
│
├── templates/                      # Output document templates
│   ├── deployment-plan.md          # Deployment plan template
│   └── release-report.md           # Release report template
│
├── README.md                       # Project overview and features
├── QUICKSTART.md                   # 5-minute getting started guide
├── CONTRIBUTING.md                 # How to add stacks, targets, adapters
├── CHANGELOG.md                    # Version history
├── LICENSE                         # MIT License
├── PROJECT_STRUCTURE.md            # This file
└── .cloudrelease.example.yml       # Configuration file example
```

## How Modules Are Loaded

1. **SKILL.md** runs first, detects platform → loads `platforms/<platform>.md`
2. SKILL.md detects project stacks → loads `stacks/<stack>.md` for each
3. SKILL.md detects deployment target → loads `targets/recommendation.md` then `targets/<target>.md`
4. SKILL.md generates output → uses `templates/<template>.md`

Each module file is read only when needed, minimizing context usage.

## Adding New Modules

See [CONTRIBUTING.md](CONTRIBUTING.md) for templates and guidelines.
