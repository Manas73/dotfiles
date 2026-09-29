#!/usr/bin/env python3
"""Run a bash snippet on a PTY, appending output to a log file.

Long-running tools (yay is Go; mise is Rust) fully buffer stdout when it
is a file. A PTY makes them line-buffer so the live_log callback has
something to tail while the command is still running.

Writes a STREAM_CHANGED / STREAM_OK / STREAM_FAILED marker to real
stdout for Ansible's changed_when / failure output. Child output goes
only to the log.

Not pty.spawn: on Python < 3.10 its copy loop keeps select()ing on
stdin after the child exits when the master reads EOF (macOS does this
instead of raising EIO). Ansible's stdin pipe never closes, so the task
hangs forever after mise finishes. Our loop ends when the child does.

Usage: pty_run.py LOG TITLE SNIPPET [REGEX] [LINES]
"""

from __future__ import annotations

import os
import re
import select
import subprocess
import sys
import time

DEFAULT_REGEX = r"install|pouring|fetch|download|build|upgrad"
DEFAULT_LINES = 20


def _read_from(path: str, offset: int) -> str:
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            fh.seek(offset)
            return fh.read()
    except OSError:
        return ""


def _run_on_pty(argv: list[str], log_fd: int) -> int:
    master, slave = os.openpty()
    try:
        proc = subprocess.Popen(
            argv,
            stdin=slave,
            stdout=slave,
            stderr=slave,
            start_new_session=True,
        )
    finally:
        os.close(slave)
    try:
        while True:
            ready, _, _ = select.select([master], [], [], 0.2)
            if not ready:
                # Child gone and nothing left to read: stop even if a
                # grandchild still holds the slave open.
                if proc.poll() is not None:
                    break
                continue
            try:
                data = os.read(master, 65536)
            except OSError:  # EIO on Linux once the slave closes.
                break
            if not data:  # EOF on macOS.
                break
            os.write(log_fd, data)
    finally:
        os.close(master)
    return proc.wait()


def _last_n_lines(text: str, n: int) -> str:
    lines = text.splitlines(keepends=True)
    return "".join(lines[-max(1, n) :])


def main(argv: list[str]) -> int:
    if len(argv) < 4:
        sys.stderr.write("usage: pty_run.py LOG TITLE SNIPPET [REGEX] [LINES]\n")
        return 2
    log_path, title, snippet = argv[1], argv[2], argv[3]
    regex = argv[4] if len(argv) > 4 and argv[4] else DEFAULT_REGEX
    try:
        lines = max(1, int(argv[5])) if len(argv) > 5 else DEFAULT_LINES
    except ValueError:
        lines = DEFAULT_LINES

    parent = os.path.dirname(log_path)
    if parent:
        os.makedirs(parent, exist_ok=True)

    start = os.path.getsize(log_path) if os.path.isfile(log_path) else 0
    with open(log_path, "a", encoding="utf-8") as fh:
        fh.write(f"===== {title} {time.strftime('%Y-%m-%dT%H:%M:%S%z')} =====\n")
        fh.flush()
    log_fd = os.open(log_path, os.O_WRONLY | os.O_APPEND)
    try:
        rc = _run_on_pty(["bash", "-c", f"set -euo pipefail; {snippet}"], log_fd)
    finally:
        os.close(log_fd)

    section = _read_from(log_path, start)
    last = _last_n_lines(section, lines)
    if rc != 0:
        sys.stdout.write("STREAM_FAILED\n")
        sys.stdout.write(last)
        sys.stdout.flush()
        return rc
    if re.search(regex, section, re.IGNORECASE):
        sys.stdout.write("STREAM_CHANGED\n")
    else:
        sys.stdout.write("STREAM_OK\n")
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
