# MQL5 Architecture Blueprint

## 1. Runtime Lifecycle
1. **OnInit**
   - Load inputs, parse symbol lists, validate risk caps.
   - Initialize shared services (configuration, symbol router, exposure manager, HUD controller).
   - Spawn strategy instances per eligible symbol via factory (`CStrategyFactory`).
   - Build chart objects (HUD panels, status labels, log window) and register timers.
2. **OnTick**
   - Route tick to `MarketDataBus`, notifying subscribed strategies for that symbol.
   - Execute strategy evaluations respecting per-strategy throttling and timeframe confirmation buffers.
   - Push resulting signals to `ExecutionCoordinator` after risk pre-checks.
   - Update HUD elements affected by price/position changes.
3. **OnTimer**
   - Refresh slower-moving metrics (daily P&L, drawdown, confidence trends).
   - Trigger AI context detection and news blackout polling.
4. **OnTradeTransaction**
   - Sync internal position registry, update exposure, annotate HUD, and log trade lifecycle events.
5. **OnDeinit**
   - Persist stats, destroy chart objects, release resources.

## 2. Module Stack
- `ConfigService`
  - Parses input strings into typed settings, manages defaults, and exposes read-only getters.
- `SymbolRouter`
  - Maintains mapping of strategies → symbol sets, ensuring only eligible ticks processed.
- `StrategyKernel`
  - Abstract base class (`CBaseStrategy`) defining hooks: `OnTick`, `GenerateSignal`, `OnBarClose`.
  - Derived classes: `CTrendStrategy`, `CMeanReversionStrategy`, `CBreakoutStrategy`, `CAIStrategy`.
- `RiskEngine`
  - Components: `PositionSizer`, `ExposureGuard`, `DrawdownMonitor`, `DailyLossMonitor`, `SlotManager`.
  - Provides `bool CanTrade(const Signal&)` and `TradeBudget CalculateOrder(const Signal&)` APIs.
- `ExecutionCoordinator`
  - Converts signals into trade requests, handles partial fills, manages trailing stops.
- `HUDController`
  - Encapsulates chart objects, layering, color palettes, and refresh scheduling.
- `AnalyticsBus`
  - Aggregates stats per strategy/symbol for HUD and logging.
- `PersistenceLayer`
  - Saves runtime metrics to Global Variables or files for continuity.

## 3. Data Flow (Textual Diagram)
```
Tick -> MarketDataBus -> StrategyKernel (per strategy & symbol)
      -> SignalQueue -> RiskEngine -> ExecutionCoordinator -> TradeServer
TradeTransaction -> PositionRegistry -> HUDController & AnalyticsBus
Timer -> AIContextDetector -> StrategyGates & HUD
```

## 4. Strategy Design Highlights
- **Trend Strategy**
  - Uses EMA cross with ADX filter; requires H4 trend alignment before M30 entries.
  - Supports configurable pullback depth and break-even logic.
- **Mean Reversion**
  - Bollinger (20,2) band touches + RSI(14) extremes; ATR filter to avoid high-vol markets.
- **Breakout**
  - Detects NR4/NR7 style ranges, confirms with tick volume percentile and momentum burst.
- **AI Strategy**
  - Loads coefficient matrices from resource file or embedded arrays.
  - Generates regime-tagged confidence; only promotes signals when `confidence >= inputConfidenceMin`.
- All strategies implement `SerializeState` for persistence and report telemetry to HUD.

## 5. Risk Management Architecture
- **Position Sizing**: `PositionSizer::CalcLots(signal)` uses `%RiskPerTrade`, ATR-based stop distance.
- **Exposure Guard**: Aggregates USD notional per currency leg; rejects trades exceeding `MaxExposureLots` or correlated cap.
- **Drawdown Monitor**: Tracks equity high-water mark, halts trading when drop exceeds `MaxDrawdownPercent`.
- **Daily Loss Monitor**: Resets at broker day start; sets system to `HALTED` mode when breached.
- **Slot Manager**: Maintains semaphore-like counters per symbol and globally to honor `MaxPositionsPerSymbol` and `MaxTotalPositions`.
- **Kill Switch**: Manual input or auto-trigger from news calendar; sets `Mode=SAFE` preventing new orders while allowing exits.

## 6. Visual Overlay / HUD
- **Main Panel (`OBJ_RECTANGLE_LABEL`)** showing account metrics: balance, equity, daily P&L bar, current drawdown.
- **Positions Table** built from stacked `OBJ_LABEL`s listing symbol, lots, P&L, elapsed time.
- **Strategy Widgets** with traffic-light indicators (green=enabled, yellow=warming, red=disabled) including last signal timestamp and confidence.
- **Signal Markers**: `OBJ_ARROW_BUY/SELL` placed at entries, `OBJ_TREND` lines for SL/TP projections, color-coded per strategy.
- **Risk Alerts**: Flashing label when >80% daily loss or drawdown thresholds reached; optional sound/push notification.
- **Interaction**: HUD toggle via hotkey or on-chart button (`OBJ_BUTTON`) to switch between compact/full views.

## 7. Configuration Schema (Key Inputs)
- `input string SymbolsMasterList`
- `input string TrendSymbols`, `input ENUM_TIMEFRAMES TrendHigherTF`, `input ENUM_TIMEFRAMES TrendSignalTF`
- `input bool EnableMeanReversion`, etc.
- `input double RiskPerTradePercent`, `input double MaxDrawdownPercent`, `input double DailyLossLimitPercent`
- `input int MaxPositionsPerSymbol`, `input int MaxTotalPositions`
- `input bool EnableHUD`, `input color HudPrimaryColor`
- `input double AiConfidenceThreshold`
- `input bool EnableNewsFilter`, `input string NewsCalendarUrl`

## 8. AI / Pattern Recognition
- Lightweight neural net (e.g., 3-layer perceptron) implemented via matrix ops in MQL5 arrays.
- Features: normalized RSI, MACD slope, ATR percentile, volume delta, regime flags.
- Outputs: `confidence`, `regime_class`. Stored in `SignalContext` struct for downstream consumption.
- Provide fallback heuristics triggered when AI disabled or data incomplete.

## 9. Testing & Validation Hooks
- `TestScenario` enum enabling deterministic modes (trend-only, mean-revert-only) for Strategy Tester.
- Built-in metrics collector producing JSON/CSV summary of win rate, expectancy, average drawdown.
- HUD debug overlay showing tick/perf counters to profile rendering impact.
- Logging macros wrapping `PrintFormat` with module tags for faster triage.

## 10. File Structure (Target)
```
UltimateEA/
  UltimateEA.mq5                 // main entry coordinating services
  config/
    Inputs.mqh                   // input declarations & validation helpers
  core/
    AppContext.mqh
    MarketDataBus.mqh
    ExecutionCoordinator.mqh
  strategies/
    StrategyBase.mqh
    TrendStrategy.mqh
    MeanReversionStrategy.mqh
    BreakoutStrategy.mqh
    AIStrategy.mqh
  risk/
    PositionSizer.mqh
    ExposureGuard.mqh
    DrawdownMonitor.mqh
  hud/
    HudController.mqh
    HudLayouts.mqh
  ai/
    FeatureBuilder.mqh
    NeuralModel.mqh
  utils/
    Logger.mqh
    MathHelpers.mqh
```

This architecture ensures every requirement—multi-strategy execution, rich HUD, risk discipline, and AI enhancements—is encapsulated in a maintainable, testable MQL5 codebase.
