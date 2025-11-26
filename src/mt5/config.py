"""Configuration helpers for MT5 connectivity."""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Optional


@dataclass(slots=True)
class MT5Config:
    server: str = "FBS-Demo"
    login: int = 105_261_321
    password: Optional[str] = None
    path: Optional[str] = None
    portable: bool = False
    timeout: int = 60_000
    retries: int = 3
    retry_delay: float = 2.5  # seconds
    check_interval: float = 1.0

    @classmethod
    def from_env(cls, prefix: str = "MT5_") -> "MT5Config":
        server = os.getenv(f"{prefix}SERVER", cls.server)
        login_value = os.getenv(f"{prefix}LOGIN")
        login = int(login_value) if login_value else cls.login
        password = os.getenv(f"{prefix}PASSWORD")
        path = os.getenv(f"{prefix}PATH")
        portable = os.getenv(f"{prefix}PORTABLE", "false").lower() in {"1", "true", "yes"}
        timeout = int(os.getenv(f"{prefix}TIMEOUT", cls.timeout))
        retries = int(os.getenv(f"{prefix}RETRIES", cls.retries))
        retry_delay = float(os.getenv(f"{prefix}RETRY_DELAY", cls.retry_delay))
        check_interval = float(os.getenv(f"{prefix}CHECK_INTERVAL", cls.check_interval))

        return cls(
            server=server,
            login=login,
            password=password,
            path=path,
            portable=portable,
            timeout=timeout,
            retries=retries,
            retry_delay=retry_delay,
            check_interval=check_interval,
        )
