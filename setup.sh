#!/bin/bash
# Cloud Release — Claude Code 安装脚本

set -e

DEST="$HOME/.claude/skills/cloud-release"
SRC="$(cd "$(dirname "$0")" && pwd)"

echo "📦 安装 cloud-release..."
mkdir -p "$DEST"
rsync -a --exclude='.git' "$SRC/" "$DEST/" 2>/dev/null || { cp -r "$SRC"/. "$DEST/" && rm -rf "$DEST/.git"; }
chmod +x "$DEST/setup.sh" "$DEST/install.sh" "$DEST/upgrade.sh" 2>/dev/null || true

echo "✅ 已安装到 $DEST"
echo "   重启 Claude Code 后运行 /cloud-release"
