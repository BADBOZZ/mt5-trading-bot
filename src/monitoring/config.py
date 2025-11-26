import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional


@dataclass
class LogConfig:
    """Configuration for structured logging outputs."""

    directory: Path = Path("logs")
    level: str = "INFO"
    max_bytes: int = 5 * 1024 * 1024
    backup_count: int = 5
    json_logs: bool = True
    stdout: bool = True


@dataclass
class AlertThresholds:
    """Thresholds that determine when alerts should be dispatched."""

    max_slippage_pips: float = 1.5
    max_drawdown_pct: float = 5.0
    max_consecutive_losses: int = 3
    max_latency_ms: float = 500.0
    heartbeat_seconds: int = 45
    min_balance: float = 100.0
    max_order_rejections: int = 1


@dataclass
class EmailConfig:
    smtp_host: str = ""
    smtp_port: int = 587
    username: str = ""
    password: str = ""
    use_tls: bool = True
    sender: str = ""
    recipients: List[str] = field(default_factory=list)


@dataclass
class SMSConfig:
    account_sid: str = ""
    auth_token: str = ""
    from_number: str = ""
    recipients: List[str] = field(default_factory=list)
    api_base_url: str = "https://api.twilio.com/2010-04-01"


@dataclass
class TelegramConfig:
    bot_token: str = ""
    chat_ids: List[str] = field(default_factory=list)


@dataclass
class NotificationConfig:
    """Container for all outbound alert channel configurations."""

    email: EmailConfig = field(default_factory=EmailConfig)
    sms: SMSConfig = field(default_factory=SMSConfig)
    telegram: TelegramConfig = field(default_factory=TelegramConfig)


@dataclass
class MonitoringConfig:
    """Top-level configuration consumed by the monitoring stack."""

    environment: str = "development"
    log: LogConfig = field(default_factory=LogConfig)
    thresholds: AlertThresholds = field(default_factory=AlertThresholds)
    notifications: NotificationConfig = field(default_factory=NotificationConfig)
    metadata: Dict[str, str] = field(default_factory=dict)
    dashboard_host: str = "0.0.0.0"
    dashboard_port: int = 8060

    @classmethod
    def from_env(cls, overrides: Optional[Dict[str, str]] = None) -> "MonitoringConfig":
        """Build a configuration object from environment variables."""

        overrides = overrides or {}
        env = os.environ

        def getenv(key: str, default: str = "") -> str:
            return overrides.get(key, env.get(key, default))

        log_dir = Path(getenv("MONITORING_LOG_DIR", "logs")).expanduser()
        log_level = getenv("MONITORING_LOG_LEVEL", "INFO")
        log_json = getenv("MONITORING_LOG_JSON", "1") in ("1", "true", "TRUE")

        email_recipients = [
            r.strip()
            for r in getenv("ALERT_EMAIL_RECIPIENTS", "").split(",")
            if r.strip()
        ]
        sms_recipients = [
            r.strip() for r in getenv("ALERT_SMS_RECIPIENTS", "").split(",") if r.strip()
        ]
        telegram_chats = [
            r.strip()
            for r in getenv("ALERT_TELEGRAM_CHAT_IDS", "").split(",")
            if r.strip()
        ]

        config = cls(
            environment=getenv("APP_ENV", "development"),
            log=LogConfig(
                directory=log_dir,
                level=log_level,
                json_logs=log_json,
                stdout=getenv("MONITORING_LOG_STDOUT", "1") in ("1", "true", "TRUE"),
            ),
            thresholds=AlertThresholds(
                max_slippage_pips=float(getenv("MAX_SLIPPAGE_PIPS", "1.5")),
                max_drawdown_pct=float(getenv("MAX_DRAWDOWN_PCT", "5")),
                max_consecutive_losses=int(getenv("MAX_CONSECUTIVE_LOSSES", "3")),
                max_latency_ms=float(getenv("MAX_LATENCY_MS", "500")),
                heartbeat_seconds=int(getenv("HEARTBEAT_SECONDS", "45")),
                min_balance=float(getenv("MIN_BALANCE", "100")),
                max_order_rejections=int(getenv("MAX_ORDER_REJECTIONS", "1")),
            ),
            notifications=NotificationConfig(
                email=EmailConfig(
                    smtp_host=getenv("SMTP_HOST", ""),
                    smtp_port=int(getenv("SMTP_PORT", "587")),
                    username=getenv("SMTP_USERNAME", ""),
                    password=getenv("SMTP_PASSWORD", ""),
                    use_tls=getenv("SMTP_USE_TLS", "1") in ("1", "true", "TRUE"),
                    sender=getenv("SMTP_SENDER", "bot-monitor@example.com"),
                    recipients=email_recipients,
                ),
                sms=SMSConfig(
                    account_sid=getenv("TWILIO_ACCOUNT_SID", ""),
                    auth_token=getenv("TWILIO_AUTH_TOKEN", ""),
                    from_number=getenv("TWILIO_FROM_NUMBER", ""),
                    recipients=sms_recipients,
                    api_base_url=getenv(
                        "TWILIO_API_BASE_URL", "https://api.twilio.com/2010-04-01"
                    ),
                ),
                telegram=TelegramConfig(
                    bot_token=getenv("TELEGRAM_BOT_TOKEN", ""),
                    chat_ids=telegram_chats,
                ),
            ),
            metadata={
                "desk": getenv("MONITORING_DESK", "global"),
                "bot": getenv("BOT_NAME", "mt5-multi-target"),
            },
            dashboard_host=getenv("MONITORING_DASHBOARD_HOST", "0.0.0.0"),
            dashboard_port=int(getenv("MONITORING_DASHBOARD_PORT", "8060")),
        )

        config.log.directory.mkdir(parents=True, exist_ok=True)
        return config
