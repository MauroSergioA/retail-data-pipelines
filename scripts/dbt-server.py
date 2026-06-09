#!/usr/bin/env python3
"""Minimal HTTP trigger server for dbt. POST /run executes dbt run."""
import http.server
import subprocess
import json
import os

DBT_PROJECT_DIR = "/dbt"
DBT_PROFILES_DIR = "/home/dbt_user/.dbt"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._respond(200, {"status": "ok"})
        else:
            self._respond(404, {"error": "not found"})

    def do_POST(self):
        if self.path.startswith("/run"):
            select = None
            if "?" in self.path:
                qs = self.path.split("?", 1)[1]
                for part in qs.split("&"):
                    if part.startswith("select="):
                        select = part[7:]

            cmd = [
                "dbt", "run",
                "--project-dir", DBT_PROJECT_DIR,
                "--profiles-dir", DBT_PROFILES_DIR,
                "--target", "prod",
            ]
            if select:
                cmd += ["--select", select]

            result = subprocess.run(cmd, capture_output=True, text=True)
            status = 200 if result.returncode == 0 else 500
            self._respond(status, {
                "returncode": result.returncode,
                "stdout": result.stdout[-4000:],
                "stderr": result.stderr[-2000:],
            })
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
        print(f"{self.address_string()} - {fmt % args}")


if __name__ == "__main__":
    port = int(os.environ.get("DBT_SERVER_PORT", 8000))
    print(f"dbt trigger server listening on :{port}")
    http.server.HTTPServer(("0.0.0.0", port), Handler).serve_forever()
