"""Live-stream the packages install log while a streamed task runs.

Long mise installs (and anything else using pty_run.py) append stdout to
packages_live_log. Ansible's command module would otherwise stay silent
until the task finishes. This notification callback tails that file in a
background thread and prints each new line as it arrives.

Enable via ansible.cfg ``callbacks_enabled = live_log``.
Override the path with ANSIBLE_PACKAGES_LIVE_LOG.
"""

from __future__ import annotations

import os
import threading
import time

from ansible.plugins.callback import CallbackBase

DOCUMENTATION = r"""
  name: live_log
  type: notification
  short_description: Live-stream the packages install log
  description:
    - While a pty_run task is executing, tail packages_live_log and print
      each new line as it is written.
    - Quiet stretches print a heartbeat so a silent command does not look stuck.
  options:
    log_path:
      description: Absolute or ~-relative path of the log to tail.
      default: ~/.cache/dotfiles/ansible-packages.log
      env:
        - name: ANSIBLE_PACKAGES_LIVE_LOG
      ini:
        - section: callback_live_log
          key: log_path
    heartbeat:
      description: Seconds of silence before printing a still-running marker.
      default: 10
      type: float
      env:
        - name: ANSIBLE_PACKAGES_LIVE_LOG_HEARTBEAT
      ini:
        - section: callback_live_log
          key: heartbeat
    interval:
      description: Seconds between tail reads.
      default: 0.1
      type: float
      env:
        - name: ANSIBLE_PACKAGES_LIVE_LOG_INTERVAL
      ini:
        - section: callback_live_log
          key: interval
"""


def _task_is_stream(task) -> bool:
    if task is None:
        return False
    args = getattr(task, "args", None) or {}
    argv = args.get("argv") or []
    return any("pty_run.py" in str(part) for part in argv)


class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "notification"
    CALLBACK_NAME = "live_log"
    CALLBACK_NEEDS_ENABLED = True

    def __init__(self):
        super().__init__()
        self._path = None
        self._heartbeat = 10.0
        self._interval = 0.1
        self._offset = 0
        self._partial = ""
        self._stop = threading.Event()
        self._thread = None
        self._last_emit = 0.0

    def set_options(self, task_keys=None, var_options=None, direct=None):
        super().set_options(task_keys=task_keys, var_options=var_options, direct=direct)
        self._path = os.path.expanduser(self.get_option("log_path"))
        try:
            self._heartbeat = max(1.0, float(self.get_option("heartbeat")))
        except (TypeError, ValueError):
            self._heartbeat = 10.0
        try:
            self._interval = max(0.05, float(self.get_option("interval")))
        except (TypeError, ValueError):
            self._interval = 0.1

    def v2_playbook_on_task_start(self, task, is_conditional):
        if _task_is_stream(task):
            self._start_tail()

    def v2_runner_on_ok(self, result):
        self._stop_if_stream(result)

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self._stop_if_stream(result)

    def v2_runner_on_unreachable(self, result):
        self._stop_if_stream(result)

    def v2_runner_on_skipped(self, result):
        self._stop_if_stream(result)

    def v2_playbook_on_stats(self, stats):
        self._stop_tail()

    def _stop_if_stream(self, result):
        task = getattr(result, "_task", None)
        if _task_is_stream(task):
            self._stop_tail()

    def _start_tail(self):
        self._stop_tail()
        if self._path and os.path.isfile(self._path):
            try:
                self._offset = os.path.getsize(self._path)
            except OSError:
                self._offset = 0
        else:
            self._offset = 0
        self._partial = ""
        self._last_emit = time.monotonic()
        self._stop.clear()
        self._thread = threading.Thread(
            target=self._loop,
            name="live_log_tail",
            daemon=True,
        )
        self._thread.start()

    def _stop_tail(self):
        thread = self._thread
        if thread is None:
            return
        self._stop.set()
        thread.join(timeout=2)
        self._thread = None
        self._flush()
        if self._partial:
            self._display.display(f"| {self._partial}", screen_only=True)
            self._partial = ""

    def _loop(self):
        while not self._stop.wait(self._interval):
            if self._flush():
                self._last_emit = time.monotonic()
            elif (time.monotonic() - self._last_emit) >= self._heartbeat:
                self._display.display("| … still running", screen_only=True)
                self._last_emit = time.monotonic()

    def _flush(self) -> bool:
        if not self._path or not os.path.isfile(self._path):
            return False
        try:
            size = os.path.getsize(self._path)
        except OSError:
            return False
        if size < self._offset:
            self._offset = 0
            self._partial = ""
        if size == self._offset:
            return False
        try:
            with open(self._path, encoding="utf-8", errors="replace") as fh:
                fh.seek(self._offset)
                chunk = fh.read()
                self._offset = fh.tell()
        except OSError:
            return False
        data = self._partial + chunk
        if not data:
            return False
        if data[-1] in "\n\r":
            lines = [line for line in data.splitlines() if line]
            self._partial = ""
        else:
            parts = data.splitlines()
            lines = [line for line in parts[:-1] if line]
            self._partial = parts[-1] if parts else ""
        if not lines:
            return False
        for line in lines:
            self._display.display(f"| {line}", screen_only=True)
        return True
