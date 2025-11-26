from __future__ import annotations

from typing import Dict
from urllib import parse, request

from ..config import TelegramConfig
from ..events import AlertEvent
from .base import AlertChannel


class TelegramChannel(AlertChannel):
    name = "telegram"
    api_base = "https://api.telegram.org"

    def __init__(self, config: TelegramConfig) -> None:
        self.config = config

    def send(self, alert: AlertEvent) -> None:
        if not self.config.bot_token or not self.config.chat_ids:
            return
        payload = {
            "text": self._format_message(alert),
            "parse_mode": "Markdown",
        }
        for chat_id in self.config.chat_ids:
            self._post_message({**payload, "chat_id": chat_id})

    def _post_message(self, payload: Dict[str, str]) -> None:
        url = f"{self.api_base}/bot{self.config.bot_token}/sendMessage"
        data = parse.urlencode(payload).encode()
        req = request.Request(url, data=data)
        with request.urlopen(req, timeout=10) as resp:
            if resp.status >= 400:
                raise RuntimeError(
                    f"Telegram delivery failed with status {resp.status}: {resp.read()}"
                )

    @staticmethod
    def _format_message(alert: AlertEvent) -> str:
        context = "\n".join(f"- *{k}*: `{v}`" for k, v in alert.context.items())
        return (
            f"*{alert.severity.value.upper()}* — `{alert.code}`\n"
            f"{alert.message}\n"
            f"{context}"
        )
