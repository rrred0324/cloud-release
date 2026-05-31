# Cloud Release — AI 驱动的云端发版工作流

零配置、自动检测的发版工作流。自动识别技术栈和部署目标，执行安全审计、构建验证、数据库迁移分析，生成部署计划，并在部署完成后主动检查前端页面是否存在 bug。

**支持 [Claude Code](https://claude.ai/code) 和 [Codex](https://openai.com/codex)。**

---

## 为什么用 Cloud Release？

发版是最容易出问题的时刻。遗漏数据库迁移、泄露密钥、忘记构建——这些问题可预测、可预防。Cloud Release 在代码上线前帮你逐一排查。

| 痛点 | Cloud Release 的解法 |
|------|---------------------|
| 遗漏数据库迁移 | 对比本地模型与远程 DB 实际状态，只输出真正需要同步的增量变更 |
| 幽灵列/幽灵表 | 自动检测远程 DB 中已废弃的列和表，扫描本地+生产环境代码引用，给出清理建议 |
| 密钥泄露 | 扫描 git 追踪的敏感文件和硬编码密钥，P0 问题直接阻断发版 |
| 忘记构建/测试 | 部署前自动运行测试和构建，失败则停止 |
| 发版后才发现前端 bug | 部署完成后主动用浏览器检查前端页面，发现 bug 自动修复并重新验证 |
| 没有回滚方案 | 每次部署都包含经过验证的回滚步骤 |

---

## 核心功能

- 🔍 **零配置自动检测** — 自动识别技术栈、部署目标、项目结构，无需任何配置
- 🗄️ **智能数据库同步分析** — 三方对比（本地模型 vs 远程 DB vs 上次发版状态），消除误报
- 👻 **幽灵列/表检测与清理建议** — 检测废弃字段，扫描代码引用，评估清理风险，给出明确建议
- 🔒 **安全审计** — 扫描泄露密钥、缺失鉴权、敏感文件追踪
- ✅ **构建验证** — 运行测试、构建、类型检查
- 📋 **部署计划生成** — 针对 systemd、Docker、K8s、Serverless 生成逐步操作指南
- 🌐 **前端自动 review** — 部署后主动检查页面，发现前端 bug 自动修复并重新部署
- 🔄 **回滚方案** — 每次部署都包含经过验证的回滚步骤
- ⬆️ **版本自动升级** — 检测 GitHub 新版本，支持 `/cloud-release --upgrade` 一键升级

---

## 支持的技术栈

| 语言 | 框架 | 迁移工具 |
|------|------|---------|
| Python | FastAPI, Flask, Django | Alembic, Django ORM |
| Node.js | Express, NestJS, Next.js | Prisma, Drizzle, TypeORM |
| Java | Spring Boot, Quarkus | Flyway, Liquibase |
| Go | Gin, Fiber, Echo | golang-migrate, Goose |
| Rust | Actix, Axum, Rocket | SQLx, Diesel, SeaORM |

## 支持的部署目标

| 目标 | 适用场景 |
|------|---------|
| systemd | Linux VPS、简单服务 |
| Docker | 容器化部署、Docker Compose |
| Kubernetes | 微服务、高可用 |
| Serverless | Vercel, Netlify, Cloudflare Workers |
| CI/CD | GitHub Actions, GitLab CI, CircleCI |

---

## 快速开始

### 1. 进入你的项目目录

```bash
cd /path/to/your/project
```

### 2. 运行 cloud-release

```bash
/cloud-release
```

### 3. 按引导完成发版

Cloud Release 会自动：
1. 检测技术栈和部署目标
2. 分析上次发版以来的变更
3. 执行安全审计
4. 验证构建和测试
5. 对比远程数据库，生成精准的数据同步计划
6. 生成部署计划
7. 可选：自动执行部署
8. 部署完成后检查前端页面，发现 bug 自动修复

### 零配置

无需任何设置——Cloud Release 从项目结构自动检测一切。如果检测结果不准确，创建 `.cloudrelease.yml` 覆盖：

```yaml
project:
  name: "my-app"

stack:
  backend:
    language: "python"
    framework: "fastapi"

target:
  method: "docker"

# 前端自动 review（部署后自动检查页面）
frontend_url: "https://my-app.vercel.app"

# 版本升级来源（默认：rrred0324/cloud-release）
# skill_repo: "your-org/cloud-release"
```

完整配置项参见 [`.cloudrelease.example.yml`](.cloudrelease.example.yml)。

---

## 使用场景

### 场景一：Python 后端 + 数据库迁移

每次发版前，Cloud Release 会 SSH 到生产服务器采集实际数据库状态，与本地模型对比，只输出真正需要同步的增量变更——不会把已经同步过的表重复列出。

```
✅ 已同步变更（无需操作）
   companies 等 9 个表 — 已于 2026-05-30 同步

📋 本次新增变更（需同步）
   new_table.col_x — VARCHAR(50)
```

### 场景二：幽灵列清理

发现远程数据库有 `avg_3yr_return_new` 列但本地模型已删除：

```
⚠️  GHOST COLUMN DETECTED

Ghost column:   avg_3yr_return_new  (37/1200 行有数据)
Similar column: avg_3yr_return      (1200/1200 行有数据)

Local code references:      0 个文件
Production code references: 0 个文件

✅ 安全清理：数据已完整迁移，无代码引用
```

### 场景三：前端部署后自动验证

部署完成后，Cloud Release 自动打开前端页面检查：

```
🌐 前端 review — https://my-app.vercel.app

检查结果：
  ✅ 首页加载正常
  ⛔ /dashboard 页面：图表组件报错 "Cannot read property 'data' of undefined"

自动修复中...
  → 定位到 DashboardChart.vue:47
  → 修复空值判断
  → 重新构建并部署前端
  → 重新验证 /dashboard ✅
```

### 场景四：版本升级

```bash
/cloud-release --upgrade
```

```
💡 cloud-release 2.1.0 可用（当前 2.0.0）
   正在升级...
✅ 已升级到 2.1.0
```

---

## 输出产物

| 文件 | 内容 |
|------|------|
| `releases/<日期>/DEPLOYMENT_PLAN.md` | 逐步部署操作指南 |
| `releases/<日期>/RELEASE_REPORT.md` | 发版摘要、问题记录、改进建议 |
| `.cloudrelease-state.json` | 上次发版状态（供下次增量对比，加入 .gitignore） |

---

## 安装

### For Claude Code

```bash
git clone https://github.com/rrred0324/cloud-release.git
cd cloud-release
./setup.sh
```

安装后重启 Claude Code，在项目目录运行 `/cloud-release`。

### For Codex CLI

```bash
git clone https://github.com/rrred0324/cloud-release.git
cd cloud-release
./install.sh codex
```

安装后运行 `codex exec "/cloud-release"`。

### 手动安装

```bash
# Claude Code
git clone https://github.com/rrred0324/cloud-release.git ~/.claude/skills/cloud-release

# Codex CLI（在项目目录下）
git clone https://github.com/rrred0324/cloud-release.git .agents/skills/cloud-release
```

---

## 版本升级

Cloud Release 在每次运行时自动检测 GitHub 是否有新版本，有更新时非阻塞提示。

在 Claude Code / Codex 中升级：

```bash
/cloud-release --upgrade
```

离线升级（全新机器或 skill 目录损坏时）：

```bash
cd /path/to/cloud-release   # 进入原 clone 目录
git pull
./upgrade.sh                # Claude Code（默认）
./upgrade.sh codex          # Codex CLI
```

查看当前版本：`/cloud-release --version`

---

## 贡献

参见 [CONTRIBUTING.md](CONTRIBUTING.md)，了解如何添加：
- 新技术栈（`stacks/`）
- 新部署目标（`targets/`）
- 新平台适配器（`platforms/`）

---

## License

MIT License — 详见 [LICENSE](LICENSE)
