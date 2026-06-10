"""QuickShell脚本使用的国际化读取工具。"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


class I18n:
    """读取与QML界面共用的功能语言包。"""

    def __init__(self, catalog: str) -> None:
        """
        初始化功能语言包。

        :param catalog: 功能语言包名称
        :return: 无
        """
        self.catalog = catalog
        self.language = self._normalize_language(self._detect_language())
        self.project_root = Path(
            os.environ.get("QS_CONFIG_ROOT", Path(__file__).resolve().parents[2])
        )
        self.current = self._load_catalog(self.language)
        self.fallback = self.current if self.language == "en_US" else self._load_catalog("en_US")

    def tr(self, key: str, variables: dict[str, Any] | None = None) -> str:
        """
        按点分隔键读取翻译文本。

        :param key: 点分隔的翻译键
        :param variables: 占位符变量
        :return: 翻译后的文本
        """
        value = self._lookup(self.current, key)
        if value is None:
            value = self._lookup(self.fallback, key)
        if not isinstance(value, str):
            return key
        return self._interpolate(value, variables)

    def literal(self, source: str, variables: dict[str, Any] | None = None) -> str:
        """
        翻译旧界面中的完整中文文本。

        :param source: 原始中文文本
        :param variables: 占位符变量
        :return: 当前语言对应的文本
        """
        value = self.current.get("literals", {}).get(source)
        if value is None:
            value = self.fallback.get("literals", {}).get(source, source)
        return self._interpolate(str(value), variables)

    def _detect_language(self) -> str:
        """
        从环境变量检测语言。

        :return: 原始语言代码
        """
        for name in ("QS_LANG", "LANG", "LC_ALL", "LC_MESSAGES"):
            value = os.environ.get(name)
            if value:
                return value
        return "en_US"

    def _normalize_language(self, language: str) -> str:
        """
        将语言代码归一化为受支持的语言。

        :param language: 原始语言代码
        :return: zh_CN或en_US
        """
        normalized = language.replace("-", "_").lower()
        return "zh_CN" if normalized.startswith("zh") else "en_US"

    def _load_catalog(self, language: str) -> dict[str, Any]:
        """
        加载指定语言的功能语言包。

        :param language: 归一化后的语言代码
        :return: 语言包对象
        """
        path = self.project_root / "locales" / language / f"{self.catalog}.json"
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return {}

    def _lookup(self, source: dict[str, Any], key: str) -> Any:
        """
        查找点分隔翻译键。

        :param source: 语言包对象
        :param key: 点分隔翻译键
        :return: 翻译值或None
        """
        current: Any = source
        for part in key.split("."):
            if not isinstance(current, dict) or part not in current:
                return None
            current = current[part]
        return current

    def _interpolate(self, text: str, variables: dict[str, Any] | None) -> str:
        """
        替换文本中的变量占位符。

        :param text: 原始翻译文本
        :param variables: 占位符变量
        :return: 替换后的文本
        """
        if not variables:
            return text
        result = text
        for name, value in variables.items():
            result = result.replace(f"{{{name}}}", str(value))
        return result
