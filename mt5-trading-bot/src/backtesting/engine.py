"""MT5 Strategy Tester integration utilities."""

from __future__ import annotations

import logging
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Protocol, Sequence

from .config import StrategyTesterConfig, SymbolConfig

logger = logging.getLogger(__name__)


class ParameterOptimizer(Protocol):
    """Protocol for optimizer implementations used by the tester."""

    def generate_batches(self) -> Iterable[Dict[str, float]]:
        """Yield input dictionaries that should be tested."""

    @property
    def criteria(self) -> str:
        """Return the optimization criterion description."""


class WalkForwardRunner(Protocol):
    """Protocol describing a walk-forward segmentation provider."""

    def build_windows(self) -> Sequence:
        """Return walk-forward windows that can be attached to the config."""


@dataclass(slots=True)
class StrategyRunResult:
    """Captured metadata from a Strategy Tester run."""

    symbol: str
    report_file: Path
    ini_file: Path
    inputs: Dict[str, float] = field(default_factory=dict)
    success: bool = True
    stdout: str = ""
    stderr: str = ""

    def as_dict(self) -> Dict[str, str]:
        return {
            "symbol": self.symbol,
            "report": str(self.report_file),
            "ini": str(self.ini_file),
            "success": str(self.success),
            "inputs": ",".join(f"{k}={v}" for k, v in self.inputs.items()),
        }


class StrategyTesterError(RuntimeError):
    """Raised when MetaTrader 5 Strategy Tester execution fails."""


class StrategyTesterIntegration:
    """High-level coordinator for running the MT5 Strategy Tester programmatically."""

    def __init__(
        self,
        config: StrategyTesterConfig,
        *,
        optimizer: Optional[ParameterOptimizer] = None,
        walkforward: Optional[WalkForwardRunner] = None,
    ) -> None:
        self.config = config
        self.optimizer = optimizer
        self.walkforward = walkforward
        self._temp_dir = Path(tempfile.mkdtemp(prefix="mt5_tester_"))

    def run(self) -> List[StrategyRunResult]:
        """Run the Strategy Tester across symbols/parameter batches."""

        parameter_plan = list(self.optimizer.generate_batches()) if self.optimizer else [None]
        results: List[StrategyRunResult] = []

        if self.walkforward:
            windows = self.walkforward.build_windows()
            self.config.walk_forward_windows = list(windows)

        for batch in parameter_plan:
            overrides = batch or {}
            for symbol in self.config.iter_symbols():
                logger.info("Launching tester for %s with overrides %s", symbol.name, overrides)
                results.append(self._execute_symbol(symbol, overrides))

        return results

    def _execute_symbol(self, symbol: SymbolConfig, overrides: Dict[str, float]) -> StrategyRunResult:
        """Build INI file and call the Strategy Tester binary."""

        ini_file = self._write_ini(symbol, overrides)
        command = self._build_command(ini_file)
        report_file = self.config.reports_dir / f"{symbol.name}_{self.config.result_format}"

        try:
            completed = subprocess.run(
                command,
                capture_output=True,
                text=True,
                check=True,
            )
            success = True
        except FileNotFoundError as exc:
            raise StrategyTesterError(
                f"Strategy Tester binary not found at {self.config.terminal_path}"
            ) from exc
        except subprocess.CalledProcessError as exc:
            completed = exc
            success = False
            logger.error(
                "Strategy Tester failed for %s (code %s)", symbol.name, exc.returncode
            )
        else:
            logger.debug("Strategy Tester completed for %s", symbol.name)

        stdout = completed.stdout if "completed" in locals() else ""
        stderr = completed.stderr if "completed" in locals() else ""

        return StrategyRunResult(
            symbol=symbol.name,
            report_file=report_file,
            ini_file=ini_file,
            inputs=overrides,
            success=success,
            stdout=stdout,
            stderr=stderr,
        )

    def _write_ini(self, symbol: SymbolConfig, overrides: Dict[str, float]) -> Path:
        payload = self.config.build_ini_block(symbol, overrides)
        ini_path = self._temp_dir / f"{symbol.name}.ini"
        ini_path.write_text(payload)
        return ini_path

    def _build_command(self, ini_path: Path) -> List[str]:
        return [
            str(self.config.terminal_path),
            f"/config:{ini_path}",
            "/portable",
        ]


__all__ = [
    "StrategyTesterIntegration",
    "StrategyTesterError",
    "StrategyRunResult",
    "ParameterOptimizer",
    "WalkForwardRunner",
]
