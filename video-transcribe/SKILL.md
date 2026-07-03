---
name: video-transcribe
type: capability
description: 视频/音频转录（硅基流动 ASR）：输入本地音视频文件或 B 站链接（BV 号/b23.tv），输出转录文本落 output/。B 站下载走 BBDown 工具（装在 tools/，反爬由它处理）。纯转录工具——摘要/纪要/分类等业务加工属于调用方 extension，不在本 skill。
version: 1.0.0
author: Guanxi Yi (third-party)
---

# 视频转录（video-transcribe）

> ASR = 硅基流动 `POST /v1/audio/transcriptions`（默认 model `FunAudioLLM/SenseVoiceSmall`，可换 `TeleAI/TeleSpeechASR`）。
> 定位 = 纯转录 capability：给文件/链接 → 出文本。业务逻辑（每日总结、会议纪要、分类归档）由调用方的 extension skill 决定。

## 密钥纪律（铁律，装 skill 时先过这关）

- **本 skill 及仓库永不存储任何密钥**。真密钥在数据盘 `agents/API-Keys/siliconflow.env`，格式一行：
  ```
  SILICONFLOW_API_KEY=<用户提供的 key>
  ```
- **落位闭环（存储到正确为止）**：用户在对话里给出 key 后，FDE：① 写入上述文件并 `chmod 600`；② **立即实测验证**——`curl -s https://api.siliconflow.cn/v1/models -H "Authorization: Bearer $KEY" | head -c 100` 返回模型列表即有效；③ 验证失败（401/403）→ 不落位、说明失败原因、重新向用户索要，**直到验证通过才算落位完成**；④ 全程零回显（不把 key 或文件内容贴进任何消息/工单/报告，只说「已落位并验证通过」）。
- 脚本读取顺序：环境变量 `SILICONFLOW_API_KEY` > `~/agents/API-Keys/siliconflow.env`。

## 工具依赖：BBDown（装 tools/，装 skill 时一并装）

B 站下载用 [BBDown](https://github.com/nilaoda/BBDown)（自包含二进制，处理 B 站反爬/流解析）：

```bash
bash scripts/install_bbdown.sh    # 自动识别 OS/架构，装到 ~/tools/bbdown/，装完自检
```

- 装完验证：`~/tools/bbdown/BBDown --version 2>&1 | head -1` 有输出即可。
- 网络不通 GitHub 时脚本会明确报错——列待人项，不要盲重试。

## 用法

```bash
# B 站链接（BV 号 / 完整 URL / b23.tv 短链均可）
python3 scripts/transcribe.py --input "BV1GJ411x7h7" --output-dir ~/output/转录

# 本地音频/视频文件
python3 scripts/transcribe.py --input /path/to/meeting.mp4 --output-dir ~/output/转录
```

- 输出：`<output-dir>/<标题或文件名>.transcript.txt`（全文）+ stdout 一个 JSON（`text_path` / `chars` / `preview`）。
- `--model` 可换 ASR 模型；`--keep-audio` 保留中间音频（默认转录完删除）。
- 本地视频文件抽音频需要 `ffmpeg`；没有 ffmpeg 时：音频文件（mp3/m4a/wav/aac/flac）直接可用，B 站链接走 BBDown `--audio-only` 也不需要 ffmpeg。

## 使用纪律

1. **长音频注意**：ASR 按整文件提交；超长/超大文件被 API 拒绝时如实报错，**不要自行切段猜测**（切段版待升级，先报缺口）。
2. **需要登录的 B 站内容（大会员/充电专属）v1 不支持**——BBDown 匿名模式覆盖普通公开视频；遇到鉴权失败如实报告，不尝试绕。
3. ASR 失败自动重试 1 次；仍失败报错退出，调用方不要循环重试。
4. 转录文本可能含错别字/口音误识——**加工纪要前先通读校对显著错误**（这是调用方 extension 的职责）。

## 边界

- 只转录，不做摘要/纪要/分类（那是 extension 的活）。
- 不下载视频画面流（`--audio-only`），不存储任何密钥，中间音频默认即用即删。
