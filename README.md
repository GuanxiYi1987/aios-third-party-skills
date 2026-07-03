# AIOS Third-Party Skills

Laplace AgenticOS 第三方 skill 托管仓（公开）。供 AgenticOS 实例内的 FDE AI 按工单指引拉取安装。

| Skill | 说明 |
|---|---|
| `arxiv-paper-search/` | arXiv 论文检索（官方 API，零依赖，输出 JSON） |
| `video-transcribe/` | 视频/音频转录（B 站链接走 BBDown 免 ffmpeg，硅基流动 ASR，零 python 依赖，密钥零存储） |

安装方式（FDE 走 `fde-installation` 准入流程）：

```bash
curl -L -o /tmp/skills.zip https://github.com/GuanxiYi1987/aios-third-party-skills/archive/refs/heads/main.zip
unzip -o /tmp/skills.zip -d /tmp/
cp -r /tmp/aios-third-party-skills-main/<skill-name> ~/skills/
```
