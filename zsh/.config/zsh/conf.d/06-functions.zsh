function y() {
 local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
 yazi "$@" --cwd-file="$tmp"
 if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
  builtin cd -- "$cwd"
 fi
 rm -f -- "$tmp"
}


#Function to manage proxy settings
proxy() {
  if [ "$1" = "on" ]; then
    # Set lowercase and uppercase variables for maximum compatibility
    export http_proxy="http://127.0.0.1:7897"
    export https_proxy="http://127.0.0.1:7897"
    export all_proxy="socks5://127.0.0.1:7897"
    export HTTP_PROXY="${http_proxy}"
    export HTTPS_PROXY="${https_proxy}"
    export ALL_PROXY="${all_proxy}"
    echo "Proxy is ON"
    echo "http_proxy: $http_proxy"
    echo "https_proxy: $https_proxy"
    echo "all_proxy: $all_proxy"
  elif [ "$1" = "off" ]; then
    # Unset all related proxy variables
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
    echo "Proxy is OFF"
  elif [ "$1" = "status" ]; then
    if [ -n "$http_proxy" ] || [ -n "$HTTP_PROXY" ]; then
      echo "Proxy is ON"
      echo "--------------------"
      echo "http_proxy: ${http_proxy:-"Not set"}"
      echo "https_proxy: ${https_proxy:-"Not set"}"
      echo "all_proxy: ${all_proxy:-"Not set"}"
      echo "--------------------"
      echo "HTTP_PROXY: ${HTTP_PROXY:-"Not set"}"
      echo "HTTPS_PROXY: ${HTTPS_PROXY:-"Not set"}"
      echo "ALL_PROXY: ${ALL_PROXY:-"Not set"}"
    else
      echo "Proxy is OFF"
    fi
  else
    echo "Usage: proxy [on|off|status]"
  fi
}

alias trans=/usr/bin/trans

# function trans(){
#     if [ -n "$http_proxy" ] || [ -n "$HTTP_PROXY" ]; then
#         _trans -e google "$@"
#     else
#         _trans -e bing "$@"
#     fi
# }
#

