from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional

import numpy as np
import pandas as pd

from .config import BacktestConfig
from .metrics import PerformanceReport, compute_performance_report


@dataclass
class Trade:
    entry_time: pd.Timestamp
    exit_time: Optional[pd.Timestamp]
    entry_price: float
    exit_price: Optional[float]
    direction: int
    size: float  # lots
    pnl: float = 0.0
    return_pct: float = 0.0
    bars_held: int = 0
    commission: float = 0.0


@dataclass
class BacktestResult:
    strategy_name: str
    config: BacktestConfig
    equity_curve: pd.Series
    positions: pd.Series
    trades: List[Trade]
    performance: PerformanceReport


class BacktestEngine:
    def __init__(self, config: BacktestConfig) -> None:
        self.config = config

    def run(self, data: pd.DataFrame, strategy) -> BacktestResult:
        self.config.validate()
        self._assert_data(data)

        strategy.reset()
        raw_signals = strategy.generate_signals(data)
        signals = raw_signals.reindex(data.index).ffill().fillna(0.0)
        signals = signals.clip(-1.0, 1.0)

        cash = self.config.initial_capital
        position = 0.0
        positions_series = []
        equity_values = []
        trades: List[Trade] = []
        open_trade: Optional[Trade] = None
        bars_open = 0
        exposure_bars = 0

        for timestamp, row in data.iterrows():
            price = float(row["close"])
            target_direction = int(np.sign(signals.loc[timestamp]))
            target_size = abs(signals.loc[timestamp]) * self.config.max_position

            if position != 0:
                exposure_bars += 1

            # Close position if needed
            if position != 0 and (target_direction == 0 or np.sign(position) != target_direction):
                cash, open_trade = self._close_position(
                    timestamp, price, position, cash, open_trade, trades
                )
                position = 0.0

            # Adjust position size (scaling in/out)
            desired_position = target_direction * target_size
            if desired_position != position:
                position, cash, open_trade = self._open_or_scale_position(
                    timestamp, price, position, desired_position, cash, open_trade
                )

            bars_open = bars_open + 1 if position != 0 else 0

            unrealized = 0.0
            if open_trade and position != 0:
                unrealized = (
                    (price - open_trade.entry_price)
                    * open_trade.direction
                    * self.config.contract_size
                    * abs(position)
                )
                open_trade.bars_held = bars_open

            equity_values.append(cash + unrealized)
            positions_series.append(position)

        # Ensure final position closed
        if position != 0 and open_trade:
            cash, open_trade = self._close_position(
                data.index[-1], data["close"].iloc[-1], position, cash, open_trade, trades
            )
            equity_values[-1] = cash
            positions_series[-1] = 0.0

        equity_curve = pd.Series(equity_values, index=data.index, name="equity")
        positions_series = pd.Series(positions_series, index=data.index, name="position")

        exposure = exposure_bars / max(len(data), 1)
        performance = compute_performance_report(
            equity_curve, trades, risk_free_rate=self.config.risk_free_rate, exposure=exposure
        )

        return BacktestResult(
            strategy_name=strategy.name,
            config=self.config,
            equity_curve=equity_curve,
            positions=positions_series,
            trades=trades,
            performance=performance,
        )

    # ------------------------------------------------------------------ #
    def _close_position(
        self,
        timestamp: pd.Timestamp,
        price: float,
        position: float,
        cash: float,
        open_trade: Optional[Trade],
        trades: List[Trade],
    ) -> tuple[float, Optional[Trade]]:
        direction = int(np.sign(position))
        exec_price = price - self.config.slippage * direction
        trade_value = position * self.config.contract_size * exec_price
        cash += trade_value

        commission = abs(position) * self.config.commission_per_lot
        cash -= commission

        if open_trade:
            pnl = (
                (exec_price - open_trade.entry_price)
                * open_trade.direction
                * self.config.contract_size
                * abs(position)
            )
            pnl -= open_trade.commission + commission
            open_trade.exit_time = timestamp
            open_trade.exit_price = exec_price
            open_trade.pnl = pnl
            open_trade.return_pct = pnl / (self.config.initial_capital or 1.0)
            open_trade.commission += commission
            trades.append(open_trade)

        return cash, None

    def _open_or_scale_position(
        self,
        timestamp: pd.Timestamp,
        price: float,
        current_position: float,
        desired_position: float,
        cash: float,
        open_trade: Optional[Trade],
    ) -> tuple[float, float, Optional[Trade]]:
        delta = desired_position - current_position
        if delta == 0:
            return current_position, cash, open_trade

        direction = int(np.sign(delta))
        exec_price = price + self.config.slippage * direction
        trade_value = delta * self.config.contract_size * exec_price
        cash -= trade_value

        commission = abs(delta) * self.config.commission_per_lot
        cash -= commission

        if open_trade is None or np.sign(desired_position) != np.sign(current_position):
            open_trade = Trade(
                entry_time=timestamp,
                exit_time=None,
                entry_price=exec_price,
                exit_price=None,
                direction=int(np.sign(desired_position)) if desired_position != 0 else direction,
                size=abs(desired_position),
                commission=commission,
            )
        else:
            open_trade.size = abs(desired_position)
            open_trade.commission += commission

        return desired_position, cash, open_trade

    def _assert_data(self, data: pd.DataFrame) -> None:
        if "close" not in data.columns:
            raise ValueError("Data must contain a 'close' column for pricing.")
        if not isinstance(data.index, pd.DatetimeIndex):
            raise ValueError("Data index must be a DatetimeIndex.")
