#!/usr/bin/env python3
"""Main entry point for MT5 Trading Bot."""
import os
import sys
import io
import time

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from dotenv import load_dotenv

# Load environment variables
load_dotenv()

from src.core.engine import StrategyEngine
from src.core.runtime import TradingOrchestrator
from src.risk.risk_engine import RiskEngine
from src.risk.config import RiskConfig
from src.risk.state import AccountState
from src.signals.generators import TrendFollowingGenerator, MeanReversionGenerator, BreakoutGenerator
from src.core.types import StrategyConfig
from mt5.connection import MT5Connection

# MT5 Connection Details
MT5_SERVER = "FBS-Demo"
MT5_LOGIN = 105261321
MT5_PASSWORD = "1LlT+/;$"

def main():
    """Main trading bot loop."""
    print("Starting MT5 Trading Bot...")
    print("=" * 60)
    
    # Connect to MT5
    print("\nConnecting to MetaTrader 5...")
    mt5_conn = MT5Connection(MT5_SERVER, MT5_LOGIN, MT5_PASSWORD)
    
    if not mt5_conn.connect():
        print("ERROR: Failed to connect to MT5. Please check:")
        print("  1. MetaTrader 5 is running")
        print("  2. Login credentials are correct")
        print("  3. Server name matches")
        return
    
    print("\n" + "=" * 60)
    
    # Get account info
    account_info = mt5_conn.get_account_info()
    if account_info:
        print(f"\nAccount Information:")
        print(f"  Login: {account_info['login']}")
        print(f"  Server: {account_info['server']}")
        print(f"  Balance: ${account_info['balance']:.2f}")
        print(f"  Equity: ${account_info['equity']:.2f}")
        print(f"  Free Margin: ${account_info['free_margin']:.2f}")
        print(f"  Margin Level: {account_info['margin_level']:.2f}%")
    
    # Initialize risk engine
    risk_config = RiskConfig()
    risk_engine = RiskEngine(risk_config)
    
    # Update risk engine with account state
    if account_info:
        account_state = AccountState(
            balance=account_info['balance'],
            equity=account_info['equity'],
            margin=account_info['margin'],
            free_margin=account_info['free_margin'],
            margin_level=account_info['margin_level']
        )
        risk_engine.update_account_state(account_state)
    
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
    
    print("\n" + "=" * 60)
    print("Trading bot initialized successfully!")
    print("Strategies registered:")
    print("   - Trend Following")
    print("   - Mean Reversion")
    print("   - Breakout")
    print("\n" + "=" * 60)
    
    # Test market data retrieval
    print("\nTesting market data retrieval...")
    test_symbols = ["EURUSD", "GBPUSD"]
    for symbol in test_symbols:
        tick = mt5_conn.get_tick(symbol)
        if tick:
            print(f"  {symbol}: Bid={tick['bid']:.5f}, Ask={tick['ask']:.5f}, Spread={(tick['ask']-tick['bid'])*10000:.1f} pips")
        else:
            print(f"  {symbol}: Not available")
    
    print("\n" + "=" * 60)
    print("Trading bot is ready!")
    print("The bot is connected to MT5 and ready to process market data.")
    print("=" * 60)
    
    # Trading loop
    print("\n🔄 Starting trading loop...")
    print("Monitoring symbols: EURUSD, GBPUSD")
    print("Press Ctrl+C to stop the bot...\n")
    
    last_check_time = {}
    check_interval = 60  # Check every 60 seconds
    
    try:
        while True:
            current_time = time.time()
            
            # Get all symbols we're monitoring
            all_symbols = set()
            for config in strategy_engine.configs.values():
                all_symbols.update(config.symbols)
            
            # Fetch market data for each symbol
            market_data = {}
            for symbol in all_symbols:
                # Get rates for M15 timeframe (primary)
                rates = mt5_conn.get_rates(symbol, 'M15', 100)
                if rates:
                    market_data[symbol] = rates
                    
                    # Check if we should process this symbol (every check_interval seconds)
                    if symbol not in last_check_time or (current_time - last_check_time[symbol]) >= check_interval:
                        print(f"\n[{time.strftime('%H:%M:%S')}] Processing {symbol}...")
                        
                        # Process through orchestrator
                        recommendations = orchestrator.process_tick(market_data)
                        
                        # Check existing positions
                        existing_positions = mt5_conn.get_positions(symbol)
                        has_position = len(existing_positions) > 0
                        
                        # Execute trades for valid recommendations
                        for rec in recommendations:
                            if rec.symbol == symbol:
                                # Don't open new position if we already have one for this symbol
                                if has_position:
                                    print(f"  ⚠️  Skipping {rec.signal.value} signal - position already open")
                                    continue
                                
                                # Get current market price
                                tick = mt5_conn.get_tick(symbol)
                                if not tick:
                                    print(f"  ⚠️  Could not get current price for {symbol}")
                                    continue
                                
                                # Use current market price for entry
                                if rec.signal.value == "buy":
                                    entry_price = tick['ask']
                                else:
                                    entry_price = tick['bid']
                                
                                # Calculate stop loss and take profit FIRST
                                if rec.signal.value == "buy":
                                    # For buy: SL below entry, TP above entry
                                    sl = entry_price * 0.995  # 0.5% stop loss
                                    tp = entry_price * 1.01   # 1% take profit
                                else:
                                    # For sell: SL above entry, TP below entry
                                    sl = entry_price * 1.005  # 0.5% stop loss
                                    tp = entry_price * 0.99   # 1% take profit
                                
                                # Update recommendation with actual entry price and stop loss
                                rec.entry_price = entry_price
                                rec.stop_loss = sl
                                rec.take_profit = tp
                                
                                # Calculate position size AFTER updating entry/SL
                                position_size = risk_engine.calculate_position_size(rec)
                                
                                # Safety check - ensure position size is reasonable
                                if position_size > 5.0:
                                    print(f"  ⚠️  Position size {position_size:.2f} lots is too large, capping at 1.0 lots")
                                    position_size = 1.0
                                
                                # Execute trade
                                print(f"  📊 Signal: {rec.signal.value.upper()} {symbol} @ {entry_price:.5f}")
                                print(f"     Confidence: {rec.confidence:.2%}, Size: {position_size:.4f} lots")
                                print(f"     SL: {sl:.5f}, TP: {tp:.5f}")
                                
                                result = mt5_conn.place_order(
                                    symbol=symbol,
                                    order_type=rec.signal.value,
                                    volume=position_size,
                                    sl=sl,
                                    tp=tp,
                                    comment=f"Bot-{rec.signal.value}"
                                )
                                
                                if result:
                                    print(f"  ✅ Order executed! Ticket: {result.get('order', 'N/A')}")
                                else:
                                    print(f"  ❌ Order failed!")
                        
                        last_check_time[symbol] = current_time
            
            # Monitor existing positions
            all_positions = mt5_conn.get_positions()
            if all_positions:
                print(f"\n📈 Open Positions: {len(all_positions)}")
                for pos in all_positions:
                    pnl = pos['profit']
                    pnl_sign = "+" if pnl >= 0 else ""
                    print(f"  {pos['symbol']} {pos['type']} | Vol: {pos['volume']:.2f} | P&L: {pnl_sign}${pnl:.2f}")
            
            # Sleep before next iteration
            time.sleep(5)  # Check every 5 seconds
            
    except KeyboardInterrupt:
        print("\n\n🛑 Stopping trading bot...")
        
        # Show final positions
        positions = mt5_conn.get_positions()
        if positions:
            print(f"\nFinal Positions: {len(positions)}")
            total_pnl = sum(p['profit'] for p in positions)
            print(f"Total P&L: ${total_pnl:.2f}")
        
        mt5_conn.disconnect()
        print("✅ Bot stopped.")

if __name__ == "__main__":
    main()
