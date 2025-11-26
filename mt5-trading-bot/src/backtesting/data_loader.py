from __future__ import annotations

import csv
import json
from dataclasses import dataclass
from io import StringIO
from pathlib import Path
from typing import Dict, List
from html.parser import HTMLParser


class _DealsTableParser(HTMLParser):
    """Minimal HTML table parser that extracts the MT5 deals table."""

    def __init__(self) -> None:
        super().__init__()
        self._in_table = False
        self._in_cell = False
        self._current_row: List[str] = []
        self._pending_rows: List[List[str]] = []
        self.rows: List[List[str]] = []

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self._start_table()
        elif self._in_table and tag == "tr":
            self._current_row = []
        elif self._in_table and tag in {"td", "th"}:
            self._in_cell = True
            self._current_cell: List[str] = []

    def handle_endtag(self, tag):
        if self._in_table and tag in {"td", "th"}:
            self._in_cell = False
            cell_text = " ".join(self._current_cell).strip()
            self._current_row.append(cell_text)
        elif self._in_table and tag == "tr" and self._current_row:
            self._pending_rows.append(self._current_row)
            self._current_row = []
        elif tag == "table" and self._in_table:
            self._finish_table()

    def handle_data(self, data):
        if self._in_cell:
            self._current_cell.append(data)

    def _start_table(self):
        if not self._in_table:
            self._in_table = True
            self._pending_rows = []

    def _finish_table(self):
        if self._looks_like_deals(self._pending_rows):
            self.rows = self._pending_rows
        self._in_table = False
        self._pending_rows = []

    @staticmethod
    def _looks_like_deals(rows: List[List[str]]) -> bool:
        if not rows:
            return False
        header = [column.lower() for column in rows[0]]
        return "deal" in " ".join(header) and any("profit" in col for col in header)


@dataclass
class TradeHistoryExporter:
    """Transforms MT5 HTML reports into CSV-friendly structures."""

    report_html: Path

    def extract_trades(self) -> List[str]:
        if not self.report_html.exists():
            raise FileNotFoundError(f"Report not found: {self.report_html}")
        parser = _DealsTableParser()
        parser.feed(self.report_html.read_text(encoding="utf-8"))
        rows = parser.rows
        if not rows:
            return []
        return self._rows_to_csv_lines(rows)

    @staticmethod
    def _rows_to_csv_lines(rows: List[List[str]]) -> List[str]:
        buffer = StringIO()
        writer = csv.writer(buffer)
        writer.writerows(rows)
        buffer.seek(0)
        return buffer.read().strip().splitlines()


@dataclass
class BacktestReportBuilder:
    """Produces structured JSON backtest reports."""

    trades_csv: Path
    metrics: Dict[str, float]

    def build(self, output_json: Path) -> Path:
        payload = {
            "metrics": self.metrics,
            "trades": self._load_trades(),
        }
        output_json.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        return output_json

    def _load_trades(self) -> List[Dict[str, str]]:
        if not self.trades_csv.exists():
            return []
        with self.trades_csv.open(encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            return list(reader)
