import json
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any, Dict, Optional

from .config import LogConfig


class JsonFormatter(logging.Formatter):
    """Simple JSON formatter for log records."""

    def format(self, record: logging.LogRecord) -> str:
        log_record: Dict[str, Any] = {
            "level": record.levelname,
            "name": record.name,
            "message": record.getMessage(),
            "time": self.formatTime(record, self.datefmt),
        }

        if record.exc_info:
            log_record["exc_info"] = self.formatException(record.exc_info)
        if record.stack_info:
            log_record["stack"] = self.formatStack(record.stack_info)

        for key, value in record.__dict__.items():
            if key.startswith("_") or key in log_record:
                continue
            if isinstance(value, (str, int, float, bool, dict, list)) or value is None:
                log_record[key] = value

        return json.dumps(log_record, default=str)


def _ensure_handler(logger: logging.Logger, handler: logging.Handler) -> None:
    logger.addHandler(handler)
    logger.propagate = False


def build_logger(
    name: str,
    log_config: LogConfig,
    extra_fields: Optional[Dict[str, Any]] = None,
) -> logging.Logger:
    """Build a logger configured according to the supplied LogConfig."""

    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, log_config.level.upper(), logging.INFO))

    if logger.handlers:
        return logger

    formatter: logging.Formatter
    if log_config.json_logs:
        formatter = JsonFormatter()
    else:
        formatter = logging.Formatter(
            fmt="%(asctime)s %(levelname)s [%(name)s] %(message)s"
        )

    log_path = Path(log_config.directory)
    log_path.mkdir(parents=True, exist_ok=True)
    file_handler = RotatingFileHandler(
        log_path / f"{name}.log",
        maxBytes=log_config.max_bytes,
        backupCount=log_config.backup_count,
    )
    file_handler.setFormatter(formatter)
    _ensure_handler(logger, file_handler)

    if log_config.stdout:
        stream_handler = logging.StreamHandler()
        stream_handler.setFormatter(formatter)
        _ensure_handler(logger, stream_handler)

    if extra_fields:
        logger = logging.LoggerAdapter(logger, extra_fields)  # type: ignore[assignment]

    return logger
