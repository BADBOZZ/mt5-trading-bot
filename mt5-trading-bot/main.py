#!/usr/bin/env python3
"""Main entry point for MT5 Trading Bot."""
import os
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

from src.core.engine import StrategyEngine
from src.core.runtime import TradingOrchestrator
from src.risk.risk_engine import RiskEngine
from src.risk.config import RiskConfig
from src.signals.generators import TrendFollowingGenerator, MeanReversionGenerator, BreakoutGenerator
from src.core.types import StrategyConfig

def main():
    """Main trading bot loop."""
    print("🚀 Starting MT5 Trading Bot...")
    
    # Initialize risk engine
    risk_config = RiskConfig()
    risk_engine = RiskEngine(risk_config)
    
    # Initialize strategy engine
    strategy_engine = StrategyEngine()
    
    # Register strategies
    trend_strategy = TrendFollowingGenerator("TrendFollowing")
    mean_rev_strategy = MeanReversionGenerator("MeanReversion")
    breakout_strategy = BreakoutGenerator("Breakout")
    
    strategy_engine.register_strategy(
        "trend",
        trend_strategy,
        StrategyConfig(
            name="Trend Following",
            symbols=["EURUSD", "GBPUSD"],
            timeframes=["M15", "H1"],
            enabled=True
        )
    )
    
    strategy_engine.register_strategy(
        "mean_reversion",
        mean_rev_strategy,
        StrategyConfig(
            name="Mean Reversion",
            symbols=["EURUSD", "GBPUSD"],
            timeframes=["M15"],
            enabled=True
        )
    )
    
    strategy_engine.register_strategy(
        "breakout",
        breakout_strategy,
        StrategyConfig(
            name="Breakout",
            symbols=["EURUSD", "GBPUSD"],
            timeframes=["H1"],
            enabled=True
        )
    )
    
    # Initialize orchestrator
    orchestrator = TradingOrchestrator(strategy_engine, risk_engine)
    
    print("✅ Trading bot initialized successfully!")
    print("📊 Strategies registered:")
    print("   - Trend Following")
    print("   - Mean Reversion")
    print("   - Breakout")
    print("\n⚠️  Connect to MT5 and start processing market data...")

if __name__ == "__main__":
    main()
