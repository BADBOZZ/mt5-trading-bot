"""Configuration helpers for MT5 Strategy Tester backtests."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Dict, Iterable, List, Optional

DATE_FMT = "%Y.%m.%d"


@dataclass(slots=True)
class OptimizationInputRange:
    """Describes an MT5 input parameter range used by the Strategy Tester."""

    name: str
    start: float
    step: float
    stop: float
    enabled: bool = True

    def as_ini_line(self) -> str:
        """Return a pseudo-INI line the runner can consume."""
        flag = 1 if self.enabled else 0
        return f"OptInput.{self.name}={self.start},{self.step},{self.stop},{flag}"


@dataclass(slots=True)
class WalkForwardWindow:
    """Represents a single walk-forward optimization slice."""

    train_start: datetime
    train_end: datetime
    test_start: datetime
    test_end: datetime

    def to_dict(self) -> Dict[str, str]:
        return {
            "train_start": self.train_start.strftime(DATE_FMT),
            "train_end": self.train_end.strftime(DATE_FMT),
            "test_start": self.test_start.strftime(DATE_FMT),
            "test_end": self.test_end.strftime(DATE_FMT),
        }


@dataclass(slots=True)
class SymbolConfig:
    """Per-symbol configuration for multi-currency optimization."""

    name: str
    timeframe: str = "H1"
    spread: int = 10
    slippage: int = 5
    leverage: int = 100
    start: Optional[datetime] = None
    end: Optional[datetime] = None
    initial_deposit: float = 10_000.0
    currency: str = "USD"

    def resolve_start(self, fallback: datetime) -> datetime:
        return self.start or fallback

    def resolve_end(self, fallback: datetime) -> datetime:
        return self.end or fallback


@dataclass
class StrategyTesterConfig:
    """High level configuration that maps directly to Strategy Tester fields."""

    expert_path: Path
    terminal_path: Path
    reports_dir: Path
    start: datetime
    end: datetime
    symbols: List[SymbolConfig] = field(default_factory=list)
    tick_mode: str = "Every tick"
    execution_mode: str = "Normal"
    optimization: bool = True
    optimization_goal: str = "Custom max"
    walk_forward_windows: List[WalkForwardWindow] = field(default_factory=list)
    optimization_inputs: Dict[str, OptimizationInputRange] = field(default_factory=dict)
    custom_inputs: Dict[str, float] = field(default_factory=dict)
    result_format: str = "xml"
    forward_mode: int = 4

    def __post_init__(self) -> None:
        if not self.symbols:
            self.symbols.append(SymbolConfig(name="EURUSD"))
        self.reports_dir.mkdir(parents=True, exist_ok=True)

    @property
    def primary_symbol(self) -> SymbolConfig:
        return self.symbols[0]

    def iter_symbols(self) -> Iterable[SymbolConfig]:
        return list(self.symbols)

    def build_ini_block(
        self,
        symbol: SymbolConfig,
        input_overrides: Optional[Dict[str, float]] = None,
    ) -> str:
        """Create an INI-style payload understood by MetaTrader's tester."""

        start = symbol.resolve_start(self.start).strftime(DATE_FMT)
        end = symbol.resolve_end(self.end).strftime(DATE_FMT)
        report_file = self.reports_dir / f"{symbol.name}_{self.result_format}"
        tester_lines = [
            "[Tester]",
            f"Expert={self.expert_path}",
            f"Symbol={symbol.name}",
            f"Period={symbol.timeframe}",
            f"FromDate={start}",
            f"ToDate={end}",
            f"Deposit={symbol.initial_deposit}",
            f"Currency={symbol.currency}",
            f"Leverage={symbol.leverage}",
            f"Spread={symbol.spread}",
            f"Slippage={symbol.slippage}",
            f"ExecutionMode={self.execution_mode}",
            f"Report={report_file}",
            f"ReportFormat={self.result_format}",
            f"Optimization={'1' if self.optimization else '0'}",
            f"OptimizationGoal={self.optimization_goal}",
            f"ForwardMode={self.forward_mode}",
            f"TickMode={self.tick_mode}",
        ]

        inputs = {**self.custom_inputs, **(input_overrides or {})}
        if inputs:
            tester_lines.append("[Inputs]")
            for key, value in inputs.items():
                tester_lines.append(f"{key}={value}")

        if self.optimization_inputs:
            tester_lines.append("[Optimization]")
            for rng in self.optimization_inputs.values():
                tester_lines.append(rng.as_ini_line())

        if self.walk_forward_windows:
            tester_lines.append("[WalkForward]")
            for idx, window in enumerate(self.walk_forward_windows, start=1):
                payload = window.to_dict()
                tester_lines.append(
                    f"Segment.{idx}={payload['train_start']},{payload['train_end']},"
                    f"{payload['test_start']},{payload['test_end']}"
                )

        return "\n".join(tester_lines)


__all__ = [
    "StrategyTesterConfig",
    "SymbolConfig",
    "OptimizationInputRange",
    "WalkForwardWindow",
]
