"""Test MT5 connection with detailed diagnostics."""
import MetaTrader5 as mt5
import sys
import os
import io

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

print("=" * 60)
print("MT5 Connection Diagnostic Test")
print("=" * 60)

# Check MT5 package
print("\n1. Checking MetaTrader5 package...")
print(f"   MT5 version: {mt5.__version__}")
print(f"   Python version: {sys.version}")

# Try to find MT5 installation
print("\n2. Looking for MT5 installation...")
mt5_paths = [
    r"C:\Program Files\MetaTrader 5\terminal64.exe",
    r"C:\Program Files (x86)\MetaTrader 5\terminal64.exe",
    os.path.expanduser(r"~\AppData\Roaming\MetaTrader 5\terminal64.exe"),
]

found_path = None
for path in mt5_paths:
    if os.path.exists(path):
        found_path = path
        print(f"   [OK] Found MT5 at: {path}")
        break

if not found_path:
    print("   [WARNING] Could not find MT5 installation automatically")
    print("   Please provide the path to terminal64.exe")

# Try initialization with path
print("\n3. Attempting to initialize MT5...")
if found_path:
    print(f"   Using path: {found_path}")
    initialized = mt5.initialize(path=found_path)
else:
    print("   Trying default initialization...")
    initialized = mt5.initialize()

if not initialized:
    error = mt5.last_error()
    print(f"   [ERROR] Initialization failed!")
    print(f"   Error code: {error[0]}")
    print(f"   Error description: {error[1]}")
    
    if error[0] == -10005:
        print("\n   🔧 IPC Timeout Solutions:")
        print("   1. Make sure MT5 is running (not just installed)")
        print("   2. In MT5: Tools -> Options -> Expert Advisors")
        print("      ✅ Enable 'Allow automated trading'")
        print("      ✅ Enable 'Allow DLL imports'")
        print("   3. Make sure you're logged into your account")
        print("   4. Try restarting MT5")
        print("   5. Try running Python as Administrator")
    elif error[0] == -10001:
        print("\n   🔧 Terminal Not Found:")
        print("   1. Make sure MT5 is installed")
        print("   2. Make sure MT5 is running")
        print("   3. Try providing the full path to terminal64.exe")
    elif error[0] == -10004:
        print("\n   🔧 Common Error:")
        print("   1. MT5 might be running but not logged in")
        print("   2. Try logging into your account in MT5")
        print("   3. Make sure the account is active")
    
    sys.exit(1)

print("   [OK] MT5 initialized successfully!")

# Try to get terminal info
print("\n4. Getting terminal information...")
terminal_info = mt5.terminal_info()
if terminal_info:
    print(f"   Terminal: {terminal_info.name}")
    print(f"   Company: {terminal_info.company}")
    print(f"   Path: {terminal_info.path}")
    print(f"   Data path: {terminal_info.data_path}")
    print(f"   Connected: {terminal_info.connected}")
    print(f"   Trade allowed: {terminal_info.trade_allowed}")
    print(f"   Tradeapi disabled: {terminal_info.tradeapi_disabled}")
    
    if not terminal_info.connected:
        print("\n   ⚠️  WARNING: Terminal is not connected!")
        print("   Please log into your account in MT5")
        mt5.shutdown()
        sys.exit(1)
    
    if not terminal_info.trade_allowed:
        print("\n   ⚠️  WARNING: Trading is not allowed!")
        print("   Enable 'Allow automated trading' in MT5 settings")
    
    if terminal_info.tradeapi_disabled:
        print("\n   ⚠️  WARNING: Trade API is disabled!")
        print("   Enable 'Allow DLL imports' in MT5 settings")

# Try to login
print("\n5. Attempting to login...")
login = 105261321
password = "1LlT+/;$"
server = "FBS-Demo"

authorized = mt5.login(login, password=password, server=server)

if not authorized:
    error = mt5.last_error()
    print(f"   [ERROR] Login failed!")
    print(f"   Error code: {error[0]}")
    print(f"   Error description: {error[1]}")
    print("\n   🔧 Login Solutions:")
    print("   1. Check login credentials")
    print("   2. Make sure server name matches exactly")
    print("   3. Try logging in manually in MT5 first")
    mt5.shutdown()
    sys.exit(1)

print("   ✅ Login successful!")

# Get account info
print("\n6. Getting account information...")
account_info = mt5.account_info()
if account_info:
    print(f"   [OK] Account connected!")
    print(f"   Login: {account_info.login}")
    print(f"   Server: {account_info.server}")
    print(f"   Balance: ${account_info.balance:.2f}")
    print(f"   Equity: ${account_info.equity:.2f}")
    print(f"   Free Margin: ${account_info.margin_free:.2f}")
    print(f"   Margin Level: {account_info.margin_level:.2f}%")
else:
    print("   [WARNING] Could not get account info")

# Test symbol access
print("\n7. Testing symbol access...")
symbols = ["EURUSD", "GBPUSD"]
for symbol in symbols:
    tick = mt5.symbol_info_tick(symbol)
    if tick:
        print(f"   [OK] {symbol}: Bid={tick.bid:.5f}, Ask={tick.ask:.5f}")
    else:
        print(f"   [ERROR] {symbol}: Not available")

print("\n" + "=" * 60)
print("[OK] Connection test complete!")
print("=" * 60)

mt5.shutdown()

