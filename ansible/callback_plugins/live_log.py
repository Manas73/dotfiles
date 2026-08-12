"""Print new lines from the packages live log during async polls.

Long brew/yay installs redirect their stdout to packages_live_log.
Ansible would otherwise stay silent until the task finishes. This
notification callback tails the log whenever an async job is polled
or completes, so the play output moves while the install runs.

Enable via ansible.cfg ``callbacks_enabled = live_log``.
Override the path with ANSIBLE_PACKAGES_LIVE_LOG.
"""

from __future__ import annotations

import os

from ansible.plugins.callback import CallbackBase

DOCUMENTATION = r"""
  name: live_log
  type: notification
  short_description: Tail the packages install log on async poll
  description:
    - On each async poll (and when a task finishes), print any new lines
      from the packages live log file.
  options:
    log_path:
      description: Absolute or ~-relative path of the log to tail.
      default: ~/.cache/dotfiles/ansible-packages.log
      env:
        - name: ANSIBLE_PACKAGES_LIVE_LOG
      ini:
        - section: callback_live_log
          key: log_path
    max_lines:
      description: Max new lines to print per poll. Older lines in the burst are skipped.
      default: 20
      type: int
      env:
        - name: ANSIBLE_PACKAGES_LIVE_LOG_LINES
      ini:
        - section: callback_live_log
          key: max_lines
"""


class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "notification"
    CALLBACK_NAME = "live_log"
    CALLBACK_NEEDS_ENABLED = True

    def __init__(self):
        super().__init__()
        self._offset = 0
        self._path = None
        self._max_lines = 20

    def set_options(self, task_keys=None, var_options=None, direct=None):
        super().set_options(task_keys=task_keys, var_options=var_options, direct=direct)
        raw = self.get_option("log_path")
        self._path = os.path.expanduser(raw)
        try:
            self._max_lines = max(1, int(self.get_option("max_lines")))
        except (TypeError, ValueError):
            self._max_lines = 20

    def v2_playbook_on_play_start(self, play):
        # Only stream lines written by this play, not leftover history.
        if self._path and os.path.isfile(self._path):
            self._offset = os.path.getsize(self._path)
        else:
            self._offset = 0

    def v2_runner_on_async_poll(self, result):
        self._flush()

    def v2_runner_on_async_ok(self, result):
        self._flush()

    def v2_runner_on_async_failed(self, result):
        self._flush()

    def v2_runner_on_ok(self, result):
        self._flush()

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self._flush()

    def _flush(self):
        if not self._path or not os.path.isfile(self._path):
            return
        try:
            size = os.path.getsize(self._path)
        except OSError:
            return
        if size < self._offset:
            self._offset = 0
        if size == self._offset:
            return
        try:
            with open(self._path, encoding="utf-8", errors="replace") as fh:
                fh.seek(self._offset)
                chunk = fh.read()
                self._offset = fh.tell()
        except OSError:
            return
        lines = chunk.splitlines()
        skipped = len(lines) - self._max_lines
        if skipped > 0:
            self._display.display(
                f"| … {skipped} earlier lines omitted …",
                screen_only=True,
            )
            lines = lines[-self._max_lines :]
        for line in lines:
            self._display.display(f"| {line}", screen_only=True)
