from __future__ import annotations

import base64
from typing import Dict
from urllib import parse, request

from ..config import SMSConfig
from ..events import AlertEvent
from .base import AlertChannel


class SMSChannel(AlertChannel):
    name = "sms"

    def __init__(self, config: SMSConfig) -> None:
        self.config = config

    def send(self, alert: AlertEvent) -> None:
        if (
            not self.config.account_sid
            or not self.config.auth_token
            or not self.config.from_number
            or not self.config.recipients
        ):
            return

        payload = {
            "Body": f"[{alert.severity.value.upper()}] {alert.message}",
            "From": self.config.from_number,
        }

        for recipient in self.config.recipients:
            self._post_message({**payload, "To": recipient})

    def _post_message(self, payload: Dict[str, str]) -> None:
        url = (
            f"{self.config.api_base_url}/Accounts/"
            f"{self.config.account_sid}/Messages.json"
        )
        data = parse.urlencode(payload).encode()
        req = request.Request(url, data=data)
        auth_header = base64.b64encode(
            f"{self.config.account_sid}:{self.config.auth_token}".encode()
        ).decode()
        req.add_header("Authorization", f"Basic {auth_header}")
        req.add_header("Content-Type", "application/x-www-form-urlencoded")
        with request.urlopen(req, timeout=10) as resp:
            if resp.status >= 400:
                raise RuntimeError(
                    f"SMS delivery failed with status {resp.status}: {resp.read()}"
                )
