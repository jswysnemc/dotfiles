# ==============================================================================
# G-Scripts Environment Variables (for gchat, gocr, gtrans, cmdh)
# ==============================================================================
#
# 将以下内容添加到你的 ~/.zshrc 或 ~/.bashrc 文件中
# 然后运行 'source ~/.zshrc' (或 'source ~/.bashrc') 或重启终端使其生效
#
# ==============================================================================

# 你的 API 端点 URL
# 如果你使用 Google AI Studio, 它看起来像: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
# 如果你使用 OpenAI 兼容的代理, 请使用代理地址
#export G_API_URL="http://154.222.24.193:8000/v1/chat/completions"
export G_API_URL="https://api.longcat.chat/openai/v1/chat/completions"

# 你的 API 密钥
# 对于 OpenAI 兼容代理, 这通常是 "YOUR_TOKEN" 部分
# 对于 Google AI Studio, 这应该是你的完整 API Key
# export G_API_KEY=$(cat $HOME/.ssh/kyes/gemini.key)
export G_API_KEY=$(cat $HOME/.ssh/keys/longcat.key)

# 用于文本生成任务的模型 (gchat, cmdh, gtrans)
#export G_TEXT_MODEL="gemini-2.5-flash"
export G_TEXT_MODEL="LongCat-Flash-Chat"

# 用于视觉识别任务的模型 (gocr)
#export G_VISION_MODEL="gemini-2.5-flash"
export G_VISION_MODEL="gemini-2.5-flash"

export GEMINI_API_KEY=$(cat $HOME/.ssh/keys/geminicli.key)
