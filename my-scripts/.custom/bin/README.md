# 自定义脚本集合

该目录包含多种实用脚本，主要用于翻译、OCR、WiFi 管理、AI 交互等任务。这些脚本大多基于 Bash 或 Python，依赖外部 API（如 Gemini、腾讯云）或本地工具。

## Arch Linux 依赖

### 核心依赖

| 包名 | 用途 |
|------|------|
| `bash` | Shell 脚本 |
| `python` | Python 脚本 |
| `python-pip` | Python 包管理器 |

### 命令行工具

| 包名 | 用途 |
|------|------|
| `jq` | JSON 处理 |
| `curl` | HTTP 客户端 |
| `wget` | 下载工具 |
| `base64` | Base64 编码 |
| `file` | 文件类型检测 |
| `openssl` | 加密工具 |
| `sed` | 文本处理 |
| `awk` | 文本处理 |
| `grep` | 文本搜索 |

### 图形工具

| 包名 | 用途 |
|------|------|
| `grim` | 截图工具 |
| `slurp` | 区域选择工具 |
| `pot` | 本地 OCR 工具 |

### 可选依赖

| 包名 | 用途 |
|------|------|
| `bat` | Markdown 渲染（可选） |
| `mdcat` | Markdown 渲染（可选） |
| `glow` | Markdown 渲染（可选） |

### Node.js 依赖（部分脚本）

| 包名 | 用途 |
|------|------|
| `nodejs` | Node.js 运行时 |
| `npm` | Node.js 包管理器 |

## 脚本列表

### 1. run-wifi-login-notify.sh
- **目的**：运行 `wifi_login` 脚本并根据其退出码发送桌面通知（成功：Wi-Fi 登录成功；失败：登录失败）。
- **用法**：直接执行，延迟 1 秒后运行登录脚本。
- **依赖**：`wifi_login`、`notify-send`。

### 2. wfreeze
- **目的**：二进制工具（如 Wayland 截屏或冻结工具）。从名称推测，与 Wayland 显示相关。
- **用法** Wayland 截屏或冻结工具。

### 3. ocr
- **目的**：使用 Gemini 视觉模型（gemini-1.5-pro-latest）从图像文件中提取文本，支持输出格式（HTML、Markdown、纯文本）。
- **用法**：`ocr [-t h|m|t] <图像路径>`（默认纯文本）。
- **依赖**：Gemini API（环境变量 `G_API_URL`、`G_API_KEY`、`G_VISION_MODEL`）、`jq`、`curl`、`file`、`base64`。

### 4. indextts
- **目的**：Python 启动器，调用 `indextts.cli.main()`，可能是 TTS（文本到语音）工具的索引或 CLI 入口。
- **用法**：直接执行，传递参数给 indextts CLI。
- **依赖**：Python 3.10、indextts 包。

### 5. imggen
- **目的**：根据提示词生成 AI 图像 URL（使用 pollinations.ai API，模型 flux）。
- **用法**：`imggen <提示词> [--width <宽度>] [--height <高度>]`。
- **依赖**：Python 3（用于 URL 编码）。

### 6. gtrans
- **目的**：使用 Gemini API 进行文本翻译（中英互译，支持指定 :en/:zh）。
- **用法**：`gtrans <:en/:zh> <文本>` 或管道输入。
- **依赖**：Gemini API（`G_API_URL`、`G_API_KEY`、`G_TRANS_MODEL`）、`jq`、`curl`。

### 7. gocr
- **目的**：使用本地 Pot 应用进行屏幕 OCR：截取选区、保存截图、调用本地 OCR 服务。
- **用法**：直接执行，使用 `slurp` 和 `grim` 截屏。
- **依赖**：`pot`、`grim`、`slurp`、`curl`。

### 8. cmdh
- **目的**：根据自然语言描述生成 shell 命令（使用 Gemini）。
- **用法**：`cmdh <问题>`（e.g., "查找大于 10MB 的 mp4 文件"）。
- **依赖**：Gemini API（`G_API_URL`、`G_API_KEY`、`G_TEXT_MODEL`）、`jq`、`curl`。

### 9. wifi_login
- **目的**：自动化登录校园 WiFi 门户（ruijie/captive portal），模拟浏览器请求处理重定向、cookies 和表单提交。
- **用法**：设置环境变量 `WIFI_USERNAME`、`WIFI_PASSWORD`，执行脚本。
- **依赖**：Node.js、`fetch`（内置或 node-fetch）。

### 10. ttrans
- **目的**：使用腾讯云 TMT API 进行文本翻译，支持自动检测源语言，长文本智能分块（优先换行/标点/空格）。
- **用法**：`ttrans :<目标语言> <文本>` 或管道输入。
- **依赖**：腾讯云 API（`T_SECRET_ID`、`T_SECRET_KEY`）、`jq`、`curl`、`openssl`。

### 11. gchat
- **目的**：交互式 Gemini 聊天助手，支持会话管理（新建、切换、删除、历史）、Markdown 渲染、系统提示自定义、加载动画。
- **用法**：`gchat`（交互模式）或 `gchat <临时提示>`；命令如 `/new`、`/switch`、`/system <提示>`。
- **依赖**：Gemini API（`G_API_URL`、`G_API_KEY`、`G_TEXT_MODEL`）、`jq`、`curl`；可选 Markdown 渲染器（mdcat/glow/bat）。

### 12. cman
- **目的**：翻译 man 页面（使用 `gtrans`），缓存结果，支持 `less` 查看；自动处理 man 内容变化。
- **用法**：`cman [man 参数]`（e.g., `cman ls`）。
- **依赖**：`gtrans`、`man`、`less`、`sha256sum`（或 `shasum`）。

## 注意事项
- 大多数脚本依赖 Gemini API（需设置环境变量 `G_API_URL`、`G_API_KEY` 等）或腾讯云密钥。
- 翻译/OCR 脚本支持管道输入，便于与 `man`、`cat` 等结合。
- WiFi 相关脚本针对特定校园网门户，可能需调整 URL/参数。
- 确保安装依赖工具（如 `jq`、`curl`、`grim` 等）。
- 脚本位置：所有脚本均为可执行文件，直接运行或添加到 PATH。

如需修改或扩展，请检查各自脚本的配置区域。
