"""Unit tests for MT5 integration layers using a fake MetaTrader API."""

from __future__ import annotations

from collections import namedtuple

import pytest

from mt5 import (
    MT5AccountManager,
    MT5Config,
    MT5ConnectionManager,
    MarketDataStreamer,
    OrderExecutor,
)
from mt5.exceptions import MT5ConnectionError


class FakeMT5:
    ORDER_TYPE_BUY = 0
    ORDER_TYPE_SELL = 1
    ORDER_FILLING_RETURN = 0
    ORDER_TIME_GTC = 0
    TRADE_ACTION_DEAL = 2
    TRADE_RETCODE_DONE = 10009
    TIMEFRAME_M1 = 1

    def __init__(self, *, can_initialize: bool = True):
        self.can_initialize = can_initialize
        self.initialized = False
        self.symbols = set()
        self._next_ticket = 1

    def initialize(self, **kwargs):
        self.initialized = self.can_initialize
        return self.can_initialize

    def last_error(self):  # pragma: no cover - used when init fails
        return (500, "init failed")

    def shutdown(self):
        self.initialized = False
        return True

    def symbol_select(self, symbol, enable):
        if not self.initialized:
            return False
        if enable:
            self.symbols.add(symbol)
        return True

    def terminal_info(self):
        if not self.initialized:
            return None
        return object()

    def account_info(self):
        AccountInfo = namedtuple(
            "AccountInfo",
            "login name leverage balance equity margin margin_free margin_level currency",
        )
        return AccountInfo(
            login=105261321,
            name="Demo",
            leverage=500,
            balance=1_000.0,
            equity=1_000.0,
            margin=0.0,
            margin_free=1_000.0,
            margin_level=1_000.0,
            currency="USD",
        )

    def symbol_info_tick(self, symbol):
        Tick = namedtuple("Tick", "time_msc bid ask last volume")
        return Tick(time_msc=0, bid=1.0, ask=1.1, last=1.05, volume=100)

    def order_send(self, request):
        Result = namedtuple("Result", "retcode comment order volume request")
        result = Result(
            retcode=self.TRADE_RETCODE_DONE,
            comment="ok",
            order=self._next_ticket,
            volume=request["volume"],
            request=request,
        )
        self._next_ticket += 1
        return result

    def positions_get(self, **kwargs):
        Position = namedtuple("Position", "ticket symbol type volume magic")
        if "ticket" in kwargs:
            return [
                Position(ticket=kwargs["ticket"], symbol="EURUSD", type=self.ORDER_TYPE_BUY, volume=0.1, magic=0)
            ]
        if "symbol" in kwargs:
            return [Position(ticket=1, symbol=kwargs["symbol"], type=self.ORDER_TYPE_BUY, volume=0.1, magic=0)]
        return []

    def copy_rates_from_pos(self, symbol, timeframe, start_pos, count):
        Rate = namedtuple("Rate", "time open high low close tick_volume")
        return [Rate(time=0, open=1.0, high=1.2, low=0.9, close=1.1, tick_volume=111)]


class FlakyMT5(FakeMT5):
    def __init__(self):
        super().__init__(can_initialize=False)
        self.attempts = 0

    def initialize(self, **kwargs):
        self.attempts += 1
        return False

    def last_error(self):
        return (501, "forced failure")


def test_connection_and_account_summary():
    api = FakeMT5()
    config = MT5Config(password="secret")
    manager = MT5ConnectionManager(config, api=api)
    manager.connect(auto_select_symbols=["EURUSD"])

    summary = MT5AccountManager(manager).summary()
    assert summary.login == config.login
    assert "EURUSD" in api.symbols


def test_order_executor_submits_market_order():
    api = FakeMT5()
    config = MT5Config()
    manager = MT5ConnectionManager(config, api=api)
    manager.connect(auto_select_symbols=["EURUSD"])
    executor = OrderExecutor(manager)

    request = executor.prepare_market_order("EURUSD", 0.1, "buy")
    result = executor.send_order(request)

    assert result["order"] == 1
    assert result["volume"] == pytest.approx(0.1)


def test_connection_failure_raises_after_retries():
    api = FlakyMT5()
    config = MT5Config(retries=1)
    manager = MT5ConnectionManager(config, api=api)

    with pytest.raises(MT5ConnectionError):
        manager.connect()


def test_market_data_subscriptions_register_without_starting_thread():
    api = FakeMT5()
    manager = MT5ConnectionManager(MT5Config(), api=api)
    manager.connect(auto_select_symbols=["EURUSD"])
    streamer = MarketDataStreamer(manager, poll_interval=0.01)
    streamer._ensure_running = lambda: None  # prevent background thread

    streamer.subscribe_ticks("EURUSD", lambda tick: None)
    streamer.subscribe_rates("EURUSD", "M1", lambda bar: None)

    assert "EURUSD" in streamer._tick_subscriptions
    assert ("EURUSD", api.TIMEFRAME_M1) in streamer._rate_subscriptions