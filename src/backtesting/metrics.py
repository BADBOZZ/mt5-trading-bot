from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable

import numpy as np
import pandas as pd

TRADING_DAYS = 252


@dataclass
class PerformanceReport:
    summary: Dict[str, float]
    equity_curve: pd.Series
    drawdown: pd.Series
    returns: pd.Series


def compute_performance_report(
    equity_curve: pd.Series,
    trades: Iterable["TradeLike"],
    risk_free_rate: float = 0.0,
    exposure: float = 1.0,
) -> PerformanceReport:
    returns = equity_curve.pct_change().fillna(0.0)
    cumulative = equity_curve.iloc[-1] / equity_curve.iloc[0] - 1.0
    years = max(len(equity_curve) / TRADING_DAYS, 1e-9)
    cagr = (1 + cumulative) ** (1 / years) - 1

    ann_return = returns.mean() * TRADING_DAYS
    ann_vol = returns.std(ddof=0) * np.sqrt(TRADING_DAYS)
    sharpe = ann_return - risk_free_rate
    if ann_vol > 0:
        sharpe /= ann_vol
    else:
        sharpe = 0.0

    downside = returns.copy()
    downside[downside > 0] = 0
    downside_dev = downside.std(ddof=0) * np.sqrt(TRADING_DAYS)
    sortino = (ann_return - risk_free_rate) / downside_dev if downside_dev else 0.0

    peak = equity_curve.cummax()
    drawdown = equity_curve / peak - 1.0
    max_dd = drawdown.min()
    calmar = (ann_return - risk_free_rate) / abs(max_dd) if max_dd < 0 else np.inf

    trades_list = list(trades)
    gross_profit = sum(max(t.pnl, 0) for t in trades_list)
    gross_loss = sum(min(t.pnl, 0) for t in trades_list)
    profit_factor = (gross_profit / abs(gross_loss)) if gross_loss != 0 else np.inf
    wins = [t for t in trades_list if t.pnl > 0]
    win_rate = len(wins) / len(trades_list) if trades_list else 0.0
    avg_trade = (gross_profit + gross_loss) / len(trades_list) if trades_list else 0.0

    summary = {
        "total_return": cumulative,
        "cagr": cagr,
        "annual_return": ann_return,
        "annual_volatility": ann_vol,
        "sharpe": sharpe,
        "sortino": sortino,
        "max_drawdown": max_dd,
        "calmar": calmar,
        "win_rate": win_rate,
        "profit_factor": profit_factor,
        "average_trade": avg_trade,
        "exposure": exposure,
    }

    return PerformanceReport(summary=summary, equity_curve=equity_curve, drawdown=drawdown, returns=returns)


class TradeLike:
    pnl: float
