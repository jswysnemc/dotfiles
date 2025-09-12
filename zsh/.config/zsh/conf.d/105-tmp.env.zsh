_KEYS_DIR=$HOME/.ssh/keys
export ANTHROPIC_BASE_URL=$(< $_KEYS_DIR/anthropic.url)
export ANTHROPIC_API_KEY=$(< $_KEYS_DIR/anthropic.key)
export ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_API_KEY
export OPENROUTER_API_KEY=$(< /home/snemc/.ssh/keys/openrouter.key)
# deepseek/deepseek-chat-v3.1:free
