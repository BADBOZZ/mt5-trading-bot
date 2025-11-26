# Rebuild MT5 EA Bot - Instructions

## What I've Done

I've created a comprehensive rebuild script that will update your project configuration and restart the agent team to build the **ultimate MQL5 Expert Advisor** as promised.

## The Script

**Location:** `backend/rebuild-mt5-ea-bot.js`

**What it does:**
1. Updates the project configuration with proper MQL5 EA requirements
2. Defines 9 specialized agents with clear roles
3. Restarts the parallel workflow to build the EA

## Critical Requirements Set

The script configures the agents to build:

### ✅ **MQL5 Expert Advisor (NOT Python)**
- All code must be in MQL5 (.mq5, .mqh files)
- Native MT5 integration
- Expert Advisor format

### ✅ **Visual Overlay on MT5 Charts**
- Real-time information display on charts
- Position tracking panel
- Signal visualization
- Risk metrics display
- Uses MQL5 Objects (labels, rectangles, lines)

### ✅ **Multi-Pair Trading**
- Configurable symbol lists
- Per-strategy symbol configuration
- Support for major pairs + crosses
- Input parameters for easy configuration

### ✅ **Multiple Strategies**
- Trend Following
- Mean Reversion
- Breakout
- Neural Network (if possible)
- Each strategy works independently per symbol

### ✅ **Comprehensive Risk Management**
- Position sizing based on risk %
- Stop loss/take profit
- Daily loss limits
- Drawdown limits
- Maximum positions per symbol

## Agent Team (9 Specialized Agents)

1. **Project Manager & MQL5 EA Architect** - Overall architecture and coordination
2. **Risk Management Specialist** - Risk limits, position sizing, safety
3. **Trading Strategy Developer** - Multiple strategies per symbol
4. **UI Overlay Developer** - **CRITICAL** - Creates the visual overlay on charts
5. **MT5 Integration Specialist** - Order management, market data
6. **Neural Network Engineer** - AI/ML integration
7. **Backtesting Engineer** - Strategy testing and optimization
8. **Monitoring Developer** - Logging and alerts
9. **Security Auditor** - Safety validation and testing

## How to Run

### Prerequisites:
1. Backend must be running (or have .env configured)
2. Database connection must be available
3. Cursor API key must be set

### Steps:

1. **Start the backend** (if not running):
   ```bash
   docker-compose up -d backend
   # OR
   cd backend && npm start
   ```

2. **Run the rebuild script**:
   ```bash
   node backend/rebuild-mt5-ea-bot.js
   ```

3. **Monitor the agents**:
   - Check the frontend UI at http://localhost:3001
   - View agent progress in the Agents tab
   - Check the project repository for commits

## What Will Be Built

The agents will create:

### Core Files:
- `UltimateTradingBot.mq5` - Main Expert Advisor
- `src/risk/RiskManager.mq5` - Risk management
- `src/strategies/*.mq5` - Multiple trading strategies
- `src/ui/ChartOverlay.mq5` - **Visual overlay on charts**
- `src/mt5/OrderManager.mq5` - Order execution
- `src/config/*.mqh` - Configuration files

### Features:
- ✅ Visual overlay on MT5 charts showing positions, signals, P&L
- ✅ Multiple currency pairs (configurable)
- ✅ Multiple strategies per symbol
- ✅ Comprehensive risk management
- ✅ AI/ML integration (if possible in MQL5)
- ✅ Backtesting support
- ✅ Monitoring and alerts

## Expected Timeline

With 9 agents working in parallel:
- **Initial setup:** 1-2 hours (Project Manager, Risk Manager, Strategy Developer)
- **Core development:** 4-6 hours (UI Overlay, MT5 Integration, Neural Network)
- **Testing & polish:** 2-3 hours (Backtesting, Monitoring, Security)
- **Total:** ~8-12 hours for complete EA

## Monitoring Progress

1. **Frontend UI:** http://localhost:3001
   - Go to Projects → MetaTrader 5 Trading Bot
   - View agent status and commits

2. **Repository:** Check GitHub for commits
   - Each agent will make multiple commits
   - Look for .mq5 and .mqh files

3. **Agent Logs:** Check backend logs for agent activity

## What's Different This Time

### Previous Build (What Went Wrong):
- ❌ Built Python bot (can't create overlay)
- ❌ Only 2 hardcoded pairs
- ❌ No configuration system
- ❌ Unused modules
- ❌ No visual overlay

### This Build (What Will Be Right):
- ✅ MQL5 Expert Advisor (can create overlay)
- ✅ Multiple pairs via configuration
- ✅ Full configuration system
- ✅ All modules integrated
- ✅ **Visual overlay on MT5 charts**

## Troubleshooting

### If script fails with database error:
- Make sure backend is running
- Check .env file has DATABASE_URL
- Verify database connection

### If agents don't start:
- Check CURSOR_API_KEY is set
- Verify project exists in database
- Check backend logs for errors

### If agents create wrong files:
- The prompts are very specific about MQL5
- UI Overlay Developer has explicit overlay requirements
- All agents know it's MQL5, not Python

## Next Steps After Build

1. **Compile the EA:**
   - Open MT5 MetaEditor
   - Compile UltimateTradingBot.mq5
   - Fix any compilation errors

2. **Test in Strategy Tester:**
   - Run backtests on historical data
   - Optimize parameters
   - Validate strategies

3. **Deploy to Demo:**
   - Attach EA to chart
   - Configure symbols and risk
   - Monitor overlay display
   - Test live trading

4. **Go Live:**
   - After thorough testing
   - Start with small risk
   - Monitor closely

---

**The team is ready to build the ultimate MQL5 EA bot with visual overlay!**

Run the script when ready: `node backend/rebuild-mt5-ea-bot.js`

