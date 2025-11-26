# MetaTrader 5 Trading Bot Program

A multi-pair, multi-strategy Expert Advisor (EA) blueprint for MetaTrader 5 that blends classical technical setups, machine learning driven context detection, and strict risk governance. This repository currently focuses on the systems design, documentation, and coordination plan required to deliver a production-grade `.mq5` EA.

## Mission Objectives
- Execute exclusively on MetaTrader 5 using native MQL5 code and chart objects.
- Trade configurable baskets of majors, crosses, and exotics with per-strategy symbol scopes.
- Run four core strategy families (trend, mean reversion, breakout, neural/AI) concurrently per symbol.
- Provide a visual heads-up display (HUD) on every attached chart covering positions, P&L, active signals, risk limits, and entry/exit markers.
- Enforce layered risk constraints: position sizing by account risk %, global exposure caps, daily loss, drawdown, and per-symbol slot limits.
- Embed ML-driven pattern recognition plus signal confidence scoring when platform resources allow.

## Repository Layout
- `PROJECT_PLAN.md` – delivery roadmap, milestones, and workstream ownership.
- `REQUIREMENTS.md` – detailed functional, non-functional, and compliance requirements.
- `MQL5_ARCHITECTURE.md` – EA component diagram, data flows, overlay spec, and strategy modules.
- `mt5-trading-bot/` – legacy Python research utilities; retained for reference but **not** part of the final EA deliverable.

## Documentation-Driven Build Flow
1. **Requirements Alignment** – capture trading, risk, UX, and operational expectations in `REQUIREMENTS.md`.
2. **Architecture Finalization** – map modules, classes, events, and message buses in `MQL5_ARCHITECTURE.md`.
3. **Planning & Resourcing** – assign responsibilities and iteration cadence via `PROJECT_PLAN.md`.
4. **MQL5 Implementation** – generate `.mq5` source from the approved specs; prioritize overlay and risk controls.
5. **Validation & Sign-off** – integrate strategy analytics, run MT5 strategy tester, then stage for production.

## Getting Started
- Review the requirements and architecture documents to align on scope.
- Use the project plan to identify the next actionable workstream (overlay, strategies, risk, AI, QA, etc.).
- When coding begins, create a new MT5 project (`File > New > Expert Advisor (template)`) and port the defined modules into `.mqh`/`.mq5` files following the architecture document.

## Status
Planning & architecture phase in progress. No MT5 EA source has been checked in yet—subsequent commits must introduce the actual `.mq5` implementation adhering to the specifications above.
