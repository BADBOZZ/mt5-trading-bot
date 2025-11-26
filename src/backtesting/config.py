from __future__ import annotations

from dataclasses import dataclass


@dataclass(slots=True)
class BacktestConfig:
    """
    Reusable configuration describing how a strategy should be evaluated.
    """

    symbol: str = "EURUSD"
    initial_capital: float = 10000.0
    lot_size: float = 0.1
    contract_size: float = 100000.0
    leverage: float = 1.0
    commission_per_lot: float = 7.0  # round-turn USD
    slippage: float = 0.0001  # price adjustment applied on trade entry/exit
    risk_free_rate: float = 0.01
    max_position: float = 5.0  # lots
    allow_short: bool = True

    def validate(self) -> None:
        if self.initial_capital <= 0:
            raise ValueError("Initial capital must be positive.")
        if self.lot_size <= 0:
            raise ValueError("Lot size must be positive.")
        if self.contract_size <= 0:
            raise ValueError("Contract size must be positive.")
        if self.max_position <= 0:
            raise ValueError("Max position must be positive.")
