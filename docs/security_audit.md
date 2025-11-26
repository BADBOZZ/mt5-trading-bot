# Security & Safety Audit

## Objectives
- Prevent catastrophic capital loss across strategies and sessions
- Enforce strict per-trade, per-symbol, and aggregate risk constraints
- Provide automated emergency stop with cooldown-based recovery
- Validate incoming orders before they reach the MetaTrader 5 bridge

## Key Controls Implemented
1. **Central Safety Controller** (`security.safety_controller.SafetyController`)
   - Aggregates order validation, account-health checks, and the emergency stop state.
   - Returns structured decisions so the execution layer can block unsafe activity early.
2. **Risk Limit Catalog** (`risk.limits.RiskLimits` & `SymbolRiskLimit`)
   - Defines max drawdowns, leverage, exposure, trade frequency, and symbol-specific limits.
   - Ships with hardened defaults via `default_limits()` but is easily configurable per broker.
3. **Emergency Stop** (`security.emergency_stop.EmergencyStop`)
   - Triggers immediately for daily/total drawdown breaches or negative equity.
   - Enforces a cooldown to prevent thrashing and requires human acknowledgement before trading resumes.
4. **Order Validators** (`security.validators`)
   - Rejects orders outside the permitted trading window and ensures SL/TP, volume, exposure, and leverage remain within policy.
5. **Testing Harness** (`tests/test_safety_controller.py`)
   - Covers edge cases such as missing stop loss, trade limits, exposure overflow, and emergency stop engagement.

## Residual Risks & Mitigations
- **Latency between MT5 and the controller**: mitigated by running the controller in-process with the order generator and upstream throttling.
- **Configuration drift**: store serialized risk limits in version control and require multi-party approval for changes.
- **Broker data integrity**: cross-validate MT5 account metrics with independent telemetry before placing trades.

## Operational Recommendations
- Wire the `SafetyController` as a mandatory dependency in every strategy runner.
- Persist emergency stop state across restarts to avoid bypassing cooldowns.
- Forward `SafetyDecision.reasons` to observability tooling for live compliance dashboards.
- Add integration tests against a simulated MT5 environment before deployment to production accounts.
