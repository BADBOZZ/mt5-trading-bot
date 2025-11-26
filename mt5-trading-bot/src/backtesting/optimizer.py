from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence


@dataclass(frozen=True)
class OptimizationParameter:
    name: str
    start: float
    step: float
    stop: float
    dtype: str = "double"


DEFAULT_PARAMETERS: Sequence[OptimizationParameter] = (
    OptimizationParameter("InpRiskPerTrade", 0.25, 0.25, 2.0, "double"),
    OptimizationParameter("InpStopLossPoints", 150, 25, 700, "int"),
    OptimizationParameter("InpTakeProfitPoints", 300, 25, 900, "int"),
    OptimizationParameter("InpTrailingStopPoints", 100, 25, 400, "double"),
    OptimizationParameter("InpLookbackPeriod", 100, 20, 400, "int"),
    OptimizationParameter("InpMinSharpe", 0.5, 0.1, 1.5, "double"),
    OptimizationParameter("InpMaxDrawdownPct", 5.0, 0.5, 15.0, "double"),
)


@dataclass
class OptimizationResult:
    parameters: Dict[str, float]
    score: float


class OptimizationScriptBuilder:
    """Produces Strategy Tester .set files and summaries for optimization batches."""

    def __init__(self, parameters: Iterable[OptimizationParameter] = DEFAULT_PARAMETERS):
        self.parameters = list(parameters)

    def write_set_file(self, output_path: Path) -> Path:
        lines = ["[Parameters]"]
        for param in self.parameters:
            dtype = param.dtype.lower()
            lines.append(f"{param.name}={param.start},{param.step},{param.stop},{dtype}")
        output_path.write_text("\n".join(lines), encoding="utf-8")
        return output_path

    def describe(self) -> str:
        return json.dumps(
            [
                {
                    "name": param.name,
                    "start": param.start,
                    "step": param.step,
                    "stop": param.stop,
                    "type": param.dtype,
                }
                for param in self.parameters
            ],
            indent=2,
        )


class OptimizationReport:
    """Aggregates raw optimization results for downstream comparison."""

    def __init__(self) -> None:
        self._results: List[OptimizationResult] = []

    def add_result(self, parameters: Dict[str, float], score: float) -> None:
        self._results.append(OptimizationResult(parameters=parameters, score=score))

    def top(self, limit: int = 5) -> List[OptimizationResult]:
        return sorted(self._results, key=lambda result: result.score, reverse=True)[:limit]

    def export(self, output_path: Path, limit: int = 10) -> Path:
        payload = [
            {
                "score": result.score,
                "parameters": result.parameters,
            }
            for result in self.top(limit)
        ]
        output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        return output_path
