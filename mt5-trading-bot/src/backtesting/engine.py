"""Pure Python execution harness mimicking the MT5 Strategy Tester."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List, Optional

import pandas as pd

from ..core.engine import StrategyEngine
from ..core.types import SignalType, StrategyRecommendation
from ..risk.config import RiskConfig
from ..risk.risk_engine import RiskEngine
from ..risk.state import AccountState, PositionState
from .config import BacktestSettings
from .metrics import (
    PerformanceReport,
    TradeResult,
    build_equity_curve,
    summarize_performance,
)

STANDARD_CONTRACT_SIZE = 100_000


@dataclass(slots=True)
class SimulatedPosition:
    """Internal representation of an open trade."""

    symbol: str
    direction: SignalType
    entry_time: pd.Timestamp
    entry_price: float
    volume: float
    stop_loss: float
    take_profit: float
    strategy: str
    risk_position: Optional[PositionState] = None
    bars_held: int = 0
    mae: float = 0.0
    mfe: float = 0.0

    def update_extremes(self, high: float, low: float) -> None:
        """Track MAE/MFE using the current bar extremes."""
        if self.direction == SignalType.BUY:
            self.mfe = max(self.mfe, high - self.entry_price)
            self.mae = min(self.mae, low - self.entry_price)
        else:
            self.mfe = max(self.mfe, self.entry_price - low)
            self.mae = min(self.mae, self.entry_price - high)

    def mark_to_market(self, price: float) -> float:
        """Return unrealised PnL."""
        if self.direction == SignalType.BUY:
            return (price - self.entry_price) * self.volume
        return (self.entry_price - price) * self.volume


@dataclass(slots=True)
class BacktestResult:
    """Output of a Strategy Tester run."""

    trades: List[TradeResult]
    performance: PerformanceReport
    equity_curve: pd.Series


class StrategyTesterEngine:
    """Replay OHLC data through the Python strategies and risk stack."""

    def __init__(
        self,
        strategy_engine: StrategyEngine,
        risk_engine: RiskEngine | None = None,
        settings: Optional[BacktestSettings] = None,
    ):
        self.strategy_engine = strategy_engine
        self.risk_engine = risk_engine or RiskEngine(RiskConfig())
        self.settings = settings or BacktestSettings()
        self.open_positions: List[SimulatedPosition] = []
        self.trade_log: List[TradeResult] = []
        self.balance = self.settings.initial_deposit

    # --------------------------------------------------------------------- util
    @staticmethod
    def _point_value(price: float) -> float:
        if price < 2:
            return 0.00001
        if price < 20:
            return 0.0001
        if price < 200:
            return 0.001
        if price < 2000:
            return 0.01
        return 0.1

    def _apply_costs(self, price: float, signal: SignalType) -> float:
        """Apply spread + slippage to an entry price."""
        point = self._point_value(price)
        spread = self.settings.spread_points * point
        slippage = self.settings.slippage_points * point
        adjustment = spread + slippage
        if signal == SignalType.BUY:
            return price + adjustment
        if signal == SignalType.SELL:
            return price - adjustment
        return price

    def _derive_levels(self, recommendation: StrategyRecommendation, entry_price: float) -> tuple[float, float]:
        """Fallback stop-loss / take-profit when strategies omit them."""
        if recommendation.stop_loss is not None:
            stop = recommendation.stop_loss
        else:
            default_distance = entry_price * 0.002
            stop = entry_price - default_distance if recommendation.signal == SignalType.BUY else entry_price + default_distance

        if recommendation.take_profit is not None:
            target = recommendation.take_profit
        else:
            distance = abs(entry_price - stop)
            target = (
                entry_price + distance * self.settings.reward_risk_ratio
                if recommendation.signal == SignalType.BUY
                else entry_price - distance * self.settings.reward_risk_ratio
            )
        return stop, target

    def _update_account(self, timestamp: pd.Timestamp, equity: float) -> None:
        """Update risk-engine account snapshot."""
        account_state = AccountState(
            balance=self.balance,
            equity=equity,
            margin=0.0,
            free_margin=equity,
            margin_level=0.0,
            timestamp=timestamp.to_pydatetime(),
        )
        self.risk_engine.update_account_state(account_state)

    # ------------------------------------------------------------------ runtime
    def run(self, market_frames: Dict[str, pd.DataFrame]) -> BacktestResult:
        """Run the backtest and return metrics."""
        if not market_frames:
            raise ValueError("No market data provided")

        lengths = {len(frame) for frame in market_frames.values()}
        if len(lengths) != 1:
            raise ValueError("All market frames must be synchronised to the same length.")

        timeline = next(iter(market_frames.values())).index
        history = {symbol: frame.reset_index().to_dict("records") for symbol, frame in market_frames.items()}

        equity_points: List[tuple[datetime, float]] = []

        for idx, timestamp in enumerate(timeline):
            current_bars = {symbol: history[symbol][idx] for symbol in history.keys()}
            self._process_open_positions(timestamp, current_bars)
            unrealised = self._mark_positions(current_bars)
            equity = self.balance + unrealised
            self._update_account(timestamp, equity)

            market_snapshot = {
                symbol: records[: idx + 1] for symbol, records in history.items()
            }
            self.strategy_engine.update_market_data(market_snapshot)
            recommendations = self.strategy_engine.get_recommendations(market_snapshot)
            self._execute_recommendations(recommendations, current_bars, timestamp)

            # Equity is sampled after trade decisions for this bar
            equity_points.append((timestamp.to_pydatetime(), equity))

        if self.open_positions:
            final_bars = {symbol: history[symbol][-1] for symbol in history.keys()}
            timestamp = timeline[-1]
            self._liquidate_all(timestamp, final_bars)
            equity_points.append((timestamp.to_pydatetime(), self.balance))

        equity_curve = build_equity_curve(equity_points)
        performance = summarize_performance(self.trade_log, equity_curve, self.settings.risk_free_rate)
        return BacktestResult(trades=self.trade_log, performance=performance, equity_curve=equity_curve)

    # -------------------------------------------------------------- trade logic
    def _process_open_positions(self, timestamp: pd.Timestamp, bars: Dict[str, dict]) -> None:
        """Check whether positions reach targets/stops on the current bar."""
        for position in list(self.open_positions):
            bar = bars[position.symbol]
            position.update_extremes(bar["high"], bar["low"])
            exit_price = None
            exit_reason = ""

            if position.direction == SignalType.BUY:
                if bar["low"] <= position.stop_loss:
                    exit_price = position.stop_loss
                    exit_reason = "stop"
                elif bar["high"] >= position.take_profit:
                    exit_price = position.take_profit
                    exit_reason = "target"
            else:
                if bar["high"] >= position.stop_loss:
                    exit_price = position.stop_loss
                    exit_reason = "stop"
                elif bar["low"] <= position.take_profit:
                    exit_price = position.take_profit
                    exit_reason = "target"

            position.bars_held += 1
            if exit_price is None and position.bars_held >= self.settings.max_holding_bars:
                exit_price = bar["close"]
                exit_reason = "timeout"

            if exit_price is not None:
                pnl = self._close_position(position, exit_price, timestamp, exit_reason)
                self.balance += pnl
                self.open_positions.remove(position)

    def _mark_positions(self, bars: Dict[str, dict]) -> float:
        """Return aggregate unrealised PnL."""
        unrealised = 0.0
        for position in self.open_positions:
            market_price = bars[position.symbol]["close"]
            unrealised += position.mark_to_market(market_price)
            if position.risk_position:
                position.risk_position.current_price = market_price
                position.risk_position.profit = position.mark_to_market(market_price)
        return unrealised

    def _execute_recommendations(
        self,
        recommendations: List[StrategyRecommendation],
        bars: Dict[str, dict],
        timestamp: pd.Timestamp,
    ) -> None:
        for recommendation in recommendations:
            if recommendation.signal == SignalType.HOLD:
                continue
            if recommendation.symbol not in bars:
                continue
            if self._has_open_position(recommendation.symbol, recommendation.signal):
                continue
            if not self.risk_engine.validate_trade(recommendation):
                continue

            position_size = self.risk_engine.calculate_position_size(recommendation)
            if position_size <= 0:
                continue

            entry_price = bars[recommendation.symbol]["close"]
            entry_price = self._apply_costs(entry_price, recommendation.signal)
            stop_loss, take_profit = self._derive_levels(recommendation, entry_price)

            position = SimulatedPosition(
                symbol=recommendation.symbol,
                direction=recommendation.signal,
                entry_time=timestamp,
                entry_price=entry_price,
                volume=position_size,
                stop_loss=stop_loss,
                take_profit=take_profit,
                strategy=getattr(recommendation, "strategy", "unknown"),
            )

            risk_position = PositionState(
                symbol=position.symbol,
                volume=position.volume,
                entry_price=position.entry_price,
                current_price=position.entry_price,
                profit=0.0,
            )
            self.risk_engine.risk_state.add_position(risk_position)
            position.risk_position = risk_position

            self.open_positions.append(position)

    def _has_open_position(self, symbol: str, direction: SignalType) -> bool:
        for position in self.open_positions:
            if position.symbol == symbol and position.direction == direction:
                return True
        return False

    def _close_position(
        self,
        position: SimulatedPosition,
        exit_price: float,
        timestamp: pd.Timestamp,
        reason: str,
    ) -> float:
        gross = position.mark_to_market(exit_price)
        commission = self.settings.commission_per_lot * (position.volume / STANDARD_CONTRACT_SIZE)
        pnl = gross - commission

        trade = TradeResult(
            symbol=position.symbol,
            direction=position.direction.value,
            entry_time=position.entry_time.to_pydatetime(),
            exit_time=timestamp.to_pydatetime(),
            entry_price=position.entry_price,
            exit_price=exit_price,
            volume=position.volume,
            pnl=pnl,
            fees=commission,
            mae=position.mae,
            mfe=position.mfe,
            strategy=position.strategy,
            exit_reason=reason,
        )
        self.trade_log.append(trade)
        if position.risk_position and position.risk_position in self.risk_engine.risk_state.positions:
            self.risk_engine.risk_state.positions.remove(position.risk_position)
        self.risk_engine.risk_state.daily_pnl += pnl
        if pnl < 0:
            self.risk_engine.limits.trigger_cooldown()
        return pnl

    def _liquidate_all(self, timestamp: pd.Timestamp, bars: Dict[str, dict]) -> None:
        for position in list(self.open_positions):
            exit_price = bars[position.symbol]["close"]
            pnl = self._close_position(position, exit_price, timestamp, "close")
            self.balance += pnl
        self.open_positions.clear()
