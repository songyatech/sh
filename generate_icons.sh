#!/bin/bash

# 检查是否安装了 ImageMagick
if ! command -v convert &> /dev/null; then
    echo "提示：需要先安装 ImageMagick 哦！"
    echo "快去终端输入：brew install imagemagick"
    exit 1
}

# 检查是否输入了源图片
if [ $# -ne 1 ]; then
    echo "小贴士：使用方法是 $0 <你的图片路径>"
    echo "举个例子：$0 我的图标.png"
    exit 1
}

# 源图片路径
SOURCE_IMAGE="$1"

# 检查图片是否存在
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "咦？找不到图片诶：'$SOURCE_IMAGE'"
    exit 1
}

# 创建存放图标的文件夹
OUTPUT_DIR="icons"
mkdir -p "$OUTPUT_DIR"

# 要生成的图标尺寸
SIZES=(16 48 128)

# 开始生成图标咯
for size in "${SIZES[@]}"; do
    output_file="${OUTPUT_DIR}/icon_${size}x${size}.png"
    
    convert "$SOURCE_IMAGE" \
        -resize "${size}x${size}" \
        -gravity center \
        -extent "${size}x${size}" \
        "$output_file"
    
    if [ $? -eq 0 ]; then
        echo "搞定！${size}x${size} 的图标已保存：$output_file"
    else
        echo "糟糕，生成 ${size}x${size} 图标时出错了..."
    fi
done

echo "完美！所有图标都在 $OUTPUT_DIR 文件夹里啦～"
