from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Dict, Optional

import pandas as pd


@dataclass
class StrategyState:
    """
    Container that strategies can use to persist data between runs.

    Attributes
    ----------
    last_position: float
        The last net position expressed in lots.
    metadata: Dict[str, Any]
        Free-form storage for indicators or diagnostics.
    """

    last_position: float = 0.0
    metadata: Dict[str, Any] = field(default_factory=dict)


class BaseStrategy(ABC):
    """
    Abstract base class for MT5 strategies that interact with the backtester.

    Strategies should inherit from this class and implement the ``generate_signals``
    method to return a pandas Series of trade intents for each bar (-1 short,
    0 flat, +1 long). Signals are later translated into actual orders by the
    portfolio simulator.
    """

    def __init__(self, name: Optional[str] = None, **parameters: Any) -> None:
        self.name = name or self.__class__.__name__
        self.parameters = parameters
        self.state = StrategyState()

    @abstractmethod
    def generate_signals(self, data: pd.DataFrame) -> pd.Series:
        """Return a Series of target positions indexed by the input data."""

    def reset(self) -> None:
        """Reset any cached state to allow clean reuse of a strategy object."""

        self.state = StrategyState()

    def update_parameters(self, **parameters: Any) -> None:
        """Update strategy parameters in-place."""

        self.parameters.update(parameters)

    # --------------------------------------------------------------------- #
    # Convenience helpers for child classes
    # --------------------------------------------------------------------- #
    def _assert_columns(self, data: pd.DataFrame, *required: str) -> None:
        missing = [col for col in required if col not in data.columns]
        if missing:
            raise ValueError(
                f"{self.name}: missing required data columns: {', '.join(missing)}"
            )

    def __repr__(self) -> str:
        return f"{self.name}(params={self.parameters})"
