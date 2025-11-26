"""State tracking structures for risk management."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Dict, Optional


@dataclass
class AccountState:
    """Snapshot of the trading account at a point in time."""

    balance: float
    equity: float
    currency: str = "USD"
    leverage: float = 1.0
    timestamp: datetime = field(default_factory=datetime.utcnow)


@dataclass
class TradeIntent:
    """Represents a trade request before risk validation."""

    symbol: str
    direction: str  # "long" or "short"
    entry_price: float
    volatility: Optional[float] = None  # e.g. ATR in price units
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    pip_value: float = 1.0
    asset_class: str = "fx"
    correlation_bucket: Optional[str] = None


@dataclass
class TradePlan:
    """Result of the risk engine: executable trade info."""

    symbol: str
    direction: str
    volume_lots: float
    entry_price: float
    stop_loss: float
    take_profit: float
    risk_amount: float
    risk_fraction: float
    reward_amount: float
    notional: float


@dataclass
class RiskState:
    """Mutable risk state updated as the bot trades."""

    peak_equity: float = 0.0
    trough_equity: float = 0.0
    current_drawdown: float = 0.0
    max_recorded_drawdown: float = 0.0
    daily_loss: float = 0.0
    daily_start_equity: float = 0.0
    daily_session: date = field(default_factory=date.today)
    cooldown_until: Optional[datetime] = None
    open_exposure: Dict[str, float] = field(default_factory=dict)
    asset_exposure: Dict[str, float] = field(default_factory=dict)
    bucket_exposure: Dict[str, float] = field(default_factory=dict)

    def update_equity(self, equity: float, timestamp: Optional[datetime] = None) -> None:
        """Update drawdown statistics from the latest equity reading."""

        if self.peak_equity == 0:
            self.peak_equity = equity
            self.trough_equity = equity
            self.daily_start_equity = equity

        if equity > self.peak_equity:
            self.peak_equity = equity
        if equity < self.trough_equity:
            self.trough_equity = equity

        drawdown = 0.0
        if self.peak_equity > 0:
            drawdown = (self.peak_equity - equity) / self.peak_equity
        self.current_drawdown = max(drawdown, 0.0)
        self.max_recorded_drawdown = max(self.max_recorded_drawdown, self.current_drawdown)

        if timestamp:
            self._reset_daily_if_needed(timestamp.date(), equity)

    def register_pnl(self, pnl: float, timestamp: datetime) -> None:
        """Track realized PnL for daily loss controls."""

        self._reset_daily_if_needed(timestamp.date(), equity=None)
        self.daily_loss += -pnl if pnl < 0 else 0.0

    def _reset_daily_if_needed(self, session: date, equity: Optional[float]) -> None:
        if session != self.daily_session:
            self.daily_session = session
            self.daily_loss = 0.0
            if equity is not None:
                self.daily_start_equity = equity

    def apply_cooldown(self, minutes: int) -> None:
        self.cooldown_until = datetime.utcnow() + timedelta(minutes=minutes)

    def in_cooldown(self) -> bool:
        if self.cooldown_until is None:
            return False
        if datetime.utcnow() >= self.cooldown_until:
            self.cooldown_until = None
            return False
        return True

    def adjust_exposure(
        self,
        symbol: str,
        delta_notional: float,
        bucket: Optional[str],
        asset_class: Optional[str] = None,
    ) -> None:
        """Update notional exposure per symbol and bucket."""

        self.open_exposure[symbol] = self.open_exposure.get(symbol, 0.0) + delta_notional
        if abs(self.open_exposure[symbol]) <= 1e-8:
            self.open_exposure.pop(symbol, None)

        if asset_class:
            self.asset_exposure[asset_class] = self.asset_exposure.get(asset_class, 0.0) + delta_notional
            if abs(self.asset_exposure[asset_class]) <= 1e-8:
                self.asset_exposure.pop(asset_class, None)

        if bucket:
            self.bucket_exposure[bucket] = self.bucket_exposure.get(bucket, 0.0) + delta_notional
            if abs(self.bucket_exposure[bucket]) <= 1e-8:
                self.bucket_exposure.pop(bucket, None)
