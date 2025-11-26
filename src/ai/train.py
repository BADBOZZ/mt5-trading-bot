from __future__ import annotations

import argparse
from pathlib import Path

from .config import Config
from .pipelines.signal_pipeline import SignalPipeline


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train neural signal model for MT5")
    parser.add_argument("--data-csv", required=True, help="Path to historical market data csv")
    parser.add_argument("--config", default=None, help="Optional YAML config override")
    parser.add_argument(
        "--generate-signals",
        action="store_true",
        help="Run inference after training and export latest signals",
    )
    parser.add_argument(
        "--checkpoint",
        default="artifacts/model_checkpoint.pt",
        help="Path to save the trained checkpoint",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = Config.load(Path(args.config)) if args.config else Config()
    pipeline = SignalPipeline(config)
    checkpoint_path = Path(args.checkpoint)
    stats = pipeline.train(Path(args.data_csv), checkpoint_path)
    print("Training stats", stats)
    if args.generate_signals:
        pipeline.generate_signals(Path(args.data_csv), checkpoint_path)


if __name__ == "__main__":
    main()
