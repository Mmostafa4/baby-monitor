from __future__ import annotations

import asyncio
from typing import Any, Awaitable, Callable


ASGIApp = Callable[
    [
        dict[str, Any],
        Callable[..., Awaitable[dict[str, Any]]],
        Callable[..., Awaitable[None]],
    ],
    Awaitable[None],
]


class MaxRequestBodySize:
    """Buffer small preview uploads in memory and reject oversized bodies early."""

    def __init__(
        self,
        app: ASGIApp,
        max_bytes: int,
        max_concurrent: int = 2,
        paths: set[str] | None = None,
    ) -> None:
        self.app = app
        self.max_bytes = max_bytes
        self.upload_slots = asyncio.Semaphore(max_concurrent)
        self.paths = paths or {"/v1/cry-analysis"}

    async def __call__(self, scope, receive, send) -> None:
        if (
            scope.get("type") != "http"
            or scope.get("method") != "POST"
            or scope.get("path") not in self.paths
        ):
            await self.app(scope, receive, send)
            return

        content_length = None
        for key, value in scope.get("headers", []):
            if key.lower() == b"content-length":
                try:
                    content_length = int(value)
                except ValueError:
                    content_length = None
                break
        if content_length is not None and content_length > self.max_bytes:
            await self._respond_too_large(send)
            return

        async with self.upload_slots:
            buffered: list[dict[str, Any]] = []
            total_bytes = 0
            while True:
                message = await receive()
                if message["type"] != "http.request":
                    buffered.append(message)
                    break

                total_bytes += len(message.get("body", b""))
                if total_bytes > self.max_bytes:
                    await self._respond_too_large(send)
                    return

                buffered.append(message)
                if not message.get("more_body", False):
                    break

            position = 0

            async def replay_receive() -> dict[str, Any]:
                nonlocal position
                if position < len(buffered):
                    message = buffered[position]
                    position += 1
                    return message
                return await receive()

            await self.app(scope, replay_receive, send)

    async def _respond_too_large(self, send) -> None:
        body = b'{"detail":"Request body is too large for preview analysis."}'
        await send(
            {
                "type": "http.response.start",
                "status": 413,
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"content-length", str(len(body)).encode("ascii")),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body, "more_body": False})
