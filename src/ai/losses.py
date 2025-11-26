"""Training losses for the hybrid neural network."""
from __future__ import annotations

import torch
import torch.nn.functional as F


def signal_loss(
    logits: torch.Tensor,
    cls_target: torch.Tensor,
    regression: torch.Tensor,
    reg_target: torch.Tensor,
    label_smoothing: float = 0.05,
    reg_weight: float = 0.35,
    consistency_weight: float = 0.15,
) -> torch.Tensor:
    cls_target = cls_target.long()
    cls_loss = F.cross_entropy(
        logits,
        cls_target,
        label_smoothing=label_smoothing,
    )

    reg_loss = F.smooth_l1_loss(regression, reg_target)

    probs = F.softmax(logits, dim=-1)
    direction = probs[:, 2] - probs[:, 0]
    expected_return = regression[:, 0]
    stacked = torch.stack([direction, expected_return])
    if stacked.shape[-1] < 2 or torch.isnan(stacked).any() or torch.isinf(stacked).any():
        consistency = torch.tensor(0.0, device=logits.device)
    else:
        corr_matrix = torch.corrcoef(stacked)
        corr = torch.nan_to_num(corr_matrix[0, 1], nan=0.0)
        consistency = 1 - corr

    return cls_loss + reg_weight * reg_loss + consistency_weight * consistency
