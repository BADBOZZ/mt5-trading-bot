"""Backtesting configuration models for MT5 Strategy Tester integration."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Sequence

import json
from textwrap import dedent

try:  # Optional YAML support
    import yaml  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    yaml = None


class OptimizationObjective(str, Enum):
    """Optimization targets supported by the MT5 Strategy Tester."""

    SHARPE = "sharpe"
    NET_PROFIT = "net_profit"
    PROFIT_FACTOR = "profit_factor"
    DRAWDOWN = "max_drawdown"
    EXPECTANCY = "expectancy"


@dataclass(slots=True)
class SymbolConfig:
    """Configuration for a symbol/timeframe pair used in multi-currency tests."""

    symbol: str
    timeframe: str
    start: datetime
    end: datetime
    spread: float = 0.0
    ticks_mode: str = "real"  # real, every_tick, open_prices
    max_slippage: float = 1.0


@dataclass(slots=True)
class ParameterRange:
    """Describes a tunable strategy parameter for optimization runs."""

    name: str
    start: float
    stop: float
    step: float
    is_integer: bool = False

    def to_dict(self) -> Dict[str, float | str | bool]:
        return {
            "name": self.name,
            "start": self.start,
            "stop": self.stop,
            "step": self.step,
            "is_integer": self.is_integer,
        }


@dataclass(slots=True)
class OptimizationConfig:
    """Holds MT5 optimization-related settings."""

    enabled: bool = False
    objective: OptimizationObjective = OptimizationObjective.SHARPE
    parameter_ranges: Sequence[ParameterRange] = field(default_factory=list)
    max_runs: int = 200
    forward_testing: bool = False
    genetic_optimization: bool = True
    criteria_thresholds: Dict[str, float] = field(default_factory=dict)


@dataclass(slots=True)
class WalkForwardWindow:
    """Represents a single walk-forward segment."""

    in_sample_start: datetime
    in_sample_end: datetime
    out_sample_start: datetime
    out_sample_end: datetime


@dataclass(slots=True)
class WalkForwardConfig:
    enabled: bool = False
    windows: Sequence[WalkForwardWindow] = field(default_factory=tuple)
    rebalance_on_forward_fail: bool = True


@dataclass(slots=True)
class ReportConfig:
    """Controls which artifacts are exported after each run."""

    output_dir: Path = Path("reports")
    export_trades: bool = True
    export_equity: bool = True
    export_json: bool = True
    generate_charts: bool = True
    strategy_leaderboard: bool = True


@dataclass(slots=True)
class BacktestConfig:
    """Top-level configuration for a Strategy Tester session."""

    expert_name: str
    deposit_currency: str
    deposit: float
    leverage: int
    symbols: Sequence[SymbolConfig]
    parameters: Dict[str, float] = field(default_factory=dict)
    optimization: OptimizationConfig = field(default_factory=OptimizationConfig)
    walk_forward: WalkForwardConfig = field(default_factory=WalkForwardConfig)
    report: ReportConfig = field(default_factory=ReportConfig)
    tester_ini_template: Optional[Path] = None
    terminal_path: Optional[Path] = None

    def ensure_report_dir(self) -> Path:
        self.report.output_dir.mkdir(parents=True, exist_ok=True)
        return self.report.output_dir

    @staticmethod
    def _parse_datetime(value: str | datetime) -> datetime:
        if isinstance(value, datetime):
            return value
        return datetime.fromisoformat(value)

    @classmethod
    def from_dict(cls, payload: Dict) -> "BacktestConfig":
        symbols = [
            SymbolConfig(
                symbol=entry["symbol"],
                timeframe=entry.get("timeframe", "H1"),
                start=cls._parse_datetime(entry["start"]),
                end=cls._parse_datetime(entry["end"]),
                spread=float(entry.get("spread", 0.0)),
                ticks_mode=entry.get("ticks_mode", "real"),
                max_slippage=float(entry.get("max_slippage", 1.0)),
            )
            for entry in payload.get("symbols", [])
        ]

        parameter_ranges = [
            ParameterRange(
                name=row["name"],
                start=float(row["start"]),
                stop=float(row["stop"]),
                step=float(row.get("step", 1)),
                is_integer=bool(row.get("is_integer", False)),
            )
            for row in payload.get("optimization", {}).get("parameter_ranges", [])
        ]

        optimization = OptimizationConfig(
            enabled=payload.get("optimization", {}).get("enabled", False),
            objective=OptimizationObjective(
                payload.get("optimization", {}).get("objective", OptimizationObjective.SHARPE.value)
            ),
            parameter_ranges=parameter_ranges,
            max_runs=int(payload.get("optimization", {}).get("max_runs", 200)),
            forward_testing=bool(payload.get("optimization", {}).get("forward_testing", False)),
            genetic_optimization=bool(payload.get("optimization", {}).get("genetic_optimization", True)),
            criteria_thresholds=payload.get("optimization", {}).get("criteria_thresholds", {}),
        )

        windows = [
            WalkForwardWindow(
                in_sample_start=cls._parse_datetime(window["in_sample_start"]),
                in_sample_end=cls._parse_datetime(window["in_sample_end"]),
                out_sample_start=cls._parse_datetime(window["out_sample_start"]),
                out_sample_end=cls._parse_datetime(window["out_sample_end"]),
            )
            for window in payload.get("walk_forward", {}).get("windows", [])
        ]

        walk_forward = WalkForwardConfig(
            enabled=payload.get("walk_forward", {}).get("enabled", False),
            windows=windows,
            rebalance_on_forward_fail=payload.get("walk_forward", {}).get("rebalance_on_forward_fail", True),
        )

        report_payload = payload.get("report", {})
        report = ReportConfig(
            output_dir=Path(report_payload.get("output_dir", "reports")),
            export_trades=report_payload.get("export_trades", True),
            export_equity=report_payload.get("export_equity", True),
            export_json=report_payload.get("export_json", True),
            generate_charts=report_payload.get("generate_charts", True),
            strategy_leaderboard=report_payload.get("strategy_leaderboard", True),
        )

        return cls(
            expert_name=payload.get("expert_name", "ExpertAdvisor"),
            deposit_currency=payload.get("deposit_currency", "USD"),
            deposit=float(payload.get("deposit", 10000)),
            leverage=int(payload.get("leverage", 100)),
            symbols=symbols,
            parameters=payload.get("parameters", {}),
            optimization=optimization,
            walk_forward=walk_forward,
            report=report,
            tester_ini_template=Path(payload["tester_ini_template"]) if payload.get("tester_ini_template") else None,
            terminal_path=Path(payload["terminal_path"]) if payload.get("terminal_path") else None,
        )

    @classmethod
    def from_file(cls, path: Path | str) -> "BacktestConfig":
        file_path = Path(path)
        if not file_path.exists():
            raise FileNotFoundError(f"Backtest config '{file_path}' not found")

        raw = file_path.read_text(encoding="utf-8")
        if file_path.suffix.lower() in {".yaml", ".yml"}:
            if yaml is None:
                raise RuntimeError("PyYAML is required to load YAML configs")
            data = yaml.safe_load(raw)
        else:
            data = json.loads(raw)
        return cls.from_dict(data)

    def to_ini(self, override_parameters: Optional[Dict[str, float]] = None) -> str:
        params = self.parameters.copy()
        if override_parameters:
            params.update(override_parameters)

        symbols_text = "\n".join(
            dedent(
                f"""
                [{cfg.symbol}]
                timeframe={cfg.timeframe}
                from={cfg.start:%Y.%m.%d}
                to={cfg.end:%Y.%m.%d}
                spread={cfg.spread}
                ticks_mode={cfg.ticks_mode}
                slippage={cfg.max_slippage}
                """
            ).strip()
            for cfg in self.symbols
        )

        params_text = "\n".join(f"{key}={value}" for key, value in params.items())

        return dedent(
            f"""
            [Tester]
            Expert={self.expert_name}
            Symbol={self.symbols[0].symbol if self.symbols else ''}
            Period={self.symbols[0].timeframe if self.symbols else 'H1'}
            Deposit={self.deposit}
            Currency={self.deposit_currency}
            Leverage={self.leverage}
            Optimization={int(self.optimization.enabled)}
            ForwardMode={int(self.walk_forward.enabled)}
            """
        ).strip() + "\n\n[Parameters]\n" + params_text + "\n\n[Symbols]\n" + symbols_text


__all__ = [
    "BacktestConfig",
    "OptimizationConfig",
    "OptimizationObjective",
    "ParameterRange",
    "ReportConfig",
    "SymbolConfig",
    "WalkForwardConfig",
    "WalkForwardWindow",
]
