---
name: video-editing
description: 使用ffmpeg实现视频拼接、字幕添加、转场效果，用于文生视频流程中的视频剪辑阶段
allowed-tools: Bash(bash *)
---

# Video Editing Skill

使用ffmpeg实现视频拼接、字幕添加、转场效果，用于文生视频流程中的视频剪辑阶段。

## 触发条件

当Agent需要将多个分镜视频片段拼接成完整成片时使用此Skill。

## 输入参数

### 必需参数

- `input_videos`: 输入视频片段路径列表（JSON数组）
- `output`: 输出成片路径

### 可选参数

- `transitions`: 转场效果配置（JSON数组，可选值：fade, dissolve, wipe, slide, circle, none）
- `subtitles`: 字幕配置（JSON对象，包含字幕文本和时间轴）
- `bgm`: 背景音乐路径
- `resolution`: 输出分辨率（默认：1920x1080）
- `fps`: 输出帧率（默认：30）
- `bitrate`: 输出码率（默认：8M）
- `format`: 输出格式（默认：mp4）
- `transition_duration`: 转场持续时间（默认：1秒，整数）

## 使用方式

### 方式一：命令行参数

```bash
# 基础拼接（无转场无字幕）
bash ~/skills/video-editing/scripts/edit.sh \
  --input-videos '["~/output/视频生成/项目A/scene_01.mp4","~/output/视频生成/项目A/scene_02.mp4"]' \
  --output ~/output/视频生成/项目A/final_video.mp4

# 带转场效果（使用xfade滤镜实现真正的fade/dissolve）
bash ~/skills/video-editing/scripts/edit.sh \
  --input-videos '["~/output/视频生成/项目A/scene_01.mp4","~/output/视频生成/项目A/scene_02.mp4","~/output/视频生成/项目A/scene_03.mp4"]' \
  --transitions '["fade","dissolve"]' \
  --transition-duration 1 \
  --output ~/output/视频生成/项目A/final_video.mp4

# 带字幕
bash ~/skills/video-editing/scripts/edit.sh \
  --input-videos '["~/output/视频生成/项目A/scene_01.mp4","~/output/视频生成/项目A/scene_02.mp4"]' \
  --subtitles '{"texts":["第一幕：春日花开","第二幕：少女起舞"],"durations":[5,5]}' \
  --output ~/output/视频生成/项目A/final_video.mp4

# 完整参数
bash ~/skills/video-editing/scripts/edit.sh \
  --input-videos '["scene_01.mp4","scene_02.mp4"]' \
  --transitions '["fade","fade"]' \
  --transition-duration 1 \
  --subtitles '{"texts":["场景一","场景二"],"durations":[5,5]}' \
  --bgm ~/output/视频生成/项目A/bgm.mp3 \
  --resolution 1920x1080 \
  --fps 30 \
  --bitrate 8M \
  --output ~/output/视频生成/项目A/final_video.mp4
```

### 方式二：配置文件

```bash
# 基于配置文件编辑
bash ~/skills/video-editing/scripts/edit.sh \
  --config ~/skills/video-editing/config/project.json
```

配置文件格式示例：

```json
{
    "input_videos": [
        "~/output/视频生成/项目A/scene_01.mp4",
        "~/output/视频生成/项目A/scene_02.mp4",
        "~/output/视频生成/项目A/scene_03.mp4"
    ],
    "transitions": ["fade", "dissolve"],
    "transition_duration": 1,
    "subtitles": {
        "texts": ["第一幕", "第二幕", "第三幕"],
        "durations": [5, 5, 5],
        "style": {
            "font": "NotoSansCJK",
            "size": 48,
            "color": "white",
            "position": "bottom"
        }
    },
    "bgm": "~/output/视频生成/项目A/background_music.mp3",
    "resolution": "1920x1080",
    "fps": 30,
    "bitrate": "8M",
    "output": "~/output/视频生成/项目A/final_video.mp4"
}
```

## 转场效果说明

使用ffmpeg xfade滤镜实现真正的视频转场效果：

| 转场类型 | ffmpeg滤镜 | 效果描述 |
|---------|-----------|---------|
| fade | fade | 淡入淡出 |
| dissolve | fade | 溶解效果（与fade相同） |
| wipe | wipeleft | 向左擦除 |
| slide | slideleft | 向左滑动 |
| circle | circlecrop | 圆形裁剪展开 |

转场效果需要ffmpeg 4.4+版本支持xfade滤镜。

## 输出格式

脚本输出纯JSON到stdout，包含以下字段：

```json
{
    "success": true,
    "output_path": "/path/to/final_video.mp4",
    "duration": 45,
    "resolution": "1920x1080",
    "file_size": "21MB",
    "scenes_count": 5,
    "transitions_applied": ["fade", "dissolve"],
    "subtitles_added": true,
    "bgm_added": false
}
```

## 故障排查

### 问题：转场效果不生效

**原因**：ffmpeg版本过低，不支持xfade滤镜
**解决**：升级ffmpeg到4.4+版本

### 问题：分辨率参数解析失败

**原因**：旧版本脚本中`scale=$RESOLUTION`格式在ffmpeg pad滤镜中解析失败
**解决**：已修复，脚本现在正确解析宽度和高度为`scale=${width}x${height}`格式

### 问题：转场时长浮点数错误

**原因**：bash算术运算不支持浮点数（如`1.0`）
**解决**：已修复，使用整数秒作为转场时长（默认1秒）

### 问题：字幕不显示

**原因**：ffmpeg未编译libass支持
**解决**：确保ffmpeg编译时启用了`--enable-libass`选项

## 依赖要求

- ffmpeg 4.4+（支持xfade滤镜）
- python3（用于JSON解析）
- libass（字幕渲染）
