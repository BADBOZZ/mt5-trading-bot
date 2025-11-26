"""Utility dataclasses to describe Strategy Tester and Python backtests.

The MT5 Strategy Tester can be controlled via `.ini`/`.set` files.  The
structures below let us describe those runs programmatically so that both the
Python backtesting harness and the MetaTrader Strategy Tester share one source
of truth for their parameters.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional


@dataclass(slots=True)
class SymbolSettings:
    """Per-symbol overrides that affect execution quality inside MT5."""

    symbol: str
    timeframe: str
    spread_points: float = 15.0
    slippage_points: float = 1.0
    contract_size: int = 100_000


@dataclass(slots=True)
class StrategyTesterWindow:
    """Represents the date window that should be replayed in Strategy Tester."""

    start: datetime
    end: datetime
    forward_start: Optional[datetime] = None
    forward_end: Optional[datetime] = None

    def to_ini_section(self) -> Dict[str, str]:
        """Serialize into MT5 tester `.ini` fields."""
        payload = {
            "FromDate": self.start.strftime("%Y.%m.%d"),
            "ToDate": self.end.strftime("%Y.%m.%d"),
        }
        if self.forward_start and self.forward_end:
            payload["ForwardMode"] = "1"
            payload["ForwardDate"] = self.forward_start.strftime("%Y.%m.%d")
            payload["ForwardDateTo"] = self.forward_end.strftime("%Y.%m.%d")
        else:
            payload["ForwardMode"] = "0"
        return payload


@dataclass(slots=True)
class OptimizationParameter:
    """Definition of an input that the MT5 optimizer should iterate over."""

    name: str
    start: float
    stop: float
    step: float
    optimise: bool = True

    def to_set_line(self) -> str:
        """Convert into MT5 `.set` format."""
        flag = 1 if self.optimise else 0
        return f"input:{self.name}={self.start}||{self.stop}||{self.step}||{flag}"


@dataclass(slots=True)
class BacktestSettings:
    """Runtime knobs for the pure Python backtesting harness."""

    initial_deposit: float = 10_000.0
    max_holding_bars: int = 12
    spread_points: float = 15.0
    slippage_points: float = 1.0
    commission_per_lot: float = 7.0
    reward_risk_ratio: float = 2.0
    risk_free_rate: float = 0.02
    timezone: str = "UTC"
    data_granularity: str = "M1"
    fill_gaps: bool = True


@dataclass(slots=True)
class StrategyTesterConfig:
    """High-level description of how the MT5 Strategy Tester should behave."""

    expert_name: str
    symbol_settings: List[SymbolSettings]
    window: StrategyTesterWindow
    deposit_currency: str = "USD"
    deposit: float = 10_000.0
    leverage: int = 100
    execution_delay_ms: int = 200
    model: str = "Every tick"
    use_real_ticks: bool = True
    genetic_optimization: bool = False
    optimization_parameters: List[OptimizationParameter] = field(default_factory=list)
    custom_inputs: Dict[str, Any] = field(default_factory=dict)

    def _common_ini(self) -> Dict[str, str]:
        """Common Strategy Tester settings section."""
        data = {
            "Expert": self.expert_name,
            "Deposit": f"{self.deposit}",
            "Currency": self.deposit_currency,
            "Leverage": f"1:{self.leverage}",
            "ExecutionDelay": str(self.execution_delay_ms),
            "Model": self.model,
            "UseLocal": "0",
            "Optimization": "1" if self.optimization_parameters else "0",
            "UseGeneticAlgorithm": "1" if self.genetic_optimization else "0",
            "UseRealTicks": "1" if self.use_real_ticks else "0",
        }
        data.update(self.window.to_ini_section())
        return data

    def to_ini(self) -> str:
        """Render an `.ini` file consumable by `terminal64.exe /config`."""
        lines = ["[Tester]"]
        common = self._common_ini()
        for key, value in common.items():
            lines.append(f"{key}={value}")

        # Custom inputs are appended under an [Inputs] section
        if self.custom_inputs:
            lines.append("")
            lines.append("[Inputs]")
            for key, value in self.custom_inputs.items():
                lines.append(f"{key}={value}")

        return "\n".join(lines)

    def to_set(self) -> str:
        """Render a `.set` file to feed the MT5 optimizer."""
        lines = ["[Common]"]
        lines.append(f"SymbolList={','.join(s.symbol for s in self.symbol_settings)}")
        lines.append(f"Timeframes={','.join(s.timeframe for s in self.symbol_settings)}")
        lines.append("")
        lines.append("[Inputs]")

        for name, value in self.custom_inputs.items():
            lines.append(f"{name}={value}")

        if self.optimization_parameters:
            lines.append("")
            lines.append("[Optimization]")
            for parameter in self.optimization_parameters:
                lines.append(parameter.to_set_line())

        return "\n".join(lines)

    def export(self, destination: Path) -> None:
        """Dump both `.ini` and `.set` payloads next to each other."""
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(self.to_ini(), encoding="utf-8")
        set_path = destination.with_suffix(".set")
        set_path.write_text(self.to_set(), encoding="utf-8")


def build_symbol_settings(symbols: Iterable[str], timeframe: str) -> List[SymbolSettings]:
    """Helper to quickly craft symbol settings with consistent defaults."""
    return [
        SymbolSettings(symbol=symbol, timeframe=timeframe) for symbol in symbols
    ]
