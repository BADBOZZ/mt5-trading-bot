from __future__ import annotations

from collections import defaultdict, deque
from typing import Deque, Dict, Iterable, List, Sequence, Tuple

from .engine import StrategyEngine, EngineResult
from .types import MarketDataPoint, StrategyContext


class MarketDataStore:
    """Keeps a rolling window of candles per symbol/timeframe pair."""

    def __init__(self, max_candles: int = 2000):
        self.max_candles = max_candles
        self._buffers: Dict[Tuple[str, str], Deque[MarketDataPoint]] = defaultdict(deque)

    def ingest(self, candles: Iterable[MarketDataPoint]) -> None:
        for candle in candles:
            key = (candle.symbol, candle.timeframe)
            buffer = self._buffers[key]
            buffer.append(candle)
            while len(buffer) > self.max_candles:
                buffer.popleft()

    def snapshot(self) -> List[MarketDataPoint]:
        data: List[MarketDataPoint] = []
        for buffer in self._buffers.values():
            data.extend(buffer)
        return data

    def latest(self, symbol: str, timeframe: str) -> Sequence[MarketDataPoint]:
        return list(self._buffers.get((symbol, timeframe), []))


class TradingOrchestrator:
    """High-level glue that coordinates data ingestion and engine execution."""

    def __init__(
        self,
        engine: StrategyEngine,
        contexts: Dict[str, StrategyContext],
        max_candles: int = 2000,
    ):
        self.engine = engine
        self.contexts = contexts
        self.market_data = MarketDataStore(max_candles)

    def push_market_data(self, candles: Iterable[MarketDataPoint]) -> None:
        self.market_data.ingest(candles)

    def evaluate_strategies(self) -> List[EngineResult]:
        data = self.market_data.snapshot()
        if not data:
            return []
        return self.engine.run(data, self.contexts)
