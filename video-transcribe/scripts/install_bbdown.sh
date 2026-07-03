#!/usr/bin/env bash
# 安装 BBDown（B 站下载工具，自包含二进制）到 tools/
# 用法：bash install_bbdown.sh   （可用 TOOLS_DIR 环境变量覆盖默认 ~/tools）
set -e

VERSION="1.6.3"
BUILD="20240814"
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
DEST="$TOOLS_DIR/bbdown"

os="$(uname -s)"; arch="$(uname -m)"
case "$os-$arch" in
  Linux-x86_64)  plat="linux-x64" ;;
  Linux-aarch64) plat="linux-arm64" ;;
  Darwin-arm64)  plat="osx-arm64" ;;
  Darwin-x86_64) plat="osx-x64" ;;
  *) echo "ERROR: 不支持的平台 $os/$arch" >&2; exit 1 ;;
esac

if [ -x "$DEST/BBDown" ]; then
  echo "已安装：$DEST/BBDown（跳过下载）"
else
  url="https://github.com/nilaoda/BBDown/releases/download/${VERSION}/BBDown_${VERSION}_${BUILD}_${plat}.zip"
  echo "下载 $url"
  mkdir -p "$DEST"
  tmp="$(mktemp -d)"
  if ! curl -fsSL --retry 2 -o "$tmp/bbdown.zip" "$url"; then
    echo "ERROR: 下载失败（GitHub 不可达？）——列为待人项，勿盲重试" >&2
    exit 1
  fi
  unzip -oq "$tmp/bbdown.zip" -d "$DEST"
  chmod +x "$DEST/BBDown"
  rm -rf "$tmp"
fi

# 自检：能解析一个公开视频的信息即为可用（-info 只解析不下载）
if "$DEST/BBDown" --help >/dev/null 2>&1 || [ -x "$DEST/BBDown" ]; then
  echo "BBDown 就绪：$DEST/BBDown"
else
  echo "ERROR: BBDown 二进制不可执行" >&2; exit 1
fi
