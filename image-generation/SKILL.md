---
name: image-generation
description: 支持多模式图像生成：Seedream文生图（默认）、Seedream图生图、Image2备用。用于文生视频流程中的参考图生成阶段。
allowed-tools: Bash(bash *), HTTP(http *)
---

# Image Generation Skill

支持多模式图像生成：
- **text2image (默认)**: Seedream文生图，2K高清
- **img2image**: Seedream图生图，支持参考图
- **fallback**: Image2备用，当Seedream失败时自动回退

## 支持的模型/服务商

| 模式 | 模型 | 端点 | 特点 |
|------|------|------|------|
| text2image | `doubao-seedream-5-0-260128` | ark.cn-beijing.volces.com | 默认，2K高清 |
| img2image | `doubao-seedream-5-0-260128` | ark.cn-beijing.volces.com | 支持参考图 |
| fallback | `gpt-image-2` | new-api.laplacelab.cn | 备用方案 |

## 触发条件

当Agent需要为分镜场景生成参考图时使用此Skill。

## API Key管理方式（数字资产统一管理）

### 配置文件位置

```
~/agents/API-Keys/seedream.json   # Seedream API配置
~/agents/API-Keys/image2.json     # Image2 API配置（备用）
```

### Seedream配置文件格式

```json
{
  "api_key": "ark-xxx",
  "base_url": "https://ark.cn-beijing.volces.com/api/v3/images/generations",
  "model": "doubao-seedream-5-0-260128"
}
```

### Image2配置文件格式（备用）

```json
{
  "api_key": "sk-xxx",
  "base_url": "https://new-api.laplacelab.cn/v1",
  "backup_base_url": "https://global.newapi.laplacelab.cn/v1",
  "model": "gpt-image-2"
}
```

### 字段说明

| 字段 | 说明 | 必需 |
|------|------|------|
| `api_key` | API密钥 | ✅ |
| `base_url` | 主API端点 | 可选（有默认值） |
| `backup_base_url` | 备用API端点（仅Image2） | 可选 |
| `model` | 默认模型 | 可选（有默认值） |

## 输入参数

### 必需参数

- `prompt`: 图像生成提示词/描述文本

### 可选参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--mode` | 生成模式：`text2image`/`img2image`/`fallback` | `text2image` |
| `--image` | 参考图URL（仅img2image模式） | - |
| `--size` | 图像尺寸 | `2K`(Seedream)/`1024x1024`(Image2) |
| `--quality` | 图像质量（仅fallback） | `medium` |
| `--number` | 生成数量 | `1` |
| `--output-dir` | 输出目录 | 当前目录 |
| `--filename` | 输出文件名 | `image_<timestamp>_<index>.png` |
| `--config` | 配置文件路径 | - |

## 使用方式

### 方式一：文生图（默认模式）

```bash
# 基础用法
bash ~/skills/image-generation/scripts/generate.sh \
  --prompt "一只可爱的猫咪坐在窗台上"

# 指定输出
bash ~/skills/image-generation/scripts/generate.sh \
  --prompt "春天的樱花树下" \
  --output-dir ~/output/images/ \
  --filename scene_01.png
```

### 方式二：图生图

```bash
bash ~/skills/image-generation/scripts/generate.sh \
  --mode img2image \
  --prompt "生成狗狗趴在草地上的近景画面" \
  --image "https://example.com/ref.png" \
  --output-dir ~/output/images/
```

### 方式三：备用模式

```bash
bash ~/skills/image-generation/scripts/generate.sh \
  --mode fallback \
  --prompt "星空下的城市" \
  --output-dir ~/output/images/
```

### 方式四：配置文件

```bash
# 基于配置文件生成
bash ~/skills/image-generation/scripts/generate.sh \
  --config ~/skills/image-generation/config/example.json
```

配置文件格式示例：

```json
{
    "mode": "img2image",
    "prompt": "生成狗狗趴在草地上的近景画面",
    "image": "https://example.com/ref.png",
    "size": "2K",
    "output_dir": "~/output/images/",
    "filename": "scene_01.png"
}
```

## 输出

成功时返回生成的图像URL和本地保存路径。

输出示例：
```json
{
    "success": true,
    "mode": "text2image",
    "images": [
        {
            "url": "https://...",
            "local_path": "~/output/images/scene_01.png"
        }
    ],
    "total_generated": 1
}
```

**注意**：此处的 `url` 是API返回的临时URL，仅供下载使用。下游Agent需要的是 laplace-filebox 上传后的公开URL。

## 与 laplace-filebox 配合使用

**重要**：生成的参考图是本地文件，但下游的video-generation-agent（Seedance API）需要远程URL。因此，生成参考图后必须使用 laplace-filebox 上传获取公开URL。

### 完整流程

```bash
# 步骤1：生成参考图（本地文件）
bash ~/skills/image-generation/scripts/generate.sh \
  --prompt "一只可爱的猫咪坐在窗台上" \
  --output-dir ~/output/视频生成/项目A/images/ \
  --filename scene_01_ref.png

# 步骤2：上传获取公开URL（关键步骤）
bash ~/skills/laplace-filebox/upload.sh ~/output/视频生成/项目A/images/scene_01_ref.png

# 输出示例：
# Uploaded: scene_01_ref.png
# URL: https://laplace-filebox.tos-ap-southeast-1.volces.com/20250602-101500-scene_01_ref.png
```


## 图生图URL传递规则（关键经验）

### 链式图生图必须使用Seedream原始URL

**重要**：在文生视频流程中进行链式图生图（如consistency-controller生成的6图计划）时，img2image的`--image`参数**必须使用Seedream API返回的原始URL**（带TOS签名的临时URL）。

**正确做法**：
```bash
# 第1张图：文生图
bash ~/skills/image-generation/scripts/generate.sh \
  --mode text2image \
  --prompt "场景1描述" \
  --output-dir ~/output/
# 返回：https://ark.cn-beijing.volces.com/xxx（Seedream原始URL）

# 第2张图：图生图，直接使用Seedream原始URL
bash ~/skills/image-generation/scripts/generate.sh \
  --mode img2image \
  --prompt "场景2描述" \
  --image "https://ark.cn-beijing.volces.com/xxx" \
  --output-dir ~/output/
```

**错误做法**：
```bash
# 不要上传到filebox后再用于图生图
bash ~/skills/laplace-filebox/upload.sh scene_01.png
# 返回：https://laplace-filebox.tos-ap-southeast-1.volces.com/xxx

# 错误：Seedream无法下载filebox URL，会超时
bash generate.sh --mode img2image --image "https://laplace-filebox..."
```

### URL使用场景区分

| 场景 | URL类型 | 说明 |
|------|---------|------|
| **图生图链式传递** | Seedream原始URL | Seedream可下载自己的URL，支持链式生成 |
| **视频生成参考图** | filebox公开URL | Seedance API需要公开可访问的URL |

### 完整流程示例

```bash
# 步骤1：生成第1张图（文生图）
bash ~/skills/image-generation/scripts/generate.sh \
  --mode text2image \
  --prompt "缅因猫晨会启动" \
  --output-dir ~/output/images/ \
  --filename scene_01_start.png
# 记录返回的Seedream URL: SEEDREAM_URL_1

# 步骤2：生成第1张图的尾图（图生图，使用Seedream原始URL）
bash ~/skills/image-generation/scripts/generate.sh \
  --mode img2image \
  --prompt "缅因猫晨会结束画面" \
  --image "$SEEDREAM_URL_1" \
  --output-dir ~/output/images/ \
  --filename scene_01_end.png
# 记录返回的Seedream URL: SEEDREAM_URL_2

# 步骤3：上传到filebox（供视频生成使用）
bash ~/skills/laplace-filebox/upload.sh ~/output/images/scene_01_end.png
# 返回filebox URL: FILEBOX_URL

# 步骤4：视频生成使用filebox URL
bash ~/skills/generate-video/scripts/generate.sh \
  --image "$FILEBOX_URL" \
  --prompt "缅因猫动态视频" \
  ...
```

## 自动回退机制

当text2image或img2image模式失败时，脚本会自动回退到fallback模式（Image2 API）。

```
Primary mode failed, trying fallback...
```

## 目录结构

```
image-generation/
├── SKILL.md                    # 技能文档
├── scripts/
│   └── generate.sh            # 主生成脚本（支持多模式）
└── config/
    └── example.json           # 配置示例
```

数字资产统一管理目录：
```
~/agents/API-Keys/
├── seedream.json              # Seedream API配置（主）
├── image2.json                # Image2 API配置（备用）
└── ...
```

## API 请求格式

### Seedream文生图

```bash
POST https://ark.cn-beijing.volces.com/api/v3/images/generations
Content-Type: application/json
Authorization: Bearer $SEEDREAM_API_KEY

{
    "model": "doubao-seedream-5-0-260128",
    "prompt": "图像描述",
    "sequential_image_generation": "disabled",
    "response_format": "url",
    "size": "2K",
    "stream": false,
    "watermark": true
}
```

### Seedream图生图

```bash
POST https://ark.cn-beijing.volces.com/api/v3/images/generations
Content-Type: application/json
Authorization: Bearer $SEEDREAM_API_KEY

{
    "model": "doubao-seedream-5-0-260128",
    "prompt": "图像描述",
    "image": "https://example.com/ref.png",
    "sequential_image_generation": "disabled",
    "response_format": "url",
    "size": "2K",
    "stream": false,
    "watermark": true
}
```

### Image2备用

```bash
POST https://new-api.laplacelab.cn/v1/images/generations
Content-Type: application/json
Authorization: Bearer $IMAGE2_API_KEY

{
    "model": "gpt-image-2",
    "prompt": "图像描述",
    "n": 1,
    "size": "1024x1024",
    "quality": "medium"
}
```

## 注意事项

1. **API Key安全**：存储在数字资产目录，便于统一管理
2. **自动回退**：Seedream失败时自动回退到Image2
3. **必须上传**：生成的参考图必须使用 laplace-filebox 上传获取公开URL
4. **img2image需要参考图URL**：图生图模式必须提供 `--image` 参数
5. **Seedream支持2K**：默认输出2K高清图像

## 依赖

- `bash`：Shell 环境
- `curl`：HTTP 请求工具
- `python3`：JSON解析

## 故障排查

### 1. API Key未设置

```
Error: Seedream API Key not found
Please configure: ~/agents/API-Keys/seedream.json
```

**解决**：按密钥落位流程创建配置文件（key 由用户提供；**全程零回显**——工单/消息里绝不出现 key 内容，只说缺哪个变量名；写完 `chmod 600`，用一次真实 API 调用验证成功才算落位完成）
```bash
# 模板（"ark-xxx" 处填用户提供的真实 key，不要回显）
echo '{
  "api_key": "ark-xxx",
  "base_url": "https://ark.cn-beijing.volces.com/api/v3/images/generations",
  "model": "doubao-seedream-5-0-260128"
}' > ~/agents/API-Keys/seedream.json
chmod 600 ~/agents/API-Keys/seedream.json
```

### 5. 图生图超时错误（Timeout while downloading url）

```
Error: Timeout while downloading url=https://laplace-filebox...
```

**原因**：img2image使用了filebox上传后的URL，Seedream无法下载（不同TOS bucket权限问题）

**解决**：图生图必须使用Seedream原始URL，不能走filebox中转

```bash
# 错误：使用filebox URL
bash generate.sh --mode img2image --image "https://laplace-filebox..."

# 正确：使用Seedream原始URL（文生图返回的URL）
bash generate.sh --mode img2image --image "https://ark.cn-beijing.volces.com/..."
```

**关键区别**：
- 图生图链式传递 → 使用Seedream原始URL
- 视频生成参考图 → 使用filebox公开URL


### 2. img2image模式缺少参考图

```
Error: img2image mode requires --image parameter
```

**解决**：提供参考图URL
```bash
bash generate.sh -m img2image -p "描述" -i "https://example.com/ref.png"
```

### 3. 主模式失败自动回退

```
Primary mode failed, trying fallback...
Using Image2 fallback mode...
```

**解决**：这是正常行为，脚本会自动回退到Image2备用方案

### 4. 下游Agent无法使用参考图

```
Error: Invalid image URL
```

**解决**：确认是否使用了 laplace-filebox 上传获取公开URL

```bash
bash ~/skills/laplace-filebox/upload.sh ~/output/images/ref.png
```
