#!/bin/bash

# Image Generation Script - Multi-Mode Support
#   1. text2image (default): Seedream文生图
#   2. img2image: Seedream图生图
#   3. fallback: Image2备用

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Config paths
SEEDREAM_CONFIG="${HOME}/agents/API-Keys/seedream.json"
IMAGE2_CONFIG="${HOME}/agents/API-Keys/image2.json"

# Defaults
DEFAULT_MODE="text2image"
DEFAULT_N=1
TIMEOUT_SECONDS=60

# Seedream defaults
SEEDREAM_API_KEY=""
SEEDREAM_ENDPOINT="https://ark.cn-beijing.volces.com/api/v3/images/generations"
SEEDREAM_MODEL="doubao-seedream-5-0-260128"
SEEDREAM_SIZE="2K"

# Image2 defaults
IMAGE2_API_KEY=""
IMAGE2_PRIMARY="https://new-api.laplacelab.cn/v1"
IMAGE2_BACKUP="https://global.newapi.laplacelab.cn/v1"
IMAGE2_MODEL="gpt-image-2"
IMAGE2_SIZE="1024x1024"
IMAGE2_QUALITY="medium"

# Load Seedream config
load_seedream_config() {
    if [[ -f "$SEEDREAM_CONFIG" ]]; then
        local json_content=$(cat "$SEEDREAM_CONFIG")
        SEEDREAM_API_KEY=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('api_key',''))")
        local endpoint=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('base_url',''))")
        [[ -n "$endpoint" ]] && SEEDREAM_ENDPOINT="$endpoint"
        local model=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('model',''))")
        [[ -n "$model" ]] && SEEDREAM_MODEL="$model"
    fi
}

# Load Image2 config
load_image2_config() {
    if [[ -f "$IMAGE2_CONFIG" ]]; then
        local json_content=$(cat "$IMAGE2_CONFIG")
        IMAGE2_API_KEY=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('api_key',''))")
        local primary=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('base_url',''))")
        [[ -n "$primary" ]] && IMAGE2_PRIMARY="$primary"
        local backup=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('backup_base_url',''))")
        [[ -n "$backup" ]] && IMAGE2_BACKUP="$backup"
        local model=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('model',''))")
        [[ -n "$model" ]] && IMAGE2_MODEL="$model"
    else
        IMAGE2_API_KEY="${IMAGE2_API_KEY:-${OPENAI_API_KEY:-}}"
    fi
}

show_help() {
    cat << 'HELP'
Usage: generate.sh [OPTIONS]

Image Generation Skill - Multi-Mode Support

Modes:
    text2image (default)  Seedream文生图 - 2K高清
    img2image             Seedream图生图 - 支持参考图
    fallback              Image2备用

Options:
    -p, --prompt TEXT      Image prompt (required)
    -m, --mode MODE        Mode: text2image/img2image/fallback
    -i, --image URL        Reference image URL (img2image)
    -s, --size SIZE        Image size
    -q, --quality QUALITY  Quality for fallback: low/medium/high/auto
    -n, --number NUM       Number of images (default: 1)
    -o, --output-dir DIR   Output directory
    -f, --filename NAME    Output filename
    -c, --config FILE      Config file
    -h, --help             Show help

Examples:
    bash generate.sh -p "一只可爱的猫咪"
    bash generate.sh -m img2image -p "描述" -i "https://ref.png"
    bash generate.sh -m fallback -p "春天的樱花"
HELP
}

parse_args() {
    PROMPT=""
    MODE="$DEFAULT_MODE"
    IMAGE_URL=""
    SIZE=""
    QUALITY="$IMAGE2_QUALITY"
    N="$DEFAULT_N"
    OUTPUT_DIR=""
    FILENAME=""
    CONFIG=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--prompt) PROMPT="$2"; shift 2 ;;
            -m|--mode) MODE="$2"; shift 2 ;;
            -i|--image) IMAGE_URL="$2"; shift 2 ;;
            -s|--size) SIZE="$2"; shift 2 ;;
            -q|--quality) QUALITY="$2"; shift 2 ;;
            -n|--number) N="$2"; shift 2 ;;
            -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
            -f|--filename) FILENAME="$2"; shift 2 ;;
            -c|--config) CONFIG="$2"; shift 2 ;;
            -h|--help) show_help; exit 0 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done
}

load_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        local json_content=$(cat "$config_file")
        PROMPT=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('prompt',''))")
        MODE=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('mode','$DEFAULT_MODE'))")
        IMAGE_URL=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('image',''))")
        SIZE=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('size',''))")
        QUALITY=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('quality','$IMAGE2_QUALITY'))")
        N=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('n',$DEFAULT_N))")
        OUTPUT_DIR=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('output_dir',''))")
        FILENAME=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('filename',''))")
    fi
}

validate_params() {
    if [[ -z "$PROMPT" ]]; then
        echo "Error: Prompt required" >&2
        exit 1
    fi
    if [[ "$MODE" != "text2image" && "$MODE" != "img2image" && "$MODE" != "fallback" ]]; then
        echo "Error: Invalid mode. Use: text2image, img2image, fallback" >&2
        exit 1
    fi
    if [[ "$MODE" == "img2image" && -z "$IMAGE_URL" ]]; then
        echo "Error: img2image requires --image" >&2
        exit 1
    fi
    if [[ -z "$SIZE" ]]; then
        if [[ "$MODE" == "fallback" ]]; then
            SIZE="$IMAGE2_SIZE"
        else
            SIZE="$SEEDREAM_SIZE"
        fi
    fi
}

generate_seedream_text() {
    local api_key="$1" prompt="$2" size="$3"
    local json_data="{\"model\":\"$SEEDREAM_MODEL\",\"prompt\":\"$prompt\",\"sequential_image_generation\":\"disabled\",\"response_format\":\"url\",\"size\":\"$size\",\"stream\":false,\"watermark\":true}"
    
    local response=$(curl -s -X POST "$SEEDREAM_ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$json_data" --max-time "$TIMEOUT_SECONDS" 2>&1)
    
    local error_msg=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null || echo "")
    if [[ -n "$error_msg" ]]; then
        echo "API Error: $error_msg" >&2
        return 1
    fi
    echo "$response"
}

generate_seedream_image() {
    local api_key="$1" prompt="$2" image_url="$3" size="$4"
    local json_data="{\"model\":\"$SEEDREAM_MODEL\",\"prompt\":\"$prompt\",\"image\":\"$image_url\",\"sequential_image_generation\":\"disabled\",\"response_format\":\"url\",\"size\":\"$size\",\"stream\":false,\"watermark\":true}"
    
    local response=$(curl -s -X POST "$SEEDREAM_ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$json_data" --max-time "$TIMEOUT_SECONDS" 2>&1)
    
    local error_msg=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null || echo "")
    if [[ -n "$error_msg" ]]; then
        echo "API Error: $error_msg" >&2
        return 1
    fi
    echo "$response"
}

try_image2_endpoint() {
    local api_base="$1" api_key="$2" prompt="$3" size="$4" quality="$5"
    local api_url="${api_base}/images/generations"
    local json_data="{\"model\":\"$IMAGE2_MODEL\",\"prompt\":\"$prompt\",\"n\":1,\"size\":\"$size\",\"quality\":\"$quality\"}"
    
    local response=$(curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$json_data" --max-time "$TIMEOUT_SECONDS" 2>&1)
    
    local error_msg=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null || echo "")
    if [[ -n "$error_msg" ]]; then
        echo "API Error: $error_msg" >&2
        return 1
    fi
    echo "$response"
}

generate_image2() {
    echo "Using Image2 fallback..." >&2
    if try_image2_endpoint "$IMAGE2_PRIMARY" "$IMAGE2_API_KEY" "$PROMPT" "$SIZE" "$QUALITY"; then
        return 0
    fi
    echo "Primary failed, trying backup..." >&2
    try_image2_endpoint "$IMAGE2_BACKUP" "$IMAGE2_API_KEY" "$PROMPT" "$SIZE" "$QUALITY"
}

generate() {
    local mode="$1"
    if [[ "$mode" == "text2image" ]]; then
        [[ -z "$SEEDREAM_API_KEY" ]] && { echo "Error: Seedream API Key not found" >&2; exit 1; }
        generate_seedream_text "$SEEDREAM_API_KEY" "$PROMPT" "$SIZE"
    elif [[ "$mode" == "img2image" ]]; then
        [[ -z "$SEEDREAM_API_KEY" ]] && { echo "Error: Seedream API Key not found" >&2; exit 1; }
        generate_seedream_image "$SEEDREAM_API_KEY" "$PROMPT" "$IMAGE_URL" "$SIZE"
    elif [[ "$mode" == "fallback" ]]; then
        [[ -z "$IMAGE2_API_KEY" ]] && { echo "Error: Image2 API Key not found" >&2; exit 1; }
        generate_image2
    fi
}

download_image() {
    curl -s -L "$1" -o "$2" 2>&1
    [[ $? -eq 0 && -f "$2" ]]
}

parse_response() {
    echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',[])))" 2>/dev/null
}

get_image_url() {
    echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',[])[$2].get('url',''))"
}

main() {
    load_seedream_config
    load_image2_config
    parse_args "$@"
    [[ -n "$CONFIG" ]] && load_config "$CONFIG"
    validate_params
    
    [[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$(pwd)"
    mkdir -p "$OUTPUT_DIR"

    local response
    if ! response=$(generate "$MODE"); then
        if [[ "$MODE" != "fallback" ]]; then
            echo "Primary mode failed, trying fallback..." >&2
            response=$(generate "fallback") || { echo "All modes failed" >&2; exit 1; }
            MODE="fallback"
        else
            exit 1
        fi
    fi

    local images_count=$(parse_response "$response")
    [[ -z "$images_count" || "$images_count" == "0" ]] && { echo "No images generated" >&2; exit 1; }

    local results="["
    for ((i=0; i<images_count; i++)); do
        local image_url=$(get_image_url "$response" "$i")
        local output_file
        if [[ -n "$FILENAME" && $images_count -eq 1 ]]; then
            output_file="${OUTPUT_DIR}/${FILENAME}"
        else
            output_file="${OUTPUT_DIR}/image_$(date +%Y%m%d_%H%M%S)_$((i+1)).png"
        fi

        echo "Downloading image $((i+1))/$images_count..." >&2
        if download_image "$image_url" "$output_file"; then
            echo "  Saved: $output_file" >&2
            [[ $i -gt 0 ]] && results+=","
            results+="{\"url\":\"$image_url\",\"local_path\":\"$output_file\"}"
        else
            echo "  Failed to download image $((i+1))" >&2
        fi
    done
    results+="]"

    echo ""
    echo "{\"success\":true,\"mode\":\"$MODE\",\"images\":$results,\"total_generated\":$images_count}"
}

main "$@"
