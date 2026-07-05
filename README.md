# AIOS Third-Party Skills

Laplace AgenticOS 第三方 skill 托管仓（公开）。供 AgenticOS 实例内的 FDE AI 按工单指引拉取安装。

| Skill | 说明 |
|---|---|
| `arxiv-paper-search/` | arXiv 论文检索（官方 API，零依赖，输出 JSON） |
| `video-transcribe/` | 视频/音频转录（本地文件通用；**在线链接仅 B 站**，走 BBDown 免 ffmpeg；硅基流动 ASR，密钥零存储） |
| `generate-video/` | 文生视频/图生视频/多模态（火山方舟 Seedance；密钥读 `~/agents/API-Keys/seedance.json` 或 `ARK_API_KEY`，零存储零回显；异步轮询约 10 分钟上限） |
| `video-editing/` | 视频拼接/剪辑（ffmpeg，需 `~/tools/ffmpeg/` 或系统 ffmpeg；无密钥依赖） |

安装方式（FDE 走 `fde-installation` 准入流程）：

```bash
curl -L -o /tmp/skills.zip https://github.com/GuanxiYi1987/aios-third-party-skills/archive/refs/heads/main.zip
unzip -o /tmp/skills.zip -d /tmp/
cp -r /tmp/aios-third-party-skills-main/<skill-name> ~/skills/
```
