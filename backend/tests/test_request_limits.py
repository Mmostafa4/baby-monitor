import asyncio
import unittest

from app.request_limits import MaxRequestBodySize


class RequestBodyTooLargeTests(unittest.TestCase):
    def run_asgi(
        self,
        *,
        chunks,
        max_bytes,
        content_length=None,
        path="/v1/cry-analysis",
        paths=None,
    ):
        events = []
        app_called = False
        messages = [
            {"type": "http.request", "body": chunk, "more_body": index < len(chunks) - 1}
            for index, chunk in enumerate(chunks)
        ]
        next_message = 0

        async def receive():
            nonlocal next_message
            message = messages[next_message]
            next_message += 1
            return message

        async def send(message):
            events.append(message)

        async def app(scope, receive_inner, send_inner):
            nonlocal app_called
            app_called = True
            body = bytearray()
            while True:
                message = await receive_inner()
                body.extend(message.get("body", b""))
                if not message.get("more_body", False):
                    break
            await send_inner({"type": "http.response.start", "status": 200, "headers": []})
            await send_inner({"type": "http.response.body", "body": bytes(body)})

        headers = []
        if content_length is not None:
            headers.append((b"content-length", str(content_length).encode("ascii")))
        scope = {"type": "http", "method": "POST", "path": path, "headers": headers}

        middleware = MaxRequestBodySize(app, max_bytes, paths=paths)
        asyncio.run(middleware(scope, receive, send))
        return events, app_called

    def test_rejects_declared_oversized_body_before_calling_app(self):
        events, app_called = self.run_asgi(
            chunks=[b"12345"], max_bytes=4, content_length=5
        )
        self.assertEqual(events[0]["status"], 413)
        self.assertFalse(app_called)

    def test_rejects_streamed_oversized_body_without_content_length(self):
        events, app_called = self.run_asgi(chunks=[b"12", b"345"], max_bytes=4)
        self.assertEqual(events[0]["status"], 413)
        self.assertFalse(app_called)

    def test_forwards_body_at_limit(self):
        events, app_called = self.run_asgi(chunks=[b"12", b"34"], max_bytes=4)
        self.assertEqual(events[0]["status"], 200)
        self.assertEqual(events[1]["body"], b"1234")
        self.assertTrue(app_called)

    def test_can_protect_a_second_json_endpoint(self):
        events, app_called = self.run_asgi(
            chunks=[b"12345"],
            max_bytes=4,
            path="/v1/newborn-assistant",
            paths={"/v1/newborn-assistant"},
        )
        self.assertEqual(events[0]["status"], 413)
        self.assertFalse(app_called)


if __name__ == "__main__":
    unittest.main()
