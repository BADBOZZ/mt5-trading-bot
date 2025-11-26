# Requirements Specification

## 1. Context
- **Platform**: Native MetaTrader 5 Expert Advisor written exclusively in MQL5 (`.mq5` + `.mqh`).
- **Deployment**: Runs on any MT5 terminal that exposes supported liquidity providers, default focus on major FX pairs with capability for crosses and exotics.
- **Goal**: Deliver a self-governing, multi-strategy EA with comprehensive visual telemetry and hard risk controls suitable for prop-firm and brokerage accounts.

## 2. Functional Requirements
### 2.1 Platform & Execution
1. FR-P1 – EA must compile and run in MetaEditor 5 without reliance on external Python/ DLL bridges.
2. FR-P2 – All chart overlays must be built using standard MQL5 graphical objects: `OBJ_LABEL`, `OBJ_RECTANGLE_LABEL`, `OBJ_ARROW`, `OBJ_TREND`, etc.
3. FR-P3 – EA must support multiple simultaneous chart attachments while sharing data through global variables or `CAppDialog` style managers.

### 2.2 Symbol & Timeframe Management
1. FR-S1 – Provide an input `SymbolsMasterList` (comma-separated) defaulting to `EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,NZDUSD,USDCHF`.
2. FR-S2 – Allow per-strategy symbol overrides (e.g., `TrendSymbols`, `MeanRevSymbols`, `BreakoutSymbols`, `AISymbols`).
3. FR-S3 – Support timeframe inputs for signal analysis vs execution timeframe (e.g., `TrendHigherTF`, `TrendSignalTF`).
4. FR-S4 – Respect market session filters (e.g., exclude low-liquidity hours for exotics) via input flags.

### 2.3 Strategy Framework
1. FR-ST1 – Trend-following module using multi-timeframe confirmation (e.g., H4 direction + M30 trigger) with configurable MA/ADX parameters.
2. FR-ST2 – Mean reversion strategy combining RSI bands and Bollinger deviations with optional volatility filter.
3. FR-ST3 – Breakout engine detecting range consolidation and confirming via tick volume / delta volume spike.
4. FR-ST4 – Neural/AI strategy leveraging either embedded lightweight model coefficients or rule-based surrogate while maintaining deterministic fallbacks.
5. FR-ST5 – Each strategy must operate independently per symbol with its own enable/disable input and risk budget.
6. FR-ST6 – Strategies publish structured signals `{symbol, direction, confidence, SL, TP, expiry}` to a shared bus consumed by the execution layer.

### 2.4 Risk Management
1. FR-R1 – Position sizing derived from configurable `%RiskPerTrade` relative to free margin and stop distance.
2. FR-R2 – Enforce per-trade stop loss (pips, ATR-based, or structure-based) and take profit inputs.
3. FR-R3 – Track and halt trading when `DailyLossLimit` or `MaxDrawdownPercent` breached.
4. FR-R4 – Cap concurrent positions by `MaxPositionsPerSymbol` and `MaxTotalPositions`.
5. FR-R5 – Monitor `MaxExposureLots` across correlated symbols using USD notional aggregation.
6. FR-R6 – Include kill-switch for news blackout windows and manual override.

### 2.5 Visual Overlay / HUD
1. FR-V1 – Display current open positions (symbol, direction, lot, P&L, time open).
2. FR-V2 – Show daily and session P&L, drawdown, and margin usage bars.
3. FR-V3 – Render per-strategy status: enabled/disabled, last signal, win rate, confidence.
4. FR-V4 – Plot entry and exit markers on the chart using arrows and dotted lines.
5. FR-V5 – Highlight upcoming risk limits (e.g., flashing label when 80% of daily loss reached).
6. FR-V6 – Provide compact legend for color coding to avoid clutter.

### 2.6 Configuration & Persistence
1. FR-C1 – All tunable values exposed as `input` variables with sensible defaults and validation.
2. FR-C2 – Allow importing/exporting JSON-like presets via `WebRequest` or file read if permitted.
3. FR-C3 – Persist runtime stats (win rate, trade count) using MT5 global variables or files for continuity between terminal restarts.

### 2.7 Monitoring & Alerting
1. FR-M1 – Log every signal, order submission, modification, and closure to the Experts log plus optional CSV file.
2. FR-M2 – Trigger alerts/push notifications for critical events (drawdown breach, strategy halt, connection loss).
3. FR-M3 – Provide optional integration with dashboard via sockets/HTTP when MT5 permissions allow.

### 2.8 AI / ML Enhancements
1. FR-AI1 – Run lightweight pattern recognition (candlestick clusters, volatility regimes) and output confidence scores 0–1.
2. FR-AI2 – Use AI signal only when confidence exceeds input threshold; otherwise rely on classical setups.
3. FR-AI3 – Automatically tag market condition (trend, range, breakout) for overlay display and strategy gating.

## 3. Non-Functional Requirements
1. NFR-1 – EA must process each tick within 10ms on a standard VPS (2 vCPU, 4GB RAM).
2. NFR-2 – GUI overlay should refresh no faster than 200ms to avoid resource spikes.
3. NFR-3 – Code must compartmentalize logic into `.mqh` modules with clear interfaces to simplify audits.
4. NFR-4 – Provide detailed inline comments for complex calculations, while keeping UI objects reusable.
5. NFR-5 – All risk limits default to conservative values and fail-safe to "trade disabled" on configuration errors.
6. NFR-6 – Adhere to broker compliance constraints (no hedging where prohibited, respect FIFO if enabled).

## 4. Acceptance Criteria
- Demonstrate on MT5 Strategy Tester: simultaneous multi-symbol trading with at least two enabled strategies.
- HUD accurately mirrors terminal trade list data and updates with <250ms lag.
- Risk engine blocks orders when thresholds reached and resumes after manual reset flag.
- Strategy toggles and symbol lists configurable from Inputs dialog without recompilation.
- Logs show AI confidence values and market regime tags for each executed trade.

## 5. Open Questions
1. Confirm brokers/exchanges requiring FIFO compliance and whether partial close is allowed.
2. Determine whether on-terminal neural models can load from file or must be hardcoded coefficients.
3. Clarify dashboard communication channel (local socket vs REST) for monitoring team.
