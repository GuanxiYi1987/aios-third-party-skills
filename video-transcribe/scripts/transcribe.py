#!/usr/bin/env python3
"""视频/音频转录：本地文件或 B 站链接 → 硅基流动 ASR → 文本。

- B 站链接（BV号/URL/b23.tv）→ BBDown --audio-only 下载音频（工具在 ~/tools/bbdown/）
- 本地视频 → ffmpeg 抽音频（无 ffmpeg 时报错）；本地音频直接用
- 零第三方依赖：仅 python3 标准库。密钥永不入库：env SILICONFLOW_API_KEY > ~/agents/API-Keys/siliconflow.env
"""

import argparse
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid
from pathlib import Path

API = "https://api.siliconflow.cn/v1/audio/transcriptions"
DEFAULT_MODEL = "FunAudioLLM/SenseVoiceSmall"
AUDIO_EXTS = {".mp3", ".m4a", ".wav", ".aac", ".flac", ".ogg", ".opus", ".m4s"}
VIDEO_EXTS = {".mp4", ".mkv", ".mov", ".flv", ".webm", ".avi", ".ts"}
BILI_RE = re.compile(r"(BV[0-9A-Za-z]{10})|bilibili\.com|b23\.tv")


def load_api_key():
    key = os.environ.get("SILICONFLOW_API_KEY", "").strip()
    if key:
        return key
    env_file = Path.home() / "agents/API-Keys/siliconflow.env"
    if env_file.is_file():
        for line in env_file.read_text().splitlines():
            if line.strip().startswith("SILICONFLOW_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("ERROR: 未找到密钥——设 SILICONFLOW_API_KEY 环境变量，或按密钥纪律落位 ~/agents/API-Keys/siliconflow.env")


def find_bbdown():
    for cand in (Path.home() / "tools/bbdown/BBDown", Path(shutil.which("BBDown") or "")):
        if cand and Path(cand).is_file():
            return str(cand)
    sys.exit("ERROR: 未找到 BBDown——先运行 scripts/install_bbdown.sh 装到 ~/tools/bbdown/")


def bilibili_fetch_audio(url_or_bv, workdir):
    bbdown = find_bbdown()
    m = re.search(r"BV[0-9A-Za-z]{10}", url_or_bv)
    target = m.group(0) if m else url_or_bv
    cmd = [bbdown, target, "--audio-only", "--skip-mux", "--work-dir", str(workdir),
           "--file-pattern", "bili_audio"]  # --skip-mux：免 ffmpeg，m4s 直出（ASR 按内容识别）
    print(f"[bbdown] {' '.join(cmd)}", file=sys.stderr)
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        tail = (r.stdout + r.stderr)[-500:]
        sys.exit(f"ERROR: BBDown 下载失败（退出码 {r.returncode}）——{tail}")
    audios = [p for p in Path(workdir).rglob("*") if p.suffix.lower() in AUDIO_EXTS]
    if not audios:
        sys.exit("ERROR: BBDown 跑完但没找到音频产物（检查视频是否需要登录/地区限制）")
    return max(audios, key=lambda p: p.stat().st_size)


def extract_audio(video_path, workdir):
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        sys.exit("ERROR: 本地视频抽音频需要 ffmpeg（沙盒没有则列待人项）；音频文件或 B 站链接不需要")
    out = Path(workdir) / "extracted.m4a"
    r = subprocess.run([ffmpeg, "-y", "-i", str(video_path), "-vn", "-acodec", "aac",
                        "-b:a", "64k", str(out)], capture_output=True, text=True, timeout=1800)
    if r.returncode != 0:
        sys.exit(f"ERROR: ffmpeg 抽音频失败——{r.stderr[-300:]}")
    return out


def asr_transcribe(audio_path, model, api_key):
    boundary = uuid.uuid4().hex
    fname = Path(audio_path).name
    # m4s 是 B 站分段容器，按 mp4 音频处理；ASR 端按内容识别
    ctype = mimetypes.guess_type(fname)[0] or "audio/mpeg"
    data = Path(audio_path).read_bytes()
    body = b"".join([
        f'--{boundary}\r\nContent-Disposition: form-data; name="model"\r\n\r\n{model}\r\n'.encode(),
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{fname}"\r\n'
        f"Content-Type: {ctype}\r\n\r\n".encode() + data + b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])
    req = urllib.request.Request(API, data=body, method="POST", headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": f"multipart/form-data; boundary={boundary}",
    })
    for attempt in (1, 2):
        try:
            with urllib.request.urlopen(req, timeout=600) as resp:
                return json.load(resp).get("text", "")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")[:300]
            if attempt == 2 or exc.code in (400, 401, 403, 413):
                sys.exit(f"ERROR: ASR 失败 HTTP {exc.code}——{detail}")
            time.sleep(5)
        except Exception as exc:  # noqa: BLE001
            if attempt == 2:
                sys.exit(f"ERROR: ASR 请求异常——{exc}")
            time.sleep(5)


def main():
    parser = argparse.ArgumentParser(description="video/audio -> transcript via SiliconFlow ASR")
    parser.add_argument("--input", required=True, help="本地音视频路径，或 B 站 BV 号/链接")
    parser.add_argument("--output-dir", default=str(Path.home() / "output/转录"))
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--keep-audio", action="store_true")
    args = parser.parse_args()

    api_key = load_api_key()
    outdir = Path(args.output_dir).expanduser()
    outdir.mkdir(parents=True, exist_ok=True)
    workdir = Path(tempfile.mkdtemp(prefix="transcribe-"))

    try:
        src = args.input.strip()
        if BILI_RE.search(src) and not Path(src).exists():
            audio, label = bilibili_fetch_audio(src, workdir), None
            m = re.search(r"BV[0-9A-Za-z]{10}", src)
            label = m.group(0) if m else "bilibili"
        else:
            p = Path(src).expanduser()
            if not p.exists():
                sys.exit(f"ERROR: 输入既不是存在的文件也不是 B 站链接：{src}")
            label = p.stem
            audio = p if p.suffix.lower() in AUDIO_EXTS else extract_audio(p, workdir)

        size_mb = audio.stat().st_size / 1024 / 1024
        print(f"[asr] {audio.name}（{size_mb:.1f} MB）→ {args.model}", file=sys.stderr)
        text = asr_transcribe(audio, args.model, api_key)
        if not text.strip():
            sys.exit("ERROR: ASR 返回空文本（检查音频是否有效/有人声）")

        out_path = outdir / f"{label}.transcript.txt"
        out_path.write_text(text, encoding="utf-8")
        print(json.dumps({"text_path": str(out_path), "chars": len(text),
                          "preview": text[:200]}, ensure_ascii=False, indent=2))
    finally:
        if not args.keep_audio:
            shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    main()
