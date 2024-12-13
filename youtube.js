[rewrite_local]
# 拒绝 googlevideo.com 和 youtubei.googleapis.com 的 UDP 连接
^https?:\/\/([\w-]+\.)?googlevideo\.com\/.* udp reject
^https?:\/\/youtubei\.googleapis\.com\/.* udp reject

# 修改 YouTube API 响应
^https:\/\/youtubei\.googleapis\.com\/youtubei\/v1\/(browse|next|player|search|reel\/reel_watch_sequence|guide|account\/get_setting|get_watch) url script-response-body https://raw.githubusercontent.com/Maasea/sgmodule/master/Script/Youtube/dist/youtube.response.preview.js

# 映射本地请求
^https?:\/\/[\w-]+\.googlevideo\.com\/initplayback.+&oad url 502

[script]
#  定义脚本的额外参数
youtube_args = type=http-response,script-path=https://raw.githubusercontent.com/Maasea/sgmodule/master/Script/Youtube/dist/youtube.response.preview.js,argument="{\"lyricLang\":\"{{{歌词翻译语言}}}\",\"captionLang\":\"{{{字幕翻译语言}}}\",\"blockUpload\":{{{屏蔽上传按钮}}},\"blockImmersive\":{{{屏蔽选段按钮}}},\"debug\":{{{启用调试模式}}}}"

[mitm]
hostname = *.googlevideo.com, youtubei.googleapis.com
