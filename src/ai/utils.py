"""Shared utilities for AI pipeline."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict


def save_json(data: Dict[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)


def exponential_smoothing(value: float, prev: float, beta: float) -> float:
    return beta * value + (1 - beta) * prev
