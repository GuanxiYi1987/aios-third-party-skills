#!/usr/bin/env bash
# 安装 ffmpeg（静态构建）到 tools/ —— 通用常备工具（转录抽音频、未来视频剪辑都用它）
# 用法：bash install_ffmpeg.sh   （可用 TOOLS_DIR 环境变量覆盖默认 ~/tools）
set -e

TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
DEST="$TOOLS_DIR/ffmpeg"

if [ -x "$DEST/ffmpeg" ]; then
  echo "已安装：$DEST/ffmpeg（跳过下载）"
  "$DEST/ffmpeg" -version | head -1
  exit 0
fi

os="$(uname -s)"; arch="$(uname -m)"
mkdir -p "$DEST"
tmp="$(mktemp -d)"

case "$os" in
  Linux)
    case "$arch" in
      x86_64)  pkg="amd64" ;;
      aarch64) pkg="arm64" ;;
      *) echo "ERROR: 不支持的 Linux 架构 $arch" >&2; exit 1 ;;
    esac
    url="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-${pkg}-static.tar.xz"
    echo "下载 $url"
    if ! curl -fsSL --retry 2 -o "$tmp/ffmpeg.tar.xz" "$url"; then
      echo "ERROR: 下载失败（johnvansickle.com 不可达？）——列为待人项，勿盲重试" >&2; exit 1
    fi
    tar -xJf "$tmp/ffmpeg.tar.xz" -C "$tmp"
    cp "$tmp"/ffmpeg-*-static/ffmpeg "$tmp"/ffmpeg-*-static/ffprobe "$DEST/"
    ;;
  Darwin)
    # macOS：优先 brew（已装则软链），否则 evermeet 静态包（x86_64，Apple Silicon 走 Rosetta）
    if command -v ffmpeg >/dev/null 2>&1; then
      ln -sf "$(command -v ffmpeg)" "$DEST/ffmpeg"
      command -v ffprobe >/dev/null 2>&1 && ln -sf "$(command -v ffprobe)" "$DEST/ffprobe"
    else
      for bin in ffmpeg ffprobe; do
        echo "下载 evermeet $bin"
        if ! curl -fsSL --retry 2 -o "$tmp/$bin.zip" "https://evermeet.cx/ffmpeg/getrelease/$bin/zip"; then
          echo "ERROR: evermeet 下载失败——macOS 可改用 brew install ffmpeg" >&2; exit 1
        fi
        unzip -oq "$tmp/$bin.zip" -d "$DEST"
      done
      chmod +x "$DEST/ffmpeg" "$DEST/ffprobe" 2>/dev/null || true
    fi
    ;;
  *) echo "ERROR: 不支持的平台 $os" >&2; exit 1 ;;
esac
rm -rf "$tmp"

"$DEST/ffmpeg" -version | head -1
echo "ffmpeg 就绪：$DEST/ffmpeg"
