import logging
from logging import Logger
from pathlib import Path
from typing import Optional

_LOGGER_CACHE: dict[str, Logger] = {}


def get_logger(name: str = "ai") -> Logger:
    if name in _LOGGER_CACHE:
        return _LOGGER_CACHE[name]

    logger = logging.getLogger(name)
    if not logger.handlers:
        logger.setLevel(logging.INFO)
        formatter = logging.Formatter(
            fmt="%(asctime)s | %(name)s | %(levelname)s | %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        stream = logging.StreamHandler()
        stream.setFormatter(formatter)
        logger.addHandler(stream)
    _LOGGER_CACHE[name] = logger
    return logger


def enable_file_logging(path: Path, name: str = "ai") -> None:
    logger = get_logger(name)
    file_handler_exists = any(isinstance(h, logging.FileHandler) for h in logger.handlers)
    if file_handler_exists:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    file_handler = logging.FileHandler(path, encoding="utf-8")
    file_handler.setFormatter(
        logging.Formatter(
            fmt="%(asctime)s | %(name)s | %(levelname)s | %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
    )
    logger.addHandler(file_handler)
