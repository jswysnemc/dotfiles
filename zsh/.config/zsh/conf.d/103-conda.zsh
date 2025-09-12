# ====================================================
#  Conda Lazy Loading Function
# ====================================================
#
# 通过定义一个同名函数来拦截 `conda` 命令
# 只有在第一次调用时，它才会真正加载 conda 环境，
# 然后执行用户请求的命令。
export CRYPTOGRAPHY_OPENSSL_NO_LEGACY=1
conda() {
  # 移除这个拦截函数本身，以便后续直接调用真正的 conda
  unset -f conda

  # 执行原始的 conda 初始化脚本
  # 这会设置好 PATH 和其他必要的环境变量
  if [ -f /opt/miniconda3/etc/profile.d/conda.sh ]; then
    source /opt/miniconda3/etc/profile.d/conda.sh
  else
    echo "Error: conda.sh not found at /opt/miniconda3/etc/profile.d/conda.sh"
    return 1
  fi

  # 现在，执行你最初想要运行的 conda 命令 (例如 "conda install numpy")
  # "$@" 会传递所有原始参数
  conda "$@"
}
