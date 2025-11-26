"""Parameter sweep helpers used for Strategy Tester optimization runs."""

from __future__ import annotations

from dataclasses import dataclass
from itertools import product
from typing import Dict, Iterable, Iterator, List, Sequence

from .config import OptimizationInputRange


def _float_range(start: float, stop: float, step: float) -> Iterator[float]:
    if step <= 0:
        raise ValueError("Optimization step must be a positive number.")
    value = start
    precision_guard = step / 10
    while value <= stop + precision_guard:
        yield round(value, 10)
        value += step


@dataclass(frozen=True)
class OptimizationParameter:
    """Concrete list of values that a single EA input should take."""

    name: str
    values: Sequence[float]

    @classmethod
    def from_range(cls, rng: OptimizationInputRange) -> "OptimizationParameter":
        return cls(name=rng.name, values=tuple(_float_range(rng.start, rng.stop, rng.step)))


class GridSearchOptimizer:
    """Deterministic optimizer that enumerates the full input grid."""

    def __init__(
        self,
        parameters: Sequence[OptimizationParameter],
        *,
        criteria: str = "Balance max",
    ) -> None:
        if not parameters:
            raise ValueError("At least one optimization parameter is required.")
        self.parameters = list(parameters)
        self._criteria = criteria

    def generate_batches(self) -> Iterable[Dict[str, float]]:
        for combination in product(*(param.values for param in self.parameters)):
            yield {
                param.name: value
                for param, value in zip(self.parameters, combination)
            }

    @property
    def criteria(self) -> str:
        return self._criteria

    @property
    def total_runs(self) -> int:
        total = 1
        for param in self.parameters:
            total *= len(param.values)
        return total

    @classmethod
    def from_ranges(
        cls,
        ranges: Iterable[OptimizationInputRange],
        *,
        criteria: str = "Balance max",
    ) -> "GridSearchOptimizer":
        parameters = [OptimizationParameter.from_range(rng) for rng in ranges]
        if not parameters:
            raise ValueError("Optimization ranges cannot be empty.")
        return cls(parameters, criteria=criteria)


__all__ = ["OptimizationParameter", "GridSearchOptimizer"]
