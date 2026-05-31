# Changelog

All notable changes to Cloud Release are documented here.

## [2.0.0] - 2026-05-30

### Added
- Auto-detection of tech stacks (Python, Node.js, Java, Go, Rust)
- Auto-detection of deployment targets (systemd, Docker, Kubernetes, Serverless, CI/CD)
- Three-layer deployment target recommendation engine
- Platform adapters for Claude Code and Codex
- Modular architecture: stacks/, targets/, platforms/, templates/
- Configuration file support (.cloudrelease.yml) with auto-detection override
- Deployment plan and release report templates
- Contributing guide for adding new stacks, targets, and adapters

### Changed
- Complete rewrite of SKILL.md as generic core workflow
- All project-specific hardcoded values removed
- README and QUICKSTART rewritten with generic examples
- Configuration file (.cloudrelease.example.yml) expanded with full documentation

### Removed
- All RedPulse-specific hardcoded values
- Single-stack-only architecture (Python/FastAPI/SQLite)

## [1.0.0] - 2026-05-30

### Added
- Initial release based on RedPulse project experience
- 8-phase release workflow
- Security audit (sensitive info scan, auth check)
- Build verification (pytest, npm build)
- Database migration support (Alembic)
- Deployment plan generation (systemd)