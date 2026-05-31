---
target: cicd
description: "CI/CD pipeline generation — GitHub Actions, GitLab CI, CircleCI. Detect, generate, and enhance pipeline configs."
---

# CI/CD Pipeline Target

## Detection Signals

### Project layer
- `.github/workflows/*.yml` → GitHub Actions
- `.gitlab-ci.yml` → GitLab CI
- `.circleci/config.yml` → CircleCI
- `Jenkinsfile` → Jenkins
- `.travis.yml` → Travis CI

## Applicable Scenarios

- Automating build, test, and deploy
- Ensuring every commit is verified
- Implementing continuous deployment
- Multi-environment promotion (dev → staging → prod)

## Prerequisites

- Git repository hosted on GitHub, GitLab, or other platform
- CI/CD platform enabled for the repository
- Secrets/variables configured in CI/CD settings (not in code)

## Pipeline Generation

### GitHub Actions — Build & Test
```yaml
name: Build & Test
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install -r {backend_dir}/requirements.txt
      - run: cd {backend_dir} && python -m pytest

  build-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: cd {frontend_dir} && npm ci && npm run build
```

### GitHub Actions — Deploy
```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    needs: [test, build-frontend]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to server
        env:
          SSH_KEY: ${{ secrets.SSH_KEY }}
        run: |
          echo "$SSH_KEY" > key && chmod 600 key
          rsync -avz -e "ssh -i key" {dist_path}/ {server_user}@{server_host}:{deploy_path}/{dist_path}/
          ssh -i key {server_user}@{server_host} "sudo systemctl restart {service_name}"
```

### GitLab CI — Basic Pipeline
```yaml
stages:
  - test
  - build
  - deploy

test:
  stage: test
  image: python:3.12
  script:
    - cd {backend_dir}
    - pip install -r requirements.txt
    - python -m pytest

build:
  stage: build
  image: node:20
  script:
    - cd {frontend_dir}
    - npm ci
    - npm run build
  artifacts:
    paths:
      - {dist_path}/

deploy:
  stage: deploy
  only:
    - main
  script:
    - rsync -avz {dist_path}/ {server_user}@{server_host}:{deploy_path}/{dist_path}/
    - ssh {server_user}@{server_host} "sudo systemctl restart {service_name}"
```

## Enhancing Existing Pipelines

When a pipeline config already exists, enhance it with:

1. **Missing stages**: Add deploy stage if only test/build exists
2. **Security scanning**: Add dependency audit step
3. **Caching**: Add pip/npm cache for faster builds
4. **Notifications**: Add Slack/Discord notification on failure

## Rollback Plan

- Re-run previous pipeline with `re-run jobs` (GitHub Actions)
- Re-deploy previous commit: `git revert HEAD && git push`
- Use deployment history to roll back (platform-specific)

## Post-Deployment Verification

Add a verification step to the pipeline:

```yaml
verify:
  needs: [deploy]
  runs-on: ubuntu-latest
  steps:
    - name: Health check
      run: |
        sleep 10
        curl -sf https://{server_host}{health_check_url} || exit 1
```

## Cost/Complexity

- **Cost**: Free (GitHub Actions free tier: 2000 min/month) to Low
- **Complexity**: Medium — YAML pipeline syntax
- **Scalability**: N/A — CI/CD is not the scaling layer
- **Monitoring**: Pipeline status dashboard + notifications

## Common Issues

1. **Pipeline fails on CI but passes locally**: Check for environment differences (OS, Node version, env vars)
2. **Secrets not accessible**: Ensure secrets are configured in repository settings, not in code
3. **Pipeline too slow**: Add caching, parallelize jobs, use smaller base images
4. **Deployment step lacks permissions**: Add SSH key as secret, ensure deploy key has write access
5. **Flaky tests**: Add retry logic or mark tests as flaky and quarantine