#!/bin/bash
# Cloud Release — 离线升级脚本
# 用法：cd /path/to/cloud-release && git pull && ./upgrade.sh [claude|codex]

set -e

PLATFORM="${1:-claude}"
SRC="$(cd "$(dirname "$0")" && pwd)"

case "$PLATFORM" in
  claude)
    DEST="$HOME/.claude/skills/cloud-release"
    ;;
  codex)
    DEST=".agents/skills/cloud-release"
    ;;
  *)
    echo "用法：./upgrade.sh [claude|codex]"
    exit 1
    ;;
esac

if [ ! -d "$DEST" ]; then
  echo "❌ 未找到安装目录 $DEST，请先运行 ./install.sh $PLATFORM"
  exit 1
fi

rsync -a --exclude='.git' "$SRC/" "$DEST/" 2>/dev/null || { cp -r "$SRC"/. "$DEST/" && rm -rf "$DEST/.git"; }
chmod +x "$DEST/setup.sh" "$DEST/install.sh" "$DEST/upgrade.sh" 2>/dev/null || true

VERSION=$(cat "$SRC/VERSION" 2>/dev/null || echo "unknown")
echo "✅ cloud-release 已升级到 $VERSION"
[ "$PLATFORM" = "claude" ] && echo "   重启 Claude Code 使更新生效"
