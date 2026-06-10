#!/usr/bin/env python3
"""HTTP trigger server for Apache Hop. POST /run starts workflow_diario in background."""
import http.server
import subprocess
import threading
import json
import os

_lock = threading.Lock()
_running = False


def _run():
    global _running
    try:
        subprocess.run(
            [
                "/opt/hop/hop-run.sh",
                "--project=retail",
                "--environment=prod",
                "--file=workflows/workflow_diario.hwf",
                "--runconfig=local",
            ],
        )
    finally:
        with _lock:
            _running = False


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            with _lock:
                status = "running" if _running else "idle"
            self._respond(200, {"status": status})
        else:
            self._respond(404, {"error": "not found"})

    def do_POST(self):
        global _running
        if self.path == "/run":
            with _lock:
                if _running:
                    self._respond(409, {"status": "already running"})
                    return
                _running = True
            threading.Thread(target=_run, daemon=True).start()
            self._respond(200, {"status": "started"})
        else:
            self._respond(404, {"error": "not found"})

    def _respond(self, code, body):
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(payload))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}", flush=True)


if __name__ == "__main__":
    port = int(os.environ.get("HOP_TRIGGER_PORT", 8080))
    print(f"hop trigger server listening on :{port}", flush=True)
    http.server.HTTPServer(("0.0.0.0", port), Handler).serve_forever()
