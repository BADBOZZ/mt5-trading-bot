from __future__ import annotations

import smtplib
from email.message import EmailMessage

from ..config import EmailConfig
from ..events import AlertEvent
from .base import AlertChannel, HealthcheckCapable


class EmailChannel(AlertChannel, HealthcheckCapable):
    name = "email"

    def __init__(self, config: EmailConfig) -> None:
        self.config = config

    def _build_message(self, alert: AlertEvent) -> EmailMessage:
        msg = EmailMessage()
        msg["Subject"] = f"[{alert.severity.value.upper()}] {alert.code}"
        msg["From"] = self.config.sender
        msg["To"] = ", ".join(self.config.recipients)

        context_lines = "\n".join(
            f"- {key}: {value}" for key, value in alert.context.items()
        )
        msg.set_content(
            f"{alert.message}\n\nSeverity: {alert.severity.value}\n"
            f"Timestamp: {alert.timestamp.isoformat()}\n"
            f"{context_lines}"
        )
        return msg

    def send(self, alert: AlertEvent) -> None:
        if not self.config.recipients or not self.config.smtp_host:
            return
        message = self._build_message(alert)
        with smtplib.SMTP(self.config.smtp_host, self.config.smtp_port, timeout=10) as smtp:
            if self.config.use_tls:
                smtp.starttls()
            if self.config.username and self.config.password:
                smtp.login(self.config.username, self.config.password)
            smtp.send_message(message)

    def healthcheck(self) -> bool:
        if not self.config.smtp_host:
            return False
        try:
            with smtplib.SMTP(self.config.smtp_host, self.config.smtp_port, timeout=5) as smtp:
                if self.config.use_tls:
                    smtp.starttls()
                if self.config.username and self.config.password:
                    smtp.login(self.config.username, self.config.password)
            return True
        except Exception:
            return False
