#!/usr/bin/env python3
"""Run a bash snippet on a PTY, appending output to a log file.

Long-running tools (yay is Go; mise is Rust) fully buffer stdout when it
is a file. A PTY makes them line-buffer so the live_log callback has
something to tail while the command is still running.

Writes a STREAM_CHANGED / STREAM_OK / STREAM_FAILED marker to real
stdout for Ansible's changed_when / failure output. Child output goes
only to the log.

Usage: pty_run.py LOG TITLE SNIPPET [REGEX] [LINES]
"""

from __future__ import annotations

import os
import pty
import re
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
    orig_out = os.dup(1)
    orig_err = os.dup(2)
    try:
        with open(log_path, "a", encoding="utf-8") as fh:
            fh.write(f"===== {title} {time.strftime('%Y-%m-%dT%H:%M:%S%z')} =====\n")
            fh.flush()
        log_fd = os.open(log_path, os.O_WRONLY | os.O_APPEND)
        try:
            os.dup2(log_fd, 1)
            os.dup2(log_fd, 2)
        finally:
            os.close(log_fd)
        status = pty.spawn(["bash", "-c", f"set -euo pipefail; {snippet}"])
        rc = os.waitstatus_to_exitcode(status)
    finally:
        os.dup2(orig_out, 1)
        os.dup2(orig_err, 2)
        os.close(orig_out)
        os.close(orig_err)

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
