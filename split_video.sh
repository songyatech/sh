#!/bin/bash

# 默认分段大小（字节）：1GB = 1073741824 字节
DEFAULT_SIZE_MB=1024
DEFAULT_SIZE_BYTES=$((DEFAULT_SIZE_MB * 1024 * 1024))

# 显示帮助信息
function show_help {
    echo "用法: $0 <视频文件路径> [分割大小(MB)]"
    echo ""
    echo "参数:"
    echo "  <视频文件路径>    必填，要分割的视频文件路径"
    echo "  [分割大小(MB)]   可选，每个分段的最大大小，单位MB，默认为${DEFAULT_SIZE_MB}MB (1GB)"
    echo ""
    echo "示例:"
    echo "  $0 movie.mp4           # 将movie.mp4分割成每段最大1GB的多个文件"
    echo "  $0 movie.mp4 500       # 将movie.mp4分割成每段最大500MB的多个文件"
    echo "  $0 movie.mp4 2048      # 将movie.mp4分割成每段最大2GB的多个文件"
    echo ""
    exit 1
}

# 检查是否提供了视频文件路径作为参数
if [ $# -eq 0 ]; then
    echo "错误: 请提供视频文件路径"
    show_help
fi

# 输入文件路径（从命令行参数获取）
INPUT_FILE="$1"

# 检查输入文件是否存在
if [ ! -f "$INPUT_FILE" ]; then
    echo "错误: 文件 '$INPUT_FILE' 不存在"
    exit 1
fi

# 设置分割大小（从命令行参数获取或使用默认值）
if [ $# -ge 2 ] && [[ "$2" =~ ^[0-9]+$ ]]; then
    SIZE_MB="$2"
    MAX_SIZE=$((SIZE_MB * 1024 * 1024))
else
    SIZE_MB=$DEFAULT_SIZE_MB
    MAX_SIZE=$DEFAULT_SIZE_BYTES
fi

# 获取文件名（不含路径和扩展名）作为输出前缀
FILENAME=$(basename -- "$INPUT_FILE")
FILENAME_NO_EXT="${FILENAME%.*}"
OUTPUT_PREFIX="${FILENAME_NO_EXT}_part_"

echo "输入文件: $INPUT_FILE"
echo "输出文件前缀: $OUTPUT_PREFIX"
echo "分段大小: ${SIZE_MB}MB ($(echo "scale=2; $SIZE_MB/1024" | bc)GB)"

# 方法一：基于时间的简单分段（近似大小分割）
# 首先，获取视频时长和比特率
echo "正在分析视频信息..."
DURATION=$(ffmpeg -i "$INPUT_FILE" 2>&1 | grep "Duration" | cut -d ' ' -f 4 | sed 's/,//')
BITRATE=$(ffmpeg -i "$INPUT_FILE" 2>&1 | grep -oP "bitrate: \K[0-9]+" | head -1)

# 在Mac上，grep -P 不可用，使用替代方法获取比特率
if [ -z "$BITRATE" ]; then
    BITRATE=$(ffmpeg -i "$INPUT_FILE" 2>&1 | grep "bitrate" | grep -o "[0-9]* kb/s" | grep -o "[0-9]*" | head -1)
fi

if [ -z "$BITRATE" ]; then
    echo "警告: 无法获取视频比特率，将使用方法三进行分割"
else
    # 根据比特率和最大大小计算分段时长（秒）
    # 比特率单位为kb/s，乘以1000得到bits/s，再除以8得到bytes/s
    BYTES_PER_SEC=$(($BITRATE * 1000 / 8))
    SEGMENT_DURATION=$(($MAX_SIZE / $BYTES_PER_SEC))

    echo "方法一: 将视频分割成大约 $SEGMENT_DURATION 秒的片段（每片段约${SIZE_MB}MB）"
    echo "执行命令: ffmpeg -i \"$INPUT_FILE\" -c copy -map 0 -segment_time $SEGMENT_DURATION -f segment -reset_timestamps 1 \"${OUTPUT_PREFIX}%03d.mp4\""
    
    ffmpeg -i "$INPUT_FILE" -c copy -map 0 -segment_time $SEGMENT_DURATION -f segment -reset_timestamps 1 "${OUTPUT_PREFIX}%03d.mp4"
    
    echo "方法一执行完成"
fi

# 方法二：使用segment_size选项精确分割（需要FFmpeg 4.4+版本）
echo "方法二: 将视频精确分割成${SIZE_MB}MB的片段（需要FFmpeg 4.4+）"
echo "执行命令: ffmpeg -i \"$INPUT_FILE\" -c copy -map 0 -f segment -segment_size $MAX_SIZE \"${OUTPUT_PREFIX}method2_%03d.mp4\""

FFMPEG_VERSION=$(ffmpeg -version | head -n1 | awk -F "version " '{print $2}' | awk '{print $1}' | cut -d. -f1,2)
if (( $(echo "$FFMPEG_VERSION >= 4.4" | bc -l) )); then
    ffmpeg -i "$INPUT_FILE" -c copy -map 0 -f segment -segment_size $MAX_SIZE "${OUTPUT_PREFIX}method2_%03d.mp4"
    echo "方法二执行完成"
else
    echo "警告: 您的FFmpeg版本 ($FFMPEG_VERSION) 可能不支持segment_size选项，跳过方法二"
fi

# 方法三：适用于较老版本FFmpeg的方法，使用-fs选项和流复制
echo "方法三: 使用较旧FFmpeg版本的分割方法"
DURATION_SEC=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
PART=0

if [ -z "$DURATION_SEC" ]; then
    echo "错误: 无法获取视频时长，方法三失败"
else
    echo "视频总时长: $DURATION_SEC 秒"
    
    START=0
    while [ $(echo "$START < $DURATION_SEC" | bc) -eq 1 ]; do
        OUTPUT_FILE="${OUTPUT_PREFIX}method3_$(printf %03d $PART).mp4"
        echo "创建第 $PART 部分，起始时间: $START 秒"
        echo "执行命令: ffmpeg -ss $START -i \"$INPUT_FILE\" -c copy -fs $MAX_SIZE \"$OUTPUT_FILE\""
        
        ffmpeg -ss $START -i "$INPUT_FILE" -c copy -fs $MAX_SIZE "$OUTPUT_FILE"
        
        # 获取创建部分的时长
        if [ -f "$OUTPUT_FILE" ]; then
            PART_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE")
            if [ -z "$PART_DURATION" ]; then
                echo "警告: 无法获取片段时长，使用估计值"
                PART_DURATION=600 # 估计值，10分钟
            fi
            echo "片段时长: $PART_DURATION 秒"
            START=$(echo "$START + $PART_DURATION" | bc)
            PART=$((PART+1))
        else
            echo "错误: 无法创建片段，跳出循环"
            break
        fi
    done
    echo "方法三执行完成"
fi

echo "所有分割方法已完成"
echo "输出文件位于当前目录，前缀为: $OUTPUT_PREFIX"
