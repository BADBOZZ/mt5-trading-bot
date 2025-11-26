"""MetaTrader 5 connection manager."""
import MetaTrader5 as mt5
import time
import os
from typing import Optional, Dict

class MT5Connection:
    """Manages MT5 connection."""
    
    def __init__(self, server: str, login: int, password: str):
        self.server = server
        self.login = login
        self.password = password
        self.connected = False
    
    def connect(self, retries: int = 3, mt5_path: str = None) -> bool:
        """Connect to MT5 with retries."""
        # Try to find MT5 path if not provided
        if not mt5_path:
            import os
            possible_paths = [
                r"C:\Program Files\MetaTrader 5\terminal64.exe",
                r"C:\Program Files (x86)\MetaTrader 5\terminal64.exe",
                os.path.expanduser(r"~\AppData\Roaming\MetaTrader 5\terminal64.exe"),
            ]
            for path in possible_paths:
                if os.path.exists(path):
                    mt5_path = path
                    break
        
        for attempt in range(retries):
            print(f"Attempting to connect to MT5 (attempt {attempt + 1}/{retries})...")
            
            # Try initialization with path if available
            if mt5_path:
                print(f"  Using MT5 path: {mt5_path}")
                initialized = mt5.initialize(path=mt5_path)
            else:
                # Try to find MT5 automatically
                possible_paths = [
                    r"C:\Program Files\MetaTrader 5\terminal64.exe",
                    r"C:\Program Files (x86)\MetaTrader 5\terminal64.exe",
                    os.path.expanduser(r"~\AppData\Roaming\MetaTrader 5\terminal64.exe"),
                ]
                initialized = False
                for path in possible_paths:
                    if os.path.exists(path):
                        print(f"  Auto-detected MT5 path: {path}")
                        initialized = mt5.initialize(path=path)
                        if initialized:
                            break
                
                if not initialized:
                    initialized = mt5.initialize()
            
            if not initialized:
                error = mt5.last_error()
                print(f"MT5 initialization failed: {error}")
                
                if error[0] == -10005:  # IPC timeout
                    print("  -> IPC timeout: Make sure MetaTrader 5 is running and 'Allow automated trading' is enabled")
                    print("  -> In MT5: Tools -> Options -> Expert Advisors -> Enable 'Allow automated trading'")
                    print("  -> Also enable 'Allow DLL imports' if available")
                elif error[0] == -10001:  # Terminal not found
                    print("  -> Terminal not found: Make sure MetaTrader 5 is running")
                elif error[0] == -10004:
                    print("  -> Common error: Make sure MT5 is logged into your account")
                
                if attempt < retries - 1:
                    print(f"  -> Retrying in 2 seconds...")
                    time.sleep(2)
                    continue
                return False
            
            # Check terminal info
            terminal_info = mt5.terminal_info()
            if terminal_info:
                if not terminal_info.connected:
                    print("  -> Terminal is not connected to server")
                    print("  -> Please log into your account in MT5")
                    mt5.shutdown()
                    if attempt < retries - 1:
                        print(f"  -> Retrying in 2 seconds...")
                        time.sleep(2)
                        continue
                    return False
                
                if not terminal_info.trade_allowed:
                    print("  -> WARNING: Trading not allowed in MT5 settings")
                    print("  -> Enable 'Allow automated trading' in MT5")
                
                if terminal_info.tradeapi_disabled:
                    print("  -> WARNING: Trade API disabled in MT5 settings")
                    print("  -> Enable 'Allow DLL imports' in MT5")
            
            break  # Successfully initialized
        
        # Login to account
        authorized = mt5.login(self.login, password=self.password, server=self.server)
        
        if not authorized:
            print(f"MT5 login failed: {mt5.last_error()}")
            mt5.shutdown()
            return False
        
        self.connected = True
        
        # Get account info
        account_info = mt5.account_info()
        if account_info:
            print(f"Connected to MT5 account: {account_info.login}")
            print(f"Server: {account_info.server}")
            print(f"Balance: {account_info.balance}")
            print(f"Equity: {account_info.equity}")
        
        return True
    
    def disconnect(self):
        """Disconnect from MT5."""
        if self.connected:
            mt5.shutdown()
            self.connected = False
            print("Disconnected from MT5")
    
    def get_account_info(self) -> Optional[Dict]:
        """Get account information."""
        if not self.connected:
            return None
        
        account_info = mt5.account_info()
        if account_info:
            return {
                'balance': account_info.balance,
                'equity': account_info.equity,
                'margin': account_info.margin,
                'free_margin': account_info.margin_free,
                'margin_level': account_info.margin_level,
                'login': account_info.login,
                'server': account_info.server
            }
        return None
    
    def get_symbol_info(self, symbol: str) -> Optional[Dict]:
        """Get symbol information."""
        if not self.connected:
            return None
        
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info:
            return {
                'name': symbol_info.name,
                'bid': symbol_info.bid,
                'ask': symbol_info.ask,
                'spread': symbol_info.spread,
                'point': symbol_info.point,
                'digits': symbol_info.digits
            }
        return None
    
    def get_tick(self, symbol: str) -> Optional[Dict]:
        """Get latest tick for symbol."""
        if not self.connected:
            return None
        
        tick = mt5.symbol_info_tick(symbol)
        if tick:
            return {
                'symbol': symbol,
                'bid': tick.bid,
                'ask': tick.ask,
                'time': tick.time,
                'volume': tick.volume
            }
        return None
    
    def get_rates(self, symbol: str, timeframe, count: int = 100) -> Optional[list]:
        """Get historical rates for symbol."""
        if not self.connected:
            return None
        
        # Map timeframe string to MT5 constant
        timeframe_map = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5,
            'M15': mt5.TIMEFRAME_M15,
            'M30': mt5.TIMEFRAME_M30,
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4,
            'D1': mt5.TIMEFRAME_D1,
        }
        
        mt5_timeframe = timeframe_map.get(timeframe, mt5.TIMEFRAME_M15)
        rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, count)
        
        if rates is not None and len(rates) > 0:
            return [{
                'time': rate[0],
                'open': rate[1],
                'high': rate[2],
                'low': rate[3],
                'close': rate[4],
                'volume': rate[5]
            } for rate in rates]
        return None
    
    def place_order(self, symbol: str, order_type: str, volume: float, 
                   price: float = None, sl: float = None, tp: float = None, 
                   comment: str = "Trading Bot") -> Optional[Dict]:
        """Place a market order."""
        if not self.connected:
            return None
        
        # Get symbol info
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            print(f"Symbol {symbol} not found")
            return None
        
        # Convert volume to lots if needed
        # Normal lot sizes are 0.01 to 2.0, so anything > 10 is definitely wrong
        if volume > 10:
            print(f"  ⚠️  WARNING: Volume {volume} is suspiciously large!")
            print(f"  Assuming units, converting to lots...")
            # 1 lot = 100,000 units for standard forex
            contract_size = getattr(symbol_info, 'trade_contract_size', 100000)
            volume_lots = volume / contract_size
            print(f"  Converted {volume} units to {volume_lots:.4f} lots")
        elif volume > 2.0:
            print(f"  ⚠️  WARNING: Volume {volume} lots seems too large, capping at 1.0 lots")
            volume_lots = 1.0
        else:
            # Already in lots and reasonable
            volume_lots = volume
        
        # Normalize to allowed lot sizes
        volume_min = symbol_info.volume_min
        volume_max = symbol_info.volume_max
        volume_step = symbol_info.volume_step
        
        # Round to nearest step (e.g., if step is 0.01, round to 2 decimal places)
        if volume_step > 0:
            volume_lots = round(volume_lots / volume_step) * volume_step
        else:
            # Fallback: round to 2 decimal places
            volume_lots = round(volume_lots, 2)
        
        # Clamp to min/max
        volume_lots = max(volume_min, min(volume_max, volume_lots))
        
        # Final validation
        if volume_lots < volume_min:
            print(f"  ❌ Volume {volume_lots:.4f} is below minimum {volume_min}")
            return None
        
        if volume_lots > volume_max:
            print(f"  ❌ Volume {volume_lots:.4f} exceeds maximum {volume_max}")
            return None
        
        print(f"  📊 Final volume: {volume_lots:.4f} lots (min: {volume_min}, max: {volume_max}, step: {volume_step})")
        
        # Prepare order request
        if order_type.upper() == "BUY":
            trade_type = mt5.ORDER_TYPE_BUY
            price = mt5.symbol_info_tick(symbol).ask if price is None else price
        elif order_type.upper() == "SELL":
            trade_type = mt5.ORDER_TYPE_SELL
            price = mt5.symbol_info_tick(symbol).bid if price is None else price
        else:
            return None
        
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume_lots,  # Use normalized lot size
            "type": trade_type,
            "price": price,
            "deviation": 20,
            "magic": 234000,
            "comment": comment,
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        
        if sl is not None:
            request["sl"] = sl
        if tp is not None:
            request["tp"] = tp
        
        # Send order
        result = mt5.order_send(request)
        
        if result.retcode != mt5.TRADE_RETCODE_DONE:
            print(f"Order failed: {result.retcode} - {result.comment}")
            return None
        
        return {
            'order': result.order,
            'volume': result.volume,
            'price': result.price,
            'comment': result.comment
        }
    
    def get_positions(self, symbol: str = None) -> list:
        """Get open positions."""
        if not self.connected:
            return []
        
        if symbol:
            positions = mt5.positions_get(symbol=symbol)
        else:
            positions = mt5.positions_get()
        
        if positions is None:
            return []
        
        return [{
            'ticket': pos.ticket,
            'symbol': pos.symbol,
            'type': 'BUY' if pos.type == mt5.ORDER_TYPE_BUY else 'SELL',
            'volume': pos.volume,
            'price_open': pos.price_open,
            'price_current': pos.price_current,
            'profit': pos.profit,
            'sl': pos.sl,
            'tp': pos.tp,
            'comment': pos.comment
        } for pos in positions]

