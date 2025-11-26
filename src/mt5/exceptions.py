"""Custom exception hierarchy for MT5 integration."""

from dataclasses import dataclass
from typing import Optional, Tuple


class MT5Error(Exception):
    """Base class for MT5-related exceptions."""


class MT5DependencyError(MT5Error):
    """Raised when the MetaTrader5 package is missing."""


@dataclass(slots=True)
class MT5ErrorDetail:
    code: int
    message: str

    def __str__(self) -> str:
        return f"[{self.code}] {self.message}"


class MT5ConnectionError(MT5Error):
    def __init__(self, detail: Optional[MT5ErrorDetail] = None, *, reason: Optional[str] = None):
        message = reason or "MetaTrader5 connection error"
        if detail:
            message = f"{message}: {detail}"
        super().__init__(message)
        self.detail = detail


class MT5AccountError(MT5Error):
    pass


class MT5OrderError(MT5Error):
    def __init__(self, detail: Optional[MT5ErrorDetail] = None, *, reason: Optional[str] = None):
        message = reason or "MetaTrader5 order error"
        if detail:
            message = f"{message}: {detail}"
        super().__init__(message)
        self.detail = detail


class MT5MarketDataError(MT5Error):
    pass


def build_error_detail(raw_error: Optional[Tuple[int, str]]) -> Optional[MT5ErrorDetail]:
    if not raw_error:
        return None
    code, message = raw_error
    return MT5ErrorDetail(code=code, message=message)
