#!/bin/bash
# Cloud Release — 双平台安装脚本
# 用法：./install.sh [claude|codex] [--global|--project]
#   --global   安装到全局目录（默认）
#   --project  安装到当前项目目录

set -e

PLATFORM="${1:-claude}"
SCOPE="global"

for arg in "$@"; do
  case "$arg" in
    --project) SCOPE="project" ;;
    --global)  SCOPE="global"  ;;
  esac
done

SRC="$(cd "$(dirname "$0")" && pwd)"

case "$PLATFORM" in
  claude)
    if [ "$SCOPE" = "project" ]; then
      DEST=".claude/skills/cloud-release"
    else
      DEST="$HOME/.claude/skills/cloud-release"
    fi
    mkdir -p "$DEST"
    rsync -a --exclude='.git' "$SRC/" "$DEST/" 2>/dev/null || { cp -r "$SRC"/. "$DEST/" && rm -rf "$DEST/.git"; }
    chmod +x "$DEST/setup.sh" "$DEST/install.sh" "$DEST/upgrade.sh" 2>/dev/null || true
    echo "✅ cloud-release 已安装到 $DEST"
    echo "   重启 Claude Code 后运行 /cloud-release"
    ;;
  codex)
    if [ "$SCOPE" = "project" ]; then
      DEST=".agents/skills/cloud-release"
    else
      DEST="$HOME/.agents/skills/cloud-release"
    fi
    mkdir -p "$DEST"
    rsync -a --exclude='.git' "$SRC/" "$DEST/" 2>/dev/null || { cp -r "$SRC"/. "$DEST/" && rm -rf "$DEST/.git"; }
    chmod +x "$DEST/setup.sh" "$DEST/install.sh" "$DEST/upgrade.sh" 2>/dev/null || true
    echo "✅ cloud-release 已安装到 $DEST"
    echo "   运行：codex exec \"/cloud-release\""
    ;;
  *)
    echo "用法：./install.sh [claude|codex] [--global|--project]"
    exit 1
    ;;
esac
