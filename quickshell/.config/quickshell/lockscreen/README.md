# QuickShell Lockscreen

基于 QuickShell 的锁屏组件，使用 Wayland ext-session-lock-v1 协议。

## 功能特性

- **Grace Period（假锁屏）**: 倒计时期间可通过移动鼠标/按键取消
- **真锁屏**: 需要密码或人脸识别解锁
- **壁纸背景**: 自动读取当前壁纸
- **农历日历**: 显示农历日期和节日
- **双认证模式**: 人脸识别和密码认证独立运行

## 依赖

- QuickShell (with Quickshell.Services.Pam)
- howdy (可选，用于人脸识别)
- swayidle (用于空闲检测)

## PAM 配置

本锁屏使用两个独立的 PAM 配置：

### 1. `/etc/pam.d/sudo` - 人脸识别 + 密码

```
#%PAM-1.0
auth sufficient pam_howdy.so
auth include system-auth
account include system-auth
session include system-auth
```

### 2. `/etc/pam.d/qs-lock` - 仅密码 (需手动创建)

```bash
sudo tee /etc/pam.d/qs-lock << 'EOF'
#%PAM-1.0
# Password-only authentication for lockscreen
auth       include    system-auth
account    include    system-auth
session    include    system-auth
EOF
```

**为什么需要两个配置？**

- 点击头像时使用 `sudo` 配置，启动人脸识别
- 输入密码时使用 `qs-lock` 配置，跳过人脸识别直接验证密码
- 这样可以在人脸识别过程中随时切换到密码认证，无需等待 howdy 超时

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `LOCK_GRACE_TIMEOUT` | Grace period 时长（秒） | 5 |

## 使用方法

```bash
# 直接启动锁屏
qs-lock

# 带 grace period
LOCK_GRACE_TIMEOUT=30 qs-lock
```

## Grace Period 操作

- **移动鼠标 / 左键 / 滚轮 / 任意键**: 取消锁屏
- **右键 / Super+L**: 立即进入真锁屏

## 文件结构

```
lockscreen/
├── shell.qml          # 主组件
├── lunar_info.py      # 农历信息脚本
└── README.md          # 本文件
```

## swayidle 集成

参考 `~/.config/niri/scripts/swayidle.sh`:

```bash
IDLE_TIMEOUT=45       # 空闲多久后启动锁屏
GRACE_DURATION=30     # Grace period 时长
DPMS_TIMEOUT=120      # 空闲多久后关闭显示器

LOCK_CMD="pgrep -x quickshell -a | grep -q 'lockscreen' || LOCK_GRACE_TIMEOUT=${GRACE_DURATION} qs-lock"

exec swayidle \
    timeout $IDLE_TIMEOUT  "$LOCK_CMD" \
    timeout $DPMS_TIMEOUT  'niri msg action power-off-monitors' \
        resume             'niri msg action power-on-monitors' \
    lock                   "$LOCK_CMD"
```
