"""Smoke tests for the monitoring helpers."""

from __future__ import annotations

import unittest

from src.monitoring.performance import (
    DrawdownThresholds,
    MQLPerformanceBridge,
    PerformanceBuffer,
)


class MonitoringPerformanceTests(unittest.TestCase):
    def test_buffer_retains_latest_sample(self) -> None:
        buffer = PerformanceBuffer(maxlen=2)
        buffer.push(1_000, 1_020, 5.5)
        buffer.push(1_005, 990, -12.0)

        tail = buffer.tail()
        self.assertIsNotNone(tail)
        self.assertEqual(tail.equity, 990)
        self.assertEqual(len(buffer), 2)

    def test_bridge_payloads_include_paths_and_metrics(self) -> None:
        thresholds = DrawdownThresholds(warn=1.5, critical=3.0)
        buffer = PerformanceBuffer(maxlen=1)
        bridge = MQLPerformanceBridge(thresholds, buffer)

        buffer.push(1_000, 980, -25.0)

        bootstrap = bridge.build_bootstrap_payload()
        snapshot = bridge.build_snapshot_payload()

        self.assertEqual(bootstrap["warn_drawdown_percent"], 1.5)
        self.assertEqual(bootstrap["critical_drawdown_percent"], 3.0)
        self.assertIn("logger_library", bootstrap)
        self.assertEqual(snapshot["equity"], 980)
        self.assertEqual(snapshot["balance"], 1_000)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
