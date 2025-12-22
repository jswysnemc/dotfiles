#!/bin/bash
# 视觉模型处理工具启动脚本
# 
# 使用方法:
#   无参数启动: ./visual-model-launcher.sh
#   指定模板:   ./visual-model-launcher.sh -t ocr
#   指定图片:   ./visual-model-launcher.sh -i /path/to/image.png
#   组合使用:   ./visual-model-launcher.sh -t ocr -i /path/to/img1.png,/path/to/img2.png
#
# 参数说明:
#   -t, --template  指定模板代号
#   -i, --images    指定图片路径，多张图片用逗号分隔
#   -h, --help      显示帮助信息

VM_TEMPLATE=""
VM_IMAGES=""

show_help() {
    echo "视觉模型处理工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -t, --template <代号>   指定要使用的模板代号"
    echo "  -i, --images <路径>     指定图片路径，多张图片用逗号分隔"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                            # 启动交互界面"
    echo "  $0 -t ocr                     # 使用 ocr 模板启动"
    echo "  $0 -i ~/image.png             # 预加载图片启动"
    echo "  $0 -t ocr -i ~/a.png,~/b.jpg  # 指定模板和多张图片"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--template)
            VM_TEMPLATE="$2"
            shift 2
            ;;
        -i|--images)
            VM_IMAGES="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 导出环境变量并启动 QuickShell
export VM_TEMPLATE
export VM_IMAGES
export POPUP_TYPE=visual

exec quickshell -c ~/.config/quickshell
