from __future__ import annotations

import torch


def smape(pred: torch.Tensor, target: torch.Tensor) -> float:
    numerator = torch.abs(pred - target)
    denominator = (torch.abs(pred) + torch.abs(target)).clamp(min=1e-6)
    return float((200 * torch.mean(numerator / denominator)).item())


def directional_accuracy(pred: torch.Tensor, target: torch.Tensor) -> float:
    return float(((pred > 0) == (target > 0)).float().mean().item())


def calmar_ratio(returns: torch.Tensor) -> float:
    cumulative = torch.cumsum(returns, dim=0)
    peak = torch.cummax(cumulative, dim=0)[0]
    drawdown = peak - cumulative
    max_drawdown = torch.max(drawdown).item() + 1e-6
    annualized_return = torch.mean(returns).item() * 252
    return annualized_return / max_drawdown
