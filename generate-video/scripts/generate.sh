#!/bin/bash

# Generate Video Script
# 支持通过 AI 模型生成视频，兼容 OpenAI API 模式
# API Key 从数据盘 agents/API-Keys 统一管理目录读取

set -e

# 默认配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# API Key配置文件路径
API_KEY_FILE="${HOME}/agents/API-Keys/seedance.json"

# 默认API配置（当配置文件不存在时使用）
API_KEY=""
API_BASE="https://ark.cn-beijing.volces.com/api/v3"
DEFAULT_MODEL="doubao-seedance-2-0-260128"
DEFAULT_RATIO="16:9"
DEFAULT_DURATION=5
DEFAULT_GENERATE_AUDIO="true"
DEFAULT_WATERMARK="false"
OUTPUT_DIR="${HOME}/output/视频生成"

# 从配置文件加载API Key和端点
load_api_config() {
    if [[ -f "$API_KEY_FILE" ]]; then
        echo "Loading API config from: $API_KEY_FILE" >&2
        local json_content
        json_content=$(cat "$API_KEY_FILE")

        # 读取API Key
        API_KEY=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('api_key',''))")

        # 读取端点
        local base_url
        base_url=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('base_url',''))")
        if [[ -n "$base_url" ]]; then
            API_BASE="$base_url"
        fi

        # 读取默认模型
        local model
        model=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('model',''))")
        if [[ -n "$model" ]]; then
            DEFAULT_MODEL="$model"
        fi
    else
        echo "Warning: API config file not found: $API_KEY_FILE" >&2
        echo "Falling back to environment variables..." >&2
        # 回退到环境变量（向后兼容）
        API_KEY="${ARK_API_KEY:-}"
    fi
}

# 显示帮助信息
show_help() {
    cat << 'HELP'
Usage: generate.sh [OPTIONS]

Generate video using AI model.

API Configuration:
    API Key 从数据盘 agents/API-Keys 统一管理目录读取：~/agents/API-Keys/seedance.json
    配置文件格式：
    {
        "api_key": "ark-xxx",
        "base_url": "https://ark.cn-beijing.volces.com/api/v3",
        "model": "doubao-seedance-2-0-260128"
    }

    如配置文件不存在，回退到环境变量：ARK_API_KEY

Options:
    -p, --prompt TEXT           Video generation prompt (required)
    -m, --model MODEL           Model name (default: from config or doubao-seedance-2-0-260128)
    -i, --image URL             Reference image URL (can be used multiple times)
    -v, --video URL             Reference video URL (can be used multiple times)
    -a, --audio URL             Reference audio URL (can be used multiple times)
    -r, --ratio RATIO           Video ratio: 16:9, 9:16, 1:1 (default: 16:9)
    -d, --duration SECONDS      Video duration in seconds (default: 5)
    --generate-audio BOOL       Generate audio (default: true)
    --watermark BOOL            Add watermark (default: false)
    -o, --output FILE           Output file path (default: ${HOME}/output/视频生成/video_<timestamp>.mp4)
    -c, --config FILE           Config file path (JSON format)
    --api-key KEY               API key (overrides config file)
    --api-base URL              API base URL (overrides config file)
    -h, --help                  Show this help message

Examples:
    # Text to video
    bash generate.sh -p "A cat playing in the garden"

    # Image to video
    bash generate.sh -p "Make the cat move" -i https://example.com/cat.jpg

    # With config file
    bash generate.sh -c config.json
HELP
}

# 解析命令行参数
parse_args() {
    PROMPT=""
    MODEL=""
    RATIO="$DEFAULT_RATIO"
    DURATION="$DEFAULT_DURATION"
    GENERATE_AUDIO="$DEFAULT_GENERATE_AUDIO"
    WATERMARK="$DEFAULT_WATERMARK"
    CONFIG=""
    declare -a IMAGES
    declare -a VIDEOS
    declare -a AUDIOS

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--prompt)
                PROMPT="$2"
                shift 2
                ;;
            -m|--model)
                MODEL="$2"
                shift 2
                ;;
            -i|--image)
                IMAGES+=("$2")
                shift 2
                ;;
            -v|--video)
                VIDEOS+=("$2")
                shift 2
                ;;
            -a|--audio)
                AUDIOS+=("$2")
                shift 2
                ;;
            -r|--ratio)
                RATIO="$2"
                shift 2
                ;;
            -d|--duration)
                DURATION="$2"
                shift 2
                ;;
            --generate-audio)
                GENERATE_AUDIO="$2"
                shift 2
                ;;
            --watermark)
                WATERMARK="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG="$2"
                shift 2
                ;;
            --api-key)
                [[ -n "$2" ]] && API_KEY="$2"
                shift 2
                ;;
            --api-base)
                API_BASE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

# 从配置文件加载参数
load_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        echo "Loading config from: $config_file" >&2
        local json_content
        json_content=$(cat "$config_file")

        PROMPT=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('prompt',''))")
        MODEL=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('model',''))")
        RATIO=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ratio','$DEFAULT_RATIO'))")
        DURATION=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('duration',$DEFAULT_DURATION))")
        GENERATE_AUDIO=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('generate_audio','$DEFAULT_GENERATE_AUDIO'))")
        WATERMARK=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('watermark','$DEFAULT_WATERMARK'))")
        OUTPUT=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('output',''))")

        # 读取图片列表
        local images_json
        images_json=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); imgs=d.get('images',[]); print(json.dumps(imgs) if imgs else '[]')")
        if [[ "$images_json" != "[]" ]]; then
            while IFS= read -r img; do
                IMAGES+=("$img")
            done <<< "$(echo "$images_json" | python3 -c "import sys,json; print('\n'.join(json.load(sys.stdin)))")"
        fi
    else
        echo "Config file not found: $config_file" >&2
        exit 1
    fi
}

# 构建请求 JSON
build_request_json() {
    local content_array="["

    # 添加文本提示
    content_array+="{\"type\": \"text\", \"text\": \"$PROMPT\"}"

    # 添加参考图片
    for img in "${IMAGES[@]}"; do
        content_array+=", {\"type\": \"image_url\", \"image_url\": {\"url\": \"$img\"}, \"role\": \"reference_image\"}"
    done

    # 添加参考视频
    for vid in "${VIDEOS[@]}"; do
        content_array+=", {\"type\": \"video_url\", \"video_url\": {\"url\": \"$vid\"}, \"role\": \"reference_video\"}"
    done

    # 添加参考音频
    for aud in "${AUDIOS[@]}"; do
        content_array+=", {\"type\": \"audio_url\", \"audio_url\": {\"url\": \"$aud\"}, \"role\": \"reference_audio\"}"
    done

    content_array+="]"

    cat << JSON
{
    "model": "$MODEL",
    "content": $content_array,
    "generate_audio": $GENERATE_AUDIO,
    "ratio": "$RATIO",
    "duration": $DURATION,
    "watermark": $WATERMARK
}
JSON
}

# 提交生成任务
submit_task() {
    local json_data="$1"
    local api_url="${API_BASE}/contents/generations/tasks"

    echo "Submitting video generation task..." >&2
    echo "API: $api_url" >&2
    echo "Model: $MODEL" >&2

    local response
    response=$(curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "$json_data" 2>&1)

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to submit task" >&2
        echo "$response" >&2
        exit 1
    fi

    echo "$response"
}

# 查询任务状态
query_task() {
    local task_id="$1"
    local api_url="${API_BASE}/contents/generations/tasks/${task_id}"

    curl -s -X GET "$api_url" \
        -H "Authorization: Bearer $API_KEY" 2>&1
}

# 下载视频
download_video() {
    local video_url="$1"
    local output_file="$2"

    echo "Downloading video to: $output_file" >&2
    curl -s -L "$video_url" -o "$output_file" 2>&1

    if [[ $? -eq 0 && -f "$output_file" ]]; then
        echo "Video saved to: $output_file" >&2
        return 0
    else
        echo "Error: Failed to download video" >&2
        return 1
    fi
}

# 主函数
main() {
    # 首先加载 agents/API-Keys 配置
    load_api_config

    parse_args "$@"

    # 如果指定了配置文件，加载配置（覆盖默认配置参数）
    if [[ -n "$CONFIG" ]]; then
        load_config "$CONFIG"
    fi

    # 如果命令行没有指定model，使用默认值
    if [[ -z "$MODEL" ]]; then
        MODEL="$DEFAULT_MODEL"
    fi

    # 验证必需参数
    if [[ -z "$PROMPT" ]]; then
        echo "Error: Prompt is required. Use -p or --prompt to specify." >&2
        show_help
        exit 1
    fi

    if [[ -z "$API_KEY" ]]; then
        echo "Error: API key is required. Configure ~/agents/API-Keys/seedance.json or use --api-key." >&2
        exit 1
    fi

    # 确保输出目录存在
    mkdir -p "$OUTPUT_DIR"

    # 生成输出文件名
    if [[ -z "$OUTPUT" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        OUTPUT="${OUTPUT_DIR}/video_${timestamp}.mp4"
    fi

    # 构建请求
    local json_data
    json_data=$(build_request_json)

    echo "Request JSON:" >&2
    echo "$json_data" | python3 -m json.tool 2>/dev/null || echo "$json_data" >&2
    echo "" >&2

    # 提交任务
    local submit_response
    submit_response=$(submit_task "$json_data")

    echo "Submit Response:" >&2
    echo "$submit_response" | python3 -m json.tool 2>/dev/null || echo "$submit_response" >&2
    echo "" >&2

    # 提取任务 ID
    local task_id
    task_id=$(echo "$submit_response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

    if [[ -z "$task_id" ]]; then
        echo "Error: Failed to get task ID from response" >&2
        exit 1
    fi

    echo "Task ID: $task_id" >&2
    echo "Waiting for video generation to complete..." >&2

    # 轮询任务状态
    local max_attempts=120
    local attempt=0
    local status="PENDING"
    local video_url=""

    while [[ $attempt -lt $max_attempts ]]; do
        sleep 5
        attempt=$((attempt + 1))

        local query_response
        query_response=$(query_task "$task_id")

        status=$(echo "$query_response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)

        echo "[$attempt/$max_attempts] Status: $status" >&2

        if [[ "$status" == "succeeded" ]]; then
            video_url=$(echo "$query_response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('content',{}).get('video_url','') or d.get('result',{}).get('url',''))" 2>/dev/null)
            break
        elif [[ "$status" == "failed" ]]; then
            echo "Error: Video generation failed" >&2
            echo "$query_response" | python3 -m json.tool 2>/dev/null || echo "$query_response" >&2
            exit 1
        fi
    done

    if [[ -z "$video_url" ]]; then
        echo "Error: Timeout waiting for video generation" >&2
        exit 1
    fi

    echo "" >&2
    echo "Video URL: $video_url" >&2

    # 下载视频
    download_video "$video_url" "$OUTPUT"

    echo "" >&2
    echo "✓ Video generation completed successfully!" >&2
    echo "  Output: $OUTPUT" >&2
}

main "$@"
