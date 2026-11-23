# A stand-in for the OpenAI API, used by the smoke test so a chat can run end
# to end without a real key. Lists one model and answers every chat with a
# fixed reply. Requests must carry the key the test configured.
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

KEY = os.environ.get("FAKE_OPENAI_KEY", "smoke-openai-key")
MODEL = "smoke-model"
REPLY = "Hello from the smoke test model."


class Handler(BaseHTTPRequestHandler):
    def send_json(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def authorized(self):
        if self.headers.get("Authorization") == f"Bearer {KEY}":
            return True
        self.send_json(401, {"error": {"message": "bad key"}})
        return False

    def do_GET(self):
        if self.path == "/health":
            return self.send_json(200, {"ok": True})
        if not self.authorized():
            return
        if self.path.rstrip("/") == "/v1/models":
            return self.send_json(200, {"object": "list", "data": [{"id": MODEL, "object": "model", "owned_by": "smoke"}]})
        self.send_json(404, {"error": {"message": "not found"}})

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        if not self.authorized():
            return
        if self.path.rstrip("/") != "/v1/chat/completions":
            return self.send_json(404, {"error": {"message": "not found"}})
        request = json.loads(body or b"{}")
        message = {"role": "assistant", "content": REPLY}
        if request.get("stream"):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            for chunk in (
                {"choices": [{"index": 0, "delta": message, "finish_reason": None}]},
                {"choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]},
            ):
                chunk.update({"id": "smoke", "object": "chat.completion.chunk", "model": MODEL})
                self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
            self.wfile.write(b"data: [DONE]\n\n")
            return
        self.send_json(200, {
            "id": "smoke",
            "object": "chat.completion",
            "model": MODEL,
            "choices": [{"index": 0, "message": message, "finish_reason": "stop"}],
            "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
        })

    def log_message(self, *args):
        pass


ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
