#!/usr/bin/env python3
"""Minimal HTTP trigger server for dbt. POST /run executes dbt run."""
import http.server
import subprocess
import json
import os
from urllib.parse import unquote

DBT_PROJECT_DIR = "/dbt"
DBT_PROFILES_DIR = "/home/dbt_user/.dbt"
_API_KEY = os.environ.get("TRIGGER_API_KEY", "")


def _hop_timing_summary():
    """Fetch the most recent Hop workflow execution's slowest pipelines, to surface
    in the same Telegram notification that already reports the dbt run result."""
    try:
        import psycopg2
        conn = psycopg2.connect(
            host=os.environ.get("PG_HOSTNAME"),
            port=os.environ.get("PG_PORT", "5432"),
            dbname=os.environ.get("PG_DATABASE", "superque"),
            user=os.environ.get("DBT_USERNAME"),
            password=os.environ.get("DBT_PASSWORD"),
            connect_timeout=5,
        )
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT pipeline_name, duration_seconds
                    FROM bronze.hop_execution_log
                    WHERE execution_id = (SELECT MAX(execution_id) FROM bronze.hop_execution_log)
                    ORDER BY duration_seconds DESC
                    LIMIT 5
                    """
                )
                rows = cur.fetchall()
        finally:
            conn.close()
        if not rows:
            return None
        return "; ".join(f"{name} {int(dur)}s" for name, dur in rows)
    except Exception:
        return None


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._respond(200, {"status": "ok"})
        else:
            self._respond(404, {"error": "not found"})

    def _check_auth(self):
        if not _API_KEY or self.headers.get("X-Api-Key") != _API_KEY:
            self._respond(401, {"error": "unauthorized"})
            return False
        return True

    def do_POST(self):
        if not self._check_auth():
            return
        if self.path.startswith("/run-mercado-externo"):
            cmd = ["python3", "/usr/local/bin/mercado_externo_enriquecimento.py"]
            result = subprocess.run(cmd, capture_output=True, text=True)
            self._respond(200, {
                "returncode": result.returncode,
                "stdout": result.stdout[-4000:],
                "stderr": result.stderr[-2000:],
            })
        elif self.path.startswith("/run-cnpj"):
            mode = "incremental"
            if "?" in self.path:
                qs = self.path.split("?", 1)[1]
                for part in qs.split("&"):
                    if part.startswith("mode="):
                        mode = unquote(part[5:])
            cmd = ["python3", "/usr/local/bin/cnpj_enriquecimento.py"]
            if mode == "full":
                cmd.append("--full")
            result = subprocess.run(cmd, capture_output=True, text=True)
            self._respond(200, {
                "returncode": result.returncode,
                "stdout": result.stdout[-4000:],
                "stderr": result.stderr[-2000:],
            })
        elif self.path.startswith("/run"):
            select = None
            if "?" in self.path:
                qs = self.path.split("?", 1)[1]
                for part in qs.split("&"):
                    if part.startswith("select="):
                        select = unquote(part[7:])

            cmd = [
                "dbt", "run",
                "--project-dir", DBT_PROJECT_DIR,
                "--profiles-dir", DBT_PROFILES_DIR,
                "--target", "prod",
            ]
            if select:
                cmd += ["--select", select]
            else:
                cmd += ["--exclude", "tag:monthly"]

            result = subprocess.run(cmd, capture_output=True, text=True)
            response = {
                "returncode": result.returncode,
                "stdout": result.stdout[-4000:],
                "stderr": result.stderr[-2000:],
            }
            hop_timing = _hop_timing_summary()
            if hop_timing:
                response["hop_timing"] = hop_timing
            self._respond(200, response)
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
