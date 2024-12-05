#!/bin/bash

# 检查是否安装了 ImageMagick
command -v convert >/dev/null 2>&1 || { 
    echo "错误: 需要安装 ImageMagick。" 
    echo "请运行: brew install imagemagick"
    exit 1
}

# 检查参数
if [ $# -ne 1 ]; then
    echo "用法: $0 <源图片路径>"
    echo "示例: $0 source.png"
    exit 1
fi

# 源图片路径
SOURCE_IMAGE="$1"

# 检查源图片是否存在
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "错误: 源图片 '$SOURCE_IMAGE' 不存在"
    exit 1
fi

# 创建输出目录
OUTPUT_DIR="icons"
mkdir -p "$OUTPUT_DIR"

# 定义尺寸数组
SIZES=(16 48 128)

# 生成不同尺寸的图标
for size in "${SIZES[@]}"; do
    output_file="${OUTPUT_DIR}/icon_${size}x${size}.png"
    
    convert "$SOURCE_IMAGE" \
        -resize "${size}x${size}" \
        -gravity center \
        -extent "${size}x${size}" \
        "$output_file"
    
    if [ $? -eq 0 ]; then
        echo "✓ 已生成 ${size}x${size} 图标: $output_file"
    else
        echo "× 生成 ${size}x${size} 图标失败"
    fi
done

echo "完成! 所有图标已保存到 $OUTPUT_DIR 目录"
