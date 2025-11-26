"""Order and position management for MT5."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Dict, List, Optional

from .connection import MT5ConnectionManager
from .exceptions import MT5OrderError, build_error_detail

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class OrderRequest:
    symbol: str
    volume: float
    action: int
    order_type: int
    price: Optional[float] = None
    sl: Optional[float] = None
    tp: Optional[float] = None
    deviation: int = 20
    magic: int = 0
    comment: str = ""
    type_time: Optional[int] = None
    type_filling: Optional[int] = None


class OrderExecutor:
    def __init__(self, connection: MT5ConnectionManager):
        self.connection = connection

    def prepare_market_order(
        self,
        symbol: str,
        volume: float,
        side: str,
        *,
        price: Optional[float] = None,
        sl: Optional[float] = None,
        tp: Optional[float] = None,
        deviation: int = 20,
        magic: int = 0,
        comment: str = "",
    ) -> OrderRequest:
        side_normalized = side.lower()
        if side_normalized not in {"buy", "sell"}:
            raise ValueError("side must be 'buy' or 'sell'")

        api = self.connection.api
        order_type = api.ORDER_TYPE_BUY if side_normalized == "buy" else api.ORDER_TYPE_SELL
        action = api.TRADE_ACTION_DEAL

        if price is None:
            tick = api.symbol_info_tick(symbol)
            if not tick:
                raise MT5OrderError(reason=f"No tick data available for {symbol}")
            price = tick.ask if side_normalized == "buy" else tick.bid

        request = OrderRequest(
            symbol=symbol,
            volume=volume,
            action=action,
            order_type=order_type,
            price=price,
            sl=sl,
            tp=tp,
            deviation=deviation,
            magic=magic,
            comment=comment,
            type_time=self._default_time_policy(),
            type_filling=self._default_fill_policy(),
        )
        logger.debug("Prepared %s market order for %s volume %.2f price %.5f", side_normalized, symbol, volume, price)
        return request

    def send_order(self, request: OrderRequest) -> Dict:
        self.connection.ensure_symbol(request.symbol)
        order_dict = self._to_order_dict(request)
        result = self.connection.api.order_send(order_dict)
        if result is None:
            raise MT5OrderError(reason="Empty response from order_send")
        if result.retcode != self.connection.api.TRADE_RETCODE_DONE:
            detail = build_error_detail((result.retcode, result.comment))
            raise MT5OrderError(detail, reason="MT5 rejected trade")
        logger.info("Order executed: ticket %s for %s volume %.2f", result.order, request.symbol, request.volume)
        return result._asdict()

    def close_position(self, ticket: int, *, deviation: int = 20, comment: str = "close") -> Dict:
        api = self.connection.api
        position = self._get_position(ticket)
        order_type = api.ORDER_TYPE_SELL if position.type == api.ORDER_TYPE_BUY else api.ORDER_TYPE_BUY
        price = self._determine_close_price(position.symbol, order_type)
        request = OrderRequest(
            symbol=position.symbol,
            volume=position.volume,
            action=api.TRADE_ACTION_DEAL,
            order_type=order_type,
            price=price,
            deviation=deviation,
            magic=position.magic,
            comment=comment,
            type_time=api.ORDER_TIME_GTC,
            type_filling=api.ORDER_FILLING_RETURN,
        )
        logger.debug("Closing ticket %s on %s", ticket, position.symbol)
        return self.send_order(request)

    def close_symbol_positions(self, symbol: str) -> List[Dict]:
        api = self.connection.api
        positions = api.positions_get(symbol=symbol)
        if not positions:
            return []
        results: List[Dict] = []
        for position in positions:
            results.append(self.close_position(position.ticket))
        logger.info("Closed %s positions for %s", len(results), symbol)
        return results

    def positions(self, symbol: Optional[str] = None):  # pragma: no cover - passthrough helper
        api = self.connection.api
        if symbol:
            return api.positions_get(symbol=symbol)
        return api.positions_get()

    def _get_position(self, ticket: int):
        api = self.connection.api
        position = api.positions_get(ticket=ticket)
        if not position:
            raise MT5OrderError(reason=f"No position found for ticket {ticket}")
        return position[0]

    def _determine_close_price(self, symbol: str, order_type: int) -> float:
        api = self.connection.api
        tick = api.symbol_info_tick(symbol)
        if not tick:
            raise MT5OrderError(reason=f"No tick data for {symbol}")
        if order_type == api.ORDER_TYPE_BUY:
            return tick.ask
        return tick.bid

    def _to_order_dict(self, request: OrderRequest) -> Dict:
        return {
            "action": request.action,
            "symbol": request.symbol,
            "volume": request.volume,
            "type": request.order_type,
            "price": request.price,
            "sl": request.sl,
            "tp": request.tp,
            "deviation": request.deviation,
            "magic": request.magic,
            "comment": request.comment,
            "type_time": request.type_time,
            "type_filling": request.type_filling,
        }

    def _default_fill_policy(self) -> int:
        api = self.connection.api
        for attr in ("ORDER_FILLING_RETURN", "ORDER_FILLING_IOC", "ORDER_FILLING_FOK"):
            if hasattr(api, attr):
                return getattr(api, attr)
        raise MT5OrderError(reason="No valid filling policy available from MT5 terminal")

    def _default_time_policy(self) -> int:
        api = self.connection.api
        return getattr(api, "ORDER_TIME_GTC", 0)
