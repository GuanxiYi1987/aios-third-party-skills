---
name: generate-video
description: 通过 AI 模型生成视频，支持文本到视频和图片到视频生成，兼容 OpenAI API 模式
allowed-tools: Bash(bash *), HTTP(http *)
---

# Generate Video Skill

通过 AI 模型生成视频内容，支持文本到视频（Text-to-Video）和图片到视频（Image-to-Video）生成，兼容 OpenAI 兼容模式 API。

## 支持的模型/服务商

- 火山方舟 Seedance (doubao-seedance-2-0-260128)
- 其他 OpenAI 兼容模式的视频生成 API

## API 配置

API Key从数字资产统一管理目录读取：

**配置文件路径**：`~/agents/API-Keys/seedance.json`

**配置文件格式**：
```json
{
    "api_key": "ark-xxx",
    "base_url": "https://ark.cn-beijing.volces.com/api/v3",
    "model": "doubao-seedance-2-0-260128"
}
```

**配置优先级**：
1. 命令行参数 `--api-key` 和 `--api-base`（最高优先级）
2. 配置文件 `~/agents/API-Keys/seedance.json`
3. 环境变量 `ARK_API_KEY`（向后兼容，最低优先级）

## 触发条件

当用户需要生成视频时，使用此 Skill。

## 输入参数

### 必需参数

- `prompt`: 视频生成提示词/描述文本

### 可选参数

- `model`: 模型名称（默认：从配置文件读取或 doubao-seedance-2-0-260128）
- `reference_images`: 参考图片 URL 列表（用于 Image-to-Video）
- `reference_videos`: 参考视频 URL 列表
- `reference_audios`: 参考音频 URL 列表
- `ratio`: 视频比例，可选值："16:9", "9:16", "1:1"（默认：16:9）
- `duration`: 视频时长（秒），范围：5-11（默认：5）
- `generate_audio`: 是否生成音频（默认：true）
- `watermark`: 是否添加水印（默认：false）
- `api_key`: API 密钥（覆盖配置文件）
- `api_base`: API 基础 URL（覆盖配置文件）
- `output`: 输出文件路径（默认：~/output/视频生成/video_<timestamp>.mp4）

## 使用方式

### 方式一：命令行参数

```bash
# 文本生成视频（使用数字资产配置）
bash ~/skills/generate-video/scripts/generate.sh \
  --prompt "一只可爱的猫咪在草地上玩耍" \
  --duration 5

# 图片生成视频（使用数字资产配置）
bash ~/skills/generate-video/scripts/generate.sh \
  --prompt "让图片中的猫咪动起来" \
  --image https://example.com/cat.jpg \
  --duration 5

# 多模态生成（文本+图片+视频+音频）
bash ~/skills/generate-video/scripts/generate.sh \
  --prompt "使用参考视频的第一视角，配合参考音频" \
  --image https://example.com/img1.jpg \
  --image https://example.com/img2.jpg \
  --video https://example.com/ref.mp4 \
  --audio https://example.com/music.mp3 \
  --duration 10

# 完整参数示例（覆盖配置文件）
bash ~/skills/generate-video/scripts/generate.sh \
  --prompt "视频描述文本" \
  --model doubao-seedance-2-0-260128 \
  --ratio 16:9 \
  --duration 10 \
  --generate-audio true \
  --watermark false \
  --api-key "your-api-key" \
  --api-base "https://ark.cn-beijing.volces.com/api/v3" \
  --output ~/output/视频生成/my_video.mp4
```

### 方式二：配置文件

```bash
# 基于配置文件生成
bash ~/skills/generate-video/scripts/generate.sh \
  --config ~/skills/generate-video/config/text-to-video.json
```

配置文件格式示例：

```json
{
    "model": "doubao-seedance-2-0-260128",
    "prompt": "视频描述文本",
    "reference_images": [
        "https://example.com/image1.jpg",
        "https://example.com/image2.jpg"
    ],
    "reference_videos": [
        "https://example.com/video.mp4"
    ],
    "reference_audios": [
        "https://example.com/audio.mp3"
    ],
    "ratio": "16:9",
    "duration": 10,
    "generate_audio": true,
    "watermark": false,
    "output": "~/output/视频生成/my_video.mp4"
}
```

## 输出格式

脚本输出执行日志到stderr，成功时输出：

```
✓ Video generation completed successfully!
  Output: /path/to/video.mp4
```

## 故障排查

### 问题：API Key无效

**原因**：`~/agents/API-Keys/seedance.json` 文件不存在或api_key字段为空
**解决**（⚠️ 零回显纪律：任何情况下不要输出密钥文件内容到日志/工单/消息）：
1. 检查配置文件是否存在：`ls ~/agents/API-Keys/seedance.json`
2. 检查 api_key 字段非空（只看长度不看内容）：`python3 -c "import json;print(len(json.load(open('$HOME/agents/API-Keys/seedance.json')).get('api_key','')))"` —— 输出 0 = 缺 key
3. 密钥有效性唯一判定 = 实际调用一次生成接口看响应；禁止格式猜测,禁止回显

### 问题：视频生成超时

**原因**：视频生成任务需要较长时间（5-10分钟）
**解决**：脚本已配置120次轮询（约10分钟），如仍超时请检查API服务状态

### 问题：参考图片URL无效

**原因**：Seedance API只支持公开可访问的http/https URL，不支持本地文件路径
**解决**：使用 `laplace-filebox` skill 上传图片获取公开URL

## 依赖要求

- curl（用于API调用）
- python3（用于JSON解析）
- 有效的 Seedance API Key

## 相关Skill

- `laplace-filebox`: 用于上传本地图片获取公开URL
- `image-generation`: 用于生成参考图片
