"""Helpers for describing MT5 Strategy Tester parameter optimization."""

from __future__ import annotations

from dataclasses import dataclass
from itertools import product
from typing import Iterator, List, Sequence


@dataclass(frozen=True)
class ParameterRange:
    """Numerical range definition compatible with MT5 input parameters."""

    name: str
    start: float
    stop: float
    step: float

    def values(self) -> List[float]:
        current = self.start
        result: List[float] = []
        while current <= self.stop + 1e-9:
            result.append(round(current, 10))
            current += self.step
        return result

    def mt5_hint(self) -> str:
        return f"{self.start},{self.stop},{self.step}"


@dataclass(frozen=True)
class ParameterChoice:
    """Discrete choice parameter for toggles or enums."""

    name: str
    options: Sequence[str | float | int]

    def values(self) -> Sequence[str | float | int]:
        return list(self.options)

    def mt5_hint(self) -> str:
        return ",".join(map(str, self.options))


ParameterDefinition = ParameterRange | ParameterChoice


class ParameterSpace:
    """Cartesian product builder that mirrors MT5 optimization logic."""

    def __init__(self, definitions: Sequence[ParameterDefinition]) -> None:
        self.definitions = list(definitions)

    def expand(self) -> Iterator[dict]:
        names = [definition.name for definition in self.definitions]
        value_lists = [definition.values() for definition in self.definitions]

        for combo in product(*value_lists):
            yield {name: value for name, value in zip(names, combo)}

    def to_mt5_set(self) -> str:
        """Produce the .set format understood by the Strategy Tester."""

        lines = ["; Auto-generated parameter set", "[TesterInputs]"]
        for definition in self.definitions:
            lines.append(f"{definition.name}={definition.values()[0]}")
            lines.append(f"{definition.name}.set={definition.mt5_hint()}")
        return "\n".join(lines)

    def describe(self) -> List[dict]:
        """Return a serializable description of the parameter search space."""

        summary: List[dict] = []
        for definition in self.definitions:
            if isinstance(definition, ParameterRange):
                summary.append(
                    {
                        "name": definition.name,
                        "type": "range",
                        "start": definition.start,
                        "stop": definition.stop,
                        "step": definition.step,
                    }
                )
            else:
                summary.append(
                    {
                        "name": definition.name,
                        "type": "choice",
                        "options": list(definition.options),
                    }
                )
        return summary


def default_space() -> ParameterSpace:
    """Return a sensible default grid for the provided EA."""

    return ParameterSpace(
        [
            ParameterRange("RiskPerTrade", 0.5, 2.0, 0.5),
            ParameterRange("StopLoss", 200, 600, 50),
            ParameterRange("TakeProfit", 200, 600, 50),
            ParameterChoice("SignalMode", ("trend", "mean_reversion", "breakout")),
            ParameterRange("TrailingStep", 10, 30, 5),
        ]
    )
