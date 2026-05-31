#!/bin/bash
# Cloud Release — 双平台安装脚本
# 用法：./install.sh [claude|codex]

set -e

PLATFORM="${1:-claude}"
SRC="$(cd "$(dirname "$0")" && pwd)"

case "$PLATFORM" in
  claude)
    DEST="$HOME/.claude/skills/cloud-release"
    mkdir -p "$DEST"
    rsync -a --exclude='.git' "$SRC/" "$DEST/" 2>/dev/null || { cp -r "$SRC"/. "$DEST/" && rm -rf "$DEST/.git"; }
    chmod +x "$DEST/setup.sh" "$DEST/install.sh" "$DEST/upgrade.sh" 2>/dev/null || true
    echo "✅ cloud-release 已安装到 $DEST"
    echo "   重启 Claude Code 后运行 /cloud-release"
    ;;
  codex)
    DEST=".agents/skills/cloud-release"
    mkdir -p "$DEST"
    rsync -a --exclude='.git' "$SRC/" "$DEST/" 2>/dev/null || { cp -r "$SRC"/. "$DEST/" && rm -rf "$DEST/.git"; }
    chmod +x "$DEST/setup.sh" "$DEST/install.sh" "$DEST/upgrade.sh" 2>/dev/null || true
    echo "✅ cloud-release 已安装到 $DEST"
    echo "   运行：codex exec \"/cloud-release\""
    ;;
  *)
    echo "用法：./install.sh [claude|codex]"
    exit 1
    ;;
esac
