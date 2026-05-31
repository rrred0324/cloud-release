#!/bin/bash
# Cloud Release — Claude Code 安装脚本
# 用法：./setup.sh [--global|--project]
#   --global   安装到全局目录（默认）：~/.claude/skills/cloud-release
#   --project  安装到当前项目目录：.claude/skills/cloud-release

set -e

SCOPE="global"
for arg in "$@"; do
  case "$arg" in
    --project) SCOPE="project" ;;
    --global)  SCOPE="global"  ;;
  esac
done

SRC="$(cd "$(dirname "$0")" && pwd)"

if [ "$SCOPE" = "project" ]; then
  DEST=".claude/skills/cloud-release"
else
  DEST="$HOME/.claude/skills/cloud-release"
fi

echo "📦 安装 cloud-release（$SCOPE）..."
mkdir -p "$DEST"
rsync -a --exclude='.git' "$SRC/" "$DEST/" 2>/dev/null || { cp -r "$SRC"/. "$DEST/" && rm -rf "$DEST/.git"; }
chmod +x "$DEST/setup.sh" "$DEST/install.sh" "$DEST/upgrade.sh" 2>/dev/null || true

echo "✅ 已安装到 $DEST"
echo "   重启 Claude Code 后运行 /cloud-release"
