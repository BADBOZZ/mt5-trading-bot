# Project Plan – MetaTrader 5 Ultimate EA

## 1. Delivery Overview
- **Objective**: Ship a production-ready, fully documented MQL5 Expert Advisor with multi-strategy execution, HUD overlay, and enterprise-grade risk controls.
- **Methodology**: Hybrid agile (two-week iterations) with stage gates for strategy validation and risk sign-off.
- **Teams**: Architecture, Strategy R&D, Risk & Compliance, UI Overlay, AI/ML, QA & Deployment.

## 2. Milestones & Timeline
| Phase | Duration | Exit Criteria |
| --- | --- | --- |
| P0 – Requirements Finalization | Week 1 | `REQUIREMENTS.md` approved, open questions logged |
| P1 – Architecture & HUD Spec | Week 2 | `MQL5_ARCHITECTURE.md`, HUD mockups validated on MT5 |
| P2 – Core Framework Build | Weeks 3-4 | EA skeleton compiles; symbol router, config loader, event bus ready |
| P3 – Strategy Integration | Weeks 5-6 | Trend, Mean Reversion, Breakout, AI modules produce signals in tester |
| P4 – Risk & Monitoring Hardening | Week 7 | Risk thresholds enforced; alerts + logging verified |
| P5 – Validation & Optimization | Weeks 8-9 | Multi-symbol backtests complete, KPIs achieved |
| P6 – Release & Handover | Week 10 | Documentation, packaging, deployment checklist delivered |

## 3. Workstreams
1. **Architecture & Framework**
   - Define module boundaries, shared services, and data contracts.
   - Owns order execution, position tracker, configuration service.
2. **Strategy R&D**
   - Produce indicator stacks, entry/exit logic, and signal confidence metrics.
   - Ensure per-symbol overrides and walk-forward validation.
3. **HUD & UX**
   - Implement on-chart overlay, interaction model (toggle panels), and performance indicators.
4. **Risk & Compliance**
   - Implement exposure manager, kill-switches, news filters, audit logging.
5. **AI/ML**
   - Build lightweight neural inference or rule-based surrogate with confidence scoring.
6. **QA & Tooling**
   - Manage Strategy Tester scenarios, regression suites, and deployment checklist.

## 4. Iteration Backlog (Initial)
- Sprint 1
  - Finalize inputs schema & default presets.
  - Mock HUD layout via MQL5 objects on demo chart.
  - Build configuration parser (string → symbol arrays) and risk parameter validators.
- Sprint 2
  - Implement event bus, strategy interface, and stub strategies returning demo signals.
  - Develop position registry + exposure tracker.
- Sprint 3
  - Code full Trend & Mean Reversion strategies with MTF confirmation.
  - Integrate risk checks pre/post order submission.
- Sprint 4
  - Add Breakout & AI strategies; wire HUD signal feed.
  - Complete logging, alerts, and news blackout logic.
- Sprint 5
  - Optimization runs, parameter sweeps, forward tests, documentation finalize.

## 5. Dependencies & Assumptions
- Access to MT5 demo accounts with sufficient history for backtests.
- Approval to use lightweight on-terminal ML (matrix ops within CPU limits).
- Team availability: minimum two MT5 developers + one quant + one QA per sprint.
- External data for news/calendar either disabled or proxied through allowed MT5 requests.

## 6. Risk Register
| Risk | Impact | Probability | Mitigation |
| --- | --- | --- | --- |
| HUD performance degradation | High | Medium | Throttle redraws, reuse object pools |
| Neural model too heavy | Medium | Medium | Provide rule-based fallback, compress weights |
| Broker compliance changes | High | Low | Implement configuration per broker, add FIFO toggle |
| Overlapping strategies causing overtrading | High | Medium | Central exposure budget + signal arbitration |
| Testing bottlenecks | Medium | High | Automate Strategy Tester scripts, nightly regressions |

## 7. Communication & Reporting
- Weekly steering meeting reviewing KPIs, blocker list, and risk status.
- Daily async standups summarizing progress & impediments in shared log.
- Dedicated MT5 terminal for HUD demos recorded via screen capture.

## 8. Deliverables Checklist
- ✅ `REQUIREMENTS.md`
- ✅ `PROJECT_PLAN.md`
- 🔜 `MQL5_ARCHITECTURE.md`
- 🔜 MQL5 EA source (`*.mq5`, `*.mqh`)
- 🔜 Test evidence pack (Strategy Tester reports, optimization tables)

## 9. Acceptance & Handover
- Conduct readiness review verifying documentation completeness, strategy KPIs, and risk approvals.
- Package EA with presets, documentation, and deployment SOP.
- Schedule knowledge transfer covering configuration, troubleshooting, and future roadmap.
