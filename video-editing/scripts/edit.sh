#!/bin/bash

# Video Editing Script
# 使用ffmpeg实现视频拼接、字幕添加、转场效果

set -e

# 默认配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
DEFAULT_RESOLUTION="1920x1080"
DEFAULT_FPS=30
DEFAULT_BITRATE="8M"
DEFAULT_FORMAT="mp4"
DEFAULT_TRANSITION_DURATION=1

# 显示帮助信息
show_help() {
    cat << 'HELP'
Usage: edit.sh [OPTIONS]

Edit video using ffmpeg.

Options:
    -i, --input-videos JSON     Input video paths (JSON array, required)
    -t, --transitions JSON      Transition effects (JSON array)
    -s, --subtitles JSON       Subtitle config (JSON object)
    -b, --bgm PATH             Background music path
    -r, --resolution WxH       Output resolution (default: 1920x1080)
    -f, --fps NUMBER           Output framerate (default: 30)
    --bitrate RATE             Output bitrate (default: 8M)
    --format FORMAT            Output format (default: mp4)
    --transition-duration SEC  Transition duration in seconds (default: 1.0)
    -o, --output PATH          Output path (required)
    -c, --config FILE          Config file path (JSON format)
    -h, --help                 Show this help message

Examples:
    # Basic concat
    bash edit.sh -i '["scene1.mp4","scene2.mp4"]' -o output.mp4

    # With transitions
    bash edit.sh -i '["s1.mp4","s2.mp4","s3.mp4"]' -t '["fade","dissolve"]' -o out.mp4

    # With subtitles
    bash edit.sh -i '["s1.mp4","s2.mp4"]' -s '{"texts":["Scene 1","Scene 2"],"durations":[5,5]}' -o out.mp4
HELP
}

# 检查依赖
check_dependencies() {
    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg is not installed" >&2
        exit 1
    fi

    if ! command -v python3 &> /dev/null; then
        echo "Error: python3 is not installed" >&2
        exit 1
    fi
    
    # 检查ffmpeg版本是否支持xfade
    local ffmpeg_version
    ffmpeg_version=$(ffmpeg -version | head -1 | grep -oP '\d+\.\d+' | head -1)
    echo "FFmpeg version: $ffmpeg_version" >&2
}

# 解析命令行参数
parse_args() {
    INPUT_VIDEOS=""
    TRANSITIONS=""
    SUBTITLES=""
    BGM=""
    RESOLUTION="$DEFAULT_RESOLUTION"
    FPS="$DEFAULT_FPS"
    BITRATE="$DEFAULT_BITRATE"
    FORMAT="$DEFAULT_FORMAT"
    TRANSITION_DURATION="$DEFAULT_TRANSITION_DURATION"
    OUTPUT=""
    CONFIG=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input-videos)
                INPUT_VIDEOS="$2"
                shift 2
                ;;
            -t|--transitions)
                TRANSITIONS="$2"
                shift 2
                ;;
            -s|--subtitles)
                SUBTITLES="$2"
                shift 2
                ;;
            -b|--bgm)
                BGM="$2"
                shift 2
                ;;
            -r|--resolution)
                RESOLUTION="$2"
                shift 2
                ;;
            -f|--fps)
                FPS="$2"
                shift 2
                ;;
            --bitrate)
                BITRATE="$2"
                shift 2
                ;;
            --format)
                FORMAT="$2"
                shift 2
                ;;
            --transition-duration)
                TRANSITION_DURATION="$2"
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

        INPUT_VIDEOS=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('input_videos',[])))")
        TRANSITIONS=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); transitions=d.get('transitions',[]); print(json.dumps(transitions) if transitions else '')")
        SUBTITLES=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); subs=d.get('subtitles'); print(json.dumps(subs) if subs else '')")
        BGM=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('bgm',''))")
        RESOLUTION=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('resolution','$DEFAULT_RESOLUTION'))")
        FPS=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('fps',$DEFAULT_FPS))")
        BITRATE=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('bitrate','$DEFAULT_BITRATE'))")
        FORMAT=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('format','$DEFAULT_FORMAT'))")
        TRANSITION_DURATION=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transition_duration',$DEFAULT_TRANSITION_DURATION))")
        OUTPUT=$(echo "$json_content" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('output',''))")
    else
        echo "Config file not found: $config_file" >&2
        exit 1
    fi
}

# 简单拼接（无转场）
concat_videos_simple() {
    local videos="$1"
    local output="$2"

    # 创建临时文件列表
    local temp_list="/tmp/video_list_$$.txt"

    # 解析JSON数组
    echo "$videos" | python3 -c "
import sys, json, os
videos = json.load(sys.stdin)
with open('$temp_list', 'w') as f:
    for v in videos:
        expanded = os.path.expanduser(v)
        f.write(f\"file '{expanded}'\n\")
"

    echo "Concatenating videos..." >&2
    ffmpeg -y -f concat -safe 0 -i "$temp_list" -c copy "$output" 2>&1 | grep -v "^\s*Duration:" >&2 || true

    rm -f "$temp_list"
}

# 获取xfade转场类型
get_xfade_transition() {
    local transition="$1"
    case "$transition" in
        fade|dissolve)
            echo "fade"
            ;;
        wipe)
            echo "wipeleft"
            ;;
        slide)
            echo "slideleft"
            ;;
        circle)
            echo "circlecrop"
            ;;
        *)
            echo "fade"
            ;;
    esac
}

# 带转场的拼接（使用xfade滤镜）
concat_videos_with_transitions() {
    local videos="$1"
    local transitions="$2"
    local output="$3"
    local trans_duration="$4"

    echo "Processing videos with transitions..." >&2
    
    # 解析视频列表
    local video_array=()
    while IFS= read -r video; do
        video_array+=("$video")
    done <<< "$(echo "$videos" | python3 -c "import sys,json; print('\n'.join(json.load(sys.stdin)))")"
    
    local n=${#video_array[@]}
    
    if [[ $n -eq 1 ]]; then
        # 只有一个视频，直接复制
        cp "${video_array[0]}" "$output"
        return 0
    fi
    
    # 解析转场列表
    local transition_array=()
    if [[ -n "$transitions" ]]; then
        while IFS= read -r trans; do
            transition_array+=("$trans")
        done <<< "$(echo "$transitions" | python3 -c "import sys,json; print('\n'.join(json.load(sys.stdin)))")"
    fi
    
    # 创建临时目录
    local temp_dir="/tmp/video_edit_$$"
    mkdir -p "$temp_dir"
    
    # 步骤1: 统一视频格式（分辨率、帧率）
    echo "Normalizing video formats..." >&2
    # 解析分辨率宽度和高度
    local width=$(echo "$RESOLUTION" | cut -d'x' -f1)
    local height=$(echo "$RESOLUTION" | cut -d'x' -f2)
    local normalized_videos=()
    for i in "${!video_array[@]}"; do
        local normalized="$temp_dir/normalized_$i.mp4"
        ffmpeg -y -i "${video_array[$i]}" -vf "scale=${width}x${height}:force_original_aspect_ratio=decrease,pad=${width}:${height}:(ow-iw)/2:(oh-ih)/2,setsar=1/1,fps=$FPS" -r "$FPS" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 192k -ar 48000 "$normalized" 2>&1 | grep -v "^\s*Duration:" >&2 || true
        normalized_videos+=("$normalized")
    done
    
    # 步骤2: 使用xfade滤镜实现转场
    local filter_complex=""
    local inputs=""
    local last_output="v0"
    local last_aoutput="a0"
    
    for ((i=0; i<${#normalized_videos[@]}; i++)); do
        inputs+=" -i \"${normalized_videos[$i]}\""
    done
    
    # 构建视频滤镜链
    for ((i=0; i<${#normalized_videos[@]}-1; i++)); do
        local next_idx=$((i+1))
        local trans_type="fade"
        
        if [[ $i -lt ${#transition_array[@]} ]]; then
            trans_type=$(get_xfade_transition "${transition_array[$i]}")
        fi
        
        # 计算偏移时间（视频时长 - 转场时长），使用整数运算避免浮点数问题
        local duration
        duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${normalized_videos[$i]}" 2>/dev/null | cut -d. -f1)
        local trans_dur_int=${trans_duration%.*}
        local offset=$((duration - trans_dur_int))
        [[ $offset -lt 0 ]] && offset=0
        
        if [[ $i -eq 0 ]]; then
            filter_complex="[0:v][1:v]xfade=transition=$trans_type:duration=$trans_duration:offset=$offset[v1];"
            filter_complex+="[0:a][1:a]acrossfade=d=$trans_duration[a1];"
            last_output="v1"
            last_aoutput="a1"
        else
            local out_idx=$((i+1))
            filter_complex+="[$last_output][$((i+1)):v]xfade=transition=$trans_type:duration=$trans_duration:offset=$offset[v$out_idx];"
            filter_complex+="[$last_aoutput][$((i+1)):a]acrossfade=d=$trans_duration[a$out_idx];"
            last_output="v$out_idx"
            last_aoutput="a$out_idx"
        fi
    done
    
    # 移除最后一个滤镜的分号
    filter_complex="${filter_complex%;}"
    
    # 构建完整命令
    local cmd="ffmpeg -y"
    for f in "${normalized_videos[@]}"; do
        cmd+=" -i \"$f\""
    done
    cmd+=" -filter_complex \"$filter_complex\""
    cmd+=" -map \"[$last_output]\" -map \"[$last_aoutput]\""
    cmd+=" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 192k"
    cmd+=" \"$output\""
    
    echo "Applying transitions: ${transition_array[*]}" >&2
    eval "$cmd" 2>&1 | grep -v "^\s*Duration:" >&2 || true
    
    # 清理临时文件
    rm -rf "$temp_dir"
}

# 添加字幕
add_subtitles() {
    local input_video="$1"
    local subtitles="$2"
    local output_video="$3"

    # 解析字幕配置
    local texts
    local durations

    texts=$(echo "$subtitles" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('texts',[])))")
    durations=$(echo "$subtitles" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('durations',[])))")

    # 创建ASS字幕文件
    local ass_file="/tmp/subtitles_$$.ass"

    cat > "$ass_file" << ASS
[Script Info]
Title: Auto-generated subtitles
ScriptType: v4.00+

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,48,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,2,0,2,10,10,50,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
ASS

    # 添加字幕事件
    local current_time=0

    while IFS= read -r text && IFS= read -r duration <&3; do
        local start_time=$current_time
        local end_time=$((current_time + duration))

        # 格式化时间 (H:MM:SS.cc)
        local start_h=$((start_time/3600))
        local start_m=$(((start_time%3600)/60))
        local start_s=$((start_time%60))
        local end_h=$((end_time/3600))
        local end_m=$(((end_time%3600)/60))
        local end_s=$((end_time%60))

        local start_formatted=$(printf "%01d:%02d:%02d.00" $start_h $start_m $start_s)
        local end_formatted=$(printf "%01d:%02d:%02d.00" $end_h $end_m $end_s)

        echo "Dialogue: 0,$start_formatted,$end_formatted,Default,,0,0,0,,$text" >> "$ass_file"

        current_time=$end_time
    done <<< "$(echo "$texts" | python3 -c "import sys,json; print('\n'.join(json.load(sys.stdin)))")" 3<<< "$(echo "$durations" | python3 -c "import sys,json; print('\n'.join(str(x) for x in json.load(sys.stdin)))")"

    # 使用ffmpeg添加字幕
    ffmpeg -y -i "$input_video" -vf "ass=$ass_file" -c:a copy "$output_video" 2>&1 | grep -v "^\s*Duration:" >&2 || true

    rm -f "$ass_file"
}

# 输出JSON结果（输出到stdout，其他信息输出到stderr）
output_json_result() {
    local output="$1"
    local duration="$2"
    local file_size="$3"
    local scenes_count="$4"
    local transitions="$5"
    local subtitles="$6"
    local bgm="$7"
    
    # 构建transitions JSON
    local transitions_json="[]"
    if [[ -n "$transitions" ]]; then
        transitions_json="$transitions"
    fi
    
    # 输出纯JSON到stdout
    cat << JSON
{
    "success": true,
    "output_path": "$output",
    "duration": $duration,
    "resolution": "$RESOLUTION",
    "file_size": "$file_size",
    "scenes_count": $scenes_count,
    "transitions_applied": $transitions_json,
    "subtitles_added": $(if [[ -n "$subtitles" ]]; then echo "true"; else echo "false"; fi),
    "bgm_added": $(if [[ -n "$bgm" ]]; then echo "true"; else echo "false"; fi)
}
JSON
}

# 主函数
main() {
    check_dependencies
    parse_args "$@"

    # 如果指定了配置文件，加载配置
    if [[ -n "$CONFIG" ]]; then
        load_config "$CONFIG"
    fi

    # 验证必需参数
    if [[ -z "$INPUT_VIDEOS" ]]; then
        echo "Error: Input videos are required. Use -i or --input-videos to specify." >&2
        show_help
        exit 1
    fi

    if [[ -z "$OUTPUT" ]]; then
        echo "Error: Output path is required. Use -o or --output to specify." >&2
        show_help
        exit 1
    fi

    # 展开输出路径
    OUTPUT=$(eval echo "$OUTPUT")

    # 确保输出目录存在
    mkdir -p "$(dirname "$OUTPUT")"

    # 创建临时目录
    local temp_dir="/tmp/video_edit_$$"
    mkdir -p "$temp_dir"

    local current_video="$temp_dir/temp_concat.mp4"

    # 步骤1: 拼接视频
    if [[ -n "$TRANSITIONS" ]]; then
        concat_videos_with_transitions "$INPUT_VIDEOS" "$TRANSITIONS" "$current_video" "$TRANSITION_DURATION"
    else
        concat_videos_simple "$INPUT_VIDEOS" "$current_video"
    fi

    # 步骤2: 添加字幕（如果需要）
    if [[ -n "$SUBTITLES" ]]; then
        echo "Adding subtitles..." >&2
        local temp_with_subs="$temp_dir/temp_with_subs.mp4"
        add_subtitles "$current_video" "$SUBTITLES" "$temp_with_subs"
        current_video="$temp_with_subs"
    fi

    # 步骤3: 添加背景音乐（如果需要）
    if [[ -n "$BGM" ]]; then
        echo "Adding background music..." >&2
        BGM=$(eval echo "$BGM")
        local temp_with_bgm="$temp_dir/temp_with_bgm.mp4"
        ffmpeg -y -i "$current_video" -i "$BGM" -filter_complex "[0:a][1:a]amix=inputs=2:duration=first[aout]" -map 0:v -map "[aout]" -c:v copy -c:a aac "$temp_with_bgm" 2>&1 | grep -v "^\s*Duration:" >&2 || true
        current_video="$temp_with_bgm"
    fi

    # 步骤4: 最终输出（调整分辨率和码率）
    echo "Finalizing output..." >&2
    ffmpeg -y -i "$current_video" -vf "scale=$RESOLUTION" -r "$FPS" -b:v "$BITRATE" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 192k "$OUTPUT" 2>&1 | grep -v "^\s*Duration:" >&2 || true

    # 清理临时文件
    rm -rf "$temp_dir"

    # 获取输出信息
    local duration
    local file_size
    local scenes_count

    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT" 2>/dev/null | cut -d. -f1)
    file_size=$(du -h "$OUTPUT" 2>/dev/null | cut -f1)
    scenes_count=$(echo "$INPUT_VIDEOS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

    # 输出JSON结果
    output_json_result "$OUTPUT" "$duration" "$file_size" "$scenes_count" "$TRANSITIONS" "$SUBTITLES" "$BGM"

    echo "" >&2
    echo "✓ Video editing completed successfully!" >&2
    echo "  Output: $OUTPUT" >&2
}

main "$@"
