# Lunar Glass

一款融合中式美学与现代设计的 SDDM 登录主题。农历日历 + 毛玻璃质感，为你的 Linux 桌面带来独特的登录体验。

## 预览

![Preview](background.png)

## 特性

- 🌙 农历日期显示（天干地支、生肖年）
- 🕐 实时时钟
- 👤 用户头像自动加载
- 🔐 密码登录 + 人脸识别支持
- ⌨️ 内置虚拟键盘
- 🖥️ 桌面环境选择器
- 💤 睡眠/重启/关机快捷操作
- 🎨 毛玻璃风格 UI

## 人脸识别

本主题支持通过 PAM 人脸识别模块实现无密码登录。

### 工作原理

主题通过 SDDM 的 PAM 认证机制实现人脸识别：

1. 用户点击人脸识别按钮（或登录界面加载后自动触发）
2. 主题调用 `sddm.login(username, "", sessionIndex)` 发起空密码认证请求
3. PAM 模块链中的人脸识别模块（如 Howdy）接管认证流程
4. 认证成功后 SDDM 完成登录，失败则显示错误提示

### 配置 Howdy（推荐）

[Howdy](https://github.com/boltgolt/howdy) 是 Linux 上流行的人脸识别方案。

1. 安装 Howdy：

```bash
# Arch Linux
yay -S howdy

# Ubuntu/Debian
sudo add-apt-repository ppa:boltgolt/howdy
sudo apt update && sudo apt install howdy

# Fedora
sudo dnf copr enable principis/howdy
sudo dnf install howdy
```

2. 录入人脸：

```bash
sudo howdy add
```

3. 配置 PAM，编辑 `/etc/pam.d/sddm`，在文件开头添加：

```
auth sufficient pam_python.so /lib/security/howdy/pam.py
```

4. 测试：

```bash
sudo howdy test
```

### 界面交互

- 点击头像旁的人脸图标手动触发识别
- 识别中：头像边框蓝色脉冲动画
- 识别成功：边框变绿
- 识别失败：边框变红 + 抖动动画

### 其他 PAM 人脸识别方案

- [pam-face-authentication](https://github.com/pam-face-authentication/pam-face-authentication)
- [face_recognition](https://github.com/ageitgey/face_recognition) + 自定义 PAM 模块

## 安装

### 快速安装

```bash
chmod +x install.sh
sudo ./install.sh
```

### 手动安装

1. 复制到 SDDM 主题目录：

```bash
sudo cp -r . /usr/share/sddm/themes/lunar-glass
```

2. 编辑 SDDM 配置文件 `/etc/sddm.conf`：

```ini
[Theme]
Current=lunar-glass
```

3. 重启 SDDM 或重启系统

## 配置

编辑 `theme.conf` 自定义主题：

```ini
[General]
background=background.png  # 背景图片
type=image                 # image 或 color
color=#1d1f21              # 纯色背景色
fontSize=14
fontFamily="Noto Sans"
```

## 依赖

- SDDM
- Qt 5.x
- Noto Sans CJK SC 字体（可选，用于中文显示）

## 文件结构

```
├── Main.qml           # 主界面
├── KeyButton.qml      # 虚拟键盘按键组件
├── theme.conf         # 主题配置
├── metadata.desktop   # 主题元数据
├── background.png     # 默认背景图
├── default-avatar.svg # 默认头像
└── icons/             # 图标资源
```

## 许可证

MIT License
