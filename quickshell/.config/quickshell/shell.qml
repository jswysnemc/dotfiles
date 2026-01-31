import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root
    
    // 通过环境变量或IPC控制显示哪个组件
    // 启动WiFi: quickshell -c ~/.config/quickshell -e POPUP_TYPE=wifi
    // 启动蓝牙: quickshell -c ~/.config/quickshell -e POPUP_TYPE=bluetooth
    // 启动日历: quickshell -c ~/.config/quickshell -e POPUP_TYPE=calendar
    // 启动通知: quickshell -c ~/.config/quickshell -e POPUP_TYPE=notification
    // 启动媒体: quickshell -c ~/.config/quickshell -e POPUP_TYPE=media
    // 启动控制中心: quickshell -c ~/.config/quickshell -e POPUP_TYPE=control
    // 启动天气: quickshell -c ~/.config/quickshell -e POPUP_TYPE=weather
    
    property string popupType: Quickshell.env("POPUP_TYPE") || "wifi"
    
    Loader {
        active: root.popupType === "wifi"
        source: "WifiPopup.qml"
    }
    
    Loader {
        active: root.popupType === "bluetooth"
        source: "BluetoothPopup.qml"
    }
    
    Loader {
        active: root.popupType === "calendar"
        source: "CalendarPopup.qml"
    }
    
    Loader {
        active: root.popupType === "notification"
        source: "NotificationPopup.qml"
    }
    
    Loader {
        active: root.popupType === "control"
        source: "ControlCenterPopup.qml"
    }
    
    Loader {
        active: root.popupType === "weather"
        source: "WeatherPopup.qml"
    }
    
    Loader {
        active: root.popupType === "visual"
        source: "VisualModelPopup.qml"
    }
    
    Loader {
        active: root.popupType === "media"
        source: "MediaPopup.qml"
    }

    Loader {
        active: root.popupType === "todo"
        source: "todo/shell.qml"
    }

    Loader {
        active: root.popupType === "welcome"
        source: "welcome/shell.qml"
    }
}
