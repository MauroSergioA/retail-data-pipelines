#!/usr/bin/env python3
"""HTTP trigger server for Apache Hop. POST /run starts a workflow in background."""
import http.server
import subprocess
import threading
import json
import os
import re

_lock = threading.Lock()
_running = False
_API_KEY = os.environ.get("TRIGGER_API_KEY", "")

DEFAULT_WORKFLOW = "workflow_consinco"
_WORKFLOW_RE = re.compile(r'^[\w-]+$')


def _parse_workflow(path):
    """Extract ?workflow= from path, defaulting to DEFAULT_WORKFLOW. Sanitized."""
    if "?" in path:
        qs = path.split("?", 1)[1]
        for part in qs.split("&"):
            if part.startswith("workflow="):
                name = part[9:]
                if _WORKFLOW_RE.match(name):
                    return name
    return DEFAULT_WORKFLOW


def _run(workflow):
    global _running
    try:
        subprocess.run(
            [
                "/opt/hop/hop-run.sh",
                "--project=retail",
                "--environment=prod",
                f"--file=workflows/{workflow}.hwf",
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

    def _check_auth(self):
        if not _API_KEY or self.headers.get("X-Api-Key") != _API_KEY:
            self._respond(401, {"error": "unauthorized"})
            return False
        return True

    def do_POST(self):
        global _running
        if not self._check_auth():
            return
        if self.path.startswith("/run"):
            workflow = _parse_workflow(self.path)
            with _lock:
                if _running:
                    self._respond(409, {"status": "already running"})
                    return
                _running = True
            threading.Thread(target=_run, args=(workflow,), daemon=True).start()
            self._respond(200, {"status": "started", "workflow": workflow})
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
