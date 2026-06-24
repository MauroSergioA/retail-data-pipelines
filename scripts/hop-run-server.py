#!/usr/bin/env python3
"""HTTP trigger server for Apache Hop. POST /run starts a workflow in background."""
import http.server
import subprocess
import threading
import json
import os
import re
import datetime

_lock = threading.Lock()
_running = False
_API_KEY = os.environ.get("TRIGGER_API_KEY", "")

DEFAULT_WORKFLOW = "workflow_consinco_cold"
_WORKFLOW_RE = re.compile(r'^[\w-]+$')

_START_RE = re.compile(r"^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}) - (\S+) - Start of workflow execution")
_FINISH_RE = re.compile(r"^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}) - (\S+) - Execution finished on a local pipeline engine")


def _parse_ts(s):
    return datetime.datetime.strptime(s, "%Y/%m/%d %H:%M:%S")


def _log_timing(workflow, lines):
    """Parse Hop's own log lines to compute per-pipeline duration and persist to
    bronze.hop_execution_log. Each pipeline's duration is the delta to the previous
    pipeline's finish time (workflows run pipelines sequentially)."""
    workflow_started = None
    events = []
    for line in lines:
        m = _START_RE.match(line)
        if m:
            workflow_started = _parse_ts(m.group(1))
            continue
        m = _FINISH_RE.match(line)
        if m:
            events.append((_parse_ts(m.group(1)), m.group(2)))

    if not workflow_started or not events:
        return

    rows = []
    prev_ts = workflow_started
    for ts, name in events:
        rows.append((name, prev_ts, ts, (ts - prev_ts).total_seconds()))
        prev_ts = ts

    execution_id = workflow_started.strftime("%Y-%m-%d %H:%M:%S")
    values = ",".join(
        "('{}', '{}', '{}', '{}', '{}', {})".format(
            execution_id,
            workflow,
            name.replace("'", "''"),
            started.strftime("%Y-%m-%d %H:%M:%S"),
            finished.strftime("%Y-%m-%d %H:%M:%S"),
            duration,
        )
        for name, started, finished, duration in rows
    )
    sql = (
        "INSERT INTO bronze.hop_execution_log "
        "(execution_id, workflow_name, pipeline_name, started_at, finished_at, duration_seconds) "
        f"VALUES {values};"
    )

    env = os.environ.copy()
    env["PGPASSWORD"] = env.get("PG_PASSWORD", "")
    try:
        result = subprocess.run(
            [
                "psql",
                "-h", env.get("PG_HOSTNAME", ""),
                "-p", env.get("PG_PORT", "5432"),
                "-U", env.get("PG_USERNAME", "hop_user"),
                "-d", env.get("PG_DATABASE", "superque"),
                "-c", sql,
            ],
            env=env, capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            print(f"hop_execution_log insert failed: {result.stderr}", flush=True)
    except Exception as e:
        print(f"hop_execution_log insert failed: {e}", flush=True)


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
    lines = []
    try:
        proc = subprocess.Popen(
            [
                "/opt/hop/hop-run.sh",
                "--project=retail",
                "--environment=prod",
                f"--file=workflows/{workflow}.hwf",
                "--runconfig=local",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        for line in proc.stdout:
            print(line, end="", flush=True)
            lines.append(line.rstrip("\n"))
        proc.wait()
        _log_timing(workflow, lines)
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
