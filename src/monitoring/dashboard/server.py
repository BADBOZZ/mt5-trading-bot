from __future__ import annotations

import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Dict, Optional

if False:  # pragma: no cover - for type checking only
    from ..manager import MonitoringManager


class MonitoringDashboard:
    """Lightweight HTTP server that exposes monitoring snapshots."""

    def __init__(
        self,
        manager: "MonitoringManager",
        host: str,
        port: int,
    ) -> None:
        self.manager = manager
        self.host = host
        self.port = port
        self._server: Optional[ThreadingHTTPServer] = None
        self._thread: Optional[threading.Thread] = None

    def start(self) -> None:
        if self._server:
            return
        handler_cls = self._handler_factory()
        self._server = ThreadingHTTPServer((self.host, self.port), handler_cls)
        self._thread = threading.Thread(
            target=self._server.serve_forever, daemon=True
        )
        self._thread.start()

    def stop(self) -> None:
        if not self._server:
            return
        self._server.shutdown()
        self._server.server_close()
        self._server = None
        if self._thread:
            self._thread.join(timeout=1)
            self._thread = None

    def _handler_factory(self):
        manager = self.manager

        class DashboardHandler(BaseHTTPRequestHandler):
            def do_GET(self) -> None:  # type: ignore[override]
                if self.path == "/metrics":
                    self._respond_json(manager.metrics_snapshot())
                elif self.path == "/alerts":
                    self._respond_json({"alerts": manager.recent_alerts()})
                elif self.path == "/health":
                    self._respond_json(manager.healthcheck())
                else:
                    self._respond_json(
                        {
                            "service": "mt5-monitoring-dashboard",
                            "metrics_url": "/metrics",
                            "alerts_url": "/alerts",
                            "health_url": "/health",
                        }
                    )

            def log_message(self, *_args: Any) -> None:  # silence default logging
                return

            def _respond_json(self, payload: Dict[str, Any]) -> None:
                body = json.dumps(payload).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        return DashboardHandler
